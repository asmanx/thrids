const express = require("express");
const cors = require("cors");
const path = require("path");
require("dotenv").config();

const authRoutes = require("./routes/auth");

const pool = require("./config/db");

const app = express();

const authMiddleware = require("./middleware/authMiddleware");

const postRoutes = require("./routes/posts");

const avatarRoutes = require("./routes/avatar");

app.use(cors());
app.use(express.json());

// File yang diunggah (foto, video, musik) bisa diakses lewat /uploads/<nama-file>
app.use(
    "/uploads",
    express.static(path.join(__dirname, "uploads"), {
        setHeaders: (res) => {
            res.setHeader("X-Content-Type-Options", "nosniff");
            res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
        },
    })
);

app.use("/api/auth", authRoutes);

app.use("/api/posts", postRoutes);

app.use("/api/auth", avatarRoutes);

// Follow (ikuti / berhenti mengikuti) dan halaman Aktivitas
app.use("/api/users", require("./routes/follows"));
app.use("/api/activity", require("./routes/activity"));

app.use("/api/notifications", require("./routes/notification"));

// Pesan (DM): kotak masuk, permintaan, dan obrolan 1-lawan-1
app.use("/api/messages", require("./routes/messages"));

// Musik online (Deezer): trending, pencarian, dan preview
app.use("/api/music", require("./routes/music"));

app.use("/post", require("./routes/share"));

// Endpoint utama
app.get("/", (req, res) => {
    res.json({
        message: "API Thrids berhasil dijalankan!",
    });
});

// Endpoint untuk menguji koneksi database
app.get("/api/health/db", async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT NOW() AS waktu_database"
        );

        res.json({
            message: "Koneksi PostgreSQL berhasil!",
            waktu: result.rows[0].waktu_database,
        });
    } catch (error) {
        console.error("Database error:", error.message);

        res.status(500).json({
            message: "Koneksi PostgreSQL gagal.",
            error: error.message,
        });
    }
});

// Jalankan server
const PORT = process.env.PORT || 3000;

app.get("/api/auth/me", authMiddleware, (req, res) => {
    res.json({
        message: "Token valid. Kamu berhasil terautentikasi!",
        user: req.user,
    });
});

app.listen(PORT, () => {
    console.log(`Server berjalan di http://localhost:${PORT}`);
});