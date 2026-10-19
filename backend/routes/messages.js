// routes/messages.js
//
//   GET  /api/messages/conversations?box=inbox|requests|hidden&filter=all|unread|unanswered|verified
//        -> { conversations: [...], request_count }
//   POST /api/messages/conversations                 body { username }
//        -> { conversation: { id, user } }           (buka / buat percakapan)
//   GET  /api/messages/conversations/:id             -> { conversation: {...detail lawan bicara} }
//   GET  /api/messages/conversations/:id/messages?after=<id>
//        -> { messages: [...] }                      (tanpa "after": 100 pesan terakhir)
//   POST /api/messages/conversations/:id/messages
//        - teks   : JSON { content }
//        - GIF    : JSON { type: "gif", media_url }       (alamat harus dari giphy.com)
//        - stiker : JSON { type: "sticker", media_url }   (alamat harus dari giphy.com)
//        - foto   : multipart/form-data, field "media" (JPG/PNG/WEBP/GIF, maks 10 MB),
//                   field "content" opsional sebagai keterangan
//        -> { message }
//   POST /api/messages/conversations/:id/read        -> tandai sudah dibaca
//   POST /api/messages/conversations/:id/hide        body { hidden: true|false }
//   POST /api/messages/conversations/:id/mute        body { muted: true|false }
//   GET  /api/messages/users?q=                      -> { users: [...] }  (untuk "Pesan baru")
//   GET  /api/messages/unread-count                  -> { unread_count, request_count }
//
// Obrolan grup (conversations.is_group = TRUE, anggota di conversation_members):
//   POST /api/messages/groups                         body { name?, usernames: [...] }  (min. 2 orang)
//        -> { conversation: { id, user: {is_group, username (= nama grup), ...} } }
//   POST /api/messages/conversations/:id/members      body { usernames: [...] }   tambah anggota
//   POST /api/messages/conversations/:id/members/remove  body { user_id }         (admin saja)
//   POST /api/messages/conversations/:id/leave        keluar dari grup
//   POST /api/messages/conversations/:id/rename       body { name }
//   Pesan, baca, senyap, dan sembunyikan memakai route percakapan yang sama.
//
// Aturan "Permintaan": percakapan masuk ke Permintaan bila saya TIDAK mengikuti
// lawan bicara dan saya belum pernah membalas. Begitu saya membalas, percakapan
// pindah ke Kotak masuk.

const express = require("express");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authMiddleware");
const {
    uploadMessageImage,
    looksLikeImage,
    discardUpload,
} = require("../middleware/uploadMessage");

const router = express.Router();

router.use(authMiddleware);

const MAX_LENGTH = 1000;

// GIF dan stiker hanya boleh berasal dari Giphy (sama seperti di postingan).
function isGiphyUrl(value) {
    try {
        const url = new URL(value);

        return (
            url.protocol === "https:" &&
            (url.hostname === "giphy.com" || url.hostname.endsWith(".giphy.com"))
        );
    } catch (_) {
        return false;
    }
}

// ───────────── Helper ─────────────

function isId(value) {
    return typeof value === "string" && /^\d{1,18}$/.test(value);
}

function sameId(a, b) {
    return String(a) === String(b);
}

function userJson(row, prefix = "") {
    return {
        id: row[`${prefix}id`],
        username: row[`${prefix}username`],
        display_name: row[`${prefix}display_name`] || row[`${prefix}username`],
        profile_picture: row[`${prefix}profile_picture`] || null,
        is_verified: row[`${prefix}is_verified`] === true,
    };
}

// Percakapan yang saya ikuti, 1-lawan-1 maupun grup (null bila bukan anggota).
async function findConversation(conversationId, userId) {
    if (!isId(conversationId)) return null;

    const result = await pool.query(
        `SELECT c.id, c.user_a, c.user_b, c.is_group, c.name, c.created_by
         FROM conversations c
         JOIN conversation_members cm
              ON cm.conversation_id = c.id AND cm.user_id = $2
         WHERE c.id = $1`,
        [conversationId, userId]
    );

    const row = result.rows[0];

    if (!row) return null;

    const isGroup = row.is_group === true;

    return {
        id: row.id,
        isGroup,
        name: row.name,
        createdBy: row.created_by,
        otherId: isGroup
            ? null
            : sameId(row.user_a, userId)
              ? row.user_b
              : row.user_a,
    };
}

