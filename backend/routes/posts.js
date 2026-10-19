const express = require("express");
const fs = require("fs");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authMiddleware");
const {
    uploadPostFiles,
    uploadCommentMedia,
    MAX_AUDIO_BYTES,
} = require("../middleware/upload");
const { notify, unnotify, notifyMentions } = require("../utils/notifications");

const router = express.Router();

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

// Menjalankan authMiddleware bila ada header Authorization, tetapi tidak
// menolak permintaan jika token tidak ada / tidak valid. Dipakai oleh GET
// supaya feed tetap publik, sementara pilihan polling milik user bisa dikirim.
function optionalAuth(req, res, next) {
    if (!req.headers.authorization) return next();

    const fakeRes = {
        status() {
            return this;
        },
        json() {
            next();
            return this;
        },
        send() {
            next();
            return this;
        },
        sendStatus() {
            next();
            return this;
        },
    };

    return authMiddleware(req, fakeRes, next);
}

// Postingan terjadwal disembunyikan dari semua daftar sampai waktunya tiba.
const NOT_SCHEDULED = "(p.scheduled_at IS NULL OR p.scheduled_at <= NOW())";

function withScheduleFilter(whereClause) {
    const rest = String(whereClause || "")
        .trim()
        .replace(/^WHERE\s+/i, "");

    return rest
        ? `WHERE (${rest}) AND ${NOT_SCHEDULED}`
        : `WHERE ${NOT_SCHEDULED}`;
}

// $1 = id user yang sedang melihat (boleh null), $2 = id postingan (opsional)
function selectPosts(whereClause = "") {
    return `
        SELECT
            p.id,
            p.user_id,
            p.content,
            p.created_at,
            p.gif_url,
            p.sticker_url,
            p.music_title,
            p.music_url,
            p.music_cover,
            p.location_name,
            p.latitude,
            p.longitude,
            p.quote_post_id,
            p.view_count,
            p.expires_at,
            p.reply_audience,
            p.approve_replies,
            p.ai_label,
            p.text_attachment,
            p.scheduled_at,
            u.username,
            u.display_name,
            u.profile_picture,
            COALESCE((
                SELECT json_agg(
                    json_build_object('url', m.url, 'type', m.type)
                    ORDER BY m.position
                )
                FROM post_media m
                WHERE m.post_id = p.id
            ), '[]'::json) AS media,
            (
                SELECT json_build_object(
                    'id', q.id,
                    'content', q.content,
                    'username', qu.username,
                    'display_name', qu.display_name
                )
                FROM posts q
                JOIN users qu ON qu.id = q.user_id
                WHERE q.id = p.quote_post_id
            ) AS quoted_post,
            COALESCE((
                SELECT json_agg(
                    json_build_object('id', o.id, 'text', o.option_text, 'votes', o.votes)
                    ORDER BY o.position
                )
                FROM (
                    SELECT
                        po.id,
                        po.option_text,
                        po.position,
                        (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = po.id)::int AS votes
                    FROM poll_options po
                    WHERE po.post_id = p.id
                ) o
            ), '[]'::json) AS poll_options,
            (
                SELECT pv.option_id
                FROM poll_votes pv
                WHERE pv.post_id = p.id AND pv.user_id = $1
            ) AS my_vote,
            (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int AS like_count,
            (SELECT COUNT(*) FROM post_comments c WHERE c.post_id = p.id)::int AS comment_count,
            (SELECT COUNT(*) FROM post_reposts r WHERE r.post_id = p.id)::int AS repost_count,
            EXISTS (
                SELECT 1 FROM post_likes l WHERE l.post_id = p.id AND l.user_id = $1
            ) AS liked_by_me,
            EXISTS (
                SELECT 1 FROM post_reposts r WHERE r.post_id = p.id AND r.user_id = $1
            ) AS reposted_by_me
        FROM posts p
        JOIN users u ON u.id = p.user_id
        ${withScheduleFilter(whereClause)}
        ORDER BY p.created_at DESC
    `;
}

// Utas boleh dilihat kalau: penulisnya tidak privat, ATAU saya penulisnya,
// ATAU saya sudah mengikutinya (permintaan sudah disetujui).
// Dipakai di WHERE bersama selectPosts(); $1 = id user yang melihat (boleh null).
const VISIBLE_POSTS = `(
    (to_jsonb(u) ->> 'is_private') IS DISTINCT FROM 'true'
    OR u.id = $1
    OR EXISTS (
        SELECT 1 FROM follows vf
        WHERE vf.follower_id = $1 AND vf.following_id = u.id
    )
)`;

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

// Cover album dari Deezer (cdn-images.dzcdn.net, dll.)
function isDeezerImageUrl(value) {
    try {
        const url = new URL(value);
        return url.protocol === "https:" && url.hostname.endsWith(".dzcdn.net");
    } catch (_) {
        return false;
    }
}

function parsePoll(raw) {
    if (raw === undefined || raw === null || raw === "") return null;

    let options = raw;

    if (typeof raw === "string") {
        try {
            options = JSON.parse(raw);
        } catch (_) {
            return { error: "Format polling tidak valid." };
        }
    }

    if (!Array.isArray(options)) {
        return { error: "Format polling tidak valid." };
    }

    const cleaned = options
        .map((option) => (typeof option === "string" ? option.trim() : ""))
        .filter(Boolean);

    if (cleaned.length < 2 || cleaned.length > 4) {
        return { error: "Polling harus punya 2 sampai 4 opsi." };
    }

    if (cleaned.some((option) => option.length > 80)) {
        return { error: "Setiap opsi polling maksimal 80 karakter." };
    }

    return { options: cleaned };
}

function optionalText(value, maxLength) {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    return trimmed.slice(0, maxLength);
}

async function getPollState(postId, userId) {
    const options = await pool.query(
        `SELECT
            po.id,
            po.option_text AS text,
            (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = po.id)::int AS votes
         FROM poll_options po
         WHERE po.post_id = $1
         ORDER BY po.position`,
        [postId]
    );

    const mine = await pool.query(
        "SELECT option_id FROM poll_votes WHERE post_id = $1 AND user_id = $2",
        [postId, userId]
    );

    return {
        poll_options: options.rows,
        my_vote: mine.rows.length ? mine.rows[0].option_id : null,
    };
}

