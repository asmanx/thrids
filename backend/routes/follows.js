// routes/follows.js
//
//   GET    /api/users/following                -> { following: ["username", ...] }
//   GET    /api/users/suggestions              -> { users: [...] }
//   GET    /api/users/:username                -> profil + jumlah follower/following + is_following
//   GET    /api/users/:username/followers      -> { users: [...] }
//   GET    /api/users/:username/following      -> { users: [...] }
//   GET    /api/users/:username/mutual         -> { users: [...] }  (pengikut yang juga saya ikuti)
//   POST   /api/users/:username/follow         -> { following, requested, followers_count }
//                                                 (akun privat -> requested: true, menunggu persetujuan)
//   DELETE /api/users/:username/follow         -> { following: false, requested: false, followers_count }
//   GET    /api/users/requests                 -> { users: [...] }  (permintaan untuk akun saya)
//   POST   /api/users/requests/:username/approve  -> { ok, followers_count }
//   POST   /api/users/requests/:username/decline  -> { ok }
//
// PENTING: route statis ("/following", "/suggestions") harus tetap di atas
// route dinamis ("/:username"), kalau tidak "following" dianggap username.

const express = require("express");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authMiddleware");
const { notify, unnotify } = require("../utils/notifications");

const router = express.Router();

router.use(authMiddleware);

// ───────────── Helper ─────────────

async function findTarget(username) {
    const result = await pool.query(
        `SELECT u.id, u.username,
                (to_jsonb(u) ->> 'is_private') = 'true' AS is_private
         FROM users u
         WHERE LOWER(u.username) = LOWER($1)
         LIMIT 1`,
        [username]
    );

    return result.rows[0] || null;
}

async function followersCount(userId) {
    const result = await pool.query(
        "SELECT COUNT(*)::int AS total FROM follows WHERE following_id = $1",
        [userId]
    );

    return result.rows[0].total;
}

async function followingCount(userId) {
    const result = await pool.query(
        "SELECT COUNT(*)::int AS total FROM follows WHERE follower_id = $1",
        [userId]
    );

    return result.rows[0].total;
}

// Pengikut terbaru (avatar kecil di samping "N pengikut").
async function recentFollowers(userId, limit = 2) {
    const result = await pool.query(
        `SELECT u.username, u.profile_picture
         FROM follows f
         JOIN users u ON u.id = f.follower_id
         WHERE f.following_id = $1
         ORDER BY f.created_at DESC
         LIMIT $2`,
        [userId, limit]
    );

    return result.rows;
}

// ───────────── Daftar yang saya ikuti ─────────────

router.get("/following", async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT u.username
             FROM follows f
             JOIN users u ON u.id = f.following_id
             WHERE f.follower_id = $1`,
            [req.user.id]
        );

        const requested = await pool.query(
            `SELECT u.username
             FROM follow_requests r
             JOIN users u ON u.id = r.target_id
             WHERE r.requester_id = $1`,
            [req.user.id]
        );

        return res.status(200).json({
            following: result.rows.map((row) => row.username),
            requested: requested.rows.map((row) => row.username),
        });
    } catch (error) {
        console.error("Get following error:", error.message);

        return res
            .status(500)
            .json({ message: "Gagal mengambil daftar yang diikuti." });
    }
});

// ───────────── Saran akun ─────────────

router.get("/suggestions", async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT
                u.id,
                u.username,
                u.display_name,
                u.profile_picture,
                (to_jsonb(u) ->> 'created_at') AS created_at
             FROM users u
             WHERE u.id <> $1
               AND u.id NOT IN (
                   SELECT following_id FROM follows WHERE follower_id = $1
               )
             ORDER BY u.id DESC
             LIMIT 20`,
            [req.user.id]
        );

        return res.status(200).json({ users: result.rows });
    } catch (error) {
        console.error("Get suggestions error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil saran akun." });
    }
});

// ───────────── Permintaan mengikuti (untuk akun privat saya) ─────────────
// Harus berada di atas route "/:username".

