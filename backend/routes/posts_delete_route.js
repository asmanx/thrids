// ════════════════════════════════════════════════════════════════════════
//  TAMBAHAN UNTUK backend/routes/posts.js  —  DELETE /api/posts/:id
//
//  Tempel blok di bawah ini tepat SEBELUM baris  module.exports = router;
//  (jangan menimpa seluruh posts.js; cukup tempel). Lalu restart server Node.
// ════════════════════════════════════════════════════════════════════════

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