import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// Avatar obrolan grup.
///   - 2+ foto  : dua avatar kecil bertumpuk
///   - 1 foto   : avatar biasa
///   - kosong   : lingkaran dengan ikon grup
///
///   GroupAvatar(pictures: [urlA, urlB], size: 62)
class GroupAvatar extends StatelessWidget {
  final List<String?> pictures;
  final double size;

  const GroupAvatar({super.key, this.pictures = const [], required this.size});

  static const _bg = Color(0xFF101010);

  @override
  Widget build(BuildContext context) {
    if (pictures.length >= 2) {
      final small = size * 0.66;

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(right: 0, top: 0, child: _ringed(pictures[0], small)),
            Positioned(left: 0, bottom: 0, child: _ringed(pictures[1], small)),
          ],
        ),
      );
    }

    if (pictures.length == 1) {
      return UserAvatar(url: pictures.first, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5),
    );
  }

  Widget _ringed(String? url, double size) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: _bg, shape: BoxShape.circle),
      child: UserAvatar(url: url, size: size),
    );
  }
}