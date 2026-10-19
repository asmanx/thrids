import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../services/api_service.dart';
import 'widgets/giphy_picker_sheet.dart';
import 'widgets/location_picker_sheet.dart';
import 'widgets/music_picker_sheet.dart';
import 'widgets/dashed_bubble.dart';
import 'widgets/post_options_sheet.dart';
import 'widgets/quote_post_picker_sheet.dart';
import 'widgets/user_avatar.dart';

/// Jenis isi utama postingan (menu titik tiga).
enum PostMode { text, quote, poll }

class CreatePostPage extends StatefulWidget {
  final String token;

  /// Akun yang sedang login (username, display_name, profile_picture).
  final Map<String, dynamic> user;

  /// true: halaman langsung terbuka dalam mode catatan (postingan sementara).
  final bool startAsNote;

  const CreatePostPage({
    super.key,
    required this.token,
    required this.user,
    this.startAsNote = false,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _controller = TextEditingController();
  final List<TextEditingController> _pollControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isPosting = false;

  PostMode _mode = PostMode.text;
  final List<UploadFile> _media = [];
  MusicTrack? _music;
  String? _gifUrl;
  String? _stickerUrl;
  Map<String, dynamic>? _quotedPost;
  PickedLocation? _location;

  /// Postingan sementara (catatan): hilang setelah 24 jam.
  bool _temporary = false;
  final TextEditingController _noteController = TextEditingController();

  /// Opsi postingan: siapa yang bisa membalas, tinjau balasan.
  PostOptions _options = const PostOptions();

  String get _username => (widget.user['username'] ?? '').toString();
  /// Sama seperti halaman profil: avatar_url (terbaru) lebih dulu, lalu
  /// profile_picture. Kosong = avatar bawaan.
  String? get _avatarUrl {
    final v =
        (widget.user['avatar_url'] ?? widget.user['profile_picture'] ?? '')
            .toString();
    return v.isEmpty ? null : v;
  }

  static const background = Color(0xFF101010);
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);
  static const surface = Color(0xFF181818);

  static const int _maxMedia = 4;
  static const int _maxMediaBytes = 50 * 1024 * 1024;
  static const Set<String> _allowedMedia = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'video/webm',
  };

