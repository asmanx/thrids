import 'package:flutter/material.dart';

import 'nav_badges.dart';

/// Navigasi bawah: Home, Pesan, Buat postingan (+), Aktivitas, Profil.
/// Tampilannya sama dengan navigasi di halaman Home.
///
/// Indeks: 0 = home, 1 = pesan, 2 = buat postingan, 3 = aktivitas, 4 = profil.
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const background = Color(0xFF101010);
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);

  static const _icons = <IconData>[
    Icons.home_outlined,
    Icons.send_outlined,
    Icons.add,
    Icons.favorite_border,
    Icons.person_outline,
  ];

  static const _selectedIcons = <IconData>[
    Icons.home_filled,
    Icons.send,
    Icons.add,
    Icons.favorite,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: separator)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_icons.length, (index) {
          final isSelected = selectedIndex == index;

          return IconButton(
            onPressed: () => onTap(index),
            icon: NavBadgeIcon(
              index: index,
              child: Icon(
                isSelected ? _selectedIcons[index] : _icons[index],
                size: index == 2 ? 35 : 29,
                color: isSelected ? Colors.white : muted,
              ),
            ),
            style: index == 2
                ? IconButton.styleFrom(
                    backgroundColor: const Color(0xFF303030),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    fixedSize: const Size(58, 52),
                  )
                : null,
          );
        }),
      ),
    );
  }
}