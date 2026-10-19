import 'package:flutter/material.dart';

import '../../auth/pages/account_picker_page.dart';
import '../activity_page.dart' show FollowStore;
import 'app_nav.dart';
import 'nav_badges.dart';
import '../profile_page.dart' show UserSession;

const _kDialogBg = Color(0xFF262626);
const _kDivider = Color(0xFF3A3A3A);
const _kLogoutRed = Color(0xFFE3162B);

/// Dialog konfirmasi logout:
///
///   Logout dari akun Anda?
///   ──────────────────────
///            Logout          (merah; teks & warna bisa diganti)
///   ──────────────────────
///           Batalkan
///
/// Mengembalikan `true` kalau pengguna memilih "Logout".
///
///   final ok = await showLogoutDialog(context);
///   if (!context.mounted) return;
///   if (ok) widget.onLogout();
Future<bool> showLogoutDialog(
  BuildContext context, {
  String title = 'Logout dari akun Anda?',
  String actionLabel = 'Logout',
  Color actionColor = _kLogoutRed,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB8000000), // latar gelap ±72%
    builder: (_) => _LogoutDialog(
      title: title,
      actionLabel: actionLabel,
      actionColor: actionColor,
    ),
  );

  return result == true;
}

/// Keluar dari akun: bersihkan data sesi, lalu kembali ke halaman Pilih akun
/// dan tutup semua halaman sebelumnya (tombol "kembali" tidak bisa kembali ke
/// akun yang sudah keluar).
void performLogout(BuildContext context) {
  UserSession.clear();
  NavBadges.stop();
  AppNav.clear();
  FollowStore.usernames.clear();
  FollowStore.requested.clear();

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const AccountPickerPage()),
    (route) => false,
  );
}

class _LogoutDialog extends StatelessWidget {
  final String title;
  final String actionLabel;
  final Color actionColor;

  const _LogoutDialog({
    required this.title,
    required this.actionLabel,
    required this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDialogBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _kDivider),
          _DialogAction(
            label: actionLabel,
            color: actionColor,
            bold: true,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const Divider(height: 1, thickness: 1, color: _kDivider),
          _DialogAction(
            label: 'Batalkan',
            color: Colors.white,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  final String label;
  final Color color;
  final bool bold;
  final VoidCallback onTap;

  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}