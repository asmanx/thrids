-- Migrasi fitur postingan: label AI, lampiran teks, jadwal, komentar bermedia,
-- dan postingan tersimpan (PostgreSQL).
--
--   psql -U <user_db> -d thrids_database -f migration_post_features.sql
--
-- Aman dijalankan ulang (memakai IF NOT EXISTS).

BEGIN;

-- Postingan
ALTER TABLE posts ADD COLUMN IF NOT EXISTS ai_label         BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS text_attachment  TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS scheduled_at     TIMESTAMPTZ;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS mentions_pending BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_posts_scheduled
    ON posts (scheduled_at) WHERE scheduled_at IS NOT NULL;

-- Komentar: satu foto / GIF / stiker (isi teks boleh kosong kalau ada media)
ALTER TABLE post_comments ADD COLUMN IF NOT EXISTS media_url  TEXT;
ALTER TABLE post_comments ADD COLUMN IF NOT EXISTS media_type TEXT;

-- Postingan tersimpan (tab "Tersimpan" di pemilih kutipan)
CREATE TABLE IF NOT EXISTS post_saves (
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id    BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

COMMIT;

-- CATATAN: kalau saat mengirim komentar hanya-foto muncul error
-- "violates check constraint", berarti post_comments punya aturan panjang
-- isi > 0. Lihat dengan:   \d post_comments
-- lalu hapus aturan itu dengan:  ALTER TABLE post_comments DROP CONSTRAINT <nama>;