import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// Avatar akun orang lain di feed, dengan badge kecil di pojok kanan bawah:
///  - belum diikuti  -> tanda "+"
///  - sudah diikuti  -> tanda centang
///
/// Mengetuk badge memunculkan popup "Buka profil" dan "Ikuti" / "Batal ikut".
/// Mengetuk avatarnya langsung membuka profil.
class FollowAvatar extends StatelessWidget {
  final String? url;
  final double size;

  /// false untuk postingan milik sendiri (tanpa badge).
  final bool showBadge;
  final bool isFollowing;

  /// Permintaan ikuti ke akun privat yang belum disetujui.
  final bool isRequested;

  final VoidCallback onAvatarTap;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleFollow;

  const FollowAvatar({
    super.key,
    required this.url,
    required this.size,
    required this.showBadge,
    required this.isFollowing,
    required this.isRequested,
    required this.onAvatarTap,
    required this.onOpenProfile,
    required this.onToggleFollow,
  });

  static const _bg = Color(0xFF101010);
  static const _menuBg = Color(0xFF1E1E1E);

  Future<void> _showMenu(BuildContext badgeContext) async {
    final box = badgeContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(badgeContext).context.findRenderObject() as RenderBox;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );

    final followed = isFollowing || isRequested;
    final followLabel = isRequested
        ? 'Batalkan permintaan'
        : (isFollowing ? 'Batal ikut' : 'Ikuti');

    final choice = await showMenu<String>(
      context: badgeContext,
      position: position,
      color: _menuBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      items: [
        _item('profile', 'Buka profil', Icons.person_outline),
        _item(
          'follow',
          followLabel,
          followed ? Icons.check_circle_outline : Icons.add_circle_outline,
        ),
      ],
    );

    if (choice == 'profile') onOpenProfile();
    if (choice == 'follow') onToggleFollow();
  }

  PopupMenuItem<String> _item(String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: Colors.white, size: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followed = isFollowing || isRequested;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAvatarTap,
            child: UserAvatar(url: url, size: size),
          ),
          if (showBadge)
            Positioned(
              right: -5,
              bottom: -5,
              child: Builder(
                builder: (badgeContext) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showMenu(badgeContext),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: followed
                          ? const Color(0xFF2E2E2E)
                          : const Color(0xFFF3F5F7),
                      border: Border.all(color: _bg, width: 2),
                    ),
                    child: Icon(
                      followed ? Icons.check_rounded : Icons.add_rounded,
                      size: 15,
                      color: followed ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}