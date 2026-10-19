-- Jalankan SEKALI di database thrids_database (PostgreSQL), setelah schema.sql.
--
--   psql -U <user_db> -d thrids_database -f migration_follow_requests.sql
--
-- Menambah fitur "permintaan mengikuti" untuk akun privat.

-- 1) Permintaan mengikuti yang menunggu persetujuan pemilik akun
CREATE TABLE IF NOT EXISTS follow_requests (
    requester_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- yang meminta
    target_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- akun privat
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (requester_id, target_id),
    CHECK (requester_id <> target_id)
);

CREATE INDEX IF NOT EXISTS idx_follow_requests_target
    ON follow_requests (target_id, created_at DESC);

-- 2) Izinkan dua jenis notifikasi baru: follow_request dan follow_accept
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_type_check CHECK (
        type IN ('like', 'comment_like', 'reply', 'mention', 'repost',
                 'follow', 'follow_request', 'follow_accept')
    );