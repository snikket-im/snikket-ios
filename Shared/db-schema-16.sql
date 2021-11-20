BEGIN;

ALTER TABLE roster_items ADD COLUMN audio_call INTEGER;
ALTER TABLE roster_items ADD COLUMN video_call INTEGER;

COMMIT;

PRAGMA user_version = 16;
