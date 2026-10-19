import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';

/// Jumlah hal yang belum dilihat, untuk tanda merah di navigasi bawah:
///  - [messages]: percakapan belum dibaca (tidak termasuk yang dibisukan)
///    ditambah permintaan pesan;
///  - [activity]: notifikasi belum dibaca (follow, suka, balasan, dst.).
///
/// HomePage memulai pemeriksaan berkala saat dibuka dan menghentikannya saat
/// keluar akun:
///
///   NavBadges.start(widget.token);   // initState
///   NavBadges.stop();                // dispose / logout
class NavBadges {
  NavBadges._();

  static final ValueNotifier<int> messages = ValueNotifier<int>(0);
  static final ValueNotifier<int> activity = ValueNotifier<int>(0);

  static String? _token;
  static Timer? _timer;
  static bool _busy = false;

  /// Mulai memeriksa sekarang, lalu ulangi tiap [every].
  static void start(
    String token, {
    Duration every = const Duration(seconds: 10),
  }) {
    if (_token == token && _timer != null) {
      refresh();
      return;
    }

    stop();

    _token = token;
    refresh();
    _timer = Timer.periodic(every, (_) => refresh());
  }

  /// Hentikan pemeriksaan dan hapus semua tanda (dipakai saat logout).
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _token = null;
    messages.value = 0;
    activity.value = 0;
  }

  /// Periksa ulang sekarang (mis. setelah membuka Aktivitas atau Pesan).
  static Future<void> refresh() async {
    final token = _token;

    if (token == null || _busy) return;

    _busy = true;

    try {
      final counts = await Future.wait<int>([
        _countActivity(token),
        _countMessages(token),
      ]);

      // Sudah logout / ganti akun saat menunggu: abaikan hasilnya.
      if (_token != token) return;

      activity.value = counts[0];
      messages.value = counts[1];
    } finally {
      _busy = false;
    }
  }

  static Future<int> _countActivity(String token) async {
    try {
      return await ApiService.getUnreadCount(token: token);
    } catch (_) {
      return activity.value; // gagal: pertahankan angka terakhir
    }
  }

  static Future<int> _countMessages(String token) async {
    try {
      final result = await ApiService.getConversations(
        token: token,
        filter: 'unread',
      );

      var total = 0;
      for (final item in result.conversations) {
        if (item['is_muted'] != true) total++;
      }

      return total + result.requestCount;
    } catch (_) {
      return messages.value;
    }
  }
}

/// Membungkus ikon navigasi dengan tanda merah. Indeks 1 = Pesan,
/// 3 = Aktivitas; indeks lain tidak diberi tanda.
class NavBadgeIcon extends StatelessWidget {
  final int index;
  final Widget child;

  const NavBadgeIcon({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final notifier = switch (index) {
      1 => NavBadges.messages,
      3 => NavBadges.activity,
      _ => null,
    };

    if (notifier == null) return child;

    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: -8,
                top: -5,
                child: _RedBadge(count: count),
              ),
          ],
        );
      },
    );
  }
}

class _RedBadge extends StatelessWidget {
  final int count;

  const _RedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3040),
        borderRadius: BorderRadius.circular(10),
        // Garis tepi seperti warna latar navigasi, supaya tanda terlihat terpisah.
        border: Border.all(color: const Color(0xFF101010), width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}