import 'package:flutter/material.dart';

/// Halaman "Privasi profil": satu tombol geser "Profil privat".
///
/// Mengembalikan nilai terakhir (`true` = privat) lewat `Navigator.pop`
/// saat pengguna kembali.
class PrivacyProfilePage extends StatefulWidget {
  final bool isPrivate;

  const PrivacyProfilePage({super.key, required this.isPrivate});

  @override
  State<PrivacyProfilePage> createState() => _PrivacyProfilePageState();
}

class _PrivacyProfilePageState extends State<PrivacyProfilePage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);

  late bool _isPrivate = widget.isPrivate;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_isPrivate);
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 64,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back, size: 30),
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(_isPrivate),
          ),
          title: const Text(
            'Privasi profil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Profil privat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _isPrivate,
                  onChanged: (value) => setState(() => _isPrivate = value),
                  thumbColor: const WidgetStatePropertyAll(Colors.black),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFFF4F4F6)
                        : const Color(0xFF3A3A3A),
                  ),
                  trackOutlineColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFFF4F4F6)
                        : const Color(0xFF3A3A3A),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Saat profil Anda privat, hanya pengikut yang bisa melihat dan '
              'berinteraksi dengan utas Anda. Balasan Anda akan bisa dilihat '
              'oleh pengikut dan profil individu yang Anda balas.',
              style: TextStyle(color: kMuted, fontSize: 18, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}