// utils/notifications.js
//
// Helper untuk membuat / menghapus notifikasi (tabel "notifications").
// Dipakai oleh routes/follows.js dan routes/posts.js.

const pool = require("../config/db");

// Jenis yang tidak boleh dobel (suka, posting ulang, ikuti).
const TOGGLE_TYPES = [
    "like",
    "comment_like",
    "repost",
    "follow",
    "follow_request",
    "follow_accept",
];

/**
 * Buat satu notifikasi.
 *  - userId  : penerima
 *  - actorId : pelaku
 *  - type    : 'like' | 'comment_like' | 'reply' | 'mention' | 'repost' | 'follow'
 *              | 'follow_request' | 'follow_accept'
 * Aksi terhadap diri sendiri diabaikan. Kegagalan di sini tidak pernah
 * menggagalkan aksi utama (suka, komentar, dst.).
 */
async function notify({ userId, actorId, type, postId = null, commentId = null }) {
    try {
        if (userId == null || actorId == null) return;
        if (String(userId) === String(actorId)) return;

        const params = [userId, actorId, type, postId, commentId];

        if (TOGGLE_TYPES.includes(type)) {
            await pool.query(
                `INSERT INTO notifications (user_id, actor_id, type, post_id, comment_id)
                 SELECT $1::bigint, $2::bigint, $3::text, $4::bigint, $5::bigint
                 WHERE NOT EXISTS (
                     SELECT 1 FROM notifications
                     WHERE user_id = $1::bigint
                       AND actor_id = $2::bigint
                       AND type = $3::text
                       AND post_id IS NOT DISTINCT FROM $4::bigint
                       AND comment_id IS NOT DISTINCT FROM $5::bigint
                 )`,
                params
            );
        } else {
            await pool.query(
                `INSERT INTO notifications (user_id, actor_id, type, post_id, comment_id)
                 VALUES ($1, $2, $3, $4, $5)`,
                params
            );
        }
    } catch (error) {
        console.error("notify error:", error.message);
    }
}

/** Hapus notifikasi (batal suka / batal posting ulang / berhenti mengikuti). */
async function unnotify({ userId, actorId, type, postId = null, commentId = null }) {
    try {
        if (userId == null || actorId == null) return;

        await pool.query(
            `DELETE FROM notifications
             WHERE user_id = $1::bigint
               AND actor_id = $2::bigint
               AND type = $3::text
               AND post_id IS NOT DISTINCT FROM $4::bigint
               AND comment_id IS NOT DISTINCT FROM $5::bigint`,
            [userId, actorId, type, postId, commentId]
        );
    } catch (error) {
        console.error("unnotify error:", error.message);
    }
}

/**
 * Kirim notifikasi "mention" ke setiap @username yang ada di [text].
 * [excludeUserIds] = user yang sudah dapat notifikasi lain dari aksi yang sama.
 */
async function notifyMentions({
    text,
    actorId,
    postId = null,
    commentId = null,
    excludeUserIds = [],
}) {
    try {
        const matches = String(text || "").match(/@([A-Za-z0-9._]{3,30})/g) || [];
        const names = [
            ...new Set(
                matches.map((m) => m.slice(1).replace(/\.+$/, "").toLowerCase())
            ),
        ].filter(Boolean);

        if (names.length === 0) return;

        const result = await pool.query(
            "SELECT id FROM users WHERE LOWER(username) = ANY($1::text[])",
            [names]
        );

        const exclude = new Set(excludeUserIds.map(String));

        for (const row of result.rows) {
            if (exclude.has(String(row.id))) continue;

            await notify({
                userId: row.id,
                actorId,
                type: "mention",
                postId,
                commentId,
            });
        }
    } catch (error) {
        console.error("notifyMentions error:", error.message);
    }
}

module.exports = { notify, unnotify, notifyMentions };