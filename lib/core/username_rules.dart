import 'package:flutter/services.dart';

/// Status pemeriksaan username (dipakai di halaman daftar).
enum UsernameStatus { idle, checking, available, taken, invalid }

/// Aturan username ala Threads / Instagram:
///
///  - hanya huruf (a–z), angka (0–9), titik (.), dan garis bawah (_)
///  - 3–30 karakter
///  - tanpa spasi atau simbol lain
///  - tidak diawali / diakhiri titik, dan tidak ada dua titik berturutan
///  - huruf besar otomatis menjadi huruf kecil; username unik walau
///    kapitalnya berbeda ("Budi" dan "budi" dianggap sama)
///
/// Aturan yang sama dipasang di server (backend/routes/auth.js).
class UsernameRules {
  UsernameRules._();

  static const int minLength = 3;
  static const int maxLength = 30;

  static const String hint =
      'Huruf, angka, titik (.), dan garis bawah (_). '
      '$minLength–$maxLength karakter.';

  /// Rapikan masukan: buang spasi di tepi & tanda "@", jadikan huruf kecil.
  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    if (value.startsWith('@')) value = value.substring(1);
    return value;
  }

  /// Mengembalikan pesan kesalahan, atau null kalau username sudah sesuai.
  static String? validate(String input) {
    final u = normalize(input);

    if (u.isEmpty) return 'Username wajib diisi.';
    if (u.length < minLength) return 'Username minimal $minLength karakter.';
    if (u.length > maxLength) return 'Username maksimal $maxLength karakter.';

    if (RegExp(r'\s').hasMatch(u)) {
      return 'Username tidak boleh mengandung spasi.';
    }

    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(u)) {
      return 'Username hanya boleh berisi huruf, angka, titik (.), '
          'dan garis bawah (_).';
    }

    if (u.startsWith('.') || u.endsWith('.')) {
      return 'Username tidak boleh diawali atau diakhiri titik.';
    }

    if (u.contains('..')) {
      return 'Username tidak boleh memiliki dua titik berturutan.';
    }

    return null;
  }

  /// Dipasang di kolom username: hanya karakter yang diizinkan, otomatis huruf
  /// kecil, dan maksimal [maxLength] karakter.
  static final List<TextInputFormatter> inputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._]')),
    TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          newValue.copyWith(text: newValue.text.toLowerCase()),
    ),
    LengthLimitingTextInputFormatter(maxLength),
  ];
}