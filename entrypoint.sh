#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"
HERMES_CONFIG_DIR="$HERMES_HOME/.hermes"

# Ensure required dirs exist
mkdir -p "$HERMES_CONFIG_DIR"/{sessions,memories,skills,cron,backups}

# ============================================================
# Apply defaults for vars that might be empty strings from Coolify
# ============================================================
if [ -z "$HERMES_MODEL" ]; then
    HERMES_MODEL="minimax/minimax-m2.7"
fi
if [ -z "$HERMES_INFERENCE_PROVIDER" ]; then
    HERMES_INFERENCE_PROVIDER="openrouter"
fi
HERMES_GATEWAY_PORT="${HERMES_GATEWAY_PORT:-18790}"
HERMES_BACKGROUND_NOTIFICATIONS="${HERMES_BACKGROUND_NOTIFICATIONS:-result}"
GATEWAY_ALLOW_ALL_USERS="${GATEWAY_ALLOW_ALL_USERS:-false}"
DISCORD_ALLOWED_USERS="${DISCORD_ALLOWED_USERS:-588858125126336544}"
DISCORD_REQUIRE_MENTION="${DISCORD_REQUIRE_MENTION:-false}"
DISCORD_ALLOW_BOTS="${DISCORD_ALLOW_BOTS:-all}"
DISCORD_FREE_RESPONSE_CHANNELS="${DISCORD_FREE_RESPONSE_CHANNELS:-1484900474363842643}"

# Write .env (hermes reads this via python-dotenv from $HERMES_CONFIG_DIR/.env)
cat > "$HERMES_CONFIG_DIR/.env" << ENVEOF
HERMES_INFERENCE_PROVIDER=${HERMES_INFERENCE_PROVIDER}
HERMES_GATEWAY_PORT=${HERMES_GATEWAY_PORT}
HERMES_BACKGROUND_NOTIFICATIONS=${HERMES_BACKGROUND_NOTIFICATIONS}
GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS}
DISCORD_ALLOWED_USERS=${DISCORD_ALLOWED_USERS}
DISCORD_REQUIRE_MENTION=${DISCORD_REQUIRE_MENTION}
DISCORD_ALLOW_BOTS=${DISCORD_ALLOW_BOTS}
DISCORD_FREE_RESPONSE_CHANNELS=${DISCORD_FREE_RESPONSE_CHANNELS}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
# --- Bot Coordination ---
BOT_COORDINATION_DB_HOST=${BOT_COORDINATION_DB_HOST:-pg-nanachi}
BOT_COORDINATION_DB_PORT=${BOT_COORDINATION_DB_PORT:-5432}
BOT_COORDINATION_DB_USER=${BOT_COORDINATION_DB_USER:-postgres}
BOT_COORDINATION_DB_PASS=${BOT_COORDINATION_DB_PASS:-WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL}
BOT_COORDINATION_DB_NAME=${BOT_COORDINATION_DB_NAME:-projects}
# --- Marketing Director Tools ---
ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY:-}
FALAI_API_KEY=${FALAI_API_KEY:-}
GH_TOKEN=${GH_TOKEN:-}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
POSTIZ_API_KEY=${POSTIZ_API_KEY:-}
POSTIZ_WEBHOOK_SECRET=${POSTIZ_WEBHOOK_SECRET:-}
MINIMAX_API_KEY=${MINIMAX_API_KEY:-}
CONTENT_REPO=${CONTENT_REPO:-https://github.com/yevgeniusr/content-studio}
ENVEOF

# Write config.yaml at the correct location: ~/.hermes/config.yaml
# This is where hermes reads the model from
cat > "$HERMES_CONFIG_DIR/config.yaml" << CFGEOF
model:
  default: "${HERMES_MODEL}"
  provider: "${HERMES_INFERENCE_PROVIDER}"
  base_url: "https://openrouter.ai/api/v1"
CFGEOF

chown -R hermes:hermes "$HERMES_CONFIG_DIR"

# ── Git credentials for push access ──────────────────────────────────────────
# GITHUB_TOKEN enables Hermess to push code/content changes to GitHub
if [ -n "$GITHUB_TOKEN" ]; then
    mkdir -p /home/hermes/.config/gh
    printf "protocol=https\nhost=github.com\nusername=git\npassword=%s\n" "$GITHUB_TOKEN" > /home/hermes/.config/gh/credentials
    chmod 600 /home/hermes/.config/gh/credentials
    git config --global credential.helper store
    git config --global credential.helper "store --file /home/hermes/.config/gh/credentials"
    echo "[OK] GitHub push access configured"
fi

# ── Write bot_coord.py at runtime (not build time) ────────────────────────────
# This ensures latest code is always used, bypassing Docker layer cache
cat > /home/hermes/bot_coord.py << 'BOTCOORD_EOF'
#!/usr/bin/env python3
"""
bot_coord.py — Nanachi ↔ Hermes bot messaging via shared Postgres table.
Supports real-time LISTEN/NOTIFY and polling fallback.
"""
import json, os, sys, argparse, select
from datetime import datetime
try:
    import psycopg2
except ImportError:
    print(json.dumps({"error": "psycopg2 not installed"}))
    sys.exit(1)

def get_db_config():
    return {
        "host": os.environ.get("BOT_COORDINATION_DB_HOST", "pg-nanachi"),
        "port": int(os.environ.get("BOT_COORDINATION_DB_PORT", "5432")),
        "user": os.environ.get("BOT_COORDINATION_DB_USER", "postgres"),
        "password": os.environ.get("BOT_COORDINATION_DB_PASS", ""),
        "dbname": os.environ.get("BOT_COORDINATION_DB_NAME", "projects"),
    }

def get_conn(autocommit=False):
    cfg = get_db_config()
    conn = psycopg2.connect(**cfg)
    if autocommit:
        conn.autocommit = True
    return conn

def cmd_setup():
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS "bot_messages" (
                id SERIAL PRIMARY KEY,
                sender VARCHAR(50) NOT NULL,
                recipient VARCHAR(50) NOT NULL,
                content TEXT NOT NULL,
                thread_id VARCHAR(100),
                status VARCHAR(20) NOT NULL DEFAULT 'unread',
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                read_at TIMESTAMPTZ
            )
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_bot_messages_recipient_status
                ON "bot_messages"(recipient, status, created_at)
        """)
        conn.commit()
    print(json.dumps({"ok": True, "message": "Table ready"}))

def cmd_read(my_name):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, sender, content, thread_id, created_at
            FROM "bot_messages"
            WHERE recipient = %s AND status = 'unread'
            ORDER BY created_at ASC LIMIT 20
        """, (my_name,))
        rows = [{"id": r[0], "from": r[1], "content": r[2],
                 "thread_id": r[3], "created_at": r[4].isoformat()}
                for r in cur.fetchall()]
        print(json.dumps({"messages": rows}))

