-- Migrasi 003: cover musik untuk musik online (Deezer)
-- Jalankan sekali, contoh:
--   psql -U <user> -d <nama_database> -f migrations/003_post_music.sql
--
-- music_title dan music_url sudah ada dari migrasi 002.
-- Untuk musik online, music_url berisi alamat relatif /api/music/preview/<id>.

ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS music_cover TEXT;