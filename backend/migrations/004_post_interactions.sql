-- Migrasi 004: interaksi postingan (like, komentar, posting ulang)
-- Jalankan sekali, contoh:
--   psql -U <user> -d <nama_database> -f migrations/004_post_interactions.sql
--
-- Tipe kolom id (integer / uuid) pada tabel posts dan users dideteksi otomatis,
-- sama seperti migrasi 002.

DO $$
DECLARE
    post_id_type text;
    user_id_type text;
BEGIN
    SELECT format_type(atttypid, atttypmod) INTO post_id_type
    FROM pg_attribute
    WHERE attrelid = 'posts'::regclass AND attname = 'id';

    SELECT format_type(atttypid, atttypmod) INTO user_id_type
    FROM pg_attribute
    WHERE attrelid = 'users'::regclass AND attname = 'id';

    -- Suka (satu user hanya bisa menyukai satu postingan sekali)
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS post_likes (
            post_id    %s NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
            user_id    %s NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            PRIMARY KEY (post_id, user_id)
        )',
        post_id_type, user_id_type
    );

    -- Posting ulang (satu user hanya bisa memposting ulang satu postingan sekali)
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS post_reposts (
            post_id    %s NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
            user_id    %s NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            PRIMARY KEY (post_id, user_id)
        )',
        post_id_type, user_id_type
    );

    -- Komentar
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS post_comments (
            id         SERIAL PRIMARY KEY,
            post_id    %s NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
            user_id    %s NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            content    VARCHAR(500) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
        )',
        post_id_type, user_id_type
    );
END $$;

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id     ON post_likes (post_id);
CREATE INDEX IF NOT EXISTS idx_post_reposts_post_id   ON post_reposts (post_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_post_id  ON post_comments (post_id, created_at);