// Semua percakapan saya, terbaru dulu. Penyaringan dilakukan di JavaScript
// (maksimal 200 baris) supaya query-nya tetap sederhana.
async function loadConversations(me) {
    const result = await pool.query(
        `SELECT
            c.id,
            c.last_message_at,
            c.is_group,
            c.name AS c_name,
            o.id AS o_id,
            o.username AS o_username,
            o.display_name AS o_display_name,
            o.profile_picture AS o_profile_picture,
            (to_jsonb(o) ->> 'is_verified') = 'true' AS o_is_verified,
            lm.id AS lm_id,
            lm.type AS lm_type,
            lm.content AS lm_content,
            lm.sender_id AS lm_sender_id,
            lm.created_at AS lm_created_at,
            su.username AS lm_sender_username,
            cm.is_muted,
            cm.is_hidden,
            (
                SELECT COUNT(*)::int
                FROM messages m
                WHERE m.conversation_id = c.id
                  AND m.sender_id <> $1
                  AND m.id > cm.last_read_message_id
            ) AS unread_count,
            (
                NOT c.is_group
                AND NOT EXISTS (
                    SELECT 1 FROM follows f
                    WHERE f.follower_id = $1 AND f.following_id = o.id
                )
                AND NOT EXISTS (
                    SELECT 1 FROM messages s
                    WHERE s.conversation_id = c.id AND s.sender_id = $1
                )
            ) AS is_request,
            (
                SELECT COUNT(*)::int
                FROM conversation_members x
                WHERE x.conversation_id = c.id
            ) AS member_count,
            (
                SELECT COALESCE(json_agg(t.profile_picture), '[]'::json)
                FROM (
                    SELECT u.profile_picture
                    FROM conversation_members x
                    JOIN users u ON u.id = x.user_id
                    WHERE x.conversation_id = c.id AND x.user_id <> $1
                    ORDER BY x.user_id
                    LIMIT 2
                ) t
            ) AS preview_pictures
         FROM conversations c
         JOIN conversation_members cm
              ON cm.conversation_id = c.id AND cm.user_id = $1
         LEFT JOIN users o
              ON o.id = CASE WHEN c.user_a = $1 THEN c.user_b ELSE c.user_a END
         LEFT JOIN LATERAL (
              SELECT m.id, m.type, m.content, m.sender_id, m.created_at
              FROM messages m
              WHERE m.conversation_id = c.id
              ORDER BY m.id DESC
              LIMIT 1
         ) lm ON TRUE
         LEFT JOIN users su ON su.id = lm.sender_id
         WHERE c.is_group OR lm.id IS NOT NULL
         ORDER BY c.last_message_at DESC, c.id DESC
         LIMIT 200`,
        [me]
    );

    return result.rows.map((row) => {
        const group = row.is_group === true;
        const hasLast = row.lm_id !== null && row.lm_id !== undefined;
        const groupName = row.c_name || "Grup";

        return {
            id: row.id,
            is_group: group,
            // Untuk grup, "user" berisi nama grup supaya layar lama tetap jalan.
            user: group
                ? {
                      id: null,
                      username: groupName,
                      display_name: groupName,
                      profile_picture: null,
                      is_verified: false,
                      is_group: true,
                      member_count: row.member_count,
                      preview_pictures: row.preview_pictures || [],
                  }
                : userJson(row, "o_"),
            member_count: row.member_count,
            preview_pictures: group ? row.preview_pictures || [] : [],
            last_message: hasLast
                ? {
                      id: row.lm_id,
                      type: row.lm_type,
                      content: row.lm_content,
                      sender_id: row.lm_sender_id,
                      sender_username: row.lm_sender_username || null,
                      mine: sameId(row.lm_sender_id, me),
                      created_at: row.lm_created_at,
                  }
                : {
                      id: null,
                      type: "system",
                      content: "Grup dibuat",
                      sender_id: null,
                      sender_username: null,
                      mine: false,
                      created_at: row.last_message_at,
                  },
            unread_count: row.unread_count,
            is_muted: row.is_muted === true,
            is_hidden: row.is_hidden === true,
            is_request: row.is_request === true,
            updated_at: row.last_message_at,
        };
    });
}

