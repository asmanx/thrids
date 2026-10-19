-- Migrasi 002: fitur postingan (media, GIF, stiker, musik, kutipan, lokasi, polling)
-- Jalankan sekali, contoh:
--   psql -U <user> -d <nama_database> -f migrations/002_post_features.sql
--
-- Tipe kolom id (integer / uuid) pada tabel posts dan users dideteksi otomatis,
-- jadi aman dipakai apa pun tipe id yang kamu pakai.

ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS gif_url       TEXT,
    ADD COLUMN IF NOT EXISTS sticker_url   TEXT,
    ADD COLUMN IF NOT EXISTS music_title   TEXT,
    ADD COLUMN IF NOT EXISTS music_url     TEXT,
    ADD COLUMN IF NOT EXISTS location_name TEXT,
    ADD COLUMN IF NOT EXISTS latitude      DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude     DOUBLE PRECISION;

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

    -- Kutipan: postingan yang mengutip postingan lain
    EXECUTE format(
        'ALTER TABLE posts ADD COLUMN IF NOT EXISTS quote_post_id %s REFERENCES posts(id) ON DELETE SET NULL',
        post_id_type
    );

    -- Foto / video (maks. 4 per postingan, diatur di backend)
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS post_media (
            id        SERIAL PRIMARY KEY,
            post_id   %s NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
            url       TEXT NOT NULL,
            type      VARCHAR(10) NOT NULL CHECK (type IN (''image'', ''video'')),
            position  INT NOT NULL DEFAULT 0
        )',
        post_id_type
    );

    -- Polling
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS poll_options (
            id           SERIAL PRIMARY KEY,
            post_id      %s NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
            option_text  VARCHAR(80) NOT NULL,
            position     INT NOT NULL DEFAULT 0
        )',
        post_id_type
    );

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS poll_votes (
            id         SERIAL PRIMARY KEY,
            post_id    %s NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
            option_id  INT NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
            user_id    %s NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            UNIQUE (post_id, user_id)
        )',
        post_id_type, user_id_type
    );
END $$;

CREATE INDEX IF NOT EXISTS idx_post_media_post_id    ON post_media (post_id);
CREATE INDEX IF NOT EXISTS idx_poll_options_post_id  ON poll_options (post_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_option_id  ON poll_votes (option_id);
CREATE INDEX IF NOT EXISTS idx_posts_quote_post_id   ON posts (quote_post_id);
