// middleware/uploadMessage.js
//
// Unggah SATU foto untuk pesan (DM): field multipart "media".
// Permintaan JSON biasa (teks / GIF / stiker) dibiarkan lewat tanpa diproses.
// File disimpan di backend/uploads dan dilayani lewat /uploads/<nama-file>.

const multer = require("multer");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const UPLOAD_DIR = path.join(__dirname, "..", "uploads");
const MAX_IMAGE_BYTES = 10 * 1024 * 1024; // 10 MB

const EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
};

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const upload = multer({
    storage: multer.diskStorage({
        destination: UPLOAD_DIR,
        filename: (req, file, cb) => {
            const name = `dm-${Date.now()}-${crypto.randomBytes(6).toString("hex")}`;

            cb(null, `${name}${EXTENSIONS[file.mimetype]}`);
        },
    }),
    limits: { fileSize: MAX_IMAGE_BYTES, files: 1 },
    fileFilter: (req, file, cb) => {
        if (EXTENSIONS[file.mimetype]) return cb(null, true);

        return cb(new Error("Format foto tidak didukung (JPG, PNG, WEBP, GIF)."));
    },
});

function uploadMessageImage(req, res, next) {
    if (!req.is("multipart/form-data")) return next();

    return upload.single("media")(req, res, (error) => {
        if (!error) return next();

        const message =
            error.code === "LIMIT_FILE_SIZE"
                ? "Ukuran foto maksimal 10 MB."
                : error.message || "Gagal mengunggah foto.";

        return res.status(400).json({ message });
    });
}

/** Memeriksa isi file (bukan hanya tipe yang dikirim klien). */
function looksLikeImage(file) {
    try {
        const fd = fs.openSync(file.path, "r");
        const head = Buffer.alloc(12);

        fs.readSync(fd, head, 0, 12, 0);
        fs.closeSync(fd);

        const isJpeg = head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff;
        const isPng = head.slice(0, 4).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47]));
        const isGif = head.slice(0, 4).toString("ascii") === "GIF8";
        const isWebp =
            head.slice(0, 4).toString("ascii") === "RIFF" &&
            head.slice(8, 12).toString("ascii") === "WEBP";

        return isJpeg || isPng || isGif || isWebp;
    } catch (_) {
        return false;
    }
}

/** Hapus file yang sudah terunggah tetapi pesannya tidak jadi dibuat. */
function discardUpload(file) {
    if (!file || !file.path) return;

    fs.unlink(file.path, () => {});
}

module.exports = { uploadMessageImage, looksLikeImage, discardUpload };