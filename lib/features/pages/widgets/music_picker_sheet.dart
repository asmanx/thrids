import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../../../services/api_service.dart';

/// Satu lagu dari backend (/api/music). Dikembalikan saat user memilih lagu.
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String cover;
  final int duration;
  final bool explicit;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.cover,
    required this.duration,
    required this.explicit,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: '${json['id']}',
      title: (json['title'] as String?) ?? '',
      artist: (json['artist'] as String?) ?? '',
      cover: (json['cover'] as String?) ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      explicit: json['explicit'] == true,
    );
  }

  /// Contoh: "4:43"
  String get durationText {
    final minutes = duration ~/ 60;
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Teks yang disimpan sebagai judul musik di postingan.
  String get displayTitle => artist.isEmpty ? title : '$title · $artist';
}

/// Pemilih musik online (bergaya Instagram/Threads): daftar "Sedang tren",
/// pencarian, dan preview 30 detik. Mengembalikan [MusicTrack] yang dipilih.
///
///   final track = await MusicPickerSheet.show(context);
class MusicPickerSheet extends StatefulWidget {
  const MusicPickerSheet({super.key});

  static Future<MusicTrack?> show(BuildContext context) {
    return showModalBottomSheet<MusicTrack>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const MusicPickerSheet(),
    );
  }

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  static const muted = Color(0xFF858585);
  static const searchFill = Color(0xFF262626);

  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _debounce;
  int _requestId = 0;

  List<MusicTrack> _tracks = [];
  bool _loading = true;
  String? _error;
  String _heading = 'Sedang tren';

  String? _playingId; // lagu yang sedang diputar
  String? _loadingId; // lagu yang preview-nya sedang dimuat

  @override
  void initState() {
    super.initState();

    _playerSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;

      if (state.processingState == ProcessingState.completed) {
        setState(() => _playingId = null);
      }
    });

    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _playerSubscription?.cancel();
    _player.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(value));
  }

  Future<void> _load(String query) async {
    final text = query.trim();
    final requestId = ++_requestId;

    await _stopPreview();

    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _heading = text.isEmpty ? 'Sedang tren' : 'Hasil pencarian';
    });

    try {
      final path = text.isEmpty
          ? '/api/music/trending'
          : '/api/music/search?q=${Uri.encodeQueryComponent(text)}';

      final response = await http.get(Uri.parse(ApiService.resolveUrl(path)));

      if (response.statusCode != 200) {
        throw Exception('Musik ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = (data['tracks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MusicTrack.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat musik. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  Future<void> _stopPreview() async {
    _playingId = null;
    _loadingId = null;

    try {
      await _player.stop();
    } catch (_) {
      // Tidak ada yang perlu dihentikan.
    }
  }

  Future<void> _togglePreview(MusicTrack track) async {
    // Tekan lagi lagu yang sedang diputar -> berhenti.
    if (_playingId == track.id || _loadingId == track.id) {
      await _stopPreview();
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _playingId = null;
      _loadingId = track.id;
    });

    try {
      // Backend mengarahkan ke link preview Deezer yang selalu segar.
      await _player.setUrl(
        ApiService.resolveUrl('/api/music/preview/${track.id}'),
      );

      if (!mounted || _loadingId != track.id) return;

      setState(() {
        _loadingId = null;
        _playingId = track.id;
      });

      await _player.play();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingId = null;
        _playingId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview musik tidak bisa diputar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchField(),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  _heading,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 4),
          const Text(
            'Musik',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        decoration: InputDecoration(
          hintText: 'Cari Musik',
          hintStyle: const TextStyle(color: muted, fontSize: 17),
          prefixIcon: const Icon(Icons.search, color: muted),
          filled: true,
          fillColor: searchFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, height: 1.4),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _load(_searchController.text),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return const Center(
        child: Text('Musik tidak ditemukan.', style: TextStyle(color: muted)),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _tracks.length,
      itemBuilder: (context, index) => _buildTile(_tracks[index]),
    );
  }

  Widget _buildCover(MusicTrack track) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        height: 54,
        child: track.cover.isEmpty
            ? Container(
                color: searchFill,
                child: const Icon(Icons.music_note, color: muted),
              )
            : Image.network(
                track.cover,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: searchFill,
                  child: const Icon(Icons.music_note, color: muted),
                ),
              ),
      ),
    );
  }

  Widget _buildTile(MusicTrack track) {
    final playing = _playingId == track.id;
    final loading = _loadingId == track.id;

    return InkWell(
      // Pilih lagu -> kembali ke halaman buat postingan.
      onTap: () => Navigator.pop(context, track),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildCover(track),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (track.explicit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A4A4A),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.duration > 0
                        ? '${track.artist} · ${track.durationText}'
                        : track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _togglePreview(track),
              customBorder: const CircleBorder(),
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFF262626),
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}