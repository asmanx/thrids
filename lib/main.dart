import 'package:flutter/material.dart';

import 'features/splash/splash_page.dart';

void main() {
  runApp(const ThridsApp());
}

class ThridsApp extends StatelessWidget {
  const ThridsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thrids',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1F1F1F),
      ),
      // Urutan: Splash -> Pilih akun -> Login / Register -> Beranda
      home: const SplashPage(),
    );
  }
}