import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Penampil foto / video layar penuh.
///
///  - geser kiri-kanan untuk berpindah bila ada beberapa media
///  - foto: cubit untuk zoom, ketuk dua kali untuk memperbesar / mengecilkan
///  - video: otomatis diputar dengan suara, ketuk untuk menampilkan kontrol
///    (putar/jeda, bilah waktu, suara)
///
///   await MediaViewerPage.open(context, index: 1, items: [
///     {'url': 'https://.../a.jpg', 'type': 'image'},
///     {'url': 'https://.../b.mp4', 'type': 'video'},
///   ]);
///
/// [items] harus berisi URL lengkap (pakai `ApiService.resolveUrl`).
class MediaViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  const MediaViewerPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
    int index = 0,
  }) {
    if (items.isEmpty) return Future.value();

    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, _, _) => MediaViewerPage(
          items: items,
          initialIndex: index.clamp(0, items.length - 1),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);

  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            // Saat foto diperbesar, geseran dipakai untuk menggeser foto.
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: total,
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final url = '${item['url'] ?? ''}';

              if ('${item['type']}' == 'video') {
                return _FullVideo(
                  key: ValueKey('video:$i:$url'),
                  url: url,
                  active: i == _index,
                );
              }

              return _ZoomableImage(
                key: ValueKey('image:$i:$url'),
                url: url,
                onZoomChanged: (zoomed) {
                  if (i == _index && zoomed != _zoomed) {
                    setState(() => _zoomed = zoomed);
                  }
                },
              );
            },
          ),
          Positioned(
            top: top + 6,
            left: 6,
            right: 6,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x66000000),
                  ),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                ),
                const Spacer(),
                if (total > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66000000),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_index + 1}/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Foto ─────────────────────────

class _ZoomableImage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({
    super.key,
    required this.url,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();
  Offset _tap = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.02;

    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  /// Ketuk dua kali: perbesar 2,5x di titik ketukan, atau kembali normal.
  void _toggleZoom() {
    if (_zoomed) {
      _controller.value = Matrix4.identity();
      return;
    }

    const s = 2.5;
    final x = -_tap.dx * (s - 1);
    final y = -_tap.dy * (s - 1);

    _controller.value = Matrix4(
      s, 0, 0, 0, //
      0, s, 0, 0, //
      0, 0, 1, 0, //
      x, y, 0, 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _tap = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Color(0xFF858585), size: 56),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Video ─────────────────────────

class _FullVideo extends StatefulWidget {
  final String url;
  final bool active;

  const _FullVideo({super.key, required this.url, required this.active});

  @override
  State<_FullVideo> createState() => _FullVideoState();
}

class _FullVideoState extends State<_FullVideo> {
  late final VideoPlayerController _controller;

  bool _ready = false;
  bool _failed = false;
  bool _showControls = true;
  bool _muted = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true);

    _controller.initialize().then((_) {
      if (!mounted) return;

      setState(() => _ready = true);

      if (widget.active) _controller.play();
      _scheduleHide();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant _FullVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.active != widget.active && _ready) {
      widget.active ? _controller.play() : _controller.pause();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlay() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
    setState(() => _showControls = true);
    _scheduleHide();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
    _scheduleHide();
  }

  String _clock(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined,
            color: Color(0xFF858585), size: 56),
      );
    }

    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final bottom = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio == 0
                  ? 16 / 9
                  : _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => IconButton(
                      onPressed: _togglePlay,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x66000000),
                        fixedSize: const Size(72, 72),
                      ),
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bottom + 18,
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Color(0x66FFFFFF),
                              backgroundColor: Color(0x33FFFFFF),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${_clock(value.position)} / ${_clock(value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _toggleMute,
                                icon: Icon(
                                  _muted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}