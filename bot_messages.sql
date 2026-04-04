-- Bot-to-bot messaging table for Nanachi ↔ Nezuko coordination
-- Run this in the pg-nanachi database (host: pg-nanachi, port: 5432, db: postgres)

CREATE TABLE IF NOT EXISTS bot_messages (
    id            SERIAL PRIMARY KEY,
    sender        VARCHAR(50)  NOT NULL,          -- 'nanachi' or 'nezuko'
    recipient     VARCHAR(50)  NOT NULL,          -- 'nanachi' or 'nezuko'
    content       TEXT         NOT NULL,
    thread_id     VARCHAR(100),                   -- optional Discord thread context
    status        VARCHAR(20)  NOT NULL DEFAULT 'unread',  -- unread | read | done
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    read_at       TIMESTAMPTZ
);

-- Index for polling: find unread messages for a recipient
CREATE INDEX IF NOT EXISTS idx_bot_messages_recipient_status
    ON bot_messages(recipient, status, created_at);

-- Allow both bots to connect
-- (connection: host=pg-nanachi port=5432 dbname=postgres user=postgres password=<from HERMES_DB_PASSWORD env>)