// ---------------------------------------------------------------------------
// GET /api/posts
// Mengambil daftar postingan (lengkap dengan media, polling, kutipan, dll.)
// ---------------------------------------------------------------------------
router.get("/", optionalAuth, async (req, res) => {
    try {
        const viewerId = req.user ? req.user.id : null;
        // Postingan sementara yang sudah lewat 24 jam tidak ikut dimuat, dan
        // utas akun privat hanya tampil untuk pemilik & pengikut yang disetujui.
        const result = await pool.query(
            selectPosts(
                `WHERE (p.expires_at IS NULL OR p.expires_at > NOW())
                   AND ${VISIBLE_POSTS}`
            ),
            [viewerId]
        );

        return res.status(200).json({
            posts: result.rows,
        });
    } catch (error) {
        console.error("Get posts error:", error.message);

        return res.status(500).json({
            message: "Gagal mengambil postingan.",
        });
    }
});

// ---------------------------------------------------------------------------
// POST /api/posts
// Membuat postingan baru (harus login).
// Menerima multipart/form-data (dengan file) maupun JSON biasa.
//
// Field teks : content, gif_url, sticker_url, music_title, poll (JSON array),
//              quote_post_id, location_name, latitude, longitude
// Field file : media (maks. 4 foto/video), audio (1 musik)
// ---------------------------------------------------------------------------
router.post("/", authMiddleware, uploadPostFiles, async (req, res) => {
    const files = req.files || {};
    const mediaFiles = files.media || [];
    const audioFile = (files.audio || [])[0] || null;
    const uploadedFiles = audioFile ? [...mediaFiles, audioFile] : [...mediaFiles];

    const fail = (status, message) => {
        uploadedFiles.forEach((file) => fs.unlink(file.path, () => {}));
        return res.status(status).json({ message });
    };

    let client;

    try {
        const userId = req.user.id;
        const body = req.body || {};

        const content = typeof body.content === "string" ? body.content.trim() : "";

        if (content.length > 500) {
            return fail(400, "Postingan maksimal 500 karakter.");
        }

        const gifUrl = optionalText(body.gif_url, 1000);
        const stickerUrl = optionalText(body.sticker_url, 1000);

        if ((gifUrl && !isGiphyUrl(gifUrl)) || (stickerUrl && !isGiphyUrl(stickerUrl))) {
            return fail(400, "URL GIF/stiker tidak valid.");
        }

        if (audioFile && audioFile.size > MAX_AUDIO_BYTES) {
            return fail(400, "File musik terlalu besar (maksimal 20 MB).");
        }

        // Musik online (dipilih dari pemilih musik): hanya id lagu yang dipercaya
        const musicTrackId = optionalText(body.music_track_id, 20);

        if (musicTrackId && !/^\d{1,15}$/.test(musicTrackId)) {
            return fail(400, "ID musik tidak valid.");
        }

        if (musicTrackId && audioFile) {
            return fail(400, "Pilih salah satu: musik online atau file musik.");
        }

        const musicCoverRaw = optionalText(body.music_cover, 500);
        const musicCover =
            musicTrackId && musicCoverRaw && isDeezerImageUrl(musicCoverRaw)
                ? musicCoverRaw
                : null;

        const poll = parsePoll(body.poll);

        if (poll && poll.error) {
            return fail(400, poll.error);
        }

        const hasAttachment =
            mediaFiles.length > 0 ||
            audioFile ||
            musicTrackId ||
            gifUrl ||
            stickerUrl;

        if (poll && hasAttachment) {
            return fail(
                400,
                "Polling tidak bisa digabung dengan foto, video, GIF, stiker, atau musik."
            );
        }

        const quotePostId = optionalText(body.quote_post_id, 40);

        if (poll && quotePostId) {
            return fail(400, "Polling tidak bisa digabung dengan kutipan.");
        }

        if (quotePostId) {
            const quoted = await pool.query("SELECT id FROM posts WHERE id = $1", [
                quotePostId,
            ]);

            if (quoted.rowCount === 0) {
                return fail(404, "Postingan yang dikutip tidak ditemukan.");
            }
        }

        const locationName = optionalText(body.location_name, 200);
        let latitude = null;
        let longitude = null;

        if (locationName) {
            latitude = Number(body.latitude);
            longitude = Number(body.longitude);

            if (
                !Number.isFinite(latitude) ||
                !Number.isFinite(longitude) ||
                Math.abs(latitude) > 90 ||
                Math.abs(longitude) > 180
            ) {
                latitude = null;
                longitude = null;
            }
        }

        // Postingan sementara (catatan) & opsi balasan.
        const isTemporary = String(body.is_temporary) === "true";
        const REPLY_AUDIENCES = ["anyone", "followers", "following", "mentioned"];
        const replyAudience = REPLY_AUDIENCES.includes(body.reply_audience)
            ? body.reply_audience
            : "anyone";
        const approveReplies = String(body.approve_replies) === "true";

        // Label AI, lampiran teks, dan jadwal posting.
        const aiLabel = String(body.ai_label) === "true";
        const textAttachment = optionalText(body.text_attachment, 10000);

        let scheduledAt = null;

        if (body.scheduled_at !== undefined && body.scheduled_at !== "") {
            const when = new Date(body.scheduled_at);

            if (Number.isNaN(when.getTime())) {
                return fail(400, "Waktu jadwal tidak valid.");
            }

            const ahead = when.getTime() - Date.now();

            if (ahead < 30 * 1000) {
                return fail(400, "Pilih waktu jadwal di masa depan.");
            }

            if (ahead > 75 * 24 * 60 * 60 * 1000) {
                return fail(400, "Jadwal maksimal 75 hari ke depan.");
            }

            scheduledAt = when.toISOString();
        }

        if (isTemporary && content.length > 100) {
            return fail(400, "Postingan sementara maksimal 100 karakter.");
        }

        let musicTitle = null;
        let musicUrl = null;

        if (audioFile) {
            musicTitle =
                optionalText(body.music_title, 100) ||
                optionalText(audioFile.originalname, 100) ||
                "Musik";
            musicUrl = `/uploads/${audioFile.filename}`;
        } else if (musicTrackId) {
            musicTitle = optionalText(body.music_title, 100) || "Musik";
            musicUrl = `/api/music/preview/${musicTrackId}`;
        }

        if (
            !content &&
            !hasAttachment &&
            !poll &&
            !quotePostId &&
            !textAttachment
        ) {
            return fail(400, "Isi postingan wajib diisi.");
        }

        client = await pool.connect();
        await client.query("BEGIN");

        const inserted = await client.query(
            `INSERT INTO posts (
                user_id, content, gif_url, sticker_url, music_title, music_url,
                music_cover, quote_post_id, location_name, latitude, longitude,
                expires_at, reply_audience, approve_replies,
                ai_label, text_attachment, scheduled_at, mentions_pending, created_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
                     CASE WHEN $12::boolean
                          THEN COALESCE($17::timestamptz, NOW()) + INTERVAL '24 hours'
                          ELSE NULL END,
                     $13, $14, $15, $16, $17::timestamptz,
                     ($17::timestamptz IS NOT NULL),
                     COALESCE($17::timestamptz, NOW()))
             RETURNING id`,
            [
                userId,
                content,
                gifUrl,
                stickerUrl,
                musicTitle,
                musicUrl,
                musicCover,
                quotePostId,
                locationName,
                latitude,
                longitude,
                isTemporary,
                replyAudience,
                approveReplies,
                aiLabel,
                textAttachment,
                scheduledAt,
            ]
        );

        const postId = inserted.rows[0].id;

        for (let i = 0; i < mediaFiles.length; i += 1) {
            const file = mediaFiles[i];
            const type = file.mimetype.startsWith("video/") ? "video" : "image";

            await client.query(
                `INSERT INTO post_media (post_id, url, type, position)
                 VALUES ($1, $2, $3, $4)`,
                [postId, `/uploads/${file.filename}`, type, i]
            );
        }

        if (poll) {
            for (let i = 0; i < poll.options.length; i += 1) {
                await client.query(
                    `INSERT INTO poll_options (post_id, option_text, position)
                     VALUES ($1, $2, $3)`,
                    [postId, poll.options[i], i]
                );
            }
        }

        await client.query("COMMIT");

        // Postingan terjadwal: tidak muncul di daftar dan notifikasi penyebutan
        // ditunda sampai waktunya tiba (lihat utils/scheduler.js).
        if (scheduledAt) {
            return res.status(201).json({
                message: "Postingan dijadwalkan.",
                scheduled: true,
                scheduled_at: scheduledAt,
                post_id: postId,
            });
        }

        // Notifikasi penyebutan (@username) di postingan baru
        await notifyMentions({ text: content, actorId: userId, postId });

        const created = await pool.query(selectPosts("WHERE p.id = $2"), [
            userId,
            postId,
        ]);

        return res.status(201).json({
            message: "Postingan berhasil dibuat.",
            post: created.rows[0],
        });
    } catch (error) {
        if (client) {
            await client.query("ROLLBACK").catch(() => {});
        }

        console.error("Create post error:", error.message);

        if (error.code === "22P02") {
            return fail(400, "ID postingan yang dikutip tidak valid.");
        }

        return fail(500, "Gagal membuat postingan.");
    } finally {
        if (client) client.release();
    }
});

