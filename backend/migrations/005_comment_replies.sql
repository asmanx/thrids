-- Migrasi 005: balasan bersarang, suka pada komentar, dan jumlah dilihat
-- Jalankan sekali (setelah 004), contoh:
--   psql -U <user> -d <nama_database> -f migrations/005_comment_replies.sql

-- Balasan komentar: parent_id menunjuk ke komentar yang dibalas (NULL = komentar utama)
ALTER TABLE post_comments
    ADD COLUMN IF NOT EXISTS parent_id INTEGER REFERENCES post_comments(id) ON DELETE CASCADE;

-- Jumlah "kali dilihat" pada postingan
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0;

-- Suka pada komentar. Tipe kolom users.id dideteksi otomatis seperti migrasi 004.
DO $$
DECLARE
    user_id_type text;
BEGIN
    SELECT format_type(atttypid, atttypmod) INTO user_id_type
    FROM pg_attribute
    WHERE attrelid = 'users'::regclass AND attname = 'id';

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS comment_likes (
            comment_id INTEGER NOT NULL REFERENCES post_comments(id) ON DELETE CASCADE,
            user_id    %s NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            PRIMARY KEY (comment_id, user_id)
        )',
        user_id_type
    );
END $$;

CREATE INDEX IF NOT EXISTS idx_post_comments_parent_id  ON post_comments (parent_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id    ON post_comments (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment_id ON comment_likes (comment_id);