def cmd_mark(msg_id):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE \"bot_messages\" SET status='read', read_at=NOW() WHERE id=%s", (msg_id,))
        conn.commit()
    print(json.dumps({"ok": True, "id": int(msg_id)}))

def cmd_post(sender, recipient, content, thread_id=None):
    channel = f"{recipient}_msg"
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO "bot_messages" (sender, recipient, content, thread_id, status)
            VALUES (%s,%s,%s,%s,'unread') RETURNING id, created_at
        """, (sender, recipient, content, thread_id))
        row = cur.fetchone()
        conn.commit()
        try:
            cur.execute(f"NOTIFY {channel}, %s", (str(row[0]),))
        except Exception as e:
            print(f"  (notify failed: {e})", file=sys.stderr)
        print(json.dumps({"ok": True, "id": row[0], "notified": channel}))

def cmd_listen(my_name, timeout=55):
    channel = f"{my_name}_msg"
    conn = get_conn(autocommit=True)
    cur = conn.cursor()
    cur.execute(f"LISTEN {channel}")
    print(json.dumps({"ok": True, "listening": channel, "timeout": timeout}))
    sys.stdout.flush()
    deadline = None if timeout == 0 else datetime.now().timestamp() + timeout
    while True:
        remaining = max(0.1, deadline - datetime.now().timestamp()) if deadline else 30
        if select.select([conn], [], [], min(remaining, 30)) != ([],[],[]):
            conn.poll()
            for notify in conn.notifies:
                cur.execute('SELECT id,sender,content,thread_id,created_at FROM "bot_messages" WHERE id=%s AND recipient=%s AND status=%s',
                           (notify.payload, my_name, 'unread'))
                row = cur.fetchone()
                if row:
                    msg = {"id":row[0],"from":row[1],"content":row[2],"thread_id":row[3],"created_at":row[4].isoformat()}
                    cur.execute('UPDATE "bot_messages" SET status=%s,read_at=NOW() WHERE id=%s', ('read',notify.payload))
                    print(json.dumps({"type":"message",**msg}))
                    sys.stdout.flush()
            conn.notifies = []
        else:
            cur.execute('SELECT id,sender,content,thread_id,created_at FROM "bot_messages" WHERE recipient=%s AND status=%s ORDER BY created_at ASC LIMIT 5',
                       (my_name,'unread'))
            for row in cur.fetchall():
                msg = {"id":row[0],"from":row[1],"content":row[2],"thread_id":row[3],"created_at":row[4].isoformat()}
                cur.execute('UPDATE "bot_messages" SET status=%s,read_at=NOW() WHERE id=%s', ('read',row[0]))
                print(json.dumps({"type":"message",**msg}))
                sys.stdout.flush()
        if deadline and datetime.now().timestamp() > deadline:
            break
    conn.close()
    print(json.dumps({"ok": True, "done": True}))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("setup")
    r = sub.add_parser("read"); r.add_argument("my_name")
    m = sub.add_parser("mark"); m.add_argument("msg_id", type=int)
    p = sub.add_parser("post"); p.add_argument("sender"); p.add_argument("recipient"); p.add_argument("content")
    p.add_argument("--thread", dest="thread_id")
    l = sub.add_parser("listen"); l.add_argument("my_name"); l.add_argument("--timeout", type=int, default=55)
    args = parser.parse_args()
    if args.cmd == "setup": cmd_setup()
    elif args.cmd == "read": cmd_read(args.my_name)
    elif args.cmd == "mark": cmd_mark(args.msg_id)
    elif args.cmd == "post": cmd_post(args.sender, args.recipient, args.content, args.thread_id)
    elif args.cmd == "listen": cmd_listen(args.my_name, args.timeout)
    else: parser.print_help()
BOTCOORD_EOF

chmod +x /home/hermes/bot_coord.py
echo "[hermes] bot_coord.py written ($(wc -l < /home/hermes/bot_coord.py) lines)"

# Run as hermes user
exec su hermes -c "
    export HOME=/home/hermes
    export HERMES_INFERENCE_PROVIDER='${HERMES_INFERENCE_PROVIDER}'
    export OPENROUTER_API_KEY='${OPENROUTER_API_KEY:-}'
    export DISCORD_BOT_TOKEN='${DISCORD_BOT_TOKEN:-}'
    cd /home/hermes

    # Start bot_coord listener as background daemon (real-time DB message processing)
    python3 bot_coord.py listen hermes &
    echo \"[hermes] bot_coord listener started (PID \$!)\"

    exec /opt/venv/bin/hermes gateway run
"
