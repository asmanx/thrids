import 'package:flutter/material.dart';

import 'user_avatar.dart';

/// "[avatar][avatar] 123 pengikut" — avatar = pengikut terbaru (bertumpuk),
/// seperti di Threads asli.
class FollowersSummary extends StatelessWidget {
  final int count;
  final List<Map<String, dynamic>> recent;
  final VoidCallback onTap;

  const FollowersSummary({
    super.key,
    required this.count,
    required this.recent,
    required this.onTap,
  });

  /// Mengubah `recent_followers` dari server menjadi List<Map>.
  static List<Map<String, dynamic>> parse(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shown = recent.take(2).toList();
    const size = 22.0;
    const step = 14.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shown.isNotEmpty) ...[
            SizedBox(
              width: size + (shown.length - 1) * step,
              height: size,
              child: Stack(
                children: [
                  // Digambar dari belakang agar yang terbaru ada di paling atas.
                  for (var i = shown.length - 1; i >= 0; i--)
                    Positioned(
                      left: i * step,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF101010),
                            width: 1.5,
                          ),
                        ),
                        child: UserAvatar(
                          url: shown[i]['profile_picture']?.toString(),
                          size: size,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '$count pengikut',
            style: const TextStyle(fontSize: 17, color: Color(0xFF858585)),
          ),
        ],
      ),
    );
  }
}