// ---------------------------------------------------------------------------
// POST /api/posts/:id/vote
// Memberi suara pada polling (satu suara per user per polling)
// Body: { "option_id": 12 }
// ---------------------------------------------------------------------------
router.post("/:id/vote", authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.id;
        const optionId = parseInt(req.body && req.body.option_id, 10);

        if (!Number.isInteger(optionId)) {
            return res.status(400).json({ message: "Pilihan polling tidak valid." });
        }

        const option = await pool.query(
            "SELECT id FROM poll_options WHERE id = $1 AND post_id = $2",
            [optionId, postId]
        );

        if (option.rowCount === 0) {
            return res.status(404).json({ message: "Pilihan polling tidak ditemukan." });
        }

        await pool.query(
            `INSERT INTO poll_votes (post_id, option_id, user_id)
             VALUES ($1, $2, $3)
             ON CONFLICT (post_id, user_id) DO NOTHING`,
            [postId, optionId, userId]
        );

        const state = await getPollState(postId, userId);

        return res.status(200).json(state);
    } catch (error) {
        console.error("Vote error:", error.message);

        if (error.code === "22P02") {
            return res.status(400).json({ message: "ID postingan tidak valid." });
        }

        return res.status(500).json({ message: "Gagal memberikan suara." });
    }
});

// ---------------------------------------------------------------------------
// Suka dan posting ulang
//
// POST   /api/posts/:id/like     -> suka       (idempoten)
// DELETE /api/posts/:id/like     -> batal suka (idempoten)
// POST   /api/posts/:id/repost   -> posting ulang
// DELETE /api/posts/:id/repost   -> batalkan posting ulang
//
// Semua membalas { liked | reposted: boolean, like_count | repost_count: number }
// ---------------------------------------------------------------------------
function toggleRoute(table, flagName, countName, addByDefault) {
    const handler = (add) => async (req, res) => {
        try {
            const userId = req.user.id;
            const postId = req.params.id;

            const post = await pool.query(
                "SELECT id, user_id FROM posts WHERE id = $1",
                [postId]
            );

            if (post.rowCount === 0) {
                return res.status(404).json({ message: "Postingan tidak ditemukan." });
            }

            if (add) {
                await pool.query(
                    `INSERT INTO ${table} (post_id, user_id)
                     VALUES ($1, $2)
                     ON CONFLICT (post_id, user_id) DO NOTHING`,
                    [postId, userId]
                );
            } else {
                await pool.query(
                    `DELETE FROM ${table} WHERE post_id = $1 AND user_id = $2`,
                    [postId, userId]
                );
            }

            // Notifikasi untuk pemilik postingan (suka / posting ulang)
            const likeOrRepost = {
                userId: post.rows[0].user_id,
                actorId: userId,
                type: table === "post_likes" ? "like" : "repost",
                postId,
            };

            if (add) {
                await notify(likeOrRepost);
            } else {
                await unnotify(likeOrRepost);
            }

            const count = await pool.query(
                `SELECT COUNT(*)::int AS total FROM ${table} WHERE post_id = $1`,
                [postId]
            );

            return res.status(200).json({
                [flagName]: add,
                [countName]: count.rows[0].total,
            });
        } catch (error) {
            console.error(`${table} error:`, error.message);

            if (error.code === "22P02") {
                return res.status(400).json({ message: "ID postingan tidak valid." });
            }

            return res.status(500).json({ message: "Gagal memproses permintaan." });
        }
    };

    return handler(addByDefault);
}

