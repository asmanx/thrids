-- Hapus utas: pastikan data yang menunjuk ke utas / komentar ikut terhapus.
-- Jalankan SEKALI di database thrids_database (aman diulang).
--
-- Semua foreign key ke posts(id) dan post_comments(id) yang BELUM berupa
-- ON DELETE CASCADE / SET NULL dibuat ulang:
--   - kolom yang boleh NULL (mis. kutipan utas, pesan yang membagikan utas)
--       -> ON DELETE SET NULL (baris lain tetap ada)
--   - kolom NOT NULL (suka, simpan, repost, media, dll.)
--       -> ON DELETE CASCADE
--
-- Tanpa ini, DELETE /api/posts/:id bisa gagal dengan pesan
-- "Utas ini belum bisa dihapus karena masih terhubung ke data lain."

DO $$
DECLARE
    r RECORD;
    action TEXT;
BEGIN
    FOR r IN
        SELECT con.conname,
               con.conrelid::regclass AS tbl,
               att.attname            AS col,
               att.attnotnull         AS not_null,
               con.confrelid::regclass AS ref
        FROM pg_constraint con
        JOIN pg_attribute att
             ON att.attrelid = con.conrelid AND att.attnum = con.conkey[1]
        WHERE con.contype = 'f'
          AND con.confrelid IN ('posts'::regclass, 'post_comments'::regclass)
          AND array_length(con.conkey, 1) = 1
          AND con.confdeltype NOT IN ('c', 'n')
    LOOP
        action := CASE WHEN r.not_null THEN 'CASCADE' ELSE 'SET NULL' END;

        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
        EXECUTE format(
            'ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %s(id) ON DELETE %s',
            r.tbl, r.conname, r.col, r.ref, action
        );

        RAISE NOTICE 'Diperbarui: %.% -> % ON DELETE %', r.tbl, r.col, r.ref, action;
    END LOOP;
END $$;