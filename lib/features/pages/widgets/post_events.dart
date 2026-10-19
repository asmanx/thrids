import 'dart:async';

/// Kabar antar halaman tentang utas. Dipakai supaya utas yang dihapus di Profil
/// langsung hilang dari Beranda (dan sebaliknya) tanpa muat ulang.
///
///   // memberi kabar
///   PostEvents.notifyDeleted(postId);
///
///   // mendengarkan (initState) dan berhenti (dispose)
///   _sub = PostEvents.onDeleted.listen((id) { ... });
///   _sub?.cancel();
class PostEvents {
  PostEvents._();

  static final StreamController<String> _deleted =
      StreamController<String>.broadcast();

  /// Berisi id utas (String) yang baru dihapus.
  static Stream<String> get onDeleted => _deleted.stream;

  static void notifyDeleted(Object postId) => _deleted.add('$postId');
}