import 'dart:async';

import 'package:flutter/material.dart';

import 'package:thrids/services/api_service.dart';

import '../auth/pages/account_picker_page.dart';

/// Layar pembuka. Tampil sebentar, lalu masuk ke halaman pilih akun.
///
/// Selama splash tampil, daftar akun (beserta foto profil terbaru) sudah
/// diunduh di latar belakang, jadi halaman pilih akun langsung terisi.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  /// Lama minimal splash tampil.
  static const minimumDuration = Duration(milliseconds: 1800);

  /// Batas tunggu daftar akun setelah splash selesai.
  static const fetchTimeout = Duration(seconds: 3);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    List<Map<String, dynamic>>? users;

    final minimum = Future<void>.delayed(SplashPage.minimumDuration);

    // Gagal (mis. server mati) tidak masalah: halaman pilih akun akan
    // memuat sendiri dan menampilkan tombol "Coba lagi".
    final fetch = ApiService.getUsers().then<void>((result) {
      users = result;
    }).catchError((_) {});

    await minimum;
    await fetch.timeout(SplashPage.fetchTimeout, onTimeout: () {});

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => AccountPickerPage(initialUsers: users),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Logo dan nama aplikasi di tengah
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alternate_email, color: Colors.white, size: 60),
                  SizedBox(width: 8),
                  Text(
                    'thrids',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -2,
                    ),
                  ),
                ],
              ),
            ),

            // Tulisan from Meta di bawah
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'from',
                    style: TextStyle(color: Colors.white, fontSize: 17),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.all_inclusive, color: Colors.white, size: 36),
                      SizedBox(width: 6),
                      Text(
                        'Meta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}