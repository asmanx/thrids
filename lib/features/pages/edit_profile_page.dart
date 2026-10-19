
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../services/api_service.dart';
import 'privacy_profile_page.dart';
import 'widgets/user_avatar.dart';

/// Halaman Edit profil.
///
/// Mengembalikan Map user yang sudah diperbarui lewat `Navigator.pop`
/// (atau `null` kalau dibatalkan).
///
/// [onSave] menerima HANYA field yang berubah, contoh:
/// `{'display_name': 'Asman', 'bio': '...', 'is_private': true}`
/// dan boleh mengembalikan Map user terbaru dari server (opsional).
/// Lempar exception di dalamnya kalau gagal; pesannya ditampilkan ke user.
/// Kalau [onSave] null, perubahan hanya diterapkan di tampilan aplikasi.
class EditProfilePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> changes)?
      onSave;

  const EditProfilePage({
    super.key,
    required this.token,
    required this.user,
    this.onSave,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const kBg = Color(0xFF101010);
  static const kCard = Color(0xFF1A1A1A);
  static const kCardBorder = Color(0xFF3A3A3A);
  static const kDivider = Color(0xFF2E2E2E);
  static const kMuted = Color(0xFF858585);
  static const kDisabled = Color(0xFF5E5E5E);
  static const kSheet = Color(0xFF242424);

  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _podcast;

  late List<String> _interests;
  late List<String> _links;
  late bool _showInstagram;
  late bool _showViews;
  late bool _isPrivate;

  /// Nilai awal, dipakai untuk mendeteksi perubahan.
  late final Map<String, dynamic> _initial;

  bool _saving = false;

  /// Foto profil baru yang dipilih (belum diunggah; diunggah saat Simpan).
  UploadFile? _newAvatar;

  // ───────────────────────── Init ─────────────────────────

  @override
  void initState() {
    super.initState();

    final u = widget.user;
    final username = (u['username'] ?? '').toString();

    _name = TextEditingController(
      text: (u['display_name'] ?? username).toString(),
    );
    _username = TextEditingController(text: username);
    _bio = TextEditingController(text: (u['bio'] ?? '').toString());
    _podcast = TextEditingController(text: (u['podcast_url'] ?? '').toString());

    _interests = _readList(u['interests']);
    _links = _readList(u['links']);
    _showInstagram = u['show_instagram_badge'] == true;
    _showViews = u['show_recent_views'] != false; // default: aktif
    _isPrivate = u['is_private'] == true;

    _initial = _current();

    for (final c in [_name, _username, _bio, _podcast]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _podcast.dispose();
    super.dispose();
  }

  List<String> _readList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  /// URL/path foto profil (boleh relatif; [UserAvatar] yang melengkapinya).
  String? get _avatarUrl {
    final s = (widget.user['avatar_url'] ?? widget.user['profile_picture'] ?? '')
        .toString();
    return s.isEmpty ? null : s;
  }

  // ───────────────────────── Perubahan & validasi ─────────────────────────

  Map<String, dynamic> _current() => {
        'display_name': _name.text.trim(),
        'username': _username.text.trim().toLowerCase(),
        'bio': _bio.text.trim(),
        'interests': List<String>.of(_interests),
        'links': List<String>.of(_links),
        'podcast_url': _podcast.text.trim(),
        'show_instagram_badge': _showInstagram,
        'show_recent_views': _showViews,
        'is_private': _isPrivate,
      };

  Map<String, dynamic> _collectChanges() {
    final now = _current();
    final changes = <String, dynamic>{};
    now.forEach((key, value) {
      final before = _initial[key];
      final same = value is List
          ? listEquals(value.cast<String>(), (before as List).cast<String>())
          : value == before;
      if (!same) changes[key] = value;
    });
    return changes;
  }

  bool get _hasChanges => _collectChanges().isNotEmpty || _newAvatar != null;

  String? _validate() {
    final name = _name.text.trim();
    final username = _username.text.trim().toLowerCase();
    final podcast = _podcast.text.trim();

    if (name.isEmpty) return 'Nama tidak boleh kosong.';
    if (name.length > 50) return 'Nama maksimal 50 karakter.';
    // Akun lama boleh punya username dengan format berbeda; cek hanya jika diubah.
    if (username != _initial['username'] &&
        !RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(username)) {
      return 'Nama pengguna 3–30 karakter: huruf, angka, titik, atau garis bawah.';
    }
    if (podcast.isNotEmpty && !podcast.startsWith('http')) {
      return 'Tautan podcast harus diawali http:// atau https://';
    }
    return null;
  }

  // ───────────────────────── Aksi ─────────────────────────

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAvatar() async {
    if (_saving) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ??
          lookupMimeType(picked.name, headerBytes: bytes) ??
          'image/jpeg';

      if (!mounted) return;
      setState(() {
        _newAvatar = UploadFile(
          name: picked.name.isEmpty ? 'avatar.jpg' : picked.name,
          bytes: bytes,
          mimeType: mime,
        );
      });
    } catch (e) {
      if (!mounted) return;
      _toast('Gagal memilih foto: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      _toast(error);
      return;
    }

    final changes = _collectChanges();
    if (changes.isEmpty && _newAvatar == null) return;

    setState(() => _saving = true);

    try {
      Map<String, dynamic>? avatarUser;
      Map<String, dynamic>? fromServer;

      // 1) Unggah foto profil baru (kalau ada).
      if (_newAvatar != null) {
        avatarUser = await ApiService.uploadAvatar(
          token: widget.token,
          file: _newAvatar!,
        );
      }

      // 2) Simpan field teks yang berubah (nama, bio, dst.).
      if (changes.isNotEmpty && widget.onSave != null) {
        fromServer = await widget.onSave!(changes);
      }

      if (!mounted) return;

      Navigator.of(context).pop(<String, dynamic>{
        ...widget.user,
        ...changes,
        ...?avatarUser,
        ...?fromServer,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _close() async {
    if (_saving) return;

    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Buang perubahan?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Perubahan yang belum disimpan akan hilang.',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Lanjut mengedit',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Buang',
              style: TextStyle(color: Color(0xFFFF3040)),
            ),
          ),
        ],
      ),
    );

    if (discard == true && mounted) Navigator.of(context).pop();
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSave = _hasChanges && !_saving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 64,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, size: 30),
            color: Colors.white,
            onPressed: _close,
          ),
          title: const Text(
            'Edit profil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: canSave ? _save : null,
                      child: Text(
                        'Selesai',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: canSave ? Colors.white : kDisabled,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameRow(),
                  _insetDivider(),
                  _fieldSection(
                    label: 'Nama pengguna',
                    controller: _username,
                    hint: 'nama.pengguna',
                    formatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9._]'),
                      ),
                      LengthLimitingTextInputFormatter(30),
                    ],
                  ),
                  _insetDivider(),
                  _fieldSection(
                    label: 'Bio',
                    controller: _bio,
                    hint: '+ Tulis bio',
                    maxLines: null,
                    formatters: [LengthLimitingTextInputFormatter(150)],
                    keyboardType: TextInputType.multiline,
                  ),
                  _insetDivider(),
                  _buildInterests(),
                  _insetDivider(),
                  _buildLinksRow(),
                  _insetDivider(),
                  _fieldSection(
                    label: 'Podcast',
                    controller: _podcast,
                    hint: '+ Tautan ke podcast Anda',
                    keyboardType: TextInputType.url,
                  ),
                  _fullDivider(),
                  _switchRow(
                    title: 'Tampilkan lencana Instagram',
                    value: _showInstagram,
                    onChanged: (v) => setState(() => _showInstagram = v),
                  ),
                  _fullDivider(),
                  _switchRow(
                    title: 'Tampilkan tayangan terbaru',
                    subtitle:
                        'Ini akan menjadi publik di profil Anda saat Anda mendapatkan 1 rb+ tayangan terbaru.',
                    value: _showViews,
                    onChanged: (v) => setState(() => _showViews = v),
                  ),
                  _fullDivider(),
                  _buildPrivacyRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Bagian-bagian form ─────────────────────────

  Widget _insetDivider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Divider(height: 1, thickness: 1, color: kDivider),
      );

  Widget _fullDivider() =>
      const Divider(height: 1, thickness: 1, color: kDivider);

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _input(
    TextEditingController controller, {
    required String hint,
    int? maxLines = 1,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      inputFormatters: formatters,
      keyboardType: keyboardType,
      cursorColor: Colors.white,
      style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted, fontSize: 17),
        isCollapsed: true,
        border: InputBorder.none,
        counterText: '',
      ),
    );
  }

  Widget _fieldSection({
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLines = 1,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          _input(
            controller,
            hint: hint,
            maxLines: maxLines,
            formatters: formatters,
            keyboardType: keyboardType,
          ),
        ],
      ),
    );
  }

  Widget _buildNameRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Nama'),
                  const SizedBox(height: 6),
                  _input(
                    _name,
                    hint: 'Nama Anda',
                    formatters: [LengthLimitingTextInputFormatter(50)],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _pickAvatar,
            child: _newAvatar != null
                ? ClipOval(
                    child: Image.memory(
                      _newAvatar!.bytes,
                      width: 94,
                      height: 94,
                      fit: BoxFit.cover,
                    ),
                  )
                : UserAvatar(url: _avatarUrl, size: 94),
          ),
        ],
      ),
    );
  }

  Widget _buildInterests() {
    return InkWell(
      onTap: _editInterests,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Minat'),
            const SizedBox(height: 8),
            if (_interests.isEmpty)
              const Text(
                '+ Tambahkan minat',
                style: TextStyle(color: kMuted, fontSize: 17),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _interests)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kCardBorder),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinksRow() {
    return InkWell(
      onTap: _editLinks,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
        child: Row(
          children: [
            _label('Tautan'),
            const Spacer(),
            Text(
              '${_links.length}',
              style: const TextStyle(color: kMuted, fontSize: 18),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: kMuted, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(title),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(Colors.black),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFFF4F4F6)
                  : const Color(0xFF3A3A3A),
            ),
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFFF4F4F6)
                  : const Color(0xFF4A4A4A),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRow() {
    return InkWell(
      onTap: _editPrivacy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _label('Privasi profil'),
                const Spacer(),
                Text(
                  _isPrivate ? 'Privat' : 'Publik',
                  style: const TextStyle(color: kMuted, fontSize: 18),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: kMuted,
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text(
                'Jika Anda mengubah ke privat, hanya pengikut yang bisa melihat thread Anda. Balasan Anda akan bisa dilihat oleh pengikut dan profil individu yang Anda balas.',
                style: TextStyle(color: kMuted, fontSize: 16, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Bottom sheet ─────────────────────────

  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );

  Widget _sheetHandle() => Center(
        child: Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white38,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  Future<void> _editInterests() {
    return _openListEditor(
      title: 'Minat',
      hint: 'Contoh: Desain, Musik, Teknologi',
      initial: _interests,
      max: 5,
      validate: (v) => v.length > 30 ? 'Maksimal 30 karakter.' : null,
      onDone: (items) => setState(() => _interests = items),
    );
  }

  Future<void> _editLinks() {
    return _openListEditor(
      title: 'Tautan',
      hint: 'https://',
      initial: _links,
      max: 5,
      keyboardType: TextInputType.url,
      validate: (v) {
        final uri = Uri.tryParse(v);
        final ok = uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.contains('.');
        return ok ? null : 'Masukkan tautan yang valid (https://…).';
      },
      onDone: (items) => setState(() => _links = items),
    );
  }

  Future<void> _openListEditor({
    required String title,
    required String hint,
    required List<String> initial,
    required int max,
    required String? Function(String value) validate,
    required void Function(List<String> items) onDone,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final items = List<String>.of(initial);
    final controller = TextEditingController();
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kSheet,
      shape: _sheetShape,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void add() {
            final value = controller.text.trim();
            if (value.isEmpty) return;

            final problem = validate(value);
            if (problem != null) {
              setSheet(() => error = problem);
              return;
            }
            if (items.contains(value)) {
              setSheet(() => error = 'Sudah ditambahkan.');
              return;
            }
            if (items.length >= max) {
              setSheet(() => error = 'Maksimal $max item.');
              return;
            }
            setSheet(() {
              items.add(value);
              controller.clear();
              error = null;
            });
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            items[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: kMuted,
                            size: 20,
                          ),
                          onPressed: () => setSheet(() => items.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF303030),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          cursorColor: Colors.white,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => add(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: const TextStyle(color: kMuted),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tambah',
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        onPressed: add,
                      ),
                    ],
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    onDone(items);
  }

  Future<void> _editPrivacy() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrivacyProfilePage(isPrivate: _isPrivate),
      ),
    );

    if (result != null && mounted) setState(() => _isPrivate = result);
  }
}