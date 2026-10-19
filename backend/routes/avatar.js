
const express = require("express");
const multer = require("multer");
const path = require("path");
const crypto = require("crypto");

const pool = require("../config/db");
const authMiddleware = require("../middleware/authMiddleware");
const { uploadDir } = require("../middleware/upload");

const router = express.Router();

const avatarStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
        const extensions = {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
            "image/gif": ".gif",
        };

        const extension = extensions[file.mimetype];

        if (!extension) {
            return cb(new Error("Format foto harus JPG, PNG, WebP, atau GIF."));
        }

        cb(null, `avatar-${crypto.randomUUID()}${extension}`);
    },
});

const avatarUpload = multer({
    storage: avatarStorage,
    limits: {
        fileSize: 5 * 1024 * 1024,
        files: 1,
    },
    fileFilter: (req, file, cb) => {
        const allowedTypes = [
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/gif",
        ];

        if (!allowedTypes.includes(file.mimetype)) {
            return cb(
                new Error("Format foto harus JPG, PNG, WebP, atau GIF.")
            );
        }

        cb(null, true);
    },
});

function handleAvatarUpload(req, res, next) {
    avatarUpload.single("avatar")(req, res, (error) => {
        if (!error) return next();

        if (error.code === "LIMIT_FILE_SIZE") {
            return res.status(400).json({
                message: "Ukuran foto maksimal 5 MB.",
            });
        }

        return res.status(400).json({
            message: error.message || "Upload foto gagal.",
        });
    });
}

router.put("/avatar", authMiddleware, handleAvatarUpload, async (req, res) => {
    let uploadedFile;

    try {
        if (!req.file) {
            return res.status(400).json({
                message: "Foto tidak ditemukan.",
            });
        }

        uploadedFile = req.file;

        const userId = req.user.id;

        if (!userId) {
            return res.status(401).json({
                message: "Identitas pengguna tidak ditemukan dalam token.",
            });
        }

        const avatarUrl = `/uploads/${req.file.filename}`;

        const result = await pool.query(
            `UPDATE users
             SET profile_picture = $1
             WHERE id = $2
             RETURNING
                id,
                username,
                display_name,
                bio,
                profile_picture,
                interests,
                links,
                podcast_url,
                show_instagram_badge,
                show_recent_views,
                is_private`,
            [avatarUrl, userId]
        );

        if (result.rowCount === 0) {
            const fs = require("fs");
            fs.unlink(uploadedFile.path, () => {});

            return res.status(404).json({
                message: "Akun tidak ditemukan.",
            });
        }

        const row = result.rows[0];

        const user = {
            id: row.id,
            username: row.username,
            display_name: row.display_name,
            bio: row.bio || "",
            avatar_url: row.profile_picture || null,
            interests: row.interests || [],
            links: row.links || [],
            podcast_url: row.podcast_url || "",
            show_instagram_badge: row.show_instagram_badge === true,
            show_recent_views: row.show_recent_views !== false,
            is_private: row.is_private === true,
            followers_count: 0,
        };

        return res.status(200).json({
            message: "Foto profil berhasil diperbarui.",
            user,
        });
    } catch (error) {
        if (uploadedFile) {
            const fs = require("fs");
            fs.unlink(uploadedFile.path, () => {});
        }

        console.error("Upload avatar error:", error.message);

        return res.status(500).json({
            message: "Gagal menyimpan foto profil.",
        });
    }
});

module.exports = router;
