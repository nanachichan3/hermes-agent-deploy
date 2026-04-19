#!/usr/bin/env python3
"""
bot_coord.py — Nanachi ↔ Hermes bot messaging via shared Postgres table.
Supports real-time LISTEN/NOTIFY and polling fallback.
"""
import json, os, sys, argparse, select, time
from datetime import datetime
try:
    import psycopg2
    from psycopg2 import sql
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
    Robust real-time listener. Uses conn.poll() in a loop.
    Falls back to polling DB every 30s if NOTIFY is missed.
    """
    channel = f"{my_name}_msg"
    print(json.dumps({"ok": True, "action": "listen_start", "channel": channel, "timeout": timeout}), flush=True)
    
    conn = get_conn(autocommit=True)
    cur = conn.cursor()
    cur.execute(f"LISTEN {channel}")
    print(json.dumps({"ok": True, "listening": channel, "phase": "registered"}), flush=True)
    
    last_poll = time.time()
    idle_count = 0
    
    while True:
        # Use poll() with a short timeout to check for notifies
        # Also do a hard timeout check for the idle counter
        now = time.time()
        
        # Check if we should do a periodic DB poll (every 30 seconds)
        if now - last_poll >= 30:
            # DB poll to catch any missed messages
            cur.execute('SELECT id, sender, content, thread_id, created_at FROM "bot_messages" WHERE recipient=%s AND status=%s ORDER BY created_at ASC LIMIT 5', (my_name, 'unread'))
            for row in cur.fetchall():
                msg = {"id": row[0], "from": row[1], "content": row[2], "thread_id": row[3], "created_at": row[4].isoformat()}
                cur.execute('UPDATE "bot_messages" SET status=%s, read_at=NOW() WHERE id=%s', ('read', row[0]))
                print(json.dumps({"type": "message", "source": "poll", **msg}), flush=True)
            last_poll = now
        
        # Wait for notification using poll() - this is the key psycopg2 method
        # poll() returns: 0 = OK, 1 = READ, 2 = WRITE, -1 = ERROR
        state = conn.poll(5)
        
        if state == psycopg2.extensions.POLL_OK:
            # Connection is fine, no notify received this cycle
            idle_count += 1
            if idle_count % 12 == 0:  # Log every minute
                print(json.dumps({"ok": True, "idle": idle_count, "since": "last_notify"}), flush=True)
            continue
        
        elif state == psycopg2.extensions.POLL_READ:
            # Socket is readable - check for notifies
            conn.poll()
            for notify in conn.notifies:
                msg_id = notify.payload
                print(json.dumps({"ok": True, "notify_received": msg_id, "channel": notify.channel}), flush=True)
                # Fetch and process the actual message from DB
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
        
        elif state == psycopg2.extensions.POLL_WRITE:
            # Socket needs writing - unusual for LISTEN but handle it
            conn.poll()
        
        elif state == psycopg2.extensions.POLL_ERROR:
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