router.post("/:id/like", authMiddleware, toggleRoute("post_likes", "liked", "like_count", true));
router.delete("/:id/like", authMiddleware, toggleRoute("post_likes", "liked", "like_count", false));
router.post("/:id/repost", authMiddleware, toggleRoute("post_reposts", "reposted", "repost_count", true));
router.delete("/:id/repost", authMiddleware, toggleRoute("post_reposts", "reposted", "repost_count", false));

// ---------------------------------------------------------------------------
// Komentar (bersarang) + suka komentar + jumlah dilihat + tab Balasan
//
// GET    /api/posts/:id/comments              -> { comments: [...] } (terlama di atas)
//        Setiap komentar punya parent_id (null = komentar utama), like_count,
//        reply_count, liked_by_me. Header Authorization opsional.
// POST   /api/posts/:id/comments              -> body { "content": "...", "parent_id": 12? }
// POST   /api/posts/comments/:commentId/like  -> suka komentar
// DELETE /api/posts/comments/:commentId/like  -> batal suka komentar
// POST   /api/posts/:id/view                  -> tambah jumlah dilihat
// GET    /api/posts/me/replies                -> { replies: [...] } balasan milik user login
// ---------------------------------------------------------------------------

// Kolom komentar yang dikirim ke aplikasi. $1 = id user yang melihat (boleh null).
const COMMENT_COLUMNS = `
    c.id,
    c.post_id,
    c.user_id,
    c.parent_id,
    c.content,
    c.media_url,
    c.media_type,
    c.created_at,
    u.username,
    u.display_name,
    u.profile_picture,
    (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.id)::int AS like_count,
    (SELECT COUNT(*) FROM post_comments ch WHERE ch.parent_id = c.id)::int AS reply_count,
    EXISTS (
        SELECT 1 FROM comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = $1
    ) AS liked_by_me
`;

// Ringkasan komentar sebagai JSON (untuk tab Balasan).
function commentJson(commentAlias, userAlias) {
    return `json_build_object(
        'id', ${commentAlias}.id,
        'user_id', ${commentAlias}.user_id,
        'content', ${commentAlias}.content,
        'media_url', ${commentAlias}.media_url,
        'media_type', ${commentAlias}.media_type,
        'created_at', ${commentAlias}.created_at,
        'username', ${userAlias}.username,
        'display_name', ${userAlias}.display_name,
        'profile_picture', ${userAlias}.profile_picture,
        'like_count', (SELECT COUNT(*) FROM comment_likes x WHERE x.comment_id = ${commentAlias}.id)::int,
        'reply_count', (SELECT COUNT(*) FROM post_comments y WHERE y.parent_id = ${commentAlias}.id)::int
    )`;
}

router.get("/:id/comments", optionalAuth, async (req, res) => {
    try {
        const viewerId = req.user ? req.user.id : null;

        const result = await pool.query(
            `SELECT ${COMMENT_COLUMNS}
             FROM post_comments c
             JOIN users u ON u.id = c.user_id
             WHERE c.post_id = $2
             ORDER BY c.created_at ASC, c.id ASC
             LIMIT 500`,
            [viewerId, req.params.id]
        );

        return res.status(200).json({ comments: result.rows });
    } catch (error) {
        console.error("Get comments error:", error.message);

        if (error.code === "22P02") {
            return res.status(400).json({ message: "ID postingan tidak valid." });
        }

        return res.status(500).json({ message: "Gagal mengambil komentar." });
    }
});

