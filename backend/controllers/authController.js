const pool = require("../config/db");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

// Kolom profil yang dikirim ke aplikasi.
const PROFILE_COLUMNS = `
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
    is_private
`;

// Mengubah baris database menjadi objek user untuk aplikasi Flutter.
function serializeUser(row) {
    return {
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
        followers_count: 0, // belum ada tabel pengikut
    };
}

// Membaca id user dari header "Authorization: Bearer <token>".
function getAuthUserId(req) {
    const header = req.headers.authorization || "";
    const [scheme, token] = header.split(" ");

    if (scheme !== "Bearer" || !token) return null;

    try {
        const payload = jwt.verify(token, process.env.JWT_SECRET);
        return payload.id;
    } catch (error) {
        return null;
    }
}

function isHttpUrl(value) {
    if (typeof value !== "string" || value.length > 200) return false;

    try {
        const url = new URL(value);
        return url.protocol === "http:" || url.protocol === "https:";
    } catch (error) {
        return false;
    }
}

// REGISTER / MEMBUAT AKUN
async function register(req, res) {
    try {
        const { username, password, display_name } = req.body;

        if (!username || !password || !display_name) {
            return res.status(400).json({
                message: "Semua field wajib diisi.",
            });
        }

        if (
            typeof username !== "string" ||
            typeof password !== "string" ||
            typeof display_name !== "string"
        ) {
            return res.status(400).json({
                message: "Format input tidak valid.",
            });
        }

        const cleanUsername = username.trim();
        const cleanDisplayName = display_name.trim();

        if (
            !cleanUsername ||
            !cleanDisplayName ||
            cleanUsername.length > 30 ||
            cleanDisplayName.length > 100
        ) {
            return res.status(400).json({
                message: "Data tidak valid atau melebihi batas karakter.",
            });
        }

        if (password.length < 8) {
            return res.status(400).json({
                message: "Password minimal 8 karakter.",
            });
        }

        if (!process.env.JWT_SECRET) {
            console.error("JWT_SECRET belum dikonfigurasi.");

            return res.status(500).json({
                message: "Konfigurasi autentikasi server bermasalah.",
            });
        }

        const passwordHash = await bcrypt.hash(password, 10);

        const result = await pool.query(
            `INSERT INTO users
                (username, password_hash, display_name)
             VALUES ($1, $2, $3)
             RETURNING ${PROFILE_COLUMNS}`,
            [
                cleanUsername,
                passwordHash,
                cleanDisplayName,
            ]
        );

        const user = result.rows[0];

        // Membuat token agar pengguna langsung bisa masuk.
        const token = jwt.sign(
            {
                id: user.id,
                username: user.username,
            },
            process.env.JWT_SECRET,
            {
                expiresIn: process.env.JWT_EXPIRES_IN || "1d",
            }
        );

        return res.status(201).json({
            message: "Registrasi berhasil.",
            token: token,
            user: serializeUser(user),
        });
    } catch (error) {
        if (error.code === "23505") {
            return res.status(409).json({
                message: "Username sudah digunakan.",
            });
        }

        console.error("Register error:", error.message);

        return res.status(500).json({
            message: "Terjadi kesalahan pada server.",
        });
    }
}

// LOGIN / MASUK AKUN
async function login(req, res) {
    try {
        const { username, password } = req.body;

        if (
            typeof username !== "string" ||
            typeof password !== "string" ||
            !username.trim() ||
            !password
        ) {
            return res.status(400).json({
                message: "Username dan password wajib diisi.",
            });
        }

        const cleanUsername = username.trim();

        const result = await pool.query(
            `SELECT password_hash, ${PROFILE_COLUMNS}
             FROM users
             WHERE username = $1`,
            [cleanUsername]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                message: "Username atau password salah.",
            });
        }

        const user = result.rows[0];

        const passwordMatch = await bcrypt.compare(
            password,
            user.password_hash
        );

        if (!passwordMatch) {
            return res.status(401).json({
                message: "Username atau password salah.",
            });
        }

        if (!process.env.JWT_SECRET) {
            console.error("JWT_SECRET belum dikonfigurasi.");

            return res.status(500).json({
                message: "Konfigurasi autentikasi server bermasalah.",
            });
        }

        const token = jwt.sign(
            {
                id: user.id,
                username: user.username,
            },
            process.env.JWT_SECRET,
            {
                expiresIn: process.env.JWT_EXPIRES_IN || "1d",
            }
        );

        return res.status(200).json({
            message: "Login berhasil.",
            token: token,
            user: serializeUser(user),
        });
    } catch (error) {
        console.error("Login error:", error.message);

        return res.status(500).json({
            message: "Terjadi kesalahan pada server.",
        });
    }
}

