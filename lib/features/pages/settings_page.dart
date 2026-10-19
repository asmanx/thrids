import 'package:flutter/material.dart';

import 'privacy_profile_page.dart';
import 'widgets/logout_dialog.dart';

/// Halaman "Pengaturan": Akun Meta di atas, lalu daftar menu, lalu
/// "Beralih akun" (biru) dan "Logout" (merah) di paling bawah.
class SettingsPage extends StatelessWidget {
  final bool isPrivate;

  /// Dipanggil saat nilai "Profil privat" diubah lewat menu Privasi.
  final Future<void> Function(bool value)? onPrivateChanged;

  /// Dipanggil setelah pengguna menekan Logout / Beralih akun dan menyetujui.
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.isPrivate,
    required this.onLogout,
    this.onPrivateChanged,
  });

  static const _bg = Color(0xFF101010);
  static const _muted = Color(0xFF858585);
  static const _divider = Color(0xFF2E2E2E);
  static const _blue = Color(0xFF0095F6);
  static const _red = Color(0xFFFF3040);

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label belum tersedia.')));
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrivacyProfilePage(isPrivate: isPrivate),
      ),
    );

    if (result != null && result != isPrivate) {
      await onPrivateChanged?.call(result);
    }
  }

  /// Dialog konfirmasi bergaya sama dengan dialog logout; setelah disetujui,
  /// memanggil [onLogout] (keluar dari akun & kembali ke Pilih akun).
  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String action,
    Color actionColor = const Color(0xFFE3162B),
  }) async {
    final ok = await showLogoutDialog(
      context,
      title: title,
      actionLabel: action,
      actionColor: actionColor,
    );

    if (ok && context.mounted) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.supervisor_account_outlined,
        label: 'Pengawasan untuk Akun Remaja',
        onTap: () => _soon(context, 'Pengawasan untuk Akun Remaja'),
      ),
      (
        icon: Icons.person_add_alt_outlined,
        label: 'Ikuti dan undang teman',
        onTap: () => _soon(context, 'Ikuti dan undang teman'),
      ),
      (
        icon: Icons.notifications_none_rounded,
        label: 'Notifikasi',
        onTap: () => _soon(context, 'Pengaturan notifikasi'),
      ),
      (
        icon: Icons.bookmark_border_rounded,
        label: 'Tersimpan',
        onTap: () => _soon(context, 'Tersimpan'),
      ),
      (
        icon: Icons.favorite_border_rounded,
        label: 'Disukai',
        onTap: () => _soon(context, 'Disukai'),
      ),
      (
        icon: Icons.history_rounded,
        label: 'Arsipkan',
        onTap: () => _soon(context, 'Arsipkan'),
      ),
      (
        icon: Icons.lock_outline_rounded,
        label: 'Privasi',
        onTap: () => _openPrivacy(context),
      ),
      (
        icon: Icons.tune_rounded,
        label: 'Preferensi konten',
        onTap: () => _soon(context, 'Preferensi konten'),
      ),
      (
        icon: Icons.person_outline_rounded,
        label: 'Status profil',
        onTap: () => _soon(context, 'Status profil'),
      ),
      (
        icon: Icons.ios_share_rounded,
        label: 'Berbagi lintas profil',
        onTap: () => _soon(context, 'Berbagi lintas profil'),
      ),
      (
        icon: Icons.settings_outlined,
        label: 'Pengaturan selengkapnya',
        onTap: () => _soon(context, 'Pengaturan selengkapnya'),
      ),
      (
        icon: Icons.help_outline_rounded,
        label: 'Bantuan',
        onTap: () => _soon(context, 'Bantuan'),
      ),
      (
        icon: Icons.bubble_chart_outlined,
        label: 'Asisten dukungan Meta AI',
        onTap: () => _soon(context, 'Asisten dukungan Meta AI'),
      ),
      (
        icon: Icons.info_outline_rounded,
        label: 'Tentang',
        onTap: () => _soon(context, 'Tentang'),
      ),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, size: 30),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Akun Meta
          InkWell(
            onTap: () => _soon(context, 'Akun Meta'),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.all_inclusive_rounded,
                      color: Colors.white, size: 32),
                  SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Akun Meta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Kata sandi, keamanan, detail pribadi, pengalaman '
                          'lintas-profil, preferensi iklan',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 18,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _divider),
          for (final item in items)
            InkWell(
              onTap: item.onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(item.icon, color: Colors.white, size: 30),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1, color: _divider),
          InkWell(
            onTap: () => _confirm(
              context,
              title: 'Beralih ke akun lain?',
              action: 'Beralih akun',
              actionColor: _blue,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Text(
                'Beralih akun',
                style: TextStyle(color: _blue, fontSize: 20),
              ),
            ),
          ),
          InkWell(
            onTap: () => _confirm(
              context,
              title: 'Logout dari akun Anda?',
              action: 'Logout',
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Text(
                'Logout',
                style: TextStyle(color: _red, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}