// Kolom pesan yang dikirim ke aplikasi (termasuk ringkasan postingan yang dibagikan).
const MESSAGE_SELECT = `
    SELECT
        m.id,
        m.conversation_id,
        m.sender_id,
        m.type,
        m.content,
        m.media_url,
        m.post_id,
        m.created_at,
        su.username AS sender_username,
        su.display_name AS sender_display_name,
        su.profile_picture AS sender_picture,
        (
            SELECT json_build_object(
                'id', p.id,
                'content', p.content,
                'username', pu.username,
                'profile_picture', pu.profile_picture,
                'like_count', (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int,
                'comment_count', (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id)::int,
                'repost_count', (SELECT COUNT(*) FROM post_reposts r WHERE r.post_id = p.id)::int
            )
            FROM posts p
            JOIN users pu ON pu.id = p.user_id
            WHERE p.id = m.post_id
        ) AS post
    FROM messages m
    LEFT JOIN users su ON su.id = m.sender_id
`;

function messageJson(row, me) {
    return {
        id: row.id,
        conversation_id: row.conversation_id,
        sender_id: row.sender_id,
        mine: sameId(row.sender_id, me),
        type: row.type,
        content: row.content,
        media_url: row.media_url || null,
        post: row.post || null,
        sender: row.sender_id
            ? {
                  id: row.sender_id,
                  username: row.sender_username || null,
                  display_name:
                      row.sender_display_name || row.sender_username || null,
                  profile_picture: row.sender_picture || null,
              }
            : null,
        created_at: row.created_at,
    };
}

async function markRead(conversationId, userId) {
    await pool.query(
        `UPDATE conversation_members
         SET last_read_message_id = COALESCE(
             (SELECT MAX(id) FROM messages WHERE conversation_id = $1), 0
         )
         WHERE conversation_id = $1 AND user_id = $2`,
        [conversationId, userId]
    );
}

// ───────────── Daftar percakapan ─────────────

router.get("/conversations", async (req, res) => {
    try {
        const me = req.user.id;

        const box = ["inbox", "requests", "hidden"].includes(req.query.box)
            ? req.query.box
            : "inbox";

        const filter = ["all", "unread", "unanswered", "verified"].includes(
            req.query.filter
        )
            ? req.query.filter
            : "all";

        const all = await loadConversations(me);

        const requestCount = all.filter(
            (item) => item.is_request && !item.is_hidden
        ).length;

        let items = all.filter((item) => {
            if (box === "requests") return item.is_request && !item.is_hidden;
            if (box === "hidden") return item.is_request && item.is_hidden;
            return !item.is_request;
        });

        if (filter === "unread") {
            items = items.filter((item) => item.unread_count > 0);
        } else if (filter === "unanswered") {
            // Pesan terakhir dari lawan bicara, belum saya jawab.
            items = items.filter((item) => !item.last_message.mine);
        } else if (filter === "verified") {
            items = items.filter((item) => item.user.is_verified);
        }

        return res
            .status(200)
            .json({ conversations: items, request_count: requestCount });
    } catch (error) {
        console.error("Get conversations error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil pesan." });
    }
});

router.get("/unread-count", async (req, res) => {
    try {
        const all = await loadConversations(req.user.id);

        return res.status(200).json({
            unread_count: all.filter(
                (item) => !item.is_request && item.unread_count > 0
            ).length,
            request_count: all.filter(
                (item) => item.is_request && !item.is_hidden
            ).length,
        });
    } catch (error) {
        console.error("Message unread count error:", error.message);

        return res.status(500).json({ message: "Gagal menghitung pesan." });
    }
});

// ───────────── Cari orang untuk "Pesan baru" ─────────────

router.get("/users", async (req, res) => {
    try {
        const q =
            typeof req.query.q === "string" ? req.query.q.trim().slice(0, 50) : "";

        const pattern = `%${q.replace(/[\\%_]/g, "\\$&")}%`;

        const result = await pool.query(
            `SELECT
                u.id,
                u.username,
                u.display_name,
                u.profile_picture,
                EXISTS (
                    SELECT 1 FROM follows a
                    WHERE a.follower_id = $1 AND a.following_id = u.id
                ) AS i_follow,
                EXISTS (
                    SELECT 1 FROM follows b
                    WHERE b.follower_id = u.id AND b.following_id = $1
                ) AS follows_me
             FROM users u
             WHERE u.id <> $1
               AND ($2 = '' OR u.username ILIKE $3 OR u.display_name ILIKE $3)
             ORDER BY i_follow DESC, follows_me DESC, u.id DESC
             LIMIT 50`,
            [req.user.id, q, pattern]
        );

        return res.status(200).json({
            users: result.rows.map((row) => ({
                ...userJson(row),
                i_follow: row.i_follow,
                follows_me: row.follows_me,
            })),
        });
    } catch (error) {
        console.error("Message users error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil daftar akun." });
    }
});

