import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../services/api_service.dart';
import '../../services/message_media_service.dart';
import 'group_info_page.dart';
import 'user_profile_page.dart';
import 'widgets/chat_utils.dart';
import 'widgets/giphy_picker_sheet.dart';
import 'widgets/group_avatar.dart';
import 'widgets/linkified_text.dart';
import 'widgets/user_avatar.dart';

/// Membuka obrolan dengan [username] (membuat percakapan bila belum ada).
/// Dipakai oleh tombol "Kirim Pesan" di profil.
Future<void> openChatWithUser(
  BuildContext context, {
  required String token,
  required Map<String, dynamic> currentUser,
  required String username,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  try {
    final conversation = await ApiService.openConversation(
      token: token,
      username: username,
    );

    final user = conversation['user'] is Map
        ? Map<String, dynamic>.from(conversation['user'] as Map)
        : <String, dynamic>{'username': username};

    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          token: token,
          currentUser: currentUser,
          conversationId: conversation['id'],
          user: user,
        ),
      ),
    );
  } catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
  }
}

int _idOf(Map<String, dynamic> message) =>
    int.tryParse('${message['id']}') ?? 0;

// ════════════════════════════════════════════════════════════════════
//  OBROLAN
// ════════════════════════════════════════════════════════════════════

/// Isi percakapan dengan satu orang. Pesan baru diambil tiap beberapa detik.
class ChatPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;
  final Object conversationId;

  /// Data awal lawan bicara (username, display_name, profile_picture).
  final Map<String, dynamic> user;

  const ChatPage({
    super.key,
    required this.token,
    required this.currentUser,
    required this.conversationId,
    required this.user,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kField = Color(0xFF1C1C1C);
  static const kMine = Color(0xFF4A4A4C);
  static const kTheirs = Color(0xFF262626);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _messages = [];

  bool _loading = true;
  bool _polling = false;
  bool _menuOpen = false;
  bool _hasText = false;
  String? _error;

  int _tempId = -1;
  Timer? _timer;

  Map<String, dynamic> get _other {
    final detail = _detail?['other'];

    return {
      ...widget.user,
      if (detail is Map) ...Map<String, dynamic>.from(detail),
    };
  }

  /// True untuk obrolan grup (dari data awal di daftar pesan atau dari detail).
  bool get _isGroup =>
      widget.user['is_group'] == true || _detail?['is_group'] == true;

  String get _groupName {
    final fromDetail = _detail?['name'];
    if (fromDetail is String && fromDetail.isNotEmpty) return fromDetail;

    return '${widget.user['username'] ?? 'Grup'}';
  }

  int get _memberCount {
    final members = _detail?['members'];
    if (members is List) return members.length;

    return int.tryParse('${widget.user['member_count'] ?? 0}') ?? 0;
  }

  /// Foto dua anggota lain, untuk avatar grup.
  List<String?> get _groupPictures {
    final members = _detail?['members'];
    final myName = '${widget.currentUser['username'] ?? ''}';

    if (members is List) {
      return [
        for (final m in members)
          if (m is Map && '${m['username']}' != myName)
            pictureOf(m['profile_picture']),
      ].take(2).toList();
    }

    final raw = widget.user['preview_pictures'];

    if (raw is List) return [for (final p in raw) pictureOf(p)].take(2).toList();

    return const [];
  }

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });

    _init();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await ApiService.getConversation(
        token: widget.token,
        conversationId: widget.conversationId,
      );

      final messages = await ApiService.getMessages(
        token: widget.token,
        conversationId: widget.conversationId,
      );

      if (!mounted) return;

      setState(() {
        _detail = detail;
        _messages = messages;
        _loading = false;
      });

      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _lastServerId() {
    var last = 0;

    for (final message in _messages) {
      final id = _idOf(message);
      if (id > last) last = id;
    }

    return last;
  }

  Future<void> _poll() async {
    if (_loading || _error != null || _polling) return;

    _polling = true;

    try {
      final fresh = await ApiService.getMessages(
        token: widget.token,
        conversationId: widget.conversationId,
        after: _lastServerId(),
      );

      if (!mounted || fresh.isEmpty) return;

      final known = _messages.map((m) => '${m['id']}').toSet();
      final added = fresh.where((m) => !known.contains('${m['id']}')).toList();

      if (added.isEmpty) return;

      final nearEnd = !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 160;

      setState(() => _messages = [..._messages, ...added]);

      if (nearEnd) _scrollToEnd(animate: true);
    } catch (_) {
      // Gagal sesaat (mis. sinyal): coba lagi pada putaran berikutnya.
    } finally {
      _polling = false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    final tempId = _tempId--;

    final temp = <String, dynamic>{
      'id': tempId,
      'mine': true,
      'type': 'text',
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'pending': true,
    };

    setState(() {
      _messages = [..._messages, temp];
      _controller.clear();
      _menuOpen = false;
    });

    _scrollToEnd(animate: true);

    try {
      final sent = await ApiService.sendMessage(
        token: widget.token,
        conversationId: widget.conversationId,
        content: text,
      );

      if (!mounted) return;

      setState(() {
        final alreadyThere = _messages.any((m) => '${m['id']}' == '${sent['id']}');

        _messages = [
          for (final m in _messages)
            if (m['id'] != tempId)
              m
            else if (!alreadyThere)
              sent,
        ];

        // Setelah membalas, percakapan tidak lagi berstatus permintaan.
        if (_detail != null) _detail!['is_request'] = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where((m) => m['id'] != tempId).toList();
        if (_controller.text.isEmpty) _controller.text = text;
      });

      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ───────────────────────── Kirim foto / GIF / stiker ─────────────────────────

  static const _imageTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };
  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _maxPhotosPerSend = 10;

  /// Tampilkan pesan sementara, kirim ke server, lalu ganti dengan pesan asli.
  Future<void> _sendMedia({
    required Map<String, dynamic> temp,
    required Future<Map<String, dynamic>> Function() send,
  }) async {
    final tempId = temp['id'];

    setState(() {
      _messages = [..._messages, temp];
      _menuOpen = false;
    });

    _scrollToEnd(animate: true);

    try {
      final sent = await send();

      if (!mounted) return;

      setState(() {
        final alreadyThere = _messages.any((m) => '${m['id']}' == '${sent['id']}');

        _messages = [
          for (final m in _messages)
            if (m['id'] != tempId)
              m
            else if (!alreadyThere)
              sent,
        ];

        // Setelah membalas, percakapan tidak lagi berstatus permintaan.
        if (_detail != null) _detail!['is_request'] = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where((m) => m['id'] != tempId).toList();
      });

      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<UploadFile?> _toUpload(XFile file) async {
    final mime =
        file.mimeType ?? lookupMimeType(file.name) ?? lookupMimeType(file.path);

    if (mime == null || !_imageTypes.contains(mime)) {
      _toast('Format "${file.name}" tidak didukung (JPG, PNG, WEBP, GIF).');
      return null;
    }

    final bytes = await file.readAsBytes();

    if (bytes.length > _maxImageBytes) {
      _toast('"${file.name}" lebih dari 10 MB.');
      return null;
    }

    return UploadFile(name: file.name, bytes: bytes, mimeType: mime);
  }

  Future<void> _queueImage(UploadFile file) {
    return _sendMedia(
      temp: <String, dynamic>{
        'id': _tempId--,
        'mine': true,
        'type': 'image',
        'content': '',
        'media_url': null,
        'local_bytes': file.bytes, // pratinjau selama diunggah
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'pending': true,
      },
      send: () => MessageMediaService.sendImage(
        token: widget.token,
        conversationId: widget.conversationId,
        file: file,
      ),
    );
  }

  /// Media: pilih satu atau beberapa foto dari galeri.
  Future<void> _pickPhotos() async {
    setState(() => _menuOpen = false);

    List<XFile> picked;

    try {
      picked = await ImagePicker().pickMultiImage(limit: _maxPhotosPerSend);
    } catch (_) {
      _toast('Gagal memilih foto.');
      return;
    }

    if (picked.length > _maxPhotosPerSend) {
      _toast('Maksimal $_maxPhotosPerSend foto sekali kirim.');
    }

    // Dikirim berurutan supaya urutannya di obrolan sama dengan pilihan.
    for (final file in picked.take(_maxPhotosPerSend)) {
      final upload = await _toUpload(file);

      if (upload != null && mounted) await _queueImage(upload);
    }
  }

  /// Kamera: ambil foto lalu langsung kirim.
  Future<void> _takePhoto() async {
    setState(() => _menuOpen = false);

    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (shot == null) return;

      final upload = await _toUpload(shot);

      if (upload != null && mounted) await _queueImage(upload);
    } catch (_) {
      _toast('Kamera tidak tersedia di perangkat ini.');
    }
  }

  /// GIF dan stiker dari Giphy (ada pilihan GIF / Stiker di dalam sheet).
  Future<void> _pickGifSticker() async {
    setState(() => _menuOpen = false);

    final isSticker = ValueNotifier<bool>(false);

    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GifStickerSheet(isSticker: isSticker),
    );

    final sticker = isSticker.value;
    isSticker.dispose();

    if (url == null || !mounted) return;

    await _sendMedia(
      temp: <String, dynamic>{
        'id': _tempId--,
        'mine': true,
        'type': sticker ? 'sticker' : 'gif',
        'content': '',
        'media_url': url,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'pending': true,
      },
      send: () => MessageMediaService.sendGiphy(
        token: widget.token,
        conversationId: widget.conversationId,
        url: url,
        sticker: sticker,
      ),
    );
  }

  // ───────────────────────── Helper ─────────────────────────

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToEnd({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      final end = _scroll.position.maxScrollExtent;

      if (animate) {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _openProfile() {
    openUserProfile(
      context,
      token: widget.token,
      currentUser: widget.currentUser,
      username: '${_other['username']}',
    );
  }

  Future<void> _openInfo() async {
    if (_isGroup) {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => GroupInfoPage(
            token: widget.token,
            currentUser: widget.currentUser,
            conversationId: widget.conversationId,
            name: _groupName,
            muted: _detail?['is_muted'] == true,
          ),
        ),
      );

      if (result == null || !mounted) return;

      // Sudah keluar dari grup: tutup obrolan ini.
      if (result['left'] == true) {
        Navigator.of(context).pop();
        return;
      }

      // Nama dan anggota bisa berubah di halaman info.
      try {
        final detail = await ApiService.getConversation(
          token: widget.token,
          conversationId: widget.conversationId,
        );

        if (mounted) setState(() => _detail = detail);
      } catch (_) {}

      return;
    }

    final muted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChatInfoPage(
          token: widget.token,
          currentUser: widget.currentUser,
          conversationId: widget.conversationId,
          user: _other,
          muted: _detail?['is_muted'] == true,
        ),
      ),
    );

    if (muted != null && mounted && _detail != null) {
      setState(() => _detail!['is_muted'] = muted);
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final other = _other;
    final username = '${other['username']}';
    final displayName = '${other['display_name'] ?? ''}';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: _isGroup ? _buildGroupTitle() : GestureDetector(
          onTap: _openProfile,
          child: Row(
            children: [
              UserAvatar(
                url: pictureOf(other['profile_picture'] ?? other['avatar_url']),
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (displayName.isNotEmpty && displayName != username)
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted, fontSize: 16),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Info',
            onPressed: _openInfo,
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.more_horiz, size: 22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildBody()),
              _buildComposer(),
            ],
          ),
          if (_menuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _menuOpen = false),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 76 + MediaQuery.of(context).padding.bottom,
              child: _buildAttachMenu(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gagal memuat percakapan.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
              TextButton(onPressed: _init, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[
      _isGroup ? _buildGroupHeader() : _buildProfileCard(),
    ];

    DateTime? previous;
    String? lastSenderId;

    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final date = parseChatDate(message['created_at']);

      // Pemisah waktu bila jeda dari pesan sebelumnya >= 30 menit.
      if (date != null &&
          (previous == null || date.difference(previous).inMinutes >= 30)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                chatSeparatorLabel(date),
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      }

      // Nama pengirim (grup) ditampilkan di pesan pertama dari satu pengirim,
      // dan lagi setelah pemisah waktu atau pesan sistem.
      final newBlock = date != null &&
          (previous == null || date.difference(previous).inMinutes >= 30);

      if (date != null) previous = date;

      final senderId = '${message['sender_id']}';
      final showSender = newBlock || senderId != lastSenderId;

      lastSenderId = '${message['type']}' == 'system' ? null : senderId;

      // Pesan terakhir dari satu rangkaian (di 1-lawan-1 diberi avatar lawan).
      final next = i + 1 < _messages.length ? _messages[i + 1] : null;
      final nextDate = next == null ? null : parseChatDate(next['created_at']);

      final endOfRun = next == null ||
          '${next['type']}' == 'system' ||
          '${next['sender_id']}' != senderId ||
          (date != null &&
              nextDate != null &&
              nextDate.difference(date).inMinutes >= 30);

      children.add(
        _buildMessage(message, showSender: showSender, showAvatar: endOfRun),
      );
    }

    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      children: children,
    );
  }

  /// Kartu profil di bagian atas obrolan.
  Widget _buildProfileCard() {
    final other = _other;

    final followers = int.tryParse('${other['followers_count'] ?? 0}') ?? 0;
    final iFollow = other['i_follow'] == true;
    final followsMe = other['follows_me'] == true;
    final mutualCount = int.tryParse('${other['mutual_count'] ?? 0}') ?? 0;
    final mutualFirst = '${other['mutual_first'] ?? ''}';
    final displayName = '${other['display_name'] ?? ''}';
    final username = '${other['username']}';

    String? relation;
    if (iFollow && followsMe) {
      relation = 'Anda saling mengikuti di Thrids';
    } else if (iFollow) {
      relation = 'Anda mengikuti akun ini di Thrids';
    } else if (followsMe) {
      relation = 'Mengikuti Anda di Thrids';
    }

    String? mutual;
    if (mutualCount > 0 && mutualFirst.isNotEmpty) {
      mutual = mutualCount > 1
          ? 'Diikuti oleh $mutualFirst dan ${mutualCount - 1} lainnya di Thrids'
          : 'Diikuti oleh $mutualFirst di Thrids';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Column(
        children: [
          UserAvatar(
            url: pictureOf(other['profile_picture'] ?? other['avatar_url']),
            size: 96,
          ),
          const SizedBox(height: 18),
          Text(
            username,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (displayName.isNotEmpty && displayName != username) ...[
            const SizedBox(height: 4),
            Text(
              displayName,
              style: const TextStyle(color: kMuted, fontSize: 18),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '$followers pengikut',
            style: const TextStyle(color: kMuted, fontSize: 17),
          ),
          if (relation != null)
            Text(relation, style: const TextStyle(color: kMuted, fontSize: 17)),
          if (mutual != null)
            Text(
              mutual,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 17),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _openProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF3A3A3A)),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Lihat profil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Judul app bar obrolan grup: avatar, nama, dan jumlah anggota.
  Widget _buildGroupTitle() {
    final count = _memberCount;

    return GestureDetector(
      onTap: _openInfo,
      child: Row(
        children: [
          GroupAvatar(pictures: _groupPictures, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count anggota',
                    maxLines: 1,
                    style: const TextStyle(color: kMuted, fontSize: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu di bagian atas obrolan grup (pengganti kartu profil).
  Widget _buildGroupHeader() {
    final count = _memberCount;

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Column(
        children: [
          GroupAvatar(pictures: _groupPictures, size: 96),
          const SizedBox(height: 18),
          Text(
            _groupName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$count anggota',
              style: const TextStyle(color: kMuted, fontSize: 17),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _openInfo,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF3A3A3A)),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Info grup',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// "asman membuat grup", "budi menambahkan dewi", dst.
  Widget _buildSystemMessage(Map<String, dynamic> message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Center(
        child: Text(
          '${message['content'] ?? ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, fontSize: 14, height: 1.3),
        ),
      ),
    );
  }

  // ───────────────────────── Pesan ─────────────────────────

  Widget _buildMessage(
    Map<String, dynamic> message, {
    bool showSender = true,
    bool showAvatar = false,
  }) {
    if ('${message['type']}' == 'system') return _buildSystemMessage(message);

    final mine = message['mine'] == true;
    final type = '${message['type']}';
    final pending = message['pending'] == true;
    final mediaUrl = '${message['media_url'] ?? ''}';

    Widget content;

    if (type == 'post' && message['post'] is Map) {
      content = _buildPostCard(Map<String, dynamic>.from(message['post'] as Map));
    } else if ((type == 'image' || type == 'gif' || type == 'sticker') &&
        (mediaUrl.isNotEmpty || message['local_bytes'] is Uint8List)) {
      content = _buildMediaMessage(message, type, mediaUrl);
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? kMine : kTheirs,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LinkifiedText(
          text: '${message['content'] ?? ''}',
          style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.3),
          linkColor: const Color(0xFF7CC4FF),
          onTapLink: (url) => openLink(
            context,
            url,
            token: widget.token,
            currentUser: widget.currentUser,
          ),
        ),
      );
    }

    // Grup: pesan orang lain diberi avatar dan nama pengirim.
    if (_isGroup && !mine) {
      final sender = message['sender'] is Map
          ? Map<String, dynamic>.from(message['sender'] as Map)
          : const <String, dynamic>{};
      final senderName = '${sender['username'] ?? ''}';

      return Padding(
        padding: EdgeInsets.only(top: showSender ? 8 : 0, bottom: 2.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 34,
              child: showSender
                  ? UserAvatar(
                      url: pictureOf(sender['profile_picture']),
                      size: 30,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.66,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSender && senderName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 3),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Opacity(opacity: pending ? 0.6 : 1, child: content),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 1-lawan-1: pesan lawan bicara diberi avatar di pesan terakhir tiap
    // rangkaian, seperti di Threads.
    if (!mine) {
      final other = _other;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 38,
              child: showAvatar
                  ? UserAvatar(
                      url: pictureOf(
                        other['profile_picture'] ?? other['avatar_url'],
                      ),
                      size: 30,
                    )
                  : null,
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: Opacity(opacity: pending ? 0.6 : 1, child: content),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Opacity(opacity: pending ? 0.6 : 1, child: content),
        ),
      ),
    );
  }

  /// Foto, GIF, atau stiker. Foto & GIF bisa diketuk untuk dibuka layar penuh.
  Widget _buildMediaMessage(
    Map<String, dynamic> message,
    String type,
    String mediaUrl,
  ) {
    final isSticker = type == 'sticker';
    final width = isSticker ? 140.0 : 230.0;
    final fit = isSticker ? BoxFit.contain : BoxFit.cover;
    final local = message['local_bytes'];
    final url = mediaUrl.isEmpty ? null : ApiService.resolveUrl(mediaUrl);

    final Widget image = local is Uint8List
        ? Image.memory(local, width: width, fit: fit)
        : Image.network(
            url!,
            width: width,
            fit: fit,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : SizedBox(
                    width: width,
                    height: isSticker ? 140 : 180,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kMuted,
                      ),
                    ),
                  ),
            errorBuilder: (_, _, _) => const SizedBox(
              width: 140,
              height: 90,
              child: Icon(Icons.broken_image_outlined, color: kMuted),
            ),
          );

    // Stiker tanpa bingkai (latar transparan).
    final picture = isSticker
        ? image
        : ClipRRect(borderRadius: BorderRadius.circular(20), child: image);

    if (url == null || isSticker) return picture;

    return GestureDetector(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _ImageViewerPage(url: url)),
      ),
      child: picture,
    );
  }

  /// Utas yang dibagikan lewat pesan.
  Widget _buildPostCard(Map<String, dynamic> post) {
    final content = '${post['content'] ?? ''}';

    Widget stat(IconData icon, dynamic count) => Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: const Color(0xFFD6D6D6)),
              const SizedBox(width: 5),
              Text(
                '${count ?? 0}',
                style: const TextStyle(color: Color(0xFFD6D6D6), fontSize: 15),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(url: pictureOf(post['profile_picture']), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${post['username']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              stat(Icons.favorite_border, post['like_count']),
              stat(Icons.chat_bubble_outline, post['comment_count']),
              stat(Icons.repeat, post['repost_count']),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Kolom pesan ─────────────────────────

  Widget _buildComposer() {
    final isRequest = _detail?['is_request'] == true;

    return Container(
      color: kBg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRequest)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Ini permintaan pesan. Membalas akan memindahkannya ke Kotak masuk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _menuOpen = !_menuOpen),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: kField,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _menuOpen ? Icons.close : Icons.add,
                        color: kMuted,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 20, right: 6),
                      decoration: BoxDecoration(
                        color: kField,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 1000,
                              textInputAction: TextInputAction.newline,
                              onTap: () => setState(() => _menuOpen = false),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Kirim pesan...',
                                hintStyle: TextStyle(color: kMuted, fontSize: 18),
                                counterText: '',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          if (_hasText)
                            IconButton(
                              tooltip: 'Kirim',
                              onPressed: _send,
                              icon: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.black,
                                  size: 24,
                                ),
                              ),
                            )
                          else ...[
                            IconButton(
                              tooltip: 'Media',
                              onPressed: _pickPhotos,
                              icon: const Icon(
                                Icons.image_outlined,
                                color: kMuted,
                                size: 28,
                              ),
                            ),
                            IconButton(
                              tooltip: 'GIF dan stiker',
                              onPressed: _pickGifSticker,
                              icon: const Icon(
                                Icons.sticky_note_2_outlined,
                                color: kMuted,
                                size: 28,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menu tombol +: Media, GIF dan stiker, Kamera.
  Widget _buildAttachMenu() {
    Widget item(
      String label,
      IconData icon,
      VoidCallback onTap, {
      bool last = false,
    }) {
      return InkWell(
        onTap: onTap,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFF2E2E2E))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              Icon(icon, color: Colors.white, size: 30),
            ],
          ),
        ),
      );
    }

    return Material(
      color: const Color(0xFF1C1C1C),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item('Media', Icons.image_outlined, _pickPhotos),
          item('GIF dan stiker', Icons.gif_box_outlined, _pickGifSticker),
          item('Kamera', Icons.photo_camera_outlined, _takePhoto, last: true),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  INFO PENGGUNA (tombol ⋯ di obrolan)
// ════════════════════════════════════════════════════════════════════

/// Halaman info lawan bicara. Mengembalikan status senyap lewat `Navigator.pop`.
class ChatInfoPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;
  final Object conversationId;
  final Map<String, dynamic> user;
  final bool muted;

  const ChatInfoPage({
    super.key,
    required this.token,
    required this.currentUser,
    required this.conversationId,
    required this.user,
    required this.muted,
  });

  @override
  State<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  static const kBg = Color(0xFF242424);
  static const kCard = Color(0xFF303030);
  static const kMuted = Color(0xFF858585);
  static const kRed = Color(0xFFFF3040);

  late bool _muted = widget.muted;
  bool _busy = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMute() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await ApiService.muteConversation(
        token: widget.token,
        conversationId: widget.conversationId,
        muted: !_muted,
      );

      if (!mounted) return;

      setState(() => _muted = !_muted);
      _toast(_muted ? 'Percakapan disenyapkan.' : 'Percakapan tidak disenyapkan.');
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_muted);
      },
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Kembali',
                  icon: const Icon(Icons.arrow_back, size: 30),
                  onPressed: () => Navigator.of(context).pop(_muted),
                ),
              ),
              Center(
                child: UserAvatar(url: pictureOf(user['profile_picture']), size: 96),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '${user['username']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _action(
                    Icons.person_outline_rounded,
                    'Lihat profil',
                    () => openUserProfile(
                      context,
                      token: widget.token,
                      currentUser: widget.currentUser,
                      username: '${user['username']}',
                    ),
                  ),
                  const SizedBox(width: 28),
                  _action(
                    _muted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    _muted ? 'Suarakan' : 'Senyapkan',
                    _toggleMute,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _card([
                _row(
                  Icons.image_outlined,
                  'Konten yang dibagikan',
                  () => _toast('Konten yang dibagikan belum tersedia.'),
                  chevron: true,
                ),
              ]),
              const SizedBox(height: 14),
              _card([
                _row(
                  Icons.person_off_outlined,
                  'Batasi',
                  () => _toast('Fitur batasi belum tersedia.'),
                ),
                _row(
                  Icons.block_rounded,
                  'Blokir',
                  () => _toast('Fitur blokir belum tersedia.'),
                  color: kRed,
                ),
                _row(
                  Icons.error_outline_rounded,
                  'Laporkan',
                  () => _toast('Fitur laporkan belum tersedia.'),
                  color: kRed,
                  last: true,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = Colors.white,
    bool chevron = false,
    bool last = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 20, 22, 20),
          decoration: BoxDecoration(
            border: last || chevron
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFF444444))),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (chevron) const Icon(Icons.chevron_right, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PEMILIH GIF / STIKER & PENAMPIL FOTO
// ════════════════════════════════════════════════════════════════════

/// Sheet dengan pilihan "GIF" dan "Stiker" di atas pemilih Giphy.
/// Jenis yang dipilih terakhir dicatat di [isSticker] supaya pemanggil tahu
/// apakah URL yang dikembalikan adalah GIF atau stiker.
class _GifStickerSheet extends StatefulWidget {
  final ValueNotifier<bool> isSticker;

  const _GifStickerSheet({required this.isSticker});

  @override
  State<_GifStickerSheet> createState() => _GifStickerSheetState();
}

class _GifStickerSheetState extends State<_GifStickerSheet> {
  Widget _tab(String label, bool sticker) {
    final selected = widget.isSticker.value == sticker;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => widget.isSticker.value = sticker),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2E2E2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF858585),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stickers = widget.isSticker.value;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [_tab('GIF', false), _tab('Stiker', true)]),
            ),
          ),
          Expanded(
            child: GiphyPickerSheet(key: ValueKey(stickers), stickers: stickers),
          ),
        ],
      ),
    );
  }
}

/// Foto layar penuh: cubit untuk memperbesar, geser untuk menggeser.
class _ImageViewerPage extends StatelessWidget {
  final String url;

  const _ImageViewerPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Tutup',
          icon: const Icon(Icons.close_rounded, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}