// MENGAMBIL DAFTAR AKUN
async function getUsers(req, res) {
    try {
        const result = await pool.query(
            `SELECT id, username, display_name
             FROM users
             ORDER BY id DESC`
        );

        return res.status(200).json({
            users: result.rows,
        });
    } catch (error) {
        console.error("Get users error:", error.message);

        return res.status(500).json({
            message: "Gagal mengambil daftar akun.",
        });
    }
}

// MEMPERBARUI PROFIL (hanya field yang dikirim yang diubah)
async function updateProfile(req, res) {
    try {
        if (!process.env.JWT_SECRET) {
            console.error("JWT_SECRET belum dikonfigurasi.");

            return res.status(500).json({
                message: "Konfigurasi autentikasi server bermasalah.",
            });
        }

        const userId = getAuthUserId(req);

        if (!userId) {
            return res.status(401).json({
                message: "Sesi tidak valid. Silakan login ulang.",
            });
        }

        const body = req.body || {};
        const updates = {}; // nama kolom -> nilai baru

        const invalid = (message) => res.status(400).json({ message });

        // Nama tampilan
        if (body.display_name !== undefined) {
            if (typeof body.display_name !== "string") {
                return invalid("Nama tidak valid.");
            }

            const value = body.display_name.trim();

            if (!value || value.length > 50) {
                return invalid("Nama wajib diisi dan maksimal 50 karakter.");
            }

            updates.display_name = value;
        }

        // Nama pengguna
        if (body.username !== undefined) {
            if (typeof body.username !== "string") {
                return invalid("Nama pengguna tidak valid.");
            }

            const value = body.username.trim().toLowerCase();

            if (!/^[a-z0-9._]{3,30}$/.test(value)) {
                return invalid(
                    "Nama pengguna 3-30 karakter: huruf, angka, titik, atau garis bawah."
                );
            }

            updates.username = value;
        }

        // Bio
        if (body.bio !== undefined) {
            if (typeof body.bio !== "string" || body.bio.trim().length > 150) {
                return invalid("Bio maksimal 150 karakter.");
            }

            updates.bio = body.bio.trim();
        }

        // Minat (maks. 5, tiap item maks. 30 karakter)
        if (body.interests !== undefined) {
            if (
                !Array.isArray(body.interests) ||
                body.interests.length > 5 ||
                body.interests.some(
                    (item) =>
                        typeof item !== "string" ||
                        !item.trim() ||
                        item.trim().length > 30
                )
            ) {
                return invalid("Minat maksimal 5 item, tiap item maksimal 30 karakter.");
            }

            updates.interests = [
                ...new Set(body.interests.map((item) => item.trim())),
            ];
        }

        // Tautan (maks. 5, harus http/https)
        if (body.links !== undefined) {
            if (
                !Array.isArray(body.links) ||
                body.links.length > 5 ||
                body.links.some((item) => !isHttpUrl(item))
            ) {
                return invalid("Tautan maksimal 5 dan harus diawali http:// atau https://");
            }

            updates.links = [...new Set(body.links)];
        }

        // Podcast
        if (body.podcast_url !== undefined) {
            if (
                typeof body.podcast_url !== "string" ||
                (body.podcast_url.trim() !== "" &&
                    !isHttpUrl(body.podcast_url.trim()))
            ) {
                return invalid("Tautan podcast tidak valid.");
            }

            updates.podcast_url = body.podcast_url.trim();
        }

        // Switch / privasi
        for (const key of [
            "show_instagram_badge",
            "show_recent_views",
            "is_private",
        ]) {
            if (body[key] !== undefined) {
                if (typeof body[key] !== "boolean") {
                    return invalid("Format input tidak valid.");
                }

                updates[key] = body[key];
            }
        }

        const columns = Object.keys(updates);

        if (columns.length === 0) {
            return invalid("Tidak ada perubahan untuk disimpan.");
        }

        // Nama kolom berasal dari daftar di atas (bukan input user), jadi aman.
        const setClause = columns
            .map((column, index) => `${column} = $${index + 1}`)
            .join(", ");

        const values = columns.map((column) => updates[column]);
        values.push(userId);

        const result = await pool.query(
            `UPDATE users
             SET ${setClause}
             WHERE id = $${values.length}
             RETURNING ${PROFILE_COLUMNS}`,
            values
        );

        if (result.rowCount === 0) {
            return res.status(404).json({
                message: "Akun tidak ditemukan.",
            });
        }

        return res.status(200).json({
            message: "Profil berhasil diperbarui.",
            user: serializeUser(result.rows[0]),
        });
    } catch (error) {
        if (error.code === "23505") {
            return res.status(409).json({
                message: "Username sudah digunakan.",
            });
        }

        console.error("Update profile error:", error.message);

        return res.status(500).json({
            message: "Terjadi kesalahan pada server.",
        });
    }
}

// EXPORT CONTROLLER
module.exports = {
    register,
    login,
    getUsers,
    updateProfile,
};