router.get("/requests", async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT
                u.id,
                u.username,
                u.display_name,
                u.profile_picture,
                r.created_at,
                EXISTS (
                    SELECT 1 FROM follows a
                    WHERE a.follower_id = $1 AND a.following_id = u.id
                ) AS is_following
             FROM follow_requests r
             JOIN users u ON u.id = r.requester_id
             WHERE r.target_id = $1
             ORDER BY r.created_at DESC
             LIMIT 200`,
            [req.user.id]
        );

        return res.status(200).json({ users: result.rows });
    } catch (error) {
        console.error("Get requests error:", error.message);

        return res
            .status(500)
            .json({ message: "Gagal mengambil permintaan mengikuti." });
    }
});

router.post("/requests/:username/approve", async (req, res) => {
    try {
        const requester = await findTarget(req.params.username);

        if (!requester) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        const removed = await pool.query(
            "DELETE FROM follow_requests WHERE requester_id = $1 AND target_id = $2",
            [requester.id, req.user.id]
        );

        if (removed.rowCount === 0) {
            return res
                .status(404)
                .json({ message: "Permintaan tidak ditemukan." });
        }

        await pool.query(
            `INSERT INTO follows (follower_id, following_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [requester.id, req.user.id]
        );

        // Notifikasi "ingin mengikuti" diganti "mulai mengikuti Anda",
        // dan peminta diberi tahu bahwa permintaannya diterima.
        await unnotify({
            userId: req.user.id,
            actorId: requester.id,
            type: "follow_request",
        });
        await notify({ userId: req.user.id, actorId: requester.id, type: "follow" });
        await notify({
            userId: requester.id,
            actorId: req.user.id,
            type: "follow_accept",
        });

        return res.status(200).json({
            ok: true,
            followers_count: await followersCount(req.user.id),
        });
    } catch (error) {
        console.error("Approve request error:", error.message);

        return res.status(500).json({ message: "Gagal menerima permintaan." });
    }
});

router.post("/requests/:username/decline", async (req, res) => {
    try {
        const requester = await findTarget(req.params.username);

        if (!requester) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        await pool.query(
            "DELETE FROM follow_requests WHERE requester_id = $1 AND target_id = $2",
            [requester.id, req.user.id]
        );

        await unnotify({
            userId: req.user.id,
            actorId: requester.id,
            type: "follow_request",
        });

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error("Decline request error:", error.message);

        return res.status(500).json({ message: "Gagal menghapus permintaan." });
    }
});

// ───────────── Profil akun (milik sendiri maupun orang lain) ─────────────

// Pengikut sebuah akun yang juga saya ikuti ("Bersama"), tidak termasuk saya.
async function mutualFollowers(targetId, meId, limit = 200) {
    const result = await pool.query(
        `SELECT
            u.id,
            u.username,
            u.display_name,
            u.profile_picture,
            TRUE AS is_following,
            FALSE AS is_requested,
            EXISTS (
                SELECT 1 FROM follows b
                WHERE b.follower_id = u.id AND b.following_id = $2
            ) AS follows_me
         FROM follows f
         JOIN users u ON u.id = f.follower_id
         WHERE f.following_id = $1
           AND f.follower_id <> $2
           AND EXISTS (
               SELECT 1 FROM follows m
               WHERE m.follower_id = $2 AND m.following_id = f.follower_id
           )
         ORDER BY f.created_at DESC
         LIMIT ${Number(limit) || 200}`,
        [targetId, meId]
    );

    return result.rows;
}

router.get("/:username", async (req, res) => {
    try {
        // SELECT * lalu dipilih field-nya di JS, supaya tidak error kalau
        // salah satu kolom (bio, is_private, dst.) belum ada di tabel users.
        const found = await pool.query(
            "SELECT * FROM users WHERE LOWER(username) = LOWER($1) LIMIT 1",
            [req.params.username]
        );

        const u = found.rows[0];

        if (!u) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        const isMe = String(u.id) === String(req.user.id);

        const rel = await pool.query(
            `SELECT
                EXISTS (SELECT 1 FROM follows
                        WHERE follower_id = $1 AND following_id = $2) AS is_following,
                EXISTS (SELECT 1 FROM follows
                        WHERE follower_id = $2 AND following_id = $1) AS follows_me,
                EXISTS (SELECT 1 FROM follow_requests
                        WHERE requester_id = $1 AND target_id = $2) AS is_requested`,
            [req.user.id, u.id]
        );

        let pendingCount = 0;

        if (isMe) {
            const pending = await pool.query(
                "SELECT COUNT(*)::int AS total FROM follow_requests WHERE target_id = $1",
                [u.id]
            );
            pendingCount = pending.rows[0].total;
        }

        const mutual = isMe ? [] : await mutualFollowers(u.id, req.user.id);

        return res.status(200).json({
            user: {
                id: u.id,
                username: u.username,
                display_name: u.display_name || u.username,
                profile_picture: u.profile_picture || null,
                bio: u.bio || "",
                is_private: u.is_private === true,
                created_at: u.created_at || null,
                followers_count: await followersCount(u.id),
                following_count: await followingCount(u.id),
                is_me: isMe,
                is_following: rel.rows[0].is_following,
                follows_me: rel.rows[0].follows_me,
                is_requested: rel.rows[0].is_requested,
                pending_count: pendingCount,
                // Foto kecil di samping "N pengikut" (maksimal 3).
                mutual_followers: mutual.slice(0, 3).map((m) => ({
                    username: m.username,
                    profile_picture: m.profile_picture,
                })),
                mutual_count: mutual.length,
                recent_followers: await recentFollowers(u.id, 2),
            },
        });
    } catch (error) {
        console.error("Get profile error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil profil." });
    }
});

