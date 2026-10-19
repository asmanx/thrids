import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/api_service.dart';

const _bg = Color(0xFF101010);
const _muted = Color(0xFF858585);
const _tabMuted = Color(0xFF5E5E5E);
const _border = Color(0xFF2E2E2E);
const _card = Color(0xFF1E1E1E);
const _green = Color(0xFF2EBD59);
const _red = Color(0xFFFF3040);

const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _dayOptions = [
  (value: 7, label: '7 hari'),
  (value: 14, label: '14 hari'),
  (value: 30, label: '30 hari'),
  (value: 90, label: '90 hari'),
];

// ───────────────────────── Helper ─────────────────────────

num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? 0}') ?? 0);

String _count(num n) => n.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

double _change(num cur, num prev) {
  if (prev == 0) return cur == 0 ? 0 : 100;
  return (cur - prev) / prev * 100;
}

String _pct(double v) {
  final s = v.abs().toStringAsFixed(1).replaceAll('.', ',');
  if (v > 0) return '+$s%';
  if (v < 0) return '-$s%';
  return '$s%';
}

Color _pctColor(double v) => v > 0 ? _green : (v < 0 ? _red : _muted);

String _shortDate(DateTime d) => '${_monthShort[d.month - 1]} ${d.day}';

void _showInfo(BuildContext context, String title, String text) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF242424),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(text, style: const TextStyle(color: _muted, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

Widget _infoIcon(BuildContext context, String title, String text) {
  return GestureDetector(
    onTap: () => _showInfo(context, title, text),
    child: const Icon(Icons.info_outline_rounded, size: 22, color: _muted),
  );
}

/// Label dengan panah bawah yang membuka menu pilihan bertanda centang.
class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onSelected;
  final TextStyle style;
  final Color arrowColor;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.style,
    this.arrowColor = _muted,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      offset: const Offset(0, 36),
      color: const Color(0xFF1A1A1A),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(
            value: o.value,
            height: 58,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    o.label,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                if (o.value == value)
                  const Icon(Icons.check_rounded,
                      color: Colors.white, size: 26),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded, color: arrowColor, size: 26),
        ],
      ),
    );
  }
}

// ───────────────────────── Halaman ─────────────────────────

/// Insight akun: tab "Gambaran Umum" (profil + postingan) dan "Audiens".
class InsightPage extends StatefulWidget {
  final String token;

  /// Postingan milik akun ini (untuk daftar "Postingan").
  final List<Map<String, dynamic>> posts;

  const InsightPage({super.key, required this.token, required this.posts});

