import 'package:flutter/widgets.dart';

/// Navigasi bersama untuk kembali ke Home.
///
/// Masalah lama: banyak halaman memakai `popUntil((route) => route.isFirst)`
/// untuk "kembali ke Home". Itu hanya benar kalau Home adalah halaman paling
/// bawah. Kalau Home dibuka dari Login / Pilih akun dengan `push` biasa, rute
/// paling bawah adalah Splash / Pilih akun / Login, sehingga tombol navigasi
/// malah membawa pengguna kembali ke halaman login.
///
/// Solusi: HomePage mendaftarkan rutenya sendiri ke sini, dan semua halaman
/// memanggil [AppNav.goHome] (bukan `isFirst`).
class AppNav {
  static Route<dynamic>? _homeRoute;

  /// Dipanggil oleh HomePage setelah selesai dibangun.
  static void registerHome(BuildContext context) {
    _homeRoute = ModalRoute.of(context);
  }

  /// Dipanggil saat logout.
  static void clear() => _homeRoute = null;

  /// Tutup semua halaman di atas Home sehingga Home kembali tampil.
  static void goHome(BuildContext context) {
    final nav = Navigator.of(context);
    final home = _homeRoute;

    if (home != null && home.isActive) {
      nav.popUntil((route) => route == home);
    } else {
      // Cadangan (Home belum terdaftar): perilaku lama.
      nav.popUntil((route) => route.isFirst);
    }
  }
}