  @override
  void initState() {
    super.initState();
    _temporary = widget.startAsNote;
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    for (final controller in _pollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // State helper
  // ---------------------------------------------------------------------------

  bool get _hasAttachment =>
      _media.isNotEmpty ||
      _gifUrl != null ||
      _stickerUrl != null ||
      _music != null;

  List<String> get _pollValues => _pollControllers
      .map((controller) => controller.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();

  bool get _canPost {
    if (_isPosting) return false;

    if (_temporary) return _noteController.text.trim().isNotEmpty;

    if (_mode == PostMode.poll) return _pollValues.length >= 2;

    return _controller.text.trim().isNotEmpty ||
        _hasAttachment ||
        _quotedPost != null;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _blockedByPoll() {
    if (_mode != PostMode.poll) return false;

    _showMessage(
      'Polling tidak bisa digabung dengan foto, video, GIF, stiker, atau musik.',
    );
    return true;
  }

  void _resetPoll() {
    while (_pollControllers.length > 2) {
      _pollControllers.removeLast().dispose();
    }

    for (final controller in _pollControllers) {
      controller.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Lampiran: foto/video, GIF, stiker, musik
  // ---------------------------------------------------------------------------

  Future<void> _pickMedia() async {
    if (_blockedByPoll()) return;

    final remaining = _maxMedia - _media.length;

    if (remaining <= 0) {
      _showMessage('Maksimal $_maxMedia foto/video per postingan.');
      return;
    }

    try {
      final picker = ImagePicker();
      List<XFile> picked;

      // pickMultipleMedia mewajibkan limit > 1, jadi sisa 1 pakai pickMedia.
      if (remaining == 1) {
        final single = await picker.pickMedia();
        picked = single == null ? [] : [single];
      } else {
        picked = await picker.pickMultipleMedia(limit: remaining);
      }

      final added = <UploadFile>[];

      for (final file in picked.take(remaining)) {
        final mime =
            file.mimeType ?? lookupMimeType(file.name) ?? lookupMimeType(file.path);

        if (mime == null || !_allowedMedia.contains(mime)) {
          _showMessage('Format file "${file.name}" tidak didukung.');
          continue;
        }

        final bytes = await file.readAsBytes();

        if (bytes.length > _maxMediaBytes) {
          _showMessage('"${file.name}" lebih dari 50 MB.');
          continue;
        }

        added.add(UploadFile(name: file.name, bytes: bytes, mimeType: mime));
      }

      if (!mounted || added.isEmpty) return;

      setState(() {
        _media.addAll(added);
      });
    } catch (_) {
      _showMessage('Gagal memilih foto/video.');
    }
  }

  Future<void> _pickGiphy({required bool sticker}) async {
    if (_blockedByPoll()) return;

    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => GiphyPickerSheet(stickers: sticker),
    );

    if (url == null || !mounted) return;

    setState(() {
      if (sticker) {
        _stickerUrl = url;
        _gifUrl = null;
      } else {
        _gifUrl = url;
        _stickerUrl = null;
      }
    });
  }

  Future<void> _pickMusic() async {
    if (_blockedByPoll()) return;

    // Musik online (Deezer lewat backend), bukan lagi dari penyimpanan lokal.
    final track = await MusicPickerSheet.show(context);

    if (track == null || !mounted) return;

    setState(() {
      _music = track;
    });
  }

  // ---------------------------------------------------------------------------
  // Menu titik tiga: Teks, Kutipan, Polling, Lokasi
  // ---------------------------------------------------------------------------

  Future<void> _handleMenuAction(String action) async {
    if (!mounted) return;

    switch (action) {
      case 'text':
        setState(() {
          _mode = PostMode.text;
          _quotedPost = null;
          _resetPoll();
        });
        break;
      case 'quote':
        await _pickQuote();
        break;
      case 'poll':
        _startPoll();
        break;
      case 'location':
        await _pickLocation();
        break;
    }
  }

  PopupMenuItem<String> _menuItem(String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          Icon(icon, color: Colors.white, size: 26),
        ],
      ),
    );
  }

  /// Titik tiga di sebelah kanan ikon musik: Teks, Kutipan, Polling, Lokasi.
  Widget _moreMenuButton() {
    return PopupMenuButton<String>(
      tooltip: 'Lainnya',
      onSelected: _handleMenuAction,
      color: const Color(0xFF1E1E1E),
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(minWidth: 230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (_) => [
        _menuItem('text', 'Teks', Icons.article_outlined),
        _menuItem('quote', 'Kutipan', Icons.format_quote_rounded),
        _menuItem('poll', 'Polling', Icons.align_horizontal_left_rounded),
        _menuItem('location', 'Lokasi', Icons.location_on_outlined),
      ],
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: (_mode != PostMode.text || _location != null)
                ? Colors.white
                : muted,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.more_horiz,
          size: 18,
          color: (_mode != PostMode.text || _location != null)
              ? Colors.white
              : muted,
        ),
      ),
    );
  }

  Future<void> _pickQuote() async {
    final post = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const QuotePostPickerSheet(),
    );

    if (post == null || !mounted) return;

    setState(() {
      _quotedPost = post;
      _mode = PostMode.quote;
      _resetPoll();
    });
  }

  void _startPoll() {
    if (_hasAttachment) {
      _showMessage(
        'Hapus foto, video, GIF, stiker, atau musik dulu. '
        'Polling tidak bisa digabung dengan lampiran.',
      );
      return;
    }

    setState(() {
      _mode = PostMode.poll;
      _quotedPost = null;
    });
  }

  Future<void> _pickLocation() async {
    final place = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const LocationPickerSheet(),
    );

    if (place == null || !mounted) return;

