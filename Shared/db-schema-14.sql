BEGIN;

ALTER TABLE roster_items ADD COLUMN nickname TEXT;

COMMIT;

PRAGMA user_version = 14;
