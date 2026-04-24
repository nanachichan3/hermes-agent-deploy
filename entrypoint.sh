#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/home/hermes}"
HERMES_CONFIG_DIR="$HERMES_HOME/.hermes"

# Agent workspaces (mounted from host or volumes)
AGENTS_DIR="/data/agents"
mkdir -p "$AGENTS_DIR"/{cto,cmo,ceo}

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
BROWSER_PASSWORD="${BROWSER_PASSWORD:-hermes2026}"

# ── OPENCLAW_AGENTS_JSON ───────────────────────────────────────────────────────
# Defines 3 agents: CTO (hermes), CMO, CEO — all with shared browser sidecar
# Each agent has its own workspace, session store, and bot_messages channel
CATALOG_VALUE="[
  {
    \"id\": \"cto\",
    \"name\": \"CTO\",
    \"workspace\": \"/data/agents/cto\",
    \"default\": false,
    \"subagents\": { \"allowAgents\": [\"main\",\"cto\",\"cmo\",\"ceo\"] }
  },
  {
    \"id\": \"cmo\",
    \"name\": \"CMO\",
    \"workspace\": \"/data/agents/cmo\",
    \"default\": false,
    \"subagents\": { \"allowAgents\": [\"main\",\"cto\",\"cmo\",\"ceo\"] }
  },
  {
    \"id\": \"ceo\",
    \"name\": \"CEO\",
    \"workspace\": \"/data/agents/ceo\",
    \"default\": false,
    \"subagents\": { \"allowAgents\": [\"main\",\"cto\",\"cmo\",\"ceo\"] }
  }
]"
export OPENCLAW_AGENTS_JSON="${OPENCLAW_AGENTS_JSON:-$CATALOG_VALUE}"

# ── AIO Browser Extension ───────────────────────────────────────────────────────
# SKIPPED: kimfindly/AIO releases URL is 404 — re-add when a valid URL is found
# AIO_VERSION="1.2.1"
# AIO_DIR="/opt/aio"
# if [ ! -d "$AIO_DIR" ]; then
#     echo "[hermes] Installing AIO browser extension v${AIO_VERSION}..."
#     curl -sL "https://github.com/kimfindly/AIO/releases/download/v${AIO_VERSION}/AIO.zip" -o /tmp/aio.zip && \
#     unzip -q /tmp/aio.zip -d "$AIO_DIR" && \
#     rm /tmp/aio.zip && \
#     echo "[hermes] AIO installed at $AIO_DIR"
# else
#     echo "[hermes] AIO already installed at $AIO_DIR"
# fi

