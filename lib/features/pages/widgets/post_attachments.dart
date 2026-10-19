import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../services/api_service.dart';
import '../media_viewer_page.dart';

const _muted = Color(0xFF858585);
const _separator = Color(0xFF292929);

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return [];

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

/// Menampilkan semua lampiran sebuah postingan: foto/video, GIF, stiker, musik,
/// polling, kutipan, dan lokasi. Letakkan tepat di bawah teks postingan:
///
///   Text(post['content']),
///   PostAttachments(post: post, token: token),
///
/// [post] adalah satu item dari ApiService.getPosts(). [token] dipakai untuk
/// memberi suara pada polling (boleh null; polling jadi hanya-baca).
class PostAttachments extends StatelessWidget {
  final Map<String, dynamic> post;
  final String? token;

  const PostAttachments({super.key, required this.post, this.token});

  @override
  Widget build(BuildContext context) {
    final media = _asMapList(post['media']);
    final gifUrl = post['gif_url'] as String?;
    final stickerUrl = post['sticker_url'] as String?;
    final musicUrl = post['music_url'] as String?;
    final musicTitle = post['music_title'] as String?;
    final pollOptions = _asMapList(post['poll_options']);
    final locationName = post['location_name'] as String?;
    final quoted = post['quoted_post'] is Map
        ? Map<String, dynamic>.from(post['quoted_post'] as Map)
        : null;

    final children = <Widget>[];

    // Lagu tampil sebagai pil kecil tepat di bawah teks, di atas foto/video.
    if (musicUrl != null) {
      children.add(
        _MusicTile(
          key: ValueKey('music:$musicUrl'),
          url: musicUrl,
          title: musicTitle ?? 'Musik',
        ),
      );
    }

    if (media.isNotEmpty) children.add(_MediaGallery(items: media));

    if (gifUrl != null) {
      children.add(
        GestureDetector(
          onTap: () => MediaViewerPage.open(
            context,
            items: [
              {'url': ApiService.resolveUrl(gifUrl), 'type': 'image'},
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Image.network(
                gifUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    if (stickerUrl != null) {
      children.add(
        Image.network(
          stickerUrl,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      );
    }

    if (pollOptions.isNotEmpty) {
      children.add(
        _PollView(
          postId: post['id'],
          options: pollOptions,
          myVote: post['my_vote'],
          token: token,
        ),
      );
    }

    if (quoted != null) children.add(_QuotedPost(post: quoted));

    if (locationName != null && locationName.isNotEmpty) {
      children.add(
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: _muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Foto / video
// -----------------------------------------------------------------------------

class _MediaGallery extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _MediaGallery({required this.items});

  /// Buka penampil layar penuh di media ke-[index].
  Future<void> _open(BuildContext context, int index) {
    return MediaViewerPage.open(
      context,
      index: index,
      items: [
        for (final m in items)
          {
            'url': ApiService.resolveUrl(m['url'] as String? ?? ''),
            'type': m['type'],
          },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: _MediaTile(item: items.first, onOpen: () => _open(context, 0)),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _MediaTile(
          item: items[index],
          width: 180,
          height: 240,
          onOpen: () => _open(context, index),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final double? width;
  final double? height;
  final Future<void> Function() onOpen;

  const _MediaTile({
    required this.item,
    required this.onOpen,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final url = ApiService.resolveUrl(item['url'] as String? ?? '');
    final isVideo = item['type'] == 'video';

    if (isVideo) {
      return _VideoTile(
        url: url,
        width: width,
        height: height,
        onOpen: onOpen,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: width ?? double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            width: width,
            height: height ?? 160,
            color: const Color(0xFF1C1C1C),
            child: const Icon(Icons.broken_image_outlined, color: _muted),
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;

  /// Dipanggil saat video diketuk (membuka penampil layar penuh).
  final Future<void> Function()? onOpen;

  const _VideoTile({
    required this.url,
    this.width,
    this.height,
    this.onOpen,
  });

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  late final VideoPlayerController _controller;
  final Key _visibilityKey = UniqueKey();

  bool _ready = false;
  bool _failed = false;
  bool _isMuted = true; // otomatis jalan tanpa suara, seperti Threads
  bool _inView = false;
  bool _pausedByUser = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..setLooping(true);

    _controller.initialize().then((_) {
      if (!mounted) return;

      _controller.setVolume(0);
      setState(() => _ready = true);
      _sync();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Putar hanya saat sebagian besar video terlihat di layar.
  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;

    _inView = info.visibleFraction >= 0.6;
    if (!_inView) _pausedByUser = false;

    _sync();
  }

  void _sync() {
    if (!_ready || _failed) return;

    if (_inView && !_pausedByUser) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  Future<void> _openFullScreen() async {
    final open = widget.onOpen;
    if (open == null) return;

    // Video di feed dijeda selama layar penuh terbuka, lalu menyesuaikan lagi.
    _controller.pause();
    await open();

    if (mounted) _sync();
  }

  void _toggle() {
    _pausedByUser = _controller.value.isPlaying;
    _sync();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _controller.setVolume(_isMuted ? 0 : 1);
  }

  Widget _placeholder(Widget child) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 220,
      color: const Color(0xFF1C1C1C),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_failed) {
      content = _placeholder(
        const Icon(Icons.videocam_off_outlined, color: _muted, size: 40),
      );
    } else if (!_ready) {
      content = _placeholder(const CircularProgressIndicator(strokeWidth: 2));
    } else {
      final size = _controller.value.size;

      final player = Stack(
        alignment: Alignment.center,
        fit: StackFit.passthrough,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpen == null ? _toggle : _openFullScreen,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          // Ikon putar hanya muncul bila video dijeda.
          IgnorePointer(
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller,
              builder: (context, value, child) => value.isPlaying
                  ? const SizedBox.shrink()
                  : const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white70,
                      size: 56,
                    ),
            ),
          ),
          // Tombol suara di kanan bawah.
          Positioned(
            right: 10,
            bottom: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMute,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      );

      content = widget.height != null
          ? SizedBox(width: widget.width, height: widget.height, child: player)
          : AspectRatio(
              aspectRatio: _controller.value.aspectRatio == 0
                  ? 16 / 9
                  : _controller.value.aspectRatio,
              child: player,
            );
    }

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibility,
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: content),
    );
  }
}

// -----------------------------------------------------------------------------
// Musik
// -----------------------------------------------------------------------------

/// Satu pemutar musik untuk seluruh aplikasi. Setiap kali sebuah lagu diketuk,
/// sumbernya SELALU dimuat ulang dari URL lagu itu, dan lagu lain berhenti.
/// (Sebelumnya tiap kartu punya pemutar sendiri yang mengingat lagu lama.)
class _MusicPlayback {
  static final AudioPlayer _player = AudioPlayer();
  static bool _ready = false;
  static int _token = 0;

  /// URL lagu yang sedang berbunyi (null = tidak ada).
  static final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  /// URL lagu yang sedang dimuat.
  static final ValueNotifier<String?> loading = ValueNotifier<String?>(null);

  static void _init() {
    if (_ready) return;
    _ready = true;

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.stop();
        playing.value = null;
      }
    });
  }

  static Future<void> stop() async {
    _token++;
    playing.value = null;
    loading.value = null;

    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Mengembalikan false kalau lagu gagal diputar.
  static Future<bool> toggle(String url) async {
    _init();

    // Ketuk lagu yang sedang berbunyi -> berhenti.
    if (playing.value == url) {
      await stop();
      return true;
    }

    final token = ++_token;

    playing.value = null;
    loading.value = url;

    try {
      await _player.stop();
      await _player.setUrl(url); // sumber baru untuk lagu yang diketuk

      if (token != _token) return true; // sudah ada ketukan yang lebih baru

      loading.value = null;
      playing.value = url;

      unawaited(_player.play());
      return true;
    } catch (_) {
      if (token == _token) {
        loading.value = null;
        playing.value = null;
      }
      return false;
    }
  }
}

class _MusicTile extends StatefulWidget {
  final String url;
  final String title;

  const _MusicTile({super.key, required this.url, required this.title});

  @override
  State<_MusicTile> createState() => _MusicTileState();
}

class _MusicTileState extends State<_MusicTile> {
  bool _failed = false;

  String get _fullUrl => ApiService.resolveUrl(widget.url);

  @override
  void dispose() {
    // Kartu keluar dari layar saat sedang berbunyi -> hentikan.
    if (_MusicPlayback.playing.value == _fullUrl ||
        _MusicPlayback.loading.value == _fullUrl) {
      _MusicPlayback.stop();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final ok = await _MusicPlayback.toggle(_fullUrl);

    if (!ok && mounted) setState(() => _failed = true);
  }

  /// "Judul · Artis" -> (Judul, Artis)
  (String, String) _split() {
    final i = widget.title.indexOf(' · ');
    if (i < 0) return (widget.title, '');
    return (widget.title.substring(0, i), widget.title.substring(i + 3));
  }

  @override
  Widget build(BuildContext context) {
    final (title, artist) = _split();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _failed ? null : _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: _MusicPlayback.loading,
            builder: (context, loadingUrl, _) {
              return ValueListenableBuilder<String?>(
                valueListenable: _MusicPlayback.playing,
                builder: (context, playingUrl, _) {
                  final loading = loadingUrl == _fullUrl;
                  final playing = playingUrl == _fullUrl;

                  return Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                    ),
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _failed
                                ? Icons.error_outline
                                : (playing
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded),
                            color: playing ? Colors.white : _muted,
                            size: 22,
                          ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _failed ? 'Musik tidak bisa diputar' : title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!_failed && artist.isNotEmpty)
                    TextSpan(
                      text: '  ·  $artist',
                      style: const TextStyle(color: _muted, fontSize: 16),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Polling
// -----------------------------------------------------------------------------

class _PollView extends StatefulWidget {
  final dynamic postId;
  final List<Map<String, dynamic>> options;
  final dynamic myVote;
  final String? token;

  const _PollView({
    required this.postId,
    required this.options,
    required this.myVote,
    required this.token,
  });

  @override
  State<_PollView> createState() => _PollViewState();
}

class _PollViewState extends State<_PollView> {
  late List<Map<String, dynamic>> _options;
  dynamic _myVote;
  bool _busy = false;
  bool _votedHere = false;

  @override
  void initState() {
    super.initState();
    _options = widget.options;
    _myVote = widget.myVote;
  }

  @override
  void didUpdateWidget(covariant _PollView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Setelah user memilih di sini, pertahankan hasil terbaru dari server
    // meskipun induknya membangun ulang widget ini dengan data lama.
    if (!_votedHere) {
      _options = widget.options;
      _myVote = widget.myVote;
    }
  }

  int _votes(Map<String, dynamic> option) =>
      (option['votes'] as num?)?.toInt() ?? 0;

  int get _total => _options.fold(0, (sum, option) => sum + _votes(option));

  Future<void> _vote(Map<String, dynamic> option) async {
    if (_busy || _myVote != null) return;

    if (widget.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masuk dulu untuk memberikan suara.')),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final result = await ApiService.votePoll(
        token: widget.token!,
        postId: widget.postId,
        optionId: (option['id'] as num).toInt(),
      );

      if (!mounted) return;

      setState(() {
        _options = _asMapList(result['poll_options']);
        _myVote = result['my_vote'];
        _votedHere = true;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voted = _myVote != null;
    final total = _total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildOption(option, voted, total),
          ),
        Text(
          '$total suara',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildOption(Map<String, dynamic> option, bool voted, int total) {
    final text = option['text'] as String? ?? '';

    if (!voted) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _busy ? null : () => _vote(option),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: _separator),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(text),
        ),
      );
    }

    final votes = _votes(option);
    final fraction = total == 0 ? 0.0 : votes / total;
    final mine = option['id'] == _myVote;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFF1C1C1C),
        height: 44,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0).toDouble(),
              child: Container(
                color: mine ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (mine)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle,
                          size: 16, color: Colors.white),
                    ),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: mine ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Kutipan
// -----------------------------------------------------------------------------

class _QuotedPost extends StatelessWidget {
  final Map<String, dynamic> post;

  const _QuotedPost({required this.post});

  @override
  Widget build(BuildContext context) {
    final content = (post['content'] as String?)?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _separator),
        borderRadius: BorderRadius.circular(14),
      ),
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
          if (content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}