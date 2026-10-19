-- Fitur Direct Messages (DM) untuk Thriids
-- PostgreSQL

-- Satu percakapan untuk setiap pasangan pengguna.
CREATE TABLE IF NOT EXISTS conversations (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_a          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (user_a < user_b),
    UNIQUE (user_a, user_b)
);

CREATE INDEX IF NOT EXISTS idx_conversations_user_a
    ON conversations (user_a, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_user_b
    ON conversations (user_b, last_message_at DESC);

-- Pesan teks, gambar, GIF, stiker, atau postingan.
CREATE TABLE IF NOT EXISTS messages (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL DEFAULT 'text'
                    CHECK (type IN ('text', 'image', 'gif', 'sticker', 'post')),
    content         TEXT NOT NULL DEFAULT '',
    media_url       TEXT,
    post_id         BIGINT REFERENCES posts(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation
    ON messages (conversation_id, id DESC);

-- Status percakapan untuk setiap pengguna.
CREATE TABLE IF NOT EXISTS conversation_members (
    conversation_id      BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id              BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_message_id BIGINT NOT NULL DEFAULT 0,
    is_hidden            BOOLEAN NOT NULL DEFAULT FALSE,
    is_muted             BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conversation_members_user
    ON conversation_members (user_id);