// ───────────── Buka / buat percakapan ─────────────

router.post("/conversations", async (req, res) => {
    try {
        const me = req.user.id;
        const username =
            typeof (req.body && req.body.username) === "string"
                ? req.body.username.trim()
                : "";

        if (!username) {
            return res.status(400).json({ message: "Username wajib diisi." });
        }

        const target = await pool.query(
            `SELECT id, username, display_name, profile_picture,
                    (to_jsonb(users) ->> 'is_verified') = 'true' AS is_verified
             FROM users
             WHERE LOWER(username) = LOWER($1)
             LIMIT 1`,
            [username]
        );

        if (target.rowCount === 0) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        const other = target.rows[0];

        if (sameId(other.id, me)) {
            return res
                .status(400)
                .json({ message: "Tidak bisa mengirim pesan ke diri sendiri." });
        }

        const [low, high] =
            Number(me) < Number(other.id) ? [me, other.id] : [other.id, me];

        const conversation = await pool.query(
            `INSERT INTO conversations (user_a, user_b)
             VALUES ($1, $2)
             ON CONFLICT (user_a, user_b) DO UPDATE SET user_a = EXCLUDED.user_a
             RETURNING id`,
            [low, high]
        );

        const conversationId = conversation.rows[0].id;

        await pool.query(
            `INSERT INTO conversation_members (conversation_id, user_id)
             VALUES ($1, $2), ($1, $3)
             ON CONFLICT DO NOTHING`,
            [conversationId, me, other.id]
        );

        return res.status(200).json({
            conversation: { id: conversationId, user: userJson(other) },
        });
    } catch (error) {
        console.error("Open conversation error:", error.message);

        return res.status(500).json({ message: "Gagal membuka percakapan." });
    }
});

// ───────────── Detail percakapan (kartu profil di atas chat) ─────────────

router.get("/conversations/:id", async (req, res) => {
    try {
        const me = req.user.id;
        const conversation = await findConversation(req.params.id, me);

        if (!conversation) {
            return res.status(404).json({ message: "Percakapan tidak ditemukan." });
        }

        if (conversation.isGroup) {
            const members = await pool.query(
                `SELECT u.id, u.username, u.display_name, u.profile_picture,
                        (to_jsonb(u) ->> 'is_verified') = 'true' AS is_verified,
                        cm.role
                 FROM conversation_members cm
                 JOIN users u ON u.id = cm.user_id
                 WHERE cm.conversation_id = $1
                 ORDER BY (cm.role = 'admin') DESC, cm.joined_at ASC, u.id ASC`,
                [conversation.id]
            );

            const state = await pool.query(
                `SELECT is_muted, is_hidden, role
                 FROM conversation_members
                 WHERE conversation_id = $1 AND user_id = $2`,
                [conversation.id, me]
            );

            const mine = state.rows[0] || {};

            return res.status(200).json({
                conversation: {
                    id: conversation.id,
                    is_group: true,
                    name: conversation.name || "Grup",
                    created_by: conversation.createdBy,
                    is_muted: mine.is_muted === true,
                    is_hidden: mine.is_hidden === true,
                    is_request: false,
                    my_role: mine.role || "member",
                    member_count: members.rowCount,
                    members: members.rows.map((row) => ({
                        ...userJson(row),
                        role: row.role,
                    })),
                },
            });
        }

        const otherId = conversation.otherId;

        const info = await pool.query(
            `SELECT
                u.id,
                u.username,
                u.display_name,
                u.profile_picture,
                (to_jsonb(u) ->> 'is_verified') = 'true' AS is_verified,
                (SELECT COUNT(*)::int FROM follows WHERE following_id = u.id) AS followers_count,
                EXISTS (
                    SELECT 1 FROM follows a
                    WHERE a.follower_id = $2 AND a.following_id = u.id
                ) AS i_follow,
                EXISTS (
                    SELECT 1 FROM follows b
                    WHERE b.follower_id = u.id AND b.following_id = $2
                ) AS follows_me
             FROM users u
             WHERE u.id = $1`,
            [otherId, me]
        );

        // Pengikut dia yang juga saya ikuti ("Diikuti oleh ...").
        const mutual = await pool.query(
            `SELECT u.username
             FROM follows f
             JOIN users u ON u.id = f.follower_id
             WHERE f.following_id = $1
               AND f.follower_id IN (
                   SELECT following_id FROM follows WHERE follower_id = $2
               )
             ORDER BY f.created_at DESC`,
            [otherId, me]
        );

        const state = await pool.query(
            `SELECT
                cm.is_muted,
                cm.is_hidden,
                (
                    NOT EXISTS (
                        SELECT 1 FROM follows f
                        WHERE f.follower_id = $2 AND f.following_id = $3
                    )
                    AND NOT EXISTS (
                        SELECT 1 FROM messages s
                        WHERE s.conversation_id = $1 AND s.sender_id = $2
                    )
                ) AS is_request
             FROM conversation_members cm
             WHERE cm.conversation_id = $1 AND cm.user_id = $2`,
            [conversation.id, me, otherId]
        );

        const row = info.rows[0];
        const mine = state.rows[0] || {};

        return res.status(200).json({
            conversation: {
                id: conversation.id,
                is_muted: mine.is_muted === true,
                is_hidden: mine.is_hidden === true,
                is_request: mine.is_request === true,
                other: {
                    ...userJson(row),
                    followers_count: row.followers_count,
                    i_follow: row.i_follow,
                    follows_me: row.follows_me,
                    mutual_count: mutual.rowCount,
                    mutual_first: mutual.rows[0] ? mutual.rows[0].username : null,
                },
            },
        });
    } catch (error) {
        console.error("Get conversation error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil percakapan." });
    }
});

