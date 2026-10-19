-- migration_notifications.sql
--
-- Memastikan tabel "notifications" ada dan mengizinkan semua jenis notifikasi
-- yang dipakai aplikasi. Aman dijalankan berulang kali.
--
-- Jalankan, misalnya:  psql -U postgres -d NAMA_DATABASE -f migration_notifications.sql

CREATE TABLE IF NOT EXISTS notifications (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    actor_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        TEXT   NOT NULL,
    post_id     BIGINT REFERENCES posts(id) ON DELETE CASCADE,
    comment_id  BIGINT REFERENCES post_comments(id) ON DELETE CASCADE,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Kolom yang mungkin belum ada kalau tabelnya dibuat versi lama.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS comment_id BIGINT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Hapus CHECK constraint lama pada kolom "type" (yang belum mengenal
-- follow_request / follow_accept), lalu pasang yang baru.
DO $$
DECLARE
    c RECORD;
BEGIN
    FOR c IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'notifications'::regclass
          AND contype = 'c'
          AND pg_get_constraintdef(oid) ILIKE '%type%'
    LOOP
        EXECUTE format('ALTER TABLE notifications DROP CONSTRAINT %I', c.conname);
    END LOOP;
END $$;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_type_check CHECK (type IN (
        'like', 'comment_like', 'reply', 'mention', 'repost',
        'follow', 'follow_request', 'follow_accept'
    ));

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications (user_id, created_at DESC);