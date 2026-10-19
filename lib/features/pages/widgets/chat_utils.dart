import '../../../services/api_service.dart';

/// Mengubah tanggal dari server (ISO 8601) menjadi waktu lokal.
DateTime? parseChatDate(dynamic value) {
  return DateTime.tryParse('${value ?? ''}')?.toLocal();
}

/// URL gambar profil lengkap, atau null bila kosong (pakai avatar bawaan).
String? pictureOf(dynamic raw) {
  final value = (raw ?? '').toString();
  return value.isEmpty ? null : ApiService.resolveUrl(value);
}

/// Waktu singkat di daftar pesan: "Baru saja", "5 mnt", "2 jam", "4 hari".
String chatListTime(dynamic value) {
  final date = parseChatDate(value);
  if (date == null) return '';

  final diff = DateTime.now().difference(date);

  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
  if (diff.inHours < 24) return '${diff.inHours} jam';
  if (diff.inDays < 7) return '${diff.inDays} hari';

  return '${date.day}/${date.month}/${date.year}';
}

const _days = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
  'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES',
];

String _hourMinute(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

/// Pemisah waktu di dalam obrolan: "07.22", "KEMARIN 15.29", "RAB 08.12".
String chatSeparatorLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) return _hourMinute(date);
  if (daysAgo == 1) return 'KEMARIN ${_hourMinute(date)}';
  if (daysAgo < 7) return '${_days[date.weekday - 1]} ${_hourMinute(date)}';

  return '${date.day} ${_months[date.month - 1]} ${_hourMinute(date)}';
}

/// Cuplikan pesan terakhir di daftar percakapan. Untuk grup ([group] true),
/// pesan dari orang lain diawali nama pengirimnya.
String messagePreview(Map<String, dynamic>? last, {bool group = false}) {
  if (last == null) return '';

  final mine = last['mine'] == true;
  final content = (last['content'] ?? '').toString();
  final type = '${last['type']}';

  // Pesan sistem ("asman membuat grup") tampil apa adanya.
  if (type == 'system') return content;

  final sender = group && !mine ? '${last['sender_username'] ?? ''}' : '';

  String media(String own, String other) {
    if (mine) return own;
    return sender.isEmpty ? other : '$sender ${other.toLowerCase()}';
  }

  switch (type) {
    case 'image':
      return media('Anda mengirim foto', 'Mengirim foto');
    case 'gif':
      return media('Anda mengirim GIF', 'Mengirim GIF');
    case 'sticker':
      return media('Anda mengirim stiker', 'Mengirim stiker');
    case 'post':
      return media('Anda membagikan utas', 'Membagikan utas');
    default:
      if (mine) return 'Anda: $content';
      return sender.isEmpty ? content : '$sender: $content';
  }
}