  @override
  State<InsightPage> createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, size: 30),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Insight',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: _border),
          TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 1.5,
            labelColor: Colors.white,
            unselectedLabelColor: _tabMuted,
            dividerColor: _border,
            dividerHeight: 1,
            labelStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(height: 58, text: 'Gambaran Umum'),
              Tab(height: 58, text: 'Audiens'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(token: widget.token, posts: widget.posts),
                _AudienceTab(token: widget.token),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Gambaran Umum ─────────────────────────

class _OverviewTab extends StatefulWidget {
  final String token;
  final List<Map<String, dynamic>> posts;

  const _OverviewTab({required this.token, required this.posts});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  static const _metrics = [
    (key: 'views', label: 'Tayangan'),
    (key: 'viewers', label: 'Pemirsa'),
    (key: 'followers', label: 'Pengikut bersih'),
    (key: 'interactions', label: 'Interaksi'),
  ];

  static const _types = [
    (value: 'semua', label: 'Semua'),
    (value: 'utas', label: 'Utas'),
    (value: 'balasan', label: 'Balasan'),
    (value: 'tautan', label: 'Tautan'),
  ];

  static const _sorts = [
    (value: 'terbaru', label: 'Terbaru'),
    (value: 'tayangan', label: 'Tayangan terbanyak'),
    (value: 'balasan', label: 'Balasan terbanyak'),
    (value: 'suka', label: 'Suka terbanyak'),
  ];

  int _days = 30;
  int _metric = 0;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  int _postDays = 90;
  String _type = 'utas';
  String _sort = 'terbaru';
  List<Map<String, dynamic>>? _replies;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getInsights(token: widget.token, days: _days);

      if (!mounted) return;

      setState(() {
        _profile = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _ensureReplies() async {
    if (_replies != null) return;

    try {
      final items = await ApiService.getMyReplies(token: widget.token);
      if (!mounted) return;
      setState(() => _replies = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _replies = []);
    }
  }

  // ── data postingan ──

  List<Map<String, dynamic>> get _items {
    final since = DateTime.now().subtract(Duration(days: _postDays));
    final list = <Map<String, dynamic>>[];

    bool inRange(dynamic raw) {
      final d = DateTime.tryParse('$raw')?.toLocal();
      return d != null && d.isAfter(since);
    }

    if (_type != 'balasan') {
      for (final p in widget.posts) {
        if (!inRange(p['created_at'])) continue;

        final content = '${p['content'] ?? ''}';
        if (_type == 'tautan' && !RegExp(r'https?://').hasMatch(content)) {
          continue;
        }

        list.add({
          'content': content,
          'created_at': p['created_at'],
          'views': _n(p['view_count']),
          'likes': _n(p['like_count']),
          'comments': _n(p['comment_count']),
        });
      }
    }

    if (_type == 'semua' || _type == 'balasan') {
      for (final r in _replies ?? const <Map<String, dynamic>>[]) {
        if (!inRange(r['created_at'])) continue;

        list.add({
          'content': '${r['content'] ?? ''}',
          'created_at': r['created_at'],
          'views': 0,
          'likes': _n(r['like_count']),
          'comments': _n(r['reply_count']),
        });
      }
    }

    num byKey(Map<String, dynamic> m, String k) => _n(m[k]);

    switch (_sort) {
      case 'tayangan':
        list.sort((a, b) => byKey(b, 'views').compareTo(byKey(a, 'views')));
        break;
      case 'balasan':
        list.sort((a, b) => byKey(b, 'comments').compareTo(byKey(a, 'comments')));
        break;
      case 'suka':
        list.sort((a, b) => byKey(b, 'likes').compareTo(byKey(a, 'likes')));
        break;
      default:
        list.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    }

    return list;
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(
            children: [
              const Text(
                'Profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _infoIcon(
                context,
                'Profil',
                'Ringkasan tayangan, pemirsa, pengikut baru, dan interaksi '
                    'di profil Anda pada rentang waktu yang dipilih, '
                    'dibandingkan dengan periode sebelumnya.',
              ),
              const Spacer(),
              _Dropdown<int>(
                label: '$_days hari',
                value: _days,
                options: _dayOptions,
                style: const TextStyle(color: _muted, fontSize: 20),
                onSelected: (v) {
                  if (v == _days) return;
                  setState(() => _days = v);
                  _load();
                },
              ),
            ],
          ),
        ),
        _buildProfileBody(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
          child: Row(
            children: [
              const Text(
                'Postingan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _infoIcon(
                context,
                'Postingan',
                'Daftar postingan Anda pada rentang waktu yang dipilih. '
                    'Urutkan menurut yang terbaru, tayangan, balasan, atau '
                    'suka terbanyak.',
              ),
              const Spacer(),
              _Dropdown<int>(
                label: '$_postDays hari',
                value: _postDays,
                options: _dayOptions,
                style: const TextStyle(color: _muted, fontSize: 20),
                onSelected: (v) => setState(() => _postDays = v),
              ),
            ],
          ),
        ),
        _buildChips(),
        const SizedBox(height: 8),
        _buildPosts(),
      ],
    );
  }

  Widget _buildProfileBody() {
    if (_loading) {
      return const SizedBox(
        height: 340,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null || _profile == null) {
      return SizedBox(
        height: 340,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Gagal memuat insight.',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                TextButton(onPressed: _load, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
      );
    }

    final p = _profile!;
    final selected = _metrics[_metric];

    final points = _seriesOf(p, selected.key);

    return Column(
      children: [
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _metrics.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _metricCard(i, p),
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 290,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(points),
            ),
          ),
        ),
      ],
    );
  }

  List<({DateTime date, num value})> _seriesOf(
    Map<String, dynamic> profile,
    String key,
  ) {
    final series = profile['series'];
    final raw = series is Map ? series[key] : null;
    final out = <({DateTime date, num value})>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final d = DateTime.tryParse('${item['date']}');
        if (d == null) continue;
        out.add((date: d, value: _n(item['value'])));
      }
    }

    return out;
  }

  Widget _metricCard(int index, Map<String, dynamic> p) {
    final m = _metrics[index];
    final cur = _n(p[m.key]);
    final prev = _n(p['${m.key}_prev']);
    final change = _change(cur, prev);
    final selected = index == _metric;

    final value = m.key == 'followers' && cur > 0
        ? '+${_count(cur)}'
        : _count(cur);

    return GestureDetector(
      onTap: () => setState(() => _metric = index),
      child: Container(
        width: 150,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        decoration: BoxDecoration(
          color: selected ? _card : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _muted,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              _pct(change),
              style: TextStyle(color: _pctColor(change), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChips() {
    final typeLabel = _types.firstWhere((t) => t.value == _type).label;

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          PopupMenuButton<String>(
            tooltip: '',
            offset: const Offset(0, 60),
            color: const Color(0xFF1A1A1A),
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            onSelected: (v) {
              setState(() => _type = v);
              if (v == 'semua' || v == 'balasan') _ensureReplies();
            },
            itemBuilder: (_) => [
              for (final t in _types)
                PopupMenuItem<String>(
                  value: t.value,
                  height: 58,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                        ),
                      ),
                      if (t.value == _type)
                        const Icon(Icons.check_rounded,
                            color: Colors.white, size: 26),
                    ],
                  ),
                ),
            ],
            child: _chip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(typeLabel, style: _chipText),
                ],
              ),
              selected: false,
            ),
          ),
          for (final s in _sorts) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _sort = s.value),
              child: _chip(
                child: Text(s.label, style: _chipText),
                selected: _sort == s.value,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _chipText = TextStyle(
    color: Colors.white,
    fontSize: 19,
    fontWeight: FontWeight.w600,
  );

  Widget _chip({required Widget child, required bool selected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _card : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _buildPosts() {
    final items = _items;

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(40, 56, 40, 0),
        child: Text(
          'Tidak ada postingan pada rentang tanggal ini',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 21, height: 1.4),
        ),
      );
    }

    return Column(
      children: [
        for (final item in items)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['content'] as String).isEmpty
                      ? '(tanpa teks)'
                      : item['content'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat(Icons.visibility_outlined, item['views'] as num),
                    const SizedBox(width: 20),
                    _stat(Icons.favorite_border, item['likes'] as num),
                    const SizedBox(width: 20),
                    _stat(Icons.chat_bubble_outline, item['comments'] as num),
                    const Spacer(),
                    Text(
                      _dateLabel(item['created_at']),
                      style: const TextStyle(color: _muted, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(IconData icon, num value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _muted, size: 20),
        const SizedBox(width: 6),
        Text(_count(value),
            style: const TextStyle(color: _muted, fontSize: 15)),
      ],
    );
  }

  String _dateLabel(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    return d == null ? '' : '${_shortDate(d)}, ${d.year}';
  }
}

/// Grafik garis putih dengan area gradien, mengikuti tampilan di desain.
class _LineChartPainter extends CustomPainter {
  final List<({DateTime date, num value})> points;

  const _LineChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 46.0;
    const bottomPad = 46.0;
    const topPad = 6.0;

    final plot = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width,
      size.height - bottomPad,
    );

    final maxValue = points.isEmpty
        ? 0
        : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final top = math.max(10, (maxValue / 10).ceil() * 10).toDouble();

    final grid = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 1.2;

    void text(String value, Offset at, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(color: _muted, fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      var dx = at.dx;
      if (align == TextAlign.right) dx -= tp.width;
      if (align == TextAlign.center) dx -= tp.width / 2;

      tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    }

    // Garis kisi + label sumbu Y: 0, setengah, puncak.
    for (final v in [0.0, top / 2, top]) {
      final y = plot.bottom - (v / top) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      text(v.toStringAsFixed(0), Offset(0, y));
    }

    if (points.isEmpty) return;

    final n = points.length;

    Offset at(int i) {
      final x = n == 1
          ? plot.center.dx
          : plot.left + plot.width * i / (n - 1);
      final y = plot.bottom - (points[i].value.toDouble() / top) * plot.height;
      return Offset(x, y);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }

    final area = Path.from(line)
      ..lineTo(at(n - 1).dx, plot.bottom)
      ..lineTo(at(0).dx, plot.bottom)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(plot),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Label sumbu X: awal, tengah, akhir.
    final labelY = plot.bottom + 24;
    text(_shortDate(points.first.date), Offset(plot.left, labelY));

    if (n > 2) {
      text(_shortDate(points[n ~/ 2].date), Offset(at(n ~/ 2).dx, labelY),
          align: TextAlign.center);
    }

    if (n > 1) {
      text(_shortDate(points.last.date), Offset(plot.right, labelY),
          align: TextAlign.right);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.points != points;
}

// ───────────────────────── Audiens ─────────────────────────

class _AudienceTab extends StatefulWidget {
  final String token;

  const _AudienceTab({required this.token});

  @override
  State<_AudienceTab> createState() => _AudienceTabState();
}

class _AudienceTabState extends State<_AudienceTab>
    with AutomaticKeepAliveClientMixin {
  static const _modes = [
    (value: 'pemirsa', label: 'Pemirsa'),
    (value: 'pengikut', label: 'Pengikut'),
  ];

  int _days = 30;
  String _mode = 'pemirsa';
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getInsights(token: widget.token, days: _days);

      if (!mounted) return;

      setState(() {
        _data = Map<String, dynamic>.from(data['audience'] as Map? ?? {});
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final modeLabel = _modes.firstWhere((m) => m.value == _mode).label;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Row(
          children: [
            _Dropdown<String>(
              label: modeLabel,
              value: _mode,
              options: _modes,
              arrowColor: _muted,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (v) => setState(() => _mode = v),
            ),
            const SizedBox(width: 8),
            _infoIcon(
              context,
              modeLabel,
              _mode == 'pemirsa'
                  ? 'Jumlah akun berbeda yang melihat postingan Anda pada '
                      'rentang waktu yang dipilih.'
                  : 'Jumlah akun yang mengikuti Anda dan pertumbuhannya pada '
                      'rentang waktu yang dipilih.',
            ),
            const Spacer(),
            _Dropdown<int>(
              label: '$_days hari',
              value: _days,
              options: _dayOptions,
              style: const TextStyle(color: _muted, fontSize: 20),
              onSelected: (v) {
                if (v == _days) return;
                setState(() => _days = v);
                _load();
              },
            ),
          ],
        ),
        if (_loading)
          const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        else if (_error != null || _data == null)
          SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat insight.',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_error ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 12)),
                  TextButton(onPressed: _load, child: const Text('Coba lagi')),
                ],
              ),
            ),
          )
        else
          ..._buildContent(_data!),
      ],
    );
  }

  List<Widget> _buildContent(Map<String, dynamic> d) {
    final since = DateTime.now().subtract(Duration(days: _days));

    final num big;
    final double change;

    if (_mode == 'pemirsa') {
      big = _n(d['viewers']);
      change = _change(big, _n(d['viewers_prev']));
    } else {
      big = _n(d['followers_total']);
      final added = _n(d['followers_new']);
      final base = big - added;
      change = base <= 0 ? 0 : added / base * 100;
    }

    final followerViewers = _n(d['follower_viewers']);
    final nonFollowerViewers = _n(d['non_follower_viewers']);

    return [
      const SizedBox(height: 36),
      Text(
        _count(big),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 60,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Text(
            _pct(change),
            style: TextStyle(color: _pctColor(change), fontSize: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'sejak ${_shortDate(since)}',
            style: const TextStyle(color: _muted, fontSize: 18),
          ),
        ],
      ),
      if (_mode == 'pemirsa') ...[
        const SizedBox(height: 40),
        Row(
          children: [
            const Text(
              'Jenis pemirsa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            _infoIcon(
              context,
              'Jenis pemirsa',
              'Pemirsa yang sudah mengikuti Anda dibandingkan dengan yang '
                  'belum.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _audienceCard(
                'Pengikut',
                followerViewers,
                _change(followerViewers, _n(d['follower_viewers_prev'])),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _audienceCard(
                'Non-pengikut',
                nonFollowerViewers,
                _change(
                  nonFollowerViewers,
                  _n(d['non_follower_viewers_prev']),
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _audienceCard(String label, num value, double change) {
    return Container(
      height: 124,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _muted, fontSize: 17, fontWeight: FontWeight.w500)),
          Text(
            _count(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(_pct(change),
              style: TextStyle(color: _pctColor(change), fontSize: 16)),
        ],
      ),
    );
  }
}