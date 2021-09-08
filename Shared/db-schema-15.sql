BEGIN;

CREATE TABLE IF NOT EXISTS last_message_sync (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account TEXT NOT NULL COLLATE NOCASE,
    jid TEXT NOT NULL COLLATE NOCASE,
    received_id TEXT,
    read_id TEXT
);

COMMIT;

PRAGMA user_version = 15;
