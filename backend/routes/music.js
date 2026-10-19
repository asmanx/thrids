const express = require("express");

const router = express.Router();

// Sumber musik: Deezer API (gratis, tanpa API key, preview 30 detik).
// Aplikasi Flutter hanya bicara dengan backend ini, jadi kalau nanti mau
// ganti sumber musik, cukup ubah file ini.
const DEEZER = "https://api.deezer.com";

async function deezer(path) {
    const response = await fetch(`${DEEZER}${path}`, {
        signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) throw new Error(`Deezer ${response.status}`);

    const json = await response.json();

    // Deezer membalas 200 walau error, dengan isi { error: {...} }
    if (json && json.error) throw new Error("Deezer error");

    return json;
}

function mapTrack(track) {
    return {
        id: String(track.id),
        title: track.title_short || track.title || "",
        artist: (track.artist && track.artist.name) || "",
        cover: (track.album && (track.album.cover_medium || track.album.cover)) || "",
        duration: track.duration || 0,
        explicit: track.explicit_lyrics === true,
    };
}

// Cache kecil untuk "Sedang tren" supaya tidak memanggil Deezer terus-menerus
let trendingCache = { at: 0, data: null };
const TRENDING_TTL_MS = 5 * 60 * 1000;

// GET /api/music/trending
router.get("/trending", async (req, res) => {
    try {
        if (trendingCache.data && Date.now() - trendingCache.at < TRENDING_TTL_MS) {
            return res.json({ tracks: trendingCache.data });
        }

        const json = await deezer("/chart/0/tracks?limit=40");
        const tracks = (json.data || []).filter((t) => t.preview).map(mapTrack);

        trendingCache = { at: Date.now(), data: tracks };

        return res.json({ tracks });
    } catch (error) {
        console.error("Music trending error:", error.message);
        return res.status(502).json({ message: "Gagal memuat musik." });
    }
});

// GET /api/music/search?q=...
router.get("/search", async (req, res) => {
    const q = typeof req.query.q === "string" ? req.query.q.trim().slice(0, 100) : "";

    if (!q) return res.json({ tracks: [] });

    try {
        const json = await deezer(`/search?q=${encodeURIComponent(q)}&limit=40`);
        const tracks = (json.data || []).filter((t) => t.preview).map(mapTrack);

        return res.json({ tracks });
    } catch (error) {
        console.error("Music search error:", error.message);
        return res.status(502).json({ message: "Gagal mencari musik." });
    }
});

// GET /api/music/preview/:id
// Link preview milik Deezer berisi token yang kedaluwarsa, jadi jangan
// disimpan ke database. Yang disimpan adalah alamat ini; setiap diputar,
// backend mengambil link segar lalu mengarahkan (redirect) pemutarnya.
router.get("/preview/:id", async (req, res) => {
    const id = req.params.id;

    if (!/^\d{1,15}$/.test(id)) {
        return res.status(400).json({ message: "ID musik tidak valid." });
    }

    try {
        const track = await deezer(`/track/${id}`);

        if (!track.preview) {
            return res.status(404).json({ message: "Preview tidak tersedia." });
        }

        // Jangan di-cache: tiap lagu harus selalu mengarah ke previewnya sendiri.
        res.set("Cache-Control", "no-store");

        return res.redirect(302, track.preview);
    } catch (error) {
        console.error("Music preview error:", error.message);
        return res.status(502).json({ message: "Gagal memuat preview." });
    }
});

module.exports = router;