// ───────────── Daftar follower / following / bersama ─────────────
// Setiap baris membawa:
//   is_following = saya mengikuti dia
//   follows_me   = dia mengikuti saya  (-> tombol "Ikuti balik")

async function listRelation(req, res, mode) {
    try {
        const target = await findTarget(req.params.username);

        if (!target) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        if (mode === "mutual") {
            return res
                .status(200)
                .json({ users: await mutualFollowers(target.id, req.user.id) });
        }

        // "followers": orang yang mengikuti target
        // "following": orang yang diikuti target
        const [joinCol, whereCol] =
            mode === "followers"
                ? ["follower_id", "following_id"]
                : ["following_id", "follower_id"];

        const result = await pool.query(
            `SELECT
                u.id,
                u.username,
                u.display_name,
                u.profile_picture,
                EXISTS (
                    SELECT 1 FROM follows a
                    WHERE a.follower_id = $2 AND a.following_id = u.id
                ) AS is_following,
                EXISTS (
                    SELECT 1 FROM follows b
                    WHERE b.follower_id = u.id AND b.following_id = $2
                ) AS follows_me,
                EXISTS (
                    SELECT 1 FROM follow_requests q
                    WHERE q.requester_id = $2 AND q.target_id = u.id
                ) AS is_requested
             FROM follows f
             JOIN users u ON u.id = f.${joinCol}
             WHERE f.${whereCol} = $1
             ORDER BY f.created_at DESC
             LIMIT 200`,
            [target.id, req.user.id]
        );

        return res.status(200).json({ users: result.rows });
    } catch (error) {
        console.error(`List ${mode} error:`, error.message);

        return res.status(500).json({ message: "Gagal mengambil daftar akun." });
    }
}

router.get("/:username/followers", (req, res) =>
    listRelation(req, res, "followers")
);

router.get("/:username/following", (req, res) =>
    listRelation(req, res, "following")
);

router.get("/:username/mutual", (req, res) =>
    listRelation(req, res, "mutual")
);

// ───────────── Ikuti / berhenti mengikuti ─────────────

router.post("/:username/follow", async (req, res) => {
    try {
        const target = await findTarget(req.params.username);

        if (!target) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        if (String(target.id) === String(req.user.id)) {
            return res
                .status(400)
                .json({ message: "Tidak bisa mengikuti diri sendiri." });
        }

        // Sudah mengikuti -> tidak ada yang berubah.
        const already = await pool.query(
            "SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2",
            [req.user.id, target.id]
        );

        if (already.rowCount > 0) {
            return res.status(200).json({
                following: true,
                requested: false,
                followers_count: await followersCount(target.id),
            });
        }

        // Akun privat: kirim permintaan, tunggu persetujuan pemilik akun.
        if (target.is_private) {
            const inserted = await pool.query(
                `INSERT INTO follow_requests (requester_id, target_id)
                 VALUES ($1, $2)
                 ON CONFLICT DO NOTHING`,
                [req.user.id, target.id]
            );

            if (inserted.rowCount > 0) {
                await notify({
                    userId: target.id,
                    actorId: req.user.id,
                    type: "follow_request",
                });
            }

            return res.status(200).json({
                following: false,
                requested: true,
                followers_count: await followersCount(target.id),
            });
        }

        const inserted = await pool.query(
            `INSERT INTO follows (follower_id, following_id)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING`,
            [req.user.id, target.id]
        );

        if (inserted.rowCount > 0) {
            await notify({ userId: target.id, actorId: req.user.id, type: "follow" });
        }

        return res.status(200).json({
            following: true,
            requested: false,
            followers_count: await followersCount(target.id),
        });
    } catch (error) {
        console.error("Follow error:", error.message);

        return res.status(500).json({ message: "Gagal mengikuti akun." });
    }
});

router.delete("/:username/follow", async (req, res) => {
    try {
        const target = await findTarget(req.params.username);

        if (!target) {
            return res.status(404).json({ message: "Akun tidak ditemukan." });
        }

        await pool.query(
            "DELETE FROM follows WHERE follower_id = $1 AND following_id = $2",
            [req.user.id, target.id]
        );

        // Batalkan juga permintaan yang masih menunggu (akun privat).
        await pool.query(
            "DELETE FROM follow_requests WHERE requester_id = $1 AND target_id = $2",
            [req.user.id, target.id]
        );

        await unnotify({ userId: target.id, actorId: req.user.id, type: "follow" });
        await unnotify({
            userId: target.id,
            actorId: req.user.id,
            type: "follow_request",
        });

        return res.status(200).json({
            following: false,
            requested: false,
            followers_count: await followersCount(target.id),
        });
    } catch (error) {
        console.error("Unfollow error:", error.message);

        return res
            .status(500)
            .json({ message: "Gagal berhenti mengikuti akun." });
    }
});

module.exports = router;