router.post("/:id/comments", authMiddleware, uploadCommentMedia, async (req, res) => {
    // Foto yang sudah terunggah dihapus lagi kalau komentar ditolak.
    if (req.file) {
        res.on("finish", () => {
            if (res.statusCode >= 400) fs.unlink(req.file.path, () => {});
        });
    }

    try {
        const userId = req.user.id;
        const postId = req.params.id;
        const content =
            typeof (req.body && req.body.content) === "string"
                ? req.body.content.trim()
                : "";

        // Media komentar: foto unggahan, atau GIF / stiker dari Giphy.
        let mediaUrl = null;
        let mediaType = null;

        if (req.file) {
            mediaUrl = `/uploads/${req.file.filename}`;
            mediaType = "image";
        } else {
            const rawUrl = optionalText(req.body && req.body.media_url, 1000);

            if (rawUrl) {
                if (!isGiphyUrl(rawUrl)) {
                    return res.status(400).json({ message: "URL GIF/stiker tidak valid." });
                }

                mediaUrl = rawUrl;
                mediaType = req.body.media_type === "sticker" ? "sticker" : "gif";
            }
        }

        if (!content && !mediaUrl) {
            return res.status(400).json({ message: "Komentar tidak boleh kosong." });
        }

        if (content.length > 500) {
            return res.status(400).json({ message: "Komentar maksimal 500 karakter." });
        }

        const post = await pool.query(
            "SELECT id, user_id, content, reply_audience FROM posts WHERE id = $1",
            [postId]
        );

        if (post.rowCount === 0) {
            return res.status(404).json({ message: "Postingan tidak ditemukan." });
        }

        // Pengaturan "siapa yang bisa membalas" dari pemilik postingan.
        const audience = post.rows[0].reply_audience || "anyone";
        const ownerId = post.rows[0].user_id;

        if (audience !== "anyone" && String(ownerId) !== String(userId)) {
            let allowed = false;

            if (audience === "followers") {
                const r = await pool.query(
                    "SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2",
                    [userId, ownerId]
                );
                allowed = r.rowCount > 0;
            } else if (audience === "following") {
                const r = await pool.query(
                    "SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2",
                    [ownerId, userId]
                );
                allowed = r.rowCount > 0;
            } else if (audience === "mentioned") {
                const me = await pool.query(
                    "SELECT LOWER(username) AS username FROM users WHERE id = $1",
                    [userId]
                );
                const mentions =
                    String(post.rows[0].content || "")
                        .toLowerCase()
                        .match(/@[a-z0-9._]{3,30}/g) || [];
                allowed = mentions.some(
                    (m) => m.slice(1).replace(/\.+$/, "") === (me.rows[0] || {}).username
                );
            }

            if (!allowed) {
                return res.status(403).json({
                    message: "Pemilik postingan membatasi siapa yang bisa membalas.",
                });
            }
        }

        // Balasan: komentar induk harus ada dan milik postingan yang sama.
        let parentId = null;
        let parentOwnerId = null;
        const rawParent = req.body && req.body.parent_id;

        if (rawParent !== undefined && rawParent !== null && rawParent !== "") {
            parentId = parseInt(rawParent, 10);

            if (!Number.isInteger(parentId)) {
                return res.status(400).json({ message: "Komentar yang dibalas tidak valid." });
            }

            const parent = await pool.query(
                "SELECT id, user_id FROM post_comments WHERE id = $1 AND post_id = $2",
                [parentId, postId]
            );

            if (parent.rowCount === 0) {
                return res.status(404).json({ message: "Komentar yang dibalas tidak ditemukan." });
            }

            parentOwnerId = parent.rows[0].user_id;
        }

        const inserted = await pool.query(
            `INSERT INTO post_comments
                 (post_id, user_id, parent_id, content, media_url, media_type)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING id`,
            [postId, userId, parentId, content, mediaUrl, mediaType]
        );

        const created = await pool.query(
            `SELECT ${COMMENT_COLUMNS}
             FROM post_comments c
             JOIN users u ON u.id = c.user_id
             WHERE c.id = $2`,
            [userId, inserted.rows[0].id]
        );

        const count = await pool.query(
            "SELECT COUNT(*)::int AS total FROM post_comments WHERE post_id = $1",
            [postId]
        );

        // Notifikasi: balasan untuk pemilik postingan & pemilik komentar yang dibalas
        const newCommentId = inserted.rows[0].id;
        const notified = new Set();

        for (const ownerId of [post.rows[0].user_id, parentOwnerId]) {
            if (ownerId == null || notified.has(String(ownerId))) continue;

            notified.add(String(ownerId));

            await notify({
                userId: ownerId,
                actorId: userId,
                type: "reply",
                postId,
                commentId: newCommentId,
            });
        }

        await notifyMentions({
            text: content,
            actorId: userId,
            postId,
            commentId: newCommentId,
            excludeUserIds: [...notified],
        });

        return res.status(201).json({
            comment: created.rows[0],
            comment_count: count.rows[0].total,
        });
    } catch (error) {
        console.error("Create comment error:", error.message);

        if (error.code === "22P02") {
            return res.status(400).json({ message: "ID postingan tidak valid." });
        }

        return res.status(500).json({ message: "Gagal mengirim komentar." });
    }
});

function commentLikeRoute(add) {
    return async (req, res) => {
        try {
            const userId = req.user.id;
            const commentId = parseInt(req.params.commentId, 10);

            if (!Number.isInteger(commentId)) {
                return res.status(400).json({ message: "ID komentar tidak valid." });
            }

            const comment = await pool.query(
                "SELECT id, user_id, post_id FROM post_comments WHERE id = $1",
                [commentId]
            );

            if (comment.rowCount === 0) {
                return res.status(404).json({ message: "Komentar tidak ditemukan." });
            }

            if (add) {
                await pool.query(
                    `INSERT INTO comment_likes (comment_id, user_id)
                     VALUES ($1, $2)
                     ON CONFLICT (comment_id, user_id) DO NOTHING`,
                    [commentId, userId]
                );
            } else {
                await pool.query(
                    "DELETE FROM comment_likes WHERE comment_id = $1 AND user_id = $2",
                    [commentId, userId]
                );
            }

            // Notifikasi untuk pemilik komentar
            const commentLike = {
                userId: comment.rows[0].user_id,
                actorId: userId,
                type: "comment_like",
                postId: comment.rows[0].post_id,
                commentId,
            };

            if (add) {
                await notify(commentLike);
            } else {
                await unnotify(commentLike);
            }

            const count = await pool.query(
                "SELECT COUNT(*)::int AS total FROM comment_likes WHERE comment_id = $1",
                [commentId]
            );

            return res.status(200).json({ liked: add, like_count: count.rows[0].total });
        } catch (error) {
            console.error("Comment like error:", error.message);

            return res.status(500).json({ message: "Gagal memproses permintaan." });
        }
    };
}

router.post("/comments/:commentId/like", authMiddleware, commentLikeRoute(true));
router.delete("/comments/:commentId/like", authMiddleware, commentLikeRoute(false));

