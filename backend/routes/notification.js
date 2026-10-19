// routes/notification.js
//
//   GET  /api/notifications               -> { notifications: [...], unread_count }
//   GET  /api/notifications/unread-count  -> { unread_count }
//   POST /api/notifications/read-all      -> tandai semua sudah dibaca
//
// (Helper notify / unnotify ada di utils/notifications.js)

const express = require("express");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

router.get("/", async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT
                n.id,
                n.type,
                n.post_id,
                n.comment_id,
                n.is_read,
                n.created_at,
                a.username AS actor_username,
                a.display_name AS actor_display_name,
                a.profile_picture AS actor_profile_picture,
                p.content AS post_content,
                c.content AS comment_content
             FROM notifications n
             JOIN users a ON a.id = n.actor_id
             LEFT JOIN posts p ON p.id = n.post_id
             LEFT JOIN post_comments c ON c.id = n.comment_id
             WHERE n.user_id = $1
             ORDER BY n.created_at DESC, n.id DESC
             LIMIT 100`,
            [req.user.id]
        );

        return res.status(200).json({
            notifications: result.rows,
            unread_count: result.rows.filter((row) => !row.is_read).length,
        });
    } catch (error) {
        console.error("Get notifications error:", error.message);

        return res.status(500).json({
            message: "Gagal mengambil notifikasi: " + error.message,
        });
    }
});

router.get("/unread-count", async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT COUNT(*)::int AS total FROM notifications WHERE user_id = $1 AND is_read = FALSE",
            [req.user.id]
        );

        return res.status(200).json({ unread_count: result.rows[0].total });
    } catch (error) {
        console.error("Unread count error:", error.message);

        return res.status(500).json({
            message: "Gagal menghitung notifikasi: " + error.message,
        });
    }
});

router.post("/read-all", async (req, res) => {
    try {
        await pool.query(
            "UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE",
            [req.user.id]
        );

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error("Mark notifications read error:", error.message);

        return res.status(500).json({
            message: "Gagal menandai notifikasi: " + error.message,
        });
    }
});

module.exports = router;