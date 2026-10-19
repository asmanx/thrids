const express = require("express");

const pool = require("../config/db");
const authMiddleware = require("../middleware/authMiddleware");
const {
    register,
    login,
    updateProfile,
} = require("../controllers/authController");

const router = express.Router();

// ───────────── Aturan username ala Threads / Instagram ─────────────
//  - hanya huruf (a-z), angka (0-9), titik (.), dan garis bawah (_)
//  - 3–30 karakter, tanpa spasi atau simbol lain
//  - tidak diawali / diakhiri titik, tidak ada dua titik berturutan
//  - huruf besar otomatis jadi huruf kecil; unik tanpa membedakan kapital
// (Aturan yang sama ada di lib/core/username_rules.dart.)

const USERNAME_MIN = 3;
const USERNAME_MAX = 30;

function normalizeUsername(value) {
    let u = String(value ?? "").trim().toLowerCase();

    if (u.startsWith("@")) u = u.slice(1);

    return u;
}

/** Mengembalikan pesan kesalahan, atau null kalau username sudah sesuai. */
function usernameError(u) {
    if (!u) return "Username wajib diisi.";
    if (u.length < USERNAME_MIN) return `Username minimal ${USERNAME_MIN} karakter.`;
    if (u.length > USERNAME_MAX) return `Username maksimal ${USERNAME_MAX} karakter.`;
    if (/\s/.test(u)) return "Username tidak boleh mengandung spasi.";

    if (!/^[a-z0-9._]+$/.test(u)) {
        return "Username hanya boleh berisi huruf, angka, titik (.), dan garis bawah (_).";
    }

    if (u.startsWith(".") || u.endsWith(".")) {
        return "Username tidak boleh diawali atau diakhiri titik.";
    }

    if (u.includes("..")) {
        return "Username tidak boleh memiliki dua titik berturutan.";
    }

    return null;
}

async function usernameTaken(username, exceptUserId = null) {
    const result = await pool.query(
        `SELECT 1 FROM users
         WHERE LOWER(username) = $1
           AND ($2::bigint IS NULL OR id <> $2::bigint)
         LIMIT 1`,
        [username, exceptUserId]
    );

    return result.rowCount > 0;
}

/** Sampai [limit] username mirip [base] yang masih kosong (belum dipakai). */
async function suggestUsernames(base, limit = 3) {
    const root = base.replace(/[._]+$/, "").slice(0, USERNAME_MAX - 4) || "user";

    const candidates = new Set();

    while (candidates.size < 10) {
        const n = Math.floor(Math.random() * 900) + 10; // 10–909
        const name = Math.random() < 0.5 ? `${root}${n}` : `${root}_${n}`;

        if (usernameError(name) === null) candidates.add(name);
    }

    const list = [...candidates];

    const used = await pool.query(
        "SELECT LOWER(username) AS u FROM users WHERE LOWER(username) = ANY($1::text[])",
        [list]
    );

    const taken = new Set(used.rows.map((row) => row.u));

    return list.filter((name) => !taken.has(name)).slice(0, limit);
}

// Sebelum register: cek aturan + ketersediaan, lalu simpan dalam huruf kecil.
async function checkNewUsername(req, res, next) {
    try {
        const username = normalizeUsername(req.body?.username);
        const error = usernameError(username);

        if (error) return res.status(400).json({ message: error });

        if (await usernameTaken(username)) {
            return res.status(409).json({
                message: "Username sudah dipakai. Cari username lain.",
                suggestions: await suggestUsernames(username),
            });
        }

        req.body.username = username;

        return next();
    } catch (error) {
        console.error("Check username error:", error.message);

        return res.status(500).json({ message: "Gagal memeriksa username." });
    }
}

// Sebelum ubah profil: kalau username ikut diubah, periksa aturan + ketersediaan.
// (Memerlukan login, jadi authMiddleware dipasang lebih dulu.)
async function checkChangedUsername(req, res, next) {
    try {
        if (req.body?.username === undefined) return next();

        const username = normalizeUsername(req.body.username);

        const current = await pool.query(
            "SELECT username FROM users WHERE id = $1",
            [req.user.id]
        );

        const currentName = current.rows[0]?.username || "";

        // Tidak berubah (selain kapital): biarkan apa adanya, jangan divalidasi
        // ulang supaya akun lama dengan username lama tetap bisa mengubah profil.
        if (currentName.toLowerCase() === username) {
            req.body.username = currentName;

            return next();
        }

        const error = usernameError(username);

        if (error) return res.status(400).json({ message: error });

        if (await usernameTaken(username, req.user.id)) {
            return res.status(409).json({ message: "Username sudah dipakai." });
        }

        req.body.username = username;

        return next();
    } catch (error) {
        console.error("Check changed username error:", error.message);

        return res.status(500).json({ message: "Gagal memeriksa username." });
    }
}

// Login tidak membedakan kapital, dan boleh diawali "@".
async function canonicalLoginUsername(req, res, next) {
    try {
        const raw = String(req.body?.username ?? "").trim().replace(/^@/, "");

        if (raw) {
            const found = await pool.query(
                "SELECT username FROM users WHERE LOWER(username) = LOWER($1) LIMIT 1",
                [raw]
            );

            req.body.username = found.rows[0] ? found.rows[0].username : raw;
        }
    } catch (error) {
        console.error("Canonical username error:", error.message);
    }

    return next();
}

// ───────────── Route ─────────────

router.post("/register", checkNewUsername, register);
router.post("/login", canonicalLoginUsername, login);

// Pemeriksaan langsung saat mengetik di halaman daftar.
//   GET /api/auth/username-available?username=abc
//   -> { valid, available, message }
router.get("/username-available", async (req, res) => {
    try {
        const username = normalizeUsername(req.query.username);
        const error = usernameError(username);

        if (error) {
            return res
                .status(200)
                .json({ valid: false, available: false, message: error });
        }

        const taken = await usernameTaken(username);

        return res.status(200).json({
            valid: true,
            available: !taken,
            message: taken
                ? "Username sudah dipakai. Cari username lain."
                : "Username tersedia.",
            suggestions: taken ? await suggestUsernames(username) : [],
        });
    } catch (error) {
        console.error("Username available error:", error.message);

        return res.status(500).json({ message: "Gagal memeriksa username." });
    }
});

// Daftar akun untuk halaman "Pilih akun" di layar awal.
// Selalu mengirim profile_picture TERBARU dari tabel users. Password tidak
// pernah dikirim.
router.get("/users", async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT
                u.id,
                u.username,
                u.display_name,
                u.profile_picture,
                (to_jsonb(u) ->> 'email') AS email
             FROM users u
             ORDER BY u.id DESC`
        );

        return res.status(200).json({ users: result.rows });
    } catch (error) {
        console.error("Get users error:", error.message);

        return res.status(500).json({ message: "Gagal mengambil daftar akun." });
    }
});

router.put("/profile", authMiddleware, checkChangedUsername, updateProfile);

module.exports = router;