# AIO_CDP_URL was used to inject extension ID into browser startup — skipped without AIO
AIO_CDP_URL="http://browser:3000"

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
BOT_COORDINATION_DB_HOST=${BOT_COORDINATION_DB_HOST:-x0k4w8404wckwwcswg808gco}
BOT_COORDINATION_DB_PORT=${BOT_COORDINATION_DB_PORT:-5432}
BOT_COORDINATION_DB_USER=${BOT_COORDINATION_DB_USER:-postgres}
BOT_COORDINATION_DB_PASS=${BOT_COORDINATION_DB_PASS:-WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL}
BOT_COORDINATION_DB_NAME=${BOT_COORDINATION_DB_NAME:-projects}
# --- MCP Servers ---
POSTGRES_MCP_DATABASE_URL=${POSTGRES_MCP_DATABASE_URL:-postgres://postgres:WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL@x0k4w8404wckwwcswg808gco:5432/postgres}
PROJECTS_MCP_DATABASE_URL=${PROJECTS_MCP_DATABASE_URL:-postgres://postgres:WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL@x0k4w8404wckwwcswg808gco:5432/projects}
# --- Marketing Director Tools ---
ELEVENLABS_API_KEY=${ELEVENLABS_API_KEY:-}
FALAI_API_KEY=${FALAI_API_KEY:-}
GH_TOKEN=${GH_TOKEN:-}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
POSTIZ_API_KEY=${POSTIZ_API_KEY:-}
POSTIZ_WEBHOOK_SECRET=${POSTIZ_WEBHOOK_SECRET:-}
MINIMAX_API_KEY=${MINIMAX_API_KEY:-}
CONTENT_REPO=${CONTENT_REPO:-https://github.com/yevgeniusr/content-studio}
# --- Browser Sidecar ---
BROWSER_PASSWORD=${BROWSER_PASSWORD}
AIO_CDP_URL=${AIO_CDP_URL}
# --- Multi-Agent ---
OPENCLAW_AGENTS_JSON=${OPENCLAW_AGENTS_JSON}
# --- Mem0 Memory ---
MEM0_URL=${MEM0_URL:-http://mem0:5000}
MEM0_API_KEY=${MEM0_API_KEY:-mem0-self-hosted}
ENVEOF

# Write config.yaml at the correct location: ~/.hermes/config.yaml
# This is where hermes reads the model and memory settings from
cat > "$HERMES_CONFIG_DIR/config.yaml" << CFGEOF
model:
  default: "${HERMES_MODEL}"
  provider: "${HERMES_INFERENCE_PROVIDER}"
  base_url: "https://openrouter.ai/api/v1"

memory:
  provider: mem0
CFGEOF

# Write openclaw.json with MCP server config (postgres + projects DBs + browser)
BROWSER_CDP_URL="http://browser:3000"
cat > "$HERMES_CONFIG_DIR/openclaw.json" << EOF
{
  "mcp": {
    "servers": {
      "postgres": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", "postgres://postgres:WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL@x0k4w8404wckwwcswg808gco:5432/postgres"]
      },
      "projects": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-postgres", "postgres://postgres:WFBGCo6cjCf7NbxVfkPSe5x0P41v3d27MowubhpPmfk9CgrfcMhBUvp8lyCfjobL@x0k4w8404wckwwcswg808gco:5432/projects"]
      }
    }
  },
  "browser": {
    "cdpUrl": "${BROWSER_CDP_URL}"
  },
  "session": {
    "browser": {
      "cdpUrl": "${BROWSER_CDP_URL}"
    }
  }
}
EOF

chown -R hermes:hermes "$HERMES_CONFIG_DIR"

# Install Nanachi's company framework skill (skills are copied at build time to /home/hermes/skills/)
if [ -d /home/hermes/skills/projects-db-framework ]; then
    mkdir -p "$HERMES_CONFIG_DIR/skills"
    cp -r /home/hermes/skills/projects-db-framework "$HERMES_CONFIG_DIR/skills/" 2>/dev/null || true
    echo "[OK] Installed projects-db-framework skill"
fi

# GITHUB_TOKEN enables Hermes to push code/content changes to GitHub
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
bot_coord.py — Multi-agent bot messaging via shared Postgres table.
Supports real-time LISTEN/NOTIFY for CTO (hermes), CMO, and CEO agents.
"""
import json, os, sys, argparse, select, time
from datetime import datetime
try:
    import psycopg2
    from psycopg2 import extensions
except ImportError:
    print(json.dumps({"error": "psycopg2 not installed"}), flush=True)
    sys.exit(1)

def get_db_config():
    return {
        "host": os.environ.get("BOT_COORDINATION_DB_HOST", "x0k4w8404wckwwcswg808gco"),
        "port": int(os.environ.get("BOT_COORDINATION_DB_PORT", "5432")),
        "user": os.environ.get("BOT_COORDINATION_DB_USER", "postgres"),
        "password": os.environ.get("BOT_COORDINATION_DB_PASS", ""),
        "dbname": os.environ.get("BOT_COORDINATION_DB_NAME", "projects"),
        "connect_timeout": 10,
        "options": "-c client_encoding=UTF8",
    }

def get_conn(autocommit=True):
    cfg = get_db_config()
    try:
        conn = psycopg2.connect(**cfg)
        if autocommit:
            conn.autocommit = True
        print(json.dumps({"ok": True, "db_connected": cfg["dbname"], "host": cfg["host"]}), flush=True)
        return conn
    except Exception as e:
        print(json.dumps({"error": f"connection failed: {e}"}), flush=True)
        raise

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
        cur.execute("CREATE INDEX IF NOT EXISTS idx_bot_messages_recipient_status ON \"bot_messages\"(recipient, status, created_at)")
        conn.commit()
    print(json.dumps({"ok": True, "message": "Table ready"}), flush=True)

def cmd_read(my_name):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute('SELECT id, sender, content, thread_id, created_at FROM "bot_messages" WHERE recipient = %s AND status = %s ORDER BY created_at ASC LIMIT 20', (my_name, 'unread'))
        rows = [{"id": r[0], "from": r[1], "content": r[2], "thread_id": r[3], "created_at": r[4].isoformat()} for r in cur.fetchall()]
        print(json.dumps({"messages": rows}), flush=True)

def cmd_mark(msg_id):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute('UPDATE "bot_messages" SET status=%s, read_at=NOW() WHERE id=%s', ('read', msg_id))
        conn.commit()
    print(json.dumps({"ok": True, "id": int(msg_id)}), flush=True)

def cmd_post(sender, recipient, content, thread_id=None):
    channel = f"{recipient}_msg"
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute('INSERT INTO "bot_messages" (sender, recipient, content, thread_id, status) VALUES (%s,%s,%s,%s,%s) RETURNING id, created_at', (sender, recipient, content, thread_id, 'unread'))
        row = cur.fetchone()
        conn.commit()
        try:
            cur.execute(f"NOTIFY {channel}, %s", (str(row[0]),))
        except Exception as e:
            print(json.dumps({"warn": f"notify failed: {e}"}), flush=True)
        print(json.dumps({"ok": True, "id": row[0], "notified": channel, "ts": row[1].isoformat()}), flush=True)

def cmd_listen(my_name, timeout=0):
    """
    Robust real-time listener for a named agent.
    Supported agents: cto (hermes), cmo, ceo
    """
    channel = f"{my_name}_msg"
    print(json.dumps({"ok": True, "action": "listen_start", "agent": my_name, "channel": channel, "timeout": timeout}), flush=True)
    
    conn = get_conn(autocommit=True)
    cur = conn.cursor()
    cur.execute(f"LISTEN {channel}")
    print(json.dumps({"ok": True, "listening": channel, "phase": "registered"}), flush=True)
    
    last_poll = time.time()
    idle_count = 0
    
    while True:
        now = time.time()
        
        # Periodic DB poll every 30 seconds as fallback
        if now - last_poll >= 30:
            cur.execute('SELECT id, sender, content, thread_id, created_at FROM "bot_messages" WHERE recipient=%s AND status=%s ORDER BY created_at ASC LIMIT 5', (my_name, 'unread'))
            for row in cur.fetchall():
                msg = {"id": row[0], "from": row[1], "content": row[2], "thread_id": row[3], "created_at": row[4].isoformat()}
                cur.execute('UPDATE "bot_messages" SET status=%s, read_at=NOW() WHERE id=%s', ('read', row[0]))
                print(json.dumps({"type": "message", "source": "poll", **msg}), flush=True)
            last_poll = now
        
        state = conn.poll(timeout=5)
        
        if state == extensions.POLL_OK:
            idle_count += 1
            if idle_count % 12 == 0:
                print(json.dumps({"ok": True, "idle": idle_count, "since": "last_notify"}), flush=True)
            continue
        
        elif state == extensions.POLL_READ:
            conn.poll()
            for notify in conn.notifies:
                msg_id = notify.payload
                cur.execute('SELECT id, sender, content, thread_id, created_at FROM "bot_messages" WHERE id=%s AND recipient=%s AND status=%s', (msg_id, my_name, 'unread'))
                row = cur.fetchone()
                if row:
                    msg = {"id": row[0], "from": row[1], "content": row[2], "thread_id": row[3], "created_at": row[4].isoformat()}
                    cur.execute('UPDATE "bot_messages" SET status=%s, read_at=NOW() WHERE id=%s', ('read', msg_id))
                    print(json.dumps({"type": "message", "source": "notify", **msg}), flush=True)
                else:
                    print(json.dumps({"warn": f"msg {msg_id} not found or already read"}), flush=True)
            conn.notifies = []
            idle_count = 0
        
        elif state == extensions.POLL_ERROR:
            print(json.dumps({"error": "POLL_ERROR, reconnecting"}), flush=True)
            time.sleep(2)
            conn.close()
            conn = get_conn(autocommit=True)
            cur = conn.cursor()
            cur.execute(f"LISTEN {channel}")
            last_poll = time.time()

if __name__ == "__main__":
    print(json.dumps({"started": "bot_coord.py", "args": sys.argv}), flush=True)
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("setup")
    r = sub.add_parser("read"); r.add_argument("my_name")
    m = sub.add_parser("mark"); m.add_argument("msg_id", type=int)
    p = sub.add_parser("post"); p.add_argument("sender"); p.add_argument("recipient"); p.add_argument("content")
    p.add_argument("--thread", dest="thread_id")
    l = sub.add_parser("listen"); l.add_argument("my_name"); l.add_argument("--timeout", type=int, default=0)
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

# ── Mem0 Client ─────────────────────────────────────────────────────────────────
# Simple REST-based mem0 client (uses built-in urllib — no extra deps needed)
cat > /home/hermes/mem0_client.py << 'MEM0_EOF'
#!/usr/bin/env python3
"""
mem0_client.py — Direct REST client for Mem0 memory (self-hosted).
Uses urllib (built-in) to avoid external dependencies beyond mem0ai.
"""
import json, os, sys, urllib.request, urllib.error

MEM0_URL = os.environ.get("MEM0_URL", "http://mem0:5000").rstrip("/")
MEM0_API_KEY = os.environ.get("MEM0_API_KEY", "mem0-self-hosted")
USER_ID = os.environ.get("MEM0_USER_ID", "588858125126336544")  # nanachi Discord ID

def api_request(method, path, data=None):
    url = f"{MEM0_URL}{path}"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {MEM0_API_KEY}"
    }
    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            err_body = e.read().decode("utf-8")
        except:
            err_body = str(e)
        print(json.dumps({"error": f"HTTP {e.code}", "detail": err_body}), flush=True)
        return None
    except Exception as e:
        print(json.dumps({"error": str(e)}), flush=True)
        return None

def cmd_add(text, agent="hermes"):
    """Store a memory."""
    payload = {
        "messages": [{"role": "user", "content": text}],
        "user_id": USER_ID,
        "agent_id": agent
    }
    result = api_request("POST", "/memories", payload)
    if result:
        print(json.dumps({"ok": True, "action": "add", "result": result}), flush=True)
    return result

def cmd_search(query, agent="hermes"):
    """Search memories."""
    payload = {
        "query": query,
        "user_id": USER_ID,
        "agent_id": agent,
        "limit": 5
    }
    result = api_request("POST", "/memories/search", payload)
    if result:
        print(json.dumps({"ok": True, "action": "search", "results": result}), flush=True)
    return result

def cmd_history(agent="hermes", limit=20):
    """Get memory history."""
    result = api_request("GET", f"/memories?user_id={USER_ID}&agent_id={agent}&limit={limit}")
    if result:
        print(json.dumps({"ok": True, "action": "history", "memories": result}), flush=True)
    return result

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Mem0 REST client")
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("history")
    a = sub.add_parser("add"); a.add_argument("text"); a.add_argument("--agent", default="hermes")
    s = sub.add_parser("search"); s.add_argument("query"); s.add_argument("--agent", default="hermes")
    args = parser.parse_args()

    if args.cmd == "add":
        cmd_add(args.text, args.agent)
    elif args.cmd == "search":
        cmd_search(args.query, args.agent)
    elif args.cmd == "history":
        cmd_history()
    else:
        parser.print_help()
MEM0_EOF

chmod +x /home/hermes/mem0_client.py
echo "[hermes] mem0_client.py written ($(wc -l < /home/hermes/mem0_client.py) lines)"
echo "[hermes] bot_coord.py written ($(wc -l < /home/hermes/bot_coord.py) lines)"

# ── Wait for browser sidecar to be ready ─────────────────────────────────────
# Browser sidecar removed from docker-compose — no browser wait needed
echo "[hermes] No browser sidecar (browser removed for reliability)"

# Run as hermes user
exec su hermes -c "
    export HOME=/home/hermes
    export HERMES_INFERENCE_PROVIDER='${HERMES_INFERENCE_PROVIDER}'
    export OPENROUTER_API_KEY='${OPENROUTER_API_KEY:-}'
    export DISCORD_BOT_TOKEN='${DISCORD_BOT_TOKEN:-}'
    export BROWSER_PASSWORD='${BROWSER_PASSWORD}'
    export AIO_CDP_URL='${AIO_CDP_URL}'
    export OPENCLAW_AGENTS_JSON='${OPENCLAW_AGENTS_JSON}'
    export MEM0_URL='${MEM0_URL}'
    export MEM0_API_KEY='${MEM0_API_KEY}'
    cd /home/hermes

    # Start bot_coord listener as background daemon for ALL 3 agents
    # CTO (hermes) — primary channel
    python3 bot_coord.py listen cto --timeout 0 &
    echo \"[hermes] bot_coord listener started for CTO/cTO (PID \$!)\"

    # CMO — marketing agent channel
    python3 bot_coord.py listen cmo --timeout 0 &
    echo \"[hermes] bot_coord listener started for CMO (PID \$!)\"

    # CEO — coordination agent channel
    python3 bot_coord.py listen ceo --timeout 0 &
    echo \"[hermes] bot_coord listener started for CEO (PID \$!)\"

    # Set up 30-min heartbeat cron (checks bot_messages, executes tasks, replies to nanachi)
    # Write cron job directly to the cron store (JSON file)
    CRON_DIR=\"$HOME/.hermes/cron\"
    mkdir -p \"\$CRON_DIR\"
    CRON_FILE=\"\$CRON_DIR/jobs.json\"
    # Add heartbeat cron if not already present
    if [ ! -f \"\$CRON_FILE\" ] || ! grep -q '30min heartbeat' \"\$CRON_FILE\" 2>/dev/null; then
        echo '[
          {
            \"id\": \"nanachi-heartbeat\",
            \"name\": \"30min heartbeat\",
            \"cron\": \"*/30 * * * *\",
            \"session\": \"hermes\",
            \"message\": \"Check projects.bot_messages for tasks from nanachi. Execute tasks. Reply results to nanachi in bot_messages.\",
            \"announce\": true,
            \"enabled\": true
          }
        ]' > \"\$CRON_FILE\" 2>/dev/null || true
        echo \"[hermes] Heartbeat cron configured (every 30 min)\"
    fi

    exec /opt/venv/bin/hermes gateway run
"
