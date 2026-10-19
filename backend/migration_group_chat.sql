-- Obrolan grup. Jalankan SEKALI di database thrids_database (aman diulang).

ALTER TABLE conversations
    ADD COLUMN IF NOT EXISTS is_group   BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS name       TEXT,
    ADD COLUMN IF NOT EXISTS created_by BIGINT REFERENCES users(id) ON DELETE SET NULL;

-- Obrolan grup tidak punya pasangan user_a / user_b.
ALTER TABLE conversations ALTER COLUMN user_a DROP NOT NULL;
ALTER TABLE conversations ALTER COLUMN user_b DROP NOT NULL;

-- Peran anggota ('admin' = pembuat grup) dan waktu bergabung.
ALTER TABLE conversation_members
    ADD COLUMN IF NOT EXISTS role      TEXT NOT NULL DEFAULT 'member',
    ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Pesan sistem ("asman membuat grup") memakai type = 'system'.
-- Kalau tabel messages punya CHECK untuk kolom type, batasan itu dilepas.
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check;