// Jumlah dilihat: dipanggil sekali setiap halaman postingan dibuka.
router.post("/:id/view", optionalAuth, async (req, res) => {
    try {
        const result = await pool.query(
            "UPDATE posts SET view_count = view_count + 1 WHERE id = $1 RETURNING view_count",
            [req.params.id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: "Postingan tidak ditemukan." });
        }

        // Riwayat tayangan (untuk grafik Insight). Gagal mencatat tidak boleh
        // membatalkan penghitung tayangan.
        try {
            await pool.query(
                "INSERT INTO post_views (post_id, viewer_id) VALUES ($1, $2)",
                [req.params.id, req.user ? req.user.id : null]
            );
        } catch (viewError) {
            console.error("post_views insert error:", viewError.message);
        }

        return res.status(200).json({ view_count: result.rows[0].view_count });
    } catch (error) {
        if (error.code === "22P02") {
            return res.status(400).json({ message: "ID postingan tidak valid." });
        }

        console.error("View error:", error.message);

        return res.status(500).json({ message: "Gagal memproses permintaan." });
    }
});

// Insight akun: GET /api/posts/me/insights?days=7|14|30|90
// -> { days, profile: {...}, audience: {...} }
// Periode sebelumnya (untuk persentase perubahan) = rentang yang sama tepat
// sebelum periode sekarang. Tayangan baru tercatat sejak tabel post_views ada.
router.get("/me/insights", authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const requested = parseInt(req.query.days, 10);
        const days = [7, 14, 30, 90].includes(requested) ? requested : 30;

        const cur = "NOW() - ($2::int * INTERVAL '1 day')";
        const interactionTypes = "('like','comment_like','reply','mention','repost')";

        const views = await pool.query(
            `WITH v AS (
                SELECT pv.viewer_id, pv.created_at
                FROM post_views pv
                WHERE pv.post_id IN (SELECT id FROM posts WHERE user_id = $1)
                  AND pv.viewer_id IS DISTINCT FROM $1
                  AND pv.created_at >= NOW() - (($2::int * 2) * INTERVAL '1 day')
            ),
            fol AS (SELECT follower_id FROM follows WHERE following_id = $1)
            SELECT
                COUNT(*) FILTER (WHERE created_at >= ${cur})::int AS views,
                COUNT(*) FILTER (WHERE created_at < ${cur})::int AS views_prev,
                COUNT(DISTINCT viewer_id) FILTER (
                    WHERE created_at >= ${cur}
                )::int AS viewers,
                COUNT(DISTINCT viewer_id) FILTER (
                    WHERE created_at < ${cur}
                )::int AS viewers_prev,
                COUNT(DISTINCT viewer_id) FILTER (
                    WHERE created_at >= ${cur}
                      AND viewer_id IN (SELECT follower_id FROM fol)
                )::int AS follower_viewers,
                COUNT(DISTINCT viewer_id) FILTER (
                    WHERE created_at < ${cur}
                      AND viewer_id IN (SELECT follower_id FROM fol)
                )::int AS follower_viewers_prev
            FROM v`,
            [userId, days]
        );

        const followers = await pool.query(
            `SELECT
                COUNT(*) FILTER (WHERE created_at >= ${cur})::int AS followers,
                COUNT(*) FILTER (
                    WHERE created_at < ${cur}
                      AND created_at >= NOW() - (($2::int * 2) * INTERVAL '1 day')
                )::int AS followers_prev,
                COUNT(*)::int AS total
             FROM follows
             WHERE following_id = $1`,
            [userId, days]
        );

        const interactions = await pool.query(
            `SELECT
                COUNT(*) FILTER (WHERE created_at >= ${cur})::int AS interactions,
                COUNT(*) FILTER (WHERE created_at < ${cur})::int AS interactions_prev
             FROM notifications
             WHERE user_id = $1
               AND type IN ${interactionTypes}
               AND created_at >= NOW() - (($2::int * 2) * INTERVAL '1 day')`,
            [userId, days]
        );

        // Data harian untuk grafik (satu baris per hari, termasuk hari kosong).
        const days_ = "generate_series(CURRENT_DATE - ($2::int - 1), CURRENT_DATE, '1 day'::interval)";
        const daySeries = async (joinSql, countExpr) => {
            const r = await pool.query(
                `SELECT to_char(d, 'YYYY-MM-DD') AS date, ${countExpr}::int AS value
                 FROM ${days_} d
                 LEFT JOIN ${joinSql}
                 GROUP BY d
                 ORDER BY d`,
                [userId, days]
            );
            return r.rows;
        };

        const [sViews, sViewers, sFollowers, sInteractions] = await Promise.all([
            daySeries(
                `post_views pv
                   ON pv.created_at >= d AND pv.created_at < d + INTERVAL '1 day'
                  AND pv.post_id IN (SELECT id FROM posts WHERE user_id = $1)
                  AND pv.viewer_id IS DISTINCT FROM $1`,
                "COUNT(pv.id)"
            ),
            daySeries(
                `post_views pv
                   ON pv.created_at >= d AND pv.created_at < d + INTERVAL '1 day'
                  AND pv.post_id IN (SELECT id FROM posts WHERE user_id = $1)
                  AND pv.viewer_id IS DISTINCT FROM $1`,
                "COUNT(DISTINCT pv.viewer_id)"
            ),
            daySeries(
                `follows f
                   ON f.following_id = $1
                  AND f.created_at >= d AND f.created_at < d + INTERVAL '1 day'`,
                "COUNT(f.follower_id)"
            ),
            daySeries(
                `notifications n
                   ON n.user_id = $1
                  AND n.type IN ${interactionTypes}
                  AND n.created_at >= d AND n.created_at < d + INTERVAL '1 day'`,
                "COUNT(n.id)"
            ),
        ]);

        const v = views.rows[0];
        const f = followers.rows[0];
        const i = interactions.rows[0];

        return res.status(200).json({
            days,
            profile: {
                views: v.views,
                views_prev: v.views_prev,
                viewers: v.viewers,
                viewers_prev: v.viewers_prev,
                followers: f.followers,
                followers_prev: f.followers_prev,
                interactions: i.interactions,
                interactions_prev: i.interactions_prev,
                series: {
                    views: sViews,
                    viewers: sViewers,
                    followers: sFollowers,
                    interactions: sInteractions,
                },
            },
            audience: {
                viewers: v.viewers,
                viewers_prev: v.viewers_prev,
                follower_viewers: v.follower_viewers,
                follower_viewers_prev: v.follower_viewers_prev,
                non_follower_viewers: Math.max(0, v.viewers - v.follower_viewers),
                non_follower_viewers_prev: Math.max(
                    0,
                    v.viewers_prev - v.follower_viewers_prev
                ),
                followers_total: f.total,
                followers_new: f.followers,
                followers_new_prev: f.followers_prev,
            },
        });
    } catch (error) {
        console.error("Get insights error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil insight." });
    }
});

