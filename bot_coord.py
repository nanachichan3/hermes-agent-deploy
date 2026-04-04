#!/usr/bin/env python3
"""
bot_coord.py — Nanachi ↔ Nezuko bot messaging via shared Postgres table.

Usage:
  python3 bot_coord.py read <my_name>          # Read unread messages for <my_name>
  python3 bot_coord.py post <sender> <recipient> <content> [--thread <thread_id>]
  python3 bot_coord.py mark <id>               # Mark message as read
  python3 bot_coord.py setup                   # Create the table (run once)

Environment variables:
  BOT_COORDINATION_DB_HOST, BOT_COORDINATION_DB_PORT,
  BOT_COORDINATION_DB_USER, BOT_COORDINATION_DB_PASS,
  BOT_COORDINATION_DB_NAME
"""

import json
import os
import sys
import argparse
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
        "dbname": os.environ.get("BOT_COORDINATION_DB_NAME", "postgres"),
    }


def get_conn():
    cfg = get_db_config()
    return psycopg2.connect(**cfg)


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
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO bot_messages (sender, recipient, content, thread_id, status)
            VALUES (%s, %s, %s, %s, 'unread')
            RETURNING id, created_at
        """, (sender, recipient, content, thread_id))
        row = cur.fetchone()
        conn.commit()
        print(json.dumps({
            "ok": True,
            "id": row[0],
            "created_at": row[1].isoformat()
        }))


def main():
    parser = argparse.ArgumentParser(description="Bot coordination via shared DB")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("setup", help="Create the bot_messages table")

    r = sub.add_parser("read", help="Read unread messages for a recipient")
    r.add_argument("my_name", help="My bot name (nanachi or nezuko)")

    m = sub.add_parser("mark", help="Mark a message as read")
    m.add_argument("msg_id", type=int, help="Message ID to mark as read")

    p = sub.add_parser("post", help="Post a message")
    p.add_argument("sender")
    p.add_argument("recipient")
    p.add_argument("content")
    p.add_argument("--thread", dest="thread_id", default=None)

    args = parser.parse_args()

    if args.cmd == "setup":
        cmd_setup()
    elif args.cmd == "read":
        cmd_read(args.my_name)
    elif args.cmd == "mark":
        cmd_mark(args.msg_id)
    elif args.cmd == "post":
        cmd_post(args.sender, args.recipient, args.content, args.thread_id)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
