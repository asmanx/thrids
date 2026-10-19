-- Jalankan SEKALI di database thrids_database (PostgreSQL).
--
--   psql -U <user_db> -d thrids_database -f schema.sql
--
-- atau paste isinya di pgAdmin / DBeaver (Query Tool) lalu Execute.

-- Siapa mengikuti siapa
CREATE TABLE IF NOT EXISTS follows (
    follower_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- yang mengikuti
    following_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- yang diikuti
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id <> following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_following ON follows (following_id);

-- Daftar aktivitas / notifikasi
CREATE TABLE IF NOT EXISTS notifications (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,   -- penerima
    actor_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,   -- pelaku
    type        TEXT NOT NULL CHECK (
                    type IN ('like', 'comment_like', 'reply', 'mention', 'repost', 'follow')
                ),
    post_id     BIGINT REFERENCES posts(id) ON DELETE CASCADE,
    comment_id  BIGINT REFERENCES post_comments(id) ON DELETE CASCADE,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS post_views (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id    BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    viewer_id  BIGINT REFERENCES users(id) ON DELETE SET NULL,  -- null = belum login
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_views_post ON post_views (post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_post_views_viewer ON post_views (viewer_id, created_at);