#!/usr/bin/env python3
"""
bot_coord.py — Nanachi ↔ Nezuko bot messaging via shared Postgres table.

Usage:
  python3 bot_coord.py read <my_name>          # Read unread messages (polling)
  python3 bot_coord.py post <sender> <recipient> <content> [--thread <thread_id>]
  python3 bot_coord.py mark <id>               # Mark message as read
  python3 bot_coord.py listen <my_name>         # Real-time listener (LISTEN/NOTIFY)
  python3 bot_coord.py setup                   # Create the table (run once)

Environment variables:
  BOT_COORDINATION_DB_HOST, BOT_COORDINATION_DB_PORT,
  BOT_COORDINATION_DB_USER, BOT_COORDINATION_DB_PASS,
  BOT_COORDINATION_DB_NAME

Real-time mode:
  python3 bot_coord.py listen nanachi           # Listen for messages addressed to nanachi
  python3 bot_coord.py listen hermes            # Listen for messages addressed to hermes

  Each bot listens on their own channel: nanachi_msg, hermes_msg
  When a message is posted, NOTIFY is sent on the recipient's channel.
  The listener prints the message and marks it as read automatically.
"""

import json
import os
import sys
import argparse
import select
from datetime import datetime

try:
    import psycopg2
except ImportError:
    print(json.dumps({"error": "psycopg2 not installed. Run: pip install psycopg2-binary"}))
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
            CREATE TABLE IF NOT EXISTS bot_messages (
                id          SERIAL PRIMARY KEY,
                sender      VARCHAR(50)  NOT NULL,
                recipient   VARCHAR(50)  NOT NULL,
                content     TEXT         NOT NULL,
                thread_id   VARCHAR(100),
                status      VARCHAR(20)  NOT NULL DEFAULT 'unread',
                created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
                read_at     TIMESTAMPTZ
            )
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_bot_messages_recipient_status
                ON bot_messages(recipient, status, created_at)
        """)
        conn.commit()
    print(json.dumps({"ok": True, "message": "Table bot_messages ready"}))


def cmd_read(my_name):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, sender, content, thread_id, created_at
            FROM bot_messages
            WHERE recipient = %s AND status = 'unread'
            ORDER BY created_at ASC
            LIMIT 20
        """, (my_name,))
        rows = []
        for (mid, sender, content, thread_id, created_at) in cur.fetchall():
            rows.append({
                "id": mid,
                "from": sender,
                "content": content,
                "thread_id": thread_id,
                "created_at": created_at.isoformat(),
            })
        if rows:
            print(json.dumps({"messages": rows}))
        else:
            print(json.dumps({"messages": []}))


def cmd_mark(msg_id):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            UPDATE bot_messages
            SET status = 'read', read_at = NOW()
            WHERE id = %s
        """, (msg_id,))
        conn.commit()
    print(json.dumps({"ok": True, "id": int(msg_id)}))


def cmd_post(sender, recipient, content, thread_id=None):
    """Post a message AND send NOTIFY to recipient's channel for real-time delivery."""
    channel = f"{recipient}_msg"
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO bot_messages (sender, recipient, content, thread_id, status)
            VALUES (%s, %s, %s, %s, 'unread')
            RETURNING id, created_at
        """, (sender, recipient, content, thread_id))
        row = cur.fetchone()
        conn.commit()
        # Send real-time notification
        try:
            cur.execute(f"NOTIFY {channel}, %s", (str(row[0]),))
        except Exception as e:
            print(f"  (notify failed: {e})", file=sys.stderr)
        print(json.dumps({
            "ok": True,
            "id": row[0],
            "created_at": row[1].isoformat(),
            "notified": channel
        }))


def cmd_listen(my_name, timeout=55):
    """
    Real-time listener using PostgreSQL LISTEN/NOTIFY.
    Opens a persistent connection, listens on <my_name>_msg channel.
    When notified, reads the message from the DB and marks it as read.
    Runs for `timeout` seconds then exits (or forever if timeout=0).
    """
    channel = f"{my_name}_msg"
    conn = get_conn(autocommit=True)
    cur = conn.cursor()
    cur.execute(f"LISTEN {channel}")
    print(json.dumps({"ok": True, "listening": channel, "timeout": timeout}))
    sys.stdout.flush()

    deadline = None if timeout == 0 else datetime.now().timestamp() + timeout

    while True:
        remaining = max(0.1, deadline - datetime.now().timestamp()) if deadline else 30
        if select.select([conn], [], [], min(remaining, 30)) != ([], [], []):
            conn.poll()
            for notify in conn.notifies:
                msg_id = notify.payload
                # Fetch the actual message from DB
                cur.execute("""
                    SELECT id, sender, content, thread_id, created_at
                    FROM bot_messages
                    WHERE id = %s AND recipient = %s AND status = 'unread'
                """, (msg_id, my_name))
                row = cur.fetchone()
                if row:
                    msg = {
                        "id": row[0],
                        "from": row[1],
                        "content": row[2],
                        "thread_id": row[3],
                        "created_at": row[4].isoformat() if row[4] else None,
                    }
                    # Mark as read
                    cur.execute(
                        "UPDATE bot_messages SET status='read', read_at=NOW() WHERE id=%s",
                        (msg_id,)
                    )
                    print(json.dumps({"type": "message", **msg}))
                    sys.stdout.flush()
            conn.notifies = []
        else:
            # Idle check - also poll for any unread messages that came in without notify
            cur.execute("""
                SELECT id, sender, content, thread_id, created_at
                FROM bot_messages
                WHERE recipient = %s AND status = 'unread'
                ORDER BY created_at ASC
                LIMIT 5
            """, (my_name,))
            for row in cur.fetchall():
                msg = {
                    "id": row[0], "from": row[1], "content": row[2],
                    "thread_id": row[3],
                    "created_at": row[4].isoformat() if row[4] else None,
                }
                cur.execute(
                    "UPDATE bot_messages SET status='read', read_at=NOW() WHERE id=%s",
                    (row[0],)
                )
                print(json.dumps({"type": "message", **msg}))
                sys.stdout.flush()

        if deadline and datetime.now().timestamp() > deadline:
            break

    conn.close()
    print(json.dumps({"ok": True, "done": True}))


def main():
    parser = argparse.ArgumentParser(
        description="Bot coordination via shared DB (supports real-time LISTEN/NOTIFY)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("setup", help="Create the bot_messages table")

    r = sub.add_parser("read", help="Read unread messages for a recipient (polling)")
    r.add_argument("my_name", help="My bot name (nanachi or hermes)")

    m = sub.add_parser("mark", help="Mark a message as read")
    m.add_argument("msg_id", type=int, help="Message ID to mark as read")

    p = sub.add_parser("post", help="Post a message (also sends NOTIFY for real-time)")
    p.add_argument("sender")
    p.add_argument("recipient")
    p.add_argument("content")
    p.add_argument("--thread", dest="thread_id", default=None)

    l = sub.add_parser("listen", help="Real-time listener (LISTEN/NOTIFY)")
    l.add_argument("my_name", help="My bot name (nanachi or hermes)")
    l.add_argument("--timeout", type=int, default=55, help="Seconds to listen (default: 55)")

    args = parser.parse_args()

    if args.cmd == "setup":
        cmd_setup()
    elif args.cmd == "read":
        cmd_read(args.my_name)
    elif args.cmd == "mark":
        cmd_mark(args.msg_id)
    elif args.cmd == "post":
        cmd_post(args.sender, args.recipient, args.content, args.thread_id)
    elif args.cmd == "listen":
        cmd_listen(args.my_name, args.timeout)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
