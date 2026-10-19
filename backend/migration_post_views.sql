-- Riwayat tayangan postingan (dipakai halaman Insight).
-- Jalankan SEKALI di database thrids_database.

CREATE TABLE IF NOT EXISTS post_views (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id    BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    viewer_id  BIGINT REFERENCES users(id) ON DELETE SET NULL,  -- null = belum login
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_views_post ON post_views (post_id, created_at);
CREATE INDEX IF NOT EXISTS idx_post_views_viewer ON post_views (viewer_id, created_at);