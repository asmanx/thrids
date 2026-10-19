-- Jalankan SEKALI di database thrids_database (PostgreSQL).
--
--   psql -U <user_db> -d thrids_database -f migration_unique_username.sql
--
-- Pengaman terakhir: database sendiri menolak dua akun dengan username yang
-- sama (tanpa membedakan huruf besar/kecil), walau dua orang mendaftar di detik
-- yang sama.

-- LANGKAH 1 - cek dulu apakah sudah ada username kembar. Hasilnya harus KOSONG.
SELECT LOWER(username) AS username, COUNT(*) AS jumlah
FROM users
GROUP BY LOWER(username)
HAVING COUNT(*) > 1;

-- LANGKAH 2 - kalau hasil langkah 1 kosong, jalankan:
CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_uniq
    ON users (LOWER(username));