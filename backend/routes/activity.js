// routes/activity.js
//
//   GET  /api/activity        -> { activities: [...], unread_count }
//   POST /api/activity/read   -> tandai semua aktivitas sudah dibaca

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
                a.id AS actor_id,
                a.username AS actor_username,
                a.display_name AS actor_display_name,
                a.profile_picture AS actor_picture,
                c.content AS comment_content
             FROM notifications n
             JOIN users a ON a.id = n.actor_id
             LEFT JOIN post_comments c ON c.id = n.comment_id
             WHERE n.user_id = $1
             ORDER BY n.created_at DESC, n.id DESC
             LIMIT 100`,
            [req.user.id]
        );

        const activities = result.rows.map((row) => ({
            id: row.id,
            type: row.type,
            post_id: row.post_id,
            is_read: row.is_read,
            created_at: row.created_at,
            actor: {
                id: row.actor_id,
                username: row.actor_username,
                display_name: row.actor_display_name || row.actor_username,
                profile_picture: row.actor_picture || null,
            },
            comment: row.comment_id
                ? { id: row.comment_id, content: row.comment_content || "" }
                : null,
        }));

        return res.status(200).json({
            activities,
            unread_count: activities.filter((item) => !item.is_read).length,
        });
    } catch (error) {
        console.error("Get activity error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil aktivitas." });
    }
});

router.post("/read", async (req, res) => {
    try {
        await pool.query(
            "UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE",
            [req.user.id]
        );

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error("Mark activity read error:", error.message);

        return res.status(500).json({ message: "Gagal menandai aktivitas." });
    }
});

module.exports = router;