// Tab "Balasan": semua komentar/balasan milik user yang login, terbaru dulu.
// Tiap item membawa: post (postingan asli), parent (komentar yang dibalas, bila
// ini balasan untuk komentar), first_reply (balasan pertama dari orang lain).
router.get("/me/replies", authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;

        const result = await pool.query(
            `SELECT
                ${COMMENT_COLUMNS},
                (
                    SELECT json_build_object(
                        'id', p.id,
                        'user_id', p.user_id,
                        'content', p.content,
                        'created_at', p.created_at,
                        'username', pu.username,
                        'display_name', pu.display_name,
                        'profile_picture', pu.profile_picture,
                        'like_count', (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int,
                        'comment_count', (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id)::int,
                        'repost_count', (SELECT COUNT(*) FROM post_reposts r WHERE r.post_id = p.id)::int,
                        'gif_url', p.gif_url,
                        'sticker_url', p.sticker_url,
                        'music_title', p.music_title,
                        'music_url', p.music_url,
                        'music_cover', p.music_cover,
                        'location_name', p.location_name,
                        'media', COALESCE((
                            SELECT json_agg(
                                json_build_object('url', m.url, 'type', m.type)
                                ORDER BY m.position
                            )
                            FROM post_media m
                            WHERE m.post_id = p.id
                        ), '[]'::json),
                        'is_first_post', NOT EXISTS (
                            SELECT 1 FROM posts e
                            WHERE e.user_id = p.user_id AND e.created_at < p.created_at
                        )
                    )
                    FROM posts p
                    JOIN users pu ON pu.id = p.user_id
                    WHERE p.id = c.post_id
                ) AS post,
                (
                    SELECT ${commentJson("par", "paru")}
                    FROM post_comments par
                    JOIN users paru ON paru.id = par.user_id
                    WHERE par.id = c.parent_id
                ) AS parent,
                (
                    SELECT ${commentJson("fr", "fru")}
                    FROM post_comments fr
                    JOIN users fru ON fru.id = fr.user_id
                    WHERE fr.parent_id = c.id
                    ORDER BY fr.created_at ASC, fr.id ASC
                    LIMIT 1
                ) AS first_reply
             FROM post_comments c
             JOIN users u ON u.id = c.user_id
             WHERE c.user_id = $1
             ORDER BY c.created_at DESC, c.id DESC
             LIMIT 100`,
            [userId]
        );

        return res.status(200).json({ replies: result.rows });
    } catch (error) {
        console.error("Get my replies error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil balasan." });
    }
});

// Tab "Postingan ulang": postingan yang diposting ulang oleh user yang login.
router.get("/me/reposts", authMiddleware, async (req, res) => {
    try {
        const result = await pool.query(
            selectPosts(
                `WHERE p.id IN (SELECT rp.post_id FROM post_reposts rp WHERE rp.user_id = $1)`
            ),
            [req.user.id]
        );

        return res.status(200).json({ posts: result.rows });
    } catch (error) {
        console.error("Get my reposts error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil postingan ulang." });
    }
});

// Tab "Postingan ulang" milik akun lain (profil orang lain).
router.get("/user/:username/reposts", authMiddleware, async (req, res) => {
    try {
        const found = await pool.query(
            `SELECT u.id, (to_jsonb(u) ->> 'is_private') = 'true' AS is_private
             FROM users u
             WHERE LOWER(u.username) = LOWER($1)
             LIMIT 1`,
            [req.params.username]
        );

        const target = found.rows[0];

        if (!target) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        const isMe = String(target.id) === String(req.user.id);

        if (target.is_private && !isMe) {
            const rel = await pool.query(
                "SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2",
                [req.user.id, target.id]
            );

            if (rel.rowCount === 0) {
                return res.status(403).json({ message: "Akun ini privat." });
            }
        }

        const result = await pool.query(
            selectPosts(
                `WHERE p.id IN (SELECT rp.post_id FROM post_reposts rp WHERE rp.user_id = $2)
                   AND ${VISIBLE_POSTS}`
            ),
            [req.user.id, target.id]
        );

        return res.status(200).json({ posts: result.rows });
    } catch (error) {
        console.error("Get user reposts error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil postingan ulang." });
    }
});

// Tab "Balasan" milik akun lain (profil orang lain).
// Sama seperti /me/replies, tetapi untuk user mana pun.
// $1 = id user yang melihat, $2 = id pemilik balasan.
const USER_REPLIES_SQL = `
    SELECT
        ${COMMENT_COLUMNS},
        (
            SELECT json_build_object(
                'id', p.id,
                'user_id', p.user_id,
                'content', p.content,
                'created_at', p.created_at,
                'username', pu.username,
                'display_name', pu.display_name,
                'profile_picture', pu.profile_picture,
                'like_count', (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id)::int,
                'comment_count', (SELECT COUNT(*) FROM post_comments pc WHERE pc.post_id = p.id)::int,
                'repost_count', (SELECT COUNT(*) FROM post_reposts r WHERE r.post_id = p.id)::int
            )
            FROM posts p
            JOIN users pu ON pu.id = p.user_id
            WHERE p.id = c.post_id
        ) AS post,
        (
            SELECT ${commentJson("par", "paru")}
            FROM post_comments par
            JOIN users paru ON paru.id = par.user_id
            WHERE par.id = c.parent_id
        ) AS parent
    FROM post_comments c
    JOIN users u ON u.id = c.user_id
    WHERE c.user_id = $2
    ORDER BY c.created_at DESC, c.id DESC
    LIMIT 100`;

