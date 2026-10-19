const multer = require("multer");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");

const uploadDir = path.join(__dirname, "..", "uploads");
fs.mkdirSync(uploadDir, { recursive: true });

// Ekstensi file ditentukan dari tipe MIME, bukan dari nama file asli,
// supaya pengguna tidak bisa menyimpan file berbahaya (mis. .html / .js).
const MEDIA_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "video/mp4": ".mp4",
    "video/quicktime": ".mov",
    "video/webm": ".webm",
};

const AUDIO_TYPES = {
    "audio/mpeg": ".mp3",
    "audio/mp3": ".mp3",
    "audio/mp4": ".m4a",
    "audio/x-m4a": ".m4a",
    "audio/aac": ".aac",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/wave": ".wav",
    "audio/ogg": ".ogg",
};

const MAX_MEDIA_FILES = 4;
const MAX_MEDIA_BYTES = 50 * 1024 * 1024; // 50 MB per file
const MAX_AUDIO_BYTES = 20 * 1024 * 1024; // 20 MB

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const table = file.fieldname === "audio" ? AUDIO_TYPES : MEDIA_TYPES;
        cb(null, `${crypto.randomUUID()}${table[file.mimetype]}`);
    },
});

const upload = multer({
    storage,
    limits: {
        fileSize: MAX_MEDIA_BYTES,
        files: MAX_MEDIA_FILES + 1,
    },
    fileFilter: (req, file, cb) => {
        if (file.fieldname === "media") {
            return MEDIA_TYPES[file.mimetype]
                ? cb(null, true)
                : cb(new Error("Format foto/video tidak didukung."));
        }

        if (file.fieldname === "audio") {
            return AUDIO_TYPES[file.mimetype]
                ? cb(null, true)
                : cb(new Error("Format musik tidak didukung."));
        }

        return cb(new Error("Field file tidak dikenal."));
    },
}).fields([
    { name: "media", maxCount: MAX_MEDIA_FILES },
    { name: "audio", maxCount: 1 },
]);

// Middleware yang mengubah error multer menjadi respons JSON yang rapi.
function uploadPostFiles(req, res, next) {
    upload(req, res, (error) => {
        if (!error) return next();

        let message = error.message || "Upload gagal.";

        if (error.code === "LIMIT_FILE_SIZE") {
            message = "File terlalu besar (maksimal 50 MB).";
        } else if (error.code === "LIMIT_UNEXPECTED_FILE") {
            message = `Maksimal ${MAX_MEDIA_FILES} foto/video dan 1 musik.`;
        }

        return res.status(400).json({ message });
    });
}

// ---------------------------------------------------------------------------
// Komentar: satu foto / GIF (field "media"), maksimal 10 MB.
// ---------------------------------------------------------------------------
const COMMENT_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
};

const MAX_COMMENT_IMAGE_BYTES = 10 * 1024 * 1024;

const commentUpload = multer({
    storage: multer.diskStorage({
        destination: (req, file, cb) => cb(null, uploadDir),
        filename: (req, file, cb) =>
            cb(null, `${crypto.randomUUID()}${COMMENT_IMAGE_TYPES[file.mimetype]}`),
    }),
    limits: { fileSize: MAX_COMMENT_IMAGE_BYTES, files: 1 },
    fileFilter: (req, file, cb) =>
        file.fieldname === "media" && COMMENT_IMAGE_TYPES[file.mimetype]
            ? cb(null, true)
            : cb(new Error("Format foto tidak didukung (JPG, PNG, WEBP, GIF).")),
}).single("media");

// Aman dipakai untuk permintaan JSON biasa: multer melewatinya begitu saja.
function uploadCommentMedia(req, res, next) {
    commentUpload(req, res, (error) => {
        if (!error) return next();

        let message = error.message || "Upload gagal.";

        if (error.code === "LIMIT_FILE_SIZE") {
            message = "Foto terlalu besar (maksimal 10 MB).";
        } else if (error.code === "LIMIT_UNEXPECTED_FILE") {
            message = "Komentar hanya boleh membawa satu foto.";
        }

        return res.status(400).json({ message });
    });
}

module.exports = {
    uploadPostFiles,
    uploadCommentMedia,
    uploadDir,
    MAX_AUDIO_BYTES,
};