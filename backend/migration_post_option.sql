-- migration_post_options.sql
--
-- Jalankan SEKALI di database thrids_database (PostgreSQL):
--   psql -U <user_db> -d thrids_database -f migration_post_options.sql
--
-- Menambah:
--   expires_at      -> postingan sementara (catatan), hilang setelah 24 jam
--   reply_audience  -> siapa yang boleh membalas
--   approve_replies -> pengaturan "Tinjau dan setujui balasan" (disimpan saja)

ALTER TABLE posts ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS reply_audience TEXT NOT NULL DEFAULT 'anyone';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS approve_replies BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_reply_audience_check;
ALTER TABLE posts
    ADD CONSTRAINT posts_reply_audience_check
    CHECK (reply_audience IN ('anyone', 'followers', 'following', 'mentioned'));

CREATE INDEX IF NOT EXISTS idx_posts_expires ON posts (expires_at)
    WHERE expires_at IS NOT NULL;