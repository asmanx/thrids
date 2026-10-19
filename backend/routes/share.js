// routes/share.js
//
//   GET /post/:id  -> halaman web sederhana untuk tautan yang dibagikan
//                     (dibuka dari WhatsApp, browser, dll.)
//
// Hanya postingan publik: akun privat dan postingan sementara yang sudah
// kedaluwarsa dijawab "tidak ditemukan". Semua teks di-escape.
//
// Pasang di server.js:
//   app.use("/post", require("./routes/share"));

const express = require("express");
const pool = require("../config/db");

const router = express.Router();

function esc(value) {
    return String(value ?? "").replace(/[&<>"']/g, (c) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
    })[c]);
}

function baseUrl(req) {
    const proto = req.get("x-forwarded-proto") || req.protocol;
    return `${proto}://${req.get("host")}`;
}

function absolute(base, url) {
    if (!url) return "";
    return /^https?:\/\//i.test(url) ? url : `${base}${url}`;
}

function page(title, body, extraHead = "") {
    return `<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
${extraHead}
<style>
  body { margin:0; background:#101010; color:#fff; font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif; }
  .wrap { max-width:560px; margin:0 auto; padding:28px 18px 48px; }
  .brand { font-size:26px; font-weight:800; font-style:italic; letter-spacing:-1px; margin-bottom:22px; }
  .card { background:#181818; border:1px solid #2a2a2a; border-radius:20px; padding:18px; }
  .head { display:flex; align-items:center; gap:12px; margin-bottom:10px; }
  .avatar { width:44px; height:44px; border-radius:50%; background:#2a2a2a; object-fit:cover; }
  .name { font-weight:700; }
  .muted { color:#858585; font-size:14px; }
  .content { font-size:18px; line-height:1.45; white-space:pre-wrap; word-wrap:break-word; }
  .media { width:100%; border-radius:14px; margin-top:12px; display:block; }
  .note { margin-top:22px; text-align:center; color:#858585; font-size:15px; }
</style>
</head>
<body><div class="wrap"><div class="brand">@ thrids</div>${body}</div></body>
</html>`;
}

router.get("/:id", async (req, res) => {
    const id = req.params.id;

    if (!/^\d+$/.test(id)) {
        return res.status(404).send(page("Tidak ditemukan", '<div class="card">Postingan tidak ditemukan.</div>'));
    }

    try {
        const result = await pool.query(
            `SELECT
                p.id,
                p.content,
                p.created_at,
                u.username,
                u.display_name,
                u.profile_picture,
                (
                    SELECT m.url
                    FROM post_media m
                    WHERE m.post_id = p.id AND m.type = 'image'
                    ORDER BY m.position
                    LIMIT 1
                ) AS image
             FROM posts p
             JOIN users u ON u.id = p.user_id
             WHERE p.id = $1
               AND (p.expires_at IS NULL OR p.expires_at > NOW())
               AND (to_jsonb(u) ->> 'is_private') IS DISTINCT FROM 'true'`,
            [id]
        );

        if (result.rowCount === 0) {
            return res.status(404).send(
                page(
                    "Tidak ditemukan",
                    '<div class="card">Postingan tidak ditemukan, sudah kedaluwarsa, atau akunnya privat.</div>' +
                        '<div class="note">Buka aplikasi Thrids untuk melihat lebih banyak.</div>'
                )
            );
        }

        const post = result.rows[0];
        const base = baseUrl(req);
        const name = post.display_name || post.username;
        const content = String(post.content || "");
        const image = absolute(base, post.image);
        const avatar = absolute(base, post.profile_picture);
        const snippet = content.length > 160 ? `${content.slice(0, 157)}...` : content;

        const head = [
            `<meta property="og:site_name" content="Thrids">`,
            `<meta property="og:type" content="article">`,
            `<meta property="og:title" content="${esc(name)} (@${esc(post.username)}) di Thrids">`,
            `<meta property="og:description" content="${esc(snippet)}">`,
            image ? `<meta property="og:image" content="${esc(image)}">` : "",
        ].join("\n");

        const body = `
<div class="card">
  <div class="head">
    ${avatar ? `<img class="avatar" src="${esc(avatar)}" alt="">` : '<div class="avatar"></div>'}
    <div>
      <div class="name">${esc(post.username)}</div>
      <div class="muted">${esc(name)}</div>
    </div>
  </div>
  <div class="content">${esc(content)}</div>
  ${image ? `<img class="media" src="${esc(image)}" alt="">` : ""}
</div>
<div class="note">Buka aplikasi Thrids untuk menyukai dan membalas postingan ini.</div>`;

        return res.status(200).send(page(`${name} di Thrids`, body, head));
    } catch (error) {
        console.error("Share page error:", error.message);

        return res
            .status(500)
            .send(page("Kesalahan", '<div class="card">Gagal memuat postingan.</div>'));
    }
});

module.exports = router;