// ───────────── Isi pesan ─────────────

router.get("/conversations/:id/messages", async (req, res) => {
    try {
        const me = req.user.id;
        const conversation = await findConversation(req.params.id, me);

        if (!conversation) {
            return res.status(404).json({ message: "Percakapan tidak ditemukan." });
        }

        let rows;

        if (isId(String(req.query.after || ""))) {
            // Polling: hanya pesan yang lebih baru dari "after".
            const result = await pool.query(
                `${MESSAGE_SELECT}
                 WHERE m.conversation_id = $1 AND m.id > $2
                 ORDER BY m.id ASC
                 LIMIT 200`,
                [conversation.id, req.query.after]
            );

            rows = result.rows;
        } else {
            const result = await pool.query(
                `SELECT * FROM (
                    ${MESSAGE_SELECT}
                    WHERE m.conversation_id = $1
                    ORDER BY m.id DESC
                    LIMIT 100
                 ) latest
                 ORDER BY id ASC`,
                [conversation.id]
            );

            rows = result.rows;
        }

        await markRead(conversation.id, me);

        return res
            .status(200)
            .json({ messages: rows.map((row) => messageJson(row, me)) });
    } catch (error) {
        console.error("Get messages error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil pesan." });
    }
});

router.post("/conversations/:id/messages", uploadMessageImage, async (req, res) => {
    const file = req.file || null;

    try {
        const me = req.user.id;
        const conversation = await findConversation(req.params.id, me);

        if (!conversation) {
            discardUpload(file);

            return res.status(404).json({ message: "Percakapan tidak ditemukan." });
        }

        const body = req.body || {};

        const text = typeof body.content === "string" ? body.content.trim() : "";

        if (text.length > MAX_LENGTH) {
            discardUpload(file);

            return res
                .status(400)
                .json({ message: `Pesan maksimal ${MAX_LENGTH} karakter.` });
        }

        let type = "text";
        let content = text;
        let mediaUrl = null;

        if (file) {
            // Foto
            if (!looksLikeImage(file)) {
                discardUpload(file);

                return res.status(400).json({ message: "File bukan foto yang valid." });
            }

            type = "image";
            mediaUrl = `/uploads/${file.filename}`;
        } else if (body.type === "gif" || body.type === "sticker") {
            // GIF / stiker dari Giphy
            const url = typeof body.media_url === "string" ? body.media_url.trim() : "";

            if (!isGiphyUrl(url)) {
                return res
                    .status(400)
                    .json({ message: "Alamat GIF/stiker tidak valid." });
            }

            type = body.type;
            mediaUrl = url;
        } else if (!text) {
            return res.status(400).json({ message: "Pesan tidak boleh kosong." });
        }

        const inserted = await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, type, content, media_url)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id`,
            [conversation.id, me, type, content, mediaUrl]
        );

        const messageId = inserted.rows[0].id;

        await pool.query(
            "UPDATE conversations SET last_message_at = NOW() WHERE id = $1",
            [conversation.id]
        );

        // Pesan yang saya kirim otomatis sudah saya baca.
        await markRead(conversation.id, me);

        const result = await pool.query(`${MESSAGE_SELECT} WHERE m.id = $1`, [
            messageId,
        ]);

        return res
            .status(201)
            .json({ message: messageJson(result.rows[0], me) });
    } catch (error) {
        discardUpload(file);

        console.error("Send message error:", error.message);

        return res.status(500).json({ message: "Gagal mengirim pesan." });
    }
});

// ───────────── Obrolan grup ─────────────

const MAX_GROUP_MEMBERS = 32;
const MAX_GROUP_NAME = 50;

function parseUsernames(value) {
    if (!Array.isArray(value)) return [];

    const seen = new Set();

    for (const item of value) {
        if (typeof item !== "string") continue;

        const name = item.trim().toLowerCase();
        if (name) seen.add(name);
    }

    return [...seen];
}

async function usernameOf(userId) {
    const result = await pool.query(
        "SELECT username FROM users WHERE id = $1",
        [userId]
    );

    return result.rows[0] ? result.rows[0].username : "seseorang";
}

// Pesan sistem ("asman membuat grup"). Gagal mencatat tidak boleh membatalkan aksinya.
async function addSystemMessage(conversationId, senderId, text) {
    try {
        await pool.query(
            `INSERT INTO messages (conversation_id, sender_id, type, content)
             VALUES ($1, $2, 'system', $3)`,
            [conversationId, senderId, text]
        );

        await pool.query(
            "UPDATE conversations SET last_message_at = NOW() WHERE id = $1",
            [conversationId]
        );
    } catch (error) {
        console.error("System message error:", error.message);
    }
}

// Percakapan grup yang saya ikuti; membalas error sendiri dan mengembalikan null.
async function requireGroup(req, res) {
    const conversation = await findConversation(req.params.id, req.user.id);

    if (!conversation) {
        res.status(404).json({ message: "Percakapan tidak ditemukan." });
        return null;
    }

    if (!conversation.isGroup) {
        res.status(400).json({ message: "Ini bukan obrolan grup." });
        return null;
    }

    return conversation;
}

async function memberCount(conversationId) {
    const result = await pool.query(
        "SELECT COUNT(*)::int AS n FROM conversation_members WHERE conversation_id = $1",
        [conversationId]
    );

    return result.rows[0].n;
}

function groupUserJson(id, name, count) {
    return {
        id: null,
        username: name,
        display_name: name,
        profile_picture: null,
        is_verified: false,
        is_group: true,
        member_count: count,
        preview_pictures: [],
    };
}

router.post("/groups", async (req, res) => {
    const client = await pool.connect();

    try {
        const me = req.user.id;
        const body = req.body || {};
        const wanted = parseUsernames(body.usernames);
        let name = typeof body.name === "string" ? body.name.trim() : "";

        if (name.length > MAX_GROUP_NAME) {
            return res.status(400).json({
                message: `Nama grup maksimal ${MAX_GROUP_NAME} karakter.`,
            });
        }

        if (wanted.length < 2) {
            return res
                .status(400)
                .json({ message: "Pilih minimal 2 orang untuk membuat grup." });
        }

        if (wanted.length + 1 > MAX_GROUP_MEMBERS) {
            return res.status(400).json({
                message: `Grup maksimal ${MAX_GROUP_MEMBERS} anggota.`,
            });
        }

        const found = await pool.query(
            `SELECT id, username
             FROM users
             WHERE LOWER(username) = ANY($1::text[]) AND id <> $2
             ORDER BY id`,
            [wanted, me]
        );

        if (found.rowCount < 2) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        if (!name) {
            name = found.rows
                .slice(0, 3)
                .map((row) => row.username)
                .join(", ")
                .slice(0, MAX_GROUP_NAME);
        }

        await client.query("BEGIN");

        const created = await client.query(
            `INSERT INTO conversations (is_group, name, created_by, last_message_at)
             VALUES (TRUE, $1, $2, NOW())
             RETURNING id`,
            [name, me]
        );

        const conversationId = created.rows[0].id;

        await client.query(
            `INSERT INTO conversation_members (conversation_id, user_id, role)
             VALUES ($1, $2, 'admin')`,
            [conversationId, me]
        );

        for (const row of found.rows) {
            await client.query(
                `INSERT INTO conversation_members (conversation_id, user_id, role)
                 VALUES ($1, $2, 'member')`,
                [conversationId, row.id]
            );
        }

        await client.query("COMMIT");

        await addSystemMessage(
            conversationId,
            me,
            `${await usernameOf(me)} membuat grup`
        );

        return res.status(201).json({
            conversation: {
                id: conversationId,
                user: groupUserJson(conversationId, name, found.rowCount + 1),
            },
        });
    } catch (error) {
        try {
            await client.query("ROLLBACK");
        } catch (_) {}

        console.error("Create group error:", error.message);

        return res.status(500).json({ message: "Gagal membuat grup." });
    } finally {
        client.release();
    }
});

// Tambah anggota (semua anggota boleh).
router.post("/conversations/:id/members", async (req, res) => {
    try {
        const me = req.user.id;
        const conversation = await requireGroup(req, res);
        if (!conversation) return;

        const wanted = parseUsernames((req.body || {}).usernames);

        if (wanted.length === 0) {
            return res.status(400).json({ message: "Pilih minimal 1 orang." });
        }

        const current = await memberCount(conversation.id);

        if (current + wanted.length > MAX_GROUP_MEMBERS) {
            return res.status(400).json({
                message: `Grup maksimal ${MAX_GROUP_MEMBERS} anggota.`,
            });
        }

        const found = await pool.query(
            `SELECT id, username FROM users
             WHERE LOWER(username) = ANY($1::text[])
             ORDER BY id`,
            [wanted]
        );

        const added = [];

        for (const row of found.rows) {
            const inserted = await pool.query(
                `INSERT INTO conversation_members (conversation_id, user_id, role)
                 VALUES ($1, $2, 'member')
                 ON CONFLICT DO NOTHING
                 RETURNING user_id`,
                [conversation.id, row.id]
            );

            if (inserted.rowCount > 0) added.push(row.username);
        }

        if (added.length === 0) {
            return res
                .status(400)
                .json({ message: "Semua akun itu sudah ada di grup." });
        }

        await addSystemMessage(
            conversation.id,
            me,
            `${await usernameOf(me)} menambahkan ${added.join(", ")}`
        );

        return res.status(200).json({
            ok: true,
            added: added.length,
            member_count: current + added.length,
        });
    } catch (error) {
        console.error("Add group members error:", error.message);

        return res.status(500).json({ message: "Gagal menambah anggota." });
    }
});

// Keluarkan anggota (admin saja).
router.post("/conversations/:id/members/remove", async (req, res) => {
    try {
        const me = req.user.id;
        const conversation = await requireGroup(req, res);
        if (!conversation) return;

        const target = String((req.body || {}).user_id || "");

        if (!isId(target)) {
            return res.status(400).json({ message: "Anggota tidak valid." });
        }

        if (sameId(target, me)) {
            return res
                .status(400)
                .json({ message: "Gunakan Keluar dari grup untuk keluar." });
        }

        const mine = await pool.query(
            `SELECT role FROM conversation_members
             WHERE conversation_id = $1 AND user_id = $2`,
            [conversation.id, me]
        );

        if (!mine.rows[0] || mine.rows[0].role !== "admin") {
            return res
                .status(403)
                .json({ message: "Hanya admin yang bisa mengeluarkan anggota." });
        }

        const removed = await pool.query(
            `DELETE FROM conversation_members
             WHERE conversation_id = $1 AND user_id = $2
             RETURNING user_id`,
            [conversation.id, target]
        );

        if (removed.rowCount === 0) {
            return res.status(404).json({ message: "Anggota tidak ditemukan." });
        }

        await addSystemMessage(
            conversation.id,
            me,
            `${await usernameOf(me)} mengeluarkan ${await usernameOf(target)}`
        );

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error("Remove group member error:", error.message);

        return res.status(500).json({ message: "Gagal mengeluarkan anggota." });
    }
});

// Keluar dari grup. Bila admin terakhir keluar, anggota tertua jadi admin.
router.post("/conversations/:id/leave", async (req, res) => {
    try {
        const me = req.user.id;
        const conversation = await requireGroup(req, res);
        if (!conversation) return;

        const myName = await usernameOf(me);

        await pool.query(
            `DELETE FROM conversation_members
             WHERE conversation_id = $1 AND user_id = $2`,
            [conversation.id, me]
        );

        const remaining = await memberCount(conversation.id);

        if (remaining === 0) {
            try {
                await pool.query("DELETE FROM conversations WHERE id = $1", [
                    conversation.id,
                ]);
            } catch (error) {
                console.error("Delete empty group error:", error.message);
            }

            return res.status(200).json({ ok: true });
        }

        const admins = await pool.query(
            `SELECT 1 FROM conversation_members
             WHERE conversation_id = $1 AND role = 'admin' LIMIT 1`,
            [conversation.id]
        );

        if (admins.rowCount === 0) {
            await pool.query(
                `UPDATE conversation_members SET role = 'admin'
                 WHERE conversation_id = $1
                   AND user_id = (
                       SELECT user_id FROM conversation_members
                       WHERE conversation_id = $1
                       ORDER BY joined_at ASC, user_id ASC
                       LIMIT 1
                   )`,
                [conversation.id]
            );
        }

        await addSystemMessage(conversation.id, me, `${myName} keluar dari grup`);

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error("Leave group error:", error.message);

        return res.status(500).json({ message: "Gagal keluar dari grup." });
    }
});

// Ganti nama grup (semua anggota boleh).
router.post("/conversations/:id/rename", async (req, res) => {
    try {
        const me = req.user.id;
        const conversation = await requireGroup(req, res);
        if (!conversation) return;

        const raw = (req.body || {}).name;
        const name = typeof raw === "string" ? raw.trim() : "";

        if (!name) {
            return res.status(400).json({ message: "Nama grup wajib diisi." });
        }

        if (name.length > MAX_GROUP_NAME) {
            return res.status(400).json({
                message: `Nama grup maksimal ${MAX_GROUP_NAME} karakter.`,
            });
        }

        await pool.query("UPDATE conversations SET name = $2 WHERE id = $1", [
            conversation.id,
            name,
        ]);

        await addSystemMessage(
            conversation.id,
            me,
            `${await usernameOf(me)} mengubah nama grup menjadi "${name}"`
        );

        return res.status(200).json({ ok: true, name });
    } catch (error) {
        console.error("Rename group error:", error.message);

        return res.status(500).json({ message: "Gagal mengganti nama grup." });
    }
});

// ───────────── Status percakapan ─────────────

router.post("/conversations/:id/read", async (req, res) => {
    try {
        const conversation = await findConversation(req.params.id, req.user.id);

        if (!conversation) {
            return res.status(404).json({ message: "Percakapan tidak ditemukan." });
        }

        await markRead(conversation.id, req.user.id);

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error("Mark read error:", error.message);

        return res.status(500).json({ message: "Gagal menandai pesan." });
    }
});

function memberFlagRoute(column, bodyKey) {
    return async (req, res) => {
        try {
            const conversation = await findConversation(
                req.params.id,
                req.user.id
            );

            if (!conversation) {
                return res
                    .status(404)
                    .json({ message: "Percakapan tidak ditemukan." });
            }

            const value = req.body && req.body[bodyKey];

            if (typeof value !== "boolean") {
                return res.status(400).json({ message: "Format input tidak valid." });
            }

            // Nama kolom berasal dari kode di atas (bukan input user), jadi aman.
            await pool.query(
                `UPDATE conversation_members
                 SET ${column} = $3
                 WHERE conversation_id = $1 AND user_id = $2`,
                [conversation.id, req.user.id, value]
            );

            return res.status(200).json({ ok: true, [bodyKey]: value });
        } catch (error) {
            console.error(`Update ${column} error:`, error.message);

            return res.status(500).json({ message: "Gagal memperbarui percakapan." });
        }
    };
}

router.post("/conversations/:id/hide", memberFlagRoute("is_hidden", "hidden"));
router.post("/conversations/:id/mute", memberFlagRoute("is_muted", "muted"));

module.exports = router;