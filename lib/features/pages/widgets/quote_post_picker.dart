import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import 'user_avatar.dart';

/// Sheet "Pilih postingan untuk dikutip" dengan tab Tersimpan, Disukai, dan
/// Postingan Anda. Mengembalikan postingan yang dipilih lewat `Navigator.pop`.
///
///   final post = await showModalBottomSheet<Map<String, dynamic>>(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: const Color(0xFF181818),
///     shape: const RoundedRectangleBorder(
///       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
///     ),
///     builder: (_) => QuotePostPickerSheet(token: token, currentUser: user),
///   );
class QuotePostPickerSheet extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;

  const QuotePostPickerSheet({
    super.key,
    required this.token,
    required this.currentUser,
  });

  @override
  State<QuotePostPickerSheet> createState() => _QuotePostPickerSheetState();
}

class _QuotePostPickerSheetState extends State<QuotePostPickerSheet>
    with SingleTickerProviderStateMixin {
  static const kBg = Color(0xFF181818);
  static const kMuted = Color(0xFF858585);
  static const kSeparator = Color(0xFF292929);

  static const List<String> _tabLabels = ['Tersimpan', 'Disukai', 'Postingan Anda'];

  static const List<String> _emptyTexts = [
    'Belum ada postingan tersimpan.',
    'Belum ada postingan yang kamu sukai.',
    'Kamu belum punya postingan.',
  ];

  late final TabController _tabs = TabController(length: 3, vsync: this);

  final List<List<Map<String, dynamic>>?> _data = [null, null, null];
  final List<String?> _errors = [null, null, null];
  final List<bool> _loading = [false, false, false];

  String get _me => '${widget.currentUser['username'] ?? ''}';

  @override
  void initState() {
    super.initState();

    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _ensure(_tabs.index);
    });

    _ensure(0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch(int tab) async {
    switch (tab) {
      case 0:
        return ApiService.getMySavedPosts(token: widget.token);
      case 1:
        return ApiService.getMyLikedPosts(token: widget.token);
      default:
        final posts = await ApiService.getPosts(token: widget.token);
        return posts.where((p) => '${p['username']}' == _me).toList();
    }
  }

  Future<void> _ensure(int tab, {bool force = false}) async {
    if (_loading[tab] || (_data[tab] != null && !force)) return;

    setState(() {
      _loading[tab] = true;
      _errors[tab] = null;
    });

    try {
      final posts = await _fetch(tab);

      if (!mounted) return;

      setState(() {
        _data[tab] = posts;
        _loading[tab] = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading[tab] = false;
        _errors[tab] = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _compact(dynamic value) {
    final n = int.tryParse('${value ?? 0}') ?? 0;

    String trim(double v, String unit) {
      final text = v.toStringAsFixed(1).replaceAll('.', ',');
      return '${text.endsWith(',0') ? text.substring(0, text.length - 2) : text}$unit';
    }

    if (n >= 1000000) return trim(n / 1000000, 'JT');
    if (n >= 1000) return trim(n / 1000, 'RB');

    return '$n';
  }

  String _shortDate(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '';

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  List<String> _imageUrls(Map<String, dynamic> post) {
    final urls = <String>[];

    final media = post['media'];
    if (media is List) {
      for (final item in media) {
        if (item is Map && '${item['type']}' != 'video' && item['url'] != null) {
          urls.add(ApiService.resolveUrl('${item['url']}'));
        }
      }
    }

    for (final key in ['gif_url', 'sticker_url']) {
      final value = '${post[key] ?? ''}';
      if (value.isNotEmpty && value != 'null') urls.add(value);
    }

    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.94;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 30),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Pilih postingan untuk dikutip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF5E5E5E),
            dividerColor: kSeparator,
            labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            tabs: [for (final label in _tabLabels) Tab(text: label)],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [for (var i = 0; i < 3; i++) _buildTab(i)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int tab) {
    final posts = _data[tab];

    if (posts == null) {
      if (_errors[tab] != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errors[tab]!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted, fontSize: 15),
                ),
                TextButton(
                  onPressed: () => _ensure(tab, force: true),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      }

      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _emptyTexts[tab],
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 17),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _ensure(tab, force: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (_, index) => _buildPost(posts[index]),
      ),
    );
  }

  Widget _buildPost(Map<String, dynamic> post) {
    final username = '${post['username'] ?? ''}';
    final content = '${post['content'] ?? ''}';
    final picture = '${post['profile_picture'] ?? ''}';
    final images = _imageUrls(post);

    Widget stat(IconData icon, dynamic count) => Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: const Color(0xFFD6D6D6)),
              const SizedBox(width: 6),
              Text(
                _compact(count),
                style: const TextStyle(color: Color(0xFFD6D6D6), fontSize: 16),
              ),
            ],
          ),
        );

    return InkWell(
      onTap: () => Navigator.of(context).pop(post),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kSeparator)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              url: picture.isEmpty ? null : ApiService.resolveUrl(picture),
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _shortDate(post['created_at']),
                        style: const TextStyle(color: kMuted, fontSize: 17),
                      ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            images[i],
                            width: 150,
                            height: 190,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 150,
                              height: 190,
                              color: const Color(0xFF222222),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: kMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
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
            ),
          ],
        ),
      ),
    );
  }
}