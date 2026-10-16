import 'package:flutter/material.dart';

import 'komponenBersama.dart';
import 'screens/halamanBeranda.dart';
import 'screens/halamanPesan.dart';
import 'screens/halamanAktivitas.dart';
import 'screens/halamanProfil.dart';
import 'screens/halamanPost.dart';

void main() => runApp(const thridsApp());

// ───────────────────────── App & shell ─────────────────────────

class thridsApp extends StatelessWidget {
  const thridsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thrids',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: kBg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dividerColor: kBorder,
      ),
      home: const mainShell(),
    );
  }
}

class mainShell extends StatefulWidget {
  const mainShell({super.key});

  @override
  State<mainShell> createState() => mainShellState();
}

class mainShellState extends State<mainShell> {
  int _nav = 4; // Membuka halaman Profil saat aplikasi dijalankan

  static const _pageOf = {
    0: 0, // Beranda
    1: 1, // Pesan
    3: 2, // Aktivitas
    4: 3, // Profil
  };

  void _tap(int i) {
    // Tombol tambah membuka halaman Post
    if (i == 2) {
      bukaHalamanPost(context);
      return;
    }

    setState(() {
      _nav = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pageOf[_nav]!,
        children: const [
          halamanBeranda(),
          halamanPesan(),
          halamanAktivitas(),
          halamanProfil(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          color: kBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(
                Icons.home_outlined,
                Icons.home_rounded,
                0,
              ),
              _item(
                Icons.chat_bubble_outline_rounded,
                Icons.chat_bubble_rounded,
                1,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _tap(2),
                child: Container(
                  width: 64,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 30,
                    color: kMuted,
                  ),
                ),
              ),
              _item(
                Icons.favorite_border_rounded,
                Icons.favorite_rounded,
                3,
              ),
              _item(
                Icons.person_outline_rounded,
                Icons.person_rounded,
                4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    IconData active,
    int i,
  ) {
    final on = _nav == i;

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _tap(i),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          on ? active : icon,
          size: 30,
          color: on ? Colors.white : kMuted,
        ),
      ),
    );
  }
}