    setState(() {
      _location = place;
    });
  }

  void _addPollOption() {
    if (_pollControllers.length >= 4) return;

    setState(() {
      _pollControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    if (_pollControllers.length <= 2) return;

    setState(() {
      _pollControllers.removeAt(index).dispose();
    });
  }

  // ---------------------------------------------------------------------------
  // Kirim postingan
  // ---------------------------------------------------------------------------

  Future<void> _submitPost() async {
    if (!_canPost) return;

    setState(() {
      _isPosting = true;
    });

    try {
      Object? quoteId;

      if (_mode == PostMode.quote && _quotedPost != null) {
        quoteId = _quotedPost!['id'];
      }

      if (_temporary) {
        // Postingan sementara: hanya teks, hilang setelah 24 jam.
        await ApiService.createPost(
          token: widget.token,
          content: _noteController.text.trim(),
          isTemporary: true,
          replyAudience: _options.replyAudience,
          approveReplies: _options.approveReplies,
        );
      } else {
        await ApiService.createPost(
          token: widget.token,
          content: _controller.text.trim(),
          media: _media,
          musicTitle: _music?.displayTitle,
          musicTrackId: _music?.id,
          musicCover: _music?.cover,
          gifUrl: _gifUrl,
          stickerUrl: _stickerUrl,
          pollOptions: _mode == PostMode.poll ? _pollValues : null,
          quotePostId: quoteId,
          locationName: _location?.name,
          latitude: _location?.lat,
          longitude: _location?.lng,
          replyAudience: _options.replyAudience,
          approveReplies: _options.approveReplies,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Tampilan
  // ---------------------------------------------------------------------------

  Future<void> _openPostOptions() async {
    FocusScope.of(context).unfocus();

    final result = await PostOptionsSheet.show(context, _options);

    if (result == null || !mounted) return;

    setState(() => _options = result);
  }

  void _clearAll() {
    setState(() {
      _controller.clear();
      _noteController.clear();
      _media.clear();
      _music = null;
      _gifUrl = null;
      _stickerUrl = null;
      _quotedPost = null;
      _location = null;
      _mode = PostMode.text;
      _resetPoll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _canPost;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Tutup',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close, size: 28),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _temporary ? 'Postingan sementara baru' : 'Utas baru',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (_temporary)
              const Text(
                'Mengarsipkan setelah 24 jam',
                style: TextStyle(color: muted, fontSize: 14),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Draf',
            onPressed: () => _showMessage('Draf belum tersedia.'),
            icon: const Icon(Icons.description_outlined, size: 28),
          ),
          PopupMenuButton<String>(
            tooltip: 'Lainnya',
            color: const Color(0xFF1E1E1E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (_) => _clearAll(),
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'clear',
                child: Text(
                  'Kosongkan utas',
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.more_horiz, size: 20),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: separator),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _temporary ? _buildTemporaryBody() : _buildThreadBody(),
              ),
            ),
            _buildBottomBar(canPost),
          ],
        ),
      ),
    );
  }

  Widget _accountAvatar(double size) =>
      UserAvatar(url: _avatarUrl, size: size);

  /// Mode utas biasa.
  Widget _buildThreadBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _accountAvatar(48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: muted),
                      const Expanded(
                        child: Text(
                          'Komunitas atau topik',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: null,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: _mode == PostMode.poll
                          ? 'Tanyakan sesuatu...'
                          : 'Apa yang baru?',
                      hintStyle: const TextStyle(color: muted, fontSize: 17),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.only(top: 4),
                      counterText: '',
                    ),
                  ),
                  if (_media.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildMediaPreview(),
                  ],
                  if (_gifUrl != null) ...[
                    const SizedBox(height: 8),
                    _buildImagePreview(_gifUrl!,
                        height: 180,
                        clip: true,
                        onRemove: () => setState(() => _gifUrl = null)),
                  ],
                  if (_stickerUrl != null) ...[
                    const SizedBox(height: 8),
                    _buildImagePreview(_stickerUrl!,
                        height: 120,
                        clip: false,
                        onRemove: () => setState(() => _stickerUrl = null)),
                  ],
                  if (_music != null) ...[
                    const SizedBox(height: 8),
                    _buildChip(
                      icon: Icons.music_note,
                      label: _music!.displayTitle,
                      onRemove: () => setState(() => _music = null),
                    ),
                  ],
                  if (_mode == PostMode.poll) _buildPoll(),
                  if (_mode == PostMode.quote && _quotedPost != null)
                    _buildQuoteCard(),
                  if (_location != null) ...[
                    const SizedBox(height: 8),
                    _buildChip(
                      icon: Icons.location_on,
                      label: _location!.name,
                      onRemove: () => setState(() => _location = null),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _toolIcon(
                        Icons.image_outlined,
                        'Foto atau video',
                        _pickMedia,
                        active: _media.isNotEmpty,
                      ),
                      const SizedBox(width: 22),
                      _toolIcon(
                        Icons.gif_box_outlined,
                        'GIF',
                        () => _pickGiphy(sticker: false),
                        active: _gifUrl != null,
                      ),
                      const SizedBox(width: 22),
                      _toolIcon(
                        Icons.sentiment_satisfied_alt_outlined,
                        'Stiker',
                        () => _pickGiphy(sticker: true),
                        active: _stickerUrl != null,
                      ),
                      const SizedBox(width: 22),
                      _toolIcon(
                        Icons.music_note_outlined,
                        'Musik',
                        _pickMusic,
                        active: _music != null,
                      ),
                      const SizedBox(width: 22),
                      _moreMenuButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Baris "Tambahkan ke utas" (tampilan saja, utas berantai belum ada).
        InkWell(
          onTap: () => _showMessage('Utas berantai belum tersedia.'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Opacity(opacity: 0.45, child: _accountAvatar(24)),
                const SizedBox(width: 36),
                const Text(
                  'Tambahkan ke utas',
                  style: TextStyle(color: Color(0xFF5E5E5E), fontSize: 17),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mode postingan sementara (catatan).
  Widget _buildTemporaryBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accountAvatar(48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              DashedBubble(
                child: TextField(
                  controller: _noteController,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 100,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Bagikan pemikiran...',
                    hintStyle: TextStyle(color: muted, fontSize: 18),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTempToggle() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _temporary = !_temporary);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 124,
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _temporary ? Colors.white : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _temporary ? Colors.white : const Color(0xFF3A3A3A),
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              _temporary ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _temporary ? Colors.black : background,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sentiment_satisfied_alt_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool canPost) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: separator),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _temporary
                    ? const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: muted, size: 26),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Balasan muncul di postingan',
                              style: TextStyle(color: muted, fontSize: 15),
                            ),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: _openPostOptions,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.tune, color: muted, size: 26),
                              SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Opsi postingan',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              _buildTempToggle(),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: canPost ? _submitPost : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF303030),
                  disabledForegroundColor: Colors.black54,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Posting',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolIcon(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool active = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 22,
      icon: Icon(
        icon,
        size: 28,
        color: active ? Colors.white : muted,
      ),
    );
  }

  Widget _removeBadge(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = _media[index];
          final isVideo = file.mimeType.startsWith('video/');

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 130,
                  height: 170,
                  color: const Color(0xFF1C1C1C),
                  child: isVideo
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 44,
                              ),
                              SizedBox(height: 6),
                              Text('Video', style: TextStyle(color: muted)),
                            ],
                          ),
                        )
                      : Image.memory(file.bytes, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _removeBadge(() => setState(() => _media.removeAt(index))),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(
    String url, {
    required double height,
    required bool clip,
    required VoidCallback onRemove,
  }) {
    final image = Image.network(
      url,
      height: height,
      fit: clip ? BoxFit.cover : BoxFit.contain,
      errorBuilder: (context, error, stack) => Container(
        height: height,
        width: height,
        color: const Color(0xFF1C1C1C),
        child: const Icon(Icons.broken_image_outlined, color: muted),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          clip
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: image)
              : image,
          Positioned(top: 6, right: 6, child: _removeBadge(onRemove)),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          border: Border.all(color: separator),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 18, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard() {
    final post = _quotedPost!;
    final content = (post['content'] as String?)?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: separator),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Icon(Icons.format_quote, color: muted, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['username'] as String? ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content.isEmpty ? '[Foto/video]' : content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, height: 1.3),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() {
              _quotedPost = null;
              _mode = PostMode.text;
            }),
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 20, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoll() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: separator),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Polling',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _mode = PostMode.text;
                  _resetPoll();
                }),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 20, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _pollControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollControllers[i],
                      maxLength: 80,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Opsi ${i + 1}',
                        hintStyle: const TextStyle(color: muted),
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF1C1C1C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: separator),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: separator),
                        ),
                      ),
                    ),
                  ),
                  if (_pollControllers.length > 2)
                    IconButton(
                      tooltip: 'Hapus opsi',
                      onPressed: () => _removePollOption(i),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: muted,
                      ),
                    ),
                ],
              ),
            ),
          if (_pollControllers.length < 4)
            TextButton.icon(
              onPressed: _addPollOption,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah opsi'),
            ),
        ],
      ),
    );
  }
}