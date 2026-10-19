// utils/scheduler.js
//
// Pekerjaan latar belakang untuk postingan terjadwal.
//
// Postingan terjadwal sebenarnya sudah tersimpan di tabel "posts" dengan
// scheduled_at di masa depan; selectPosts() menyembunyikannya sampai waktunya
// tiba. Yang perlu dilakukan saat waktunya tiba hanyalah mengirim notifikasi
// penyebutan (@username) yang ditunda saat postingan dibuat.

const pool = require("../config/db");
const { notifyMentions } = require("./notifications");

const INTERVAL_MS = 30 * 1000;

async function publishDuePosts() {
    try {
        const due = await pool.query(
            `SELECT id, user_id, content
             FROM posts
             WHERE mentions_pending = TRUE
               AND scheduled_at IS NOT NULL
               AND scheduled_at <= NOW()
             ORDER BY scheduled_at ASC
             LIMIT 50`
        );

        for (const post of due.rows) {
            // Tandai dulu supaya tidak terkirim dua kali walau server ramai.
            const claimed = await pool.query(
                `UPDATE posts SET mentions_pending = FALSE
                 WHERE id = $1 AND mentions_pending = TRUE`,
                [post.id]
            );

            if (claimed.rowCount === 0) continue;

            await notifyMentions({
                text: post.content,
                actorId: post.user_id,
                postId: post.id,
            });
        }
    } catch (error) {
        console.error("Scheduler error:", error.message);
    }
}

function startScheduler() {
    publishDuePosts();
    return setInterval(publishDuePosts, INTERVAL_MS);
}

module.exports = { startScheduler, publishDuePosts };