router.get("/user/:username/replies", authMiddleware, async (req, res) => {
    try {
        const found = await pool.query(
            `SELECT u.id, (to_jsonb(u) ->> 'is_private') = 'true' AS is_private
             FROM users u
             WHERE LOWER(u.username) = LOWER($1)
             LIMIT 1`,
            [req.params.username]
        );

        const target = found.rows[0];

        if (!target) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        const isMe = String(target.id) === String(req.user.id);

        if (target.is_private && !isMe) {
            const rel = await pool.query(
                "SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2",
                [req.user.id, target.id]
            );

            if (rel.rowCount === 0) {
                return res.status(403).json({ message: "Akun ini privat." });
            }
        }

        const result = await pool.query(USER_REPLIES_SQL, [req.user.id, target.id]);

        return res.status(200).json({ replies: result.rows });
    } catch (error) {
        console.error("Get user replies error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil balasan." });
    }
});

// ---------------------------------------------------------------------------
// Postingan yang saya sukai / simpan (dipakai pemilih kutipan)
//
// GET    /api/posts/me/liked   -> { posts: [...] }
// GET    /api/posts/me/saved   -> { posts: [...] }
// POST   /api/posts/:id/save   -> simpan postingan
// DELETE /api/posts/:id/save   -> batal simpan
// ---------------------------------------------------------------------------
router.get("/me/liked", authMiddleware, async (req, res) => {
    try {
        const result = await pool.query(
            selectPosts(
                `WHERE EXISTS (
                        SELECT 1 FROM post_likes ml
                        WHERE ml.post_id = p.id AND ml.user_id = $1
                    )
                    AND (p.expires_at IS NULL OR p.expires_at > NOW())
                    AND ${VISIBLE_POSTS}`
            ),
            [req.user.id]
        );

        return res.status(200).json({ posts: result.rows });
    } catch (error) {
        console.error("Get liked posts error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil postingan yang disukai." });
    }
});

router.get("/me/saved", authMiddleware, async (req, res) => {
    try {
        const result = await pool.query(
            selectPosts(
                `WHERE EXISTS (
                        SELECT 1 FROM post_saves ms
                        WHERE ms.post_id = p.id AND ms.user_id = $1
                    )
                    AND (p.expires_at IS NULL OR p.expires_at > NOW())
                    AND ${VISIBLE_POSTS}`
            ),
            [req.user.id]
        );

        return res.status(200).json({ posts: result.rows });
    } catch (error) {
        console.error("Get saved posts error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil postingan tersimpan." });
    }
});

router.post("/:id/save", authMiddleware, async (req, res) => {
    try {
        const exists = await pool.query("SELECT 1 FROM posts WHERE id = $1", [req.params.id]);

        if (exists.rowCount === 0) {
            return res.status(404).json({ message: "Postingan tidak ditemukan." });
        }

        await pool.query(
            `INSERT INTO post_saves (user_id, post_id) VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [req.user.id, req.params.id]
        );

        return res.status(200).json({ saved: true });
    } catch (error) {
        console.error("Save post error:", error.message);

        if (error.code === "22P02") {
            return res.status(400).json({ message: "ID postingan tidak valid." });
        }

        return res.status(500).json({ message: "Gagal menyimpan postingan." });
    }
});

router.delete("/:id/save", authMiddleware, async (req, res) => {
    try {
        await pool.query(
            "DELETE FROM post_saves WHERE user_id = $1 AND post_id = $2",
            [req.user.id, req.params.id]
        );

        return res.status(200).json({ saved: false });
    } catch (error) {
        console.error("Unsave post error:", error.message);

        return res.status(500).json({ message: "Gagal membatalkan simpan." });
    }
});

// ───────────── Hapus utas milik sendiri ─────────────

const deleteFs = require("fs");
const deletePath = require("path");

const DELETE_UPLOAD_DIR = deletePath.join(__dirname, "..", "uploads");

/** Hapus file hasil unggahan (foto, video, musik). Alamat luar (Giphy, Deezer) diabaikan. */
function removeUploadedFile(url) {
    if (typeof url !== "string" || !url.startsWith("/uploads/")) return;

    const name = deletePath.basename(url);

    // Cegah nama aneh seperti "../.." supaya hanya file di folder uploads yang terhapus.
    if (!name || name !== url.slice("/uploads/".length)) return;

    deleteFs.unlink(deletePath.join(DELETE_UPLOAD_DIR, name), () => {});
}

router.delete("/:id", authMiddleware, async (req, res) => {
    try {
        const id = req.params.id;

        if (!/^\d{1,18}$/.test(id)) {
            return res.status(400).json({ message: "Utas tidak valid." });
        }

        const found = await pool.query(
            "SELECT id, user_id, music_url FROM posts WHERE id = $1",
            [id]
        );

        const post = found.rows[0];

        if (!post) {
            return res.status(404).json({ message: "Utas tidak ditemukan." });
        }

        if (String(post.user_id) !== String(req.user.id)) {
            return res
                .status(403)
                .json({ message: "Kamu hanya bisa menghapus utasmu sendiri." });
        }

        // Catat file-nya dulu, karena baris post_media ikut terhapus bersama utas.
        const media = await pool.query(
            "SELECT url FROM post_media WHERE post_id = $1",
            [id]
        );

        await pool.query("DELETE FROM posts WHERE id = $1 AND user_id = $2", [
            id,
            req.user.id,
        ]);

        // File dihapus SETELAH utasnya berhasil terhapus.
        [...media.rows.map((row) => row.url), post.music_url].forEach(
            removeUploadedFile
        );

        return res.status(200).json({ ok: true, id: post.id });
    } catch (error) {
        // 23503 = masih ada tabel lain yang menunjuk ke utas ini tanpa aturan hapus.
        if (error.code === "23503") {
            console.error(
                "Hapus utas tertahan relasi:",
                error.table,
                error.constraint
            );

            return res.status(409).json({
                message:
                    "Utas ini belum bisa dihapus karena masih terhubung ke data lain.",
            });
        }

        console.error("Delete post error:", error.message);

        return res.status(500).json({ message: "Gagal menghapus utas." });
    }
});

module.exports = router;