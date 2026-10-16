import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ───────────────────────── Warna & util ─────────────────────────

const kBg = Color(0xFF101010);
const kCard = Color(0xFF1E1E1E);
const kBorder = Color(0xFF363636);
const kMuted = Color(0xFF777777);
const kBlue = Color(0xFF0095F6);
const kRed = Color(0xFFFF3040);

const avatarColors = [
  Color(0xFFB5485D),
  Color(0xFF3F7CAC),
  Color(0xFF4F9D69),
  Color(0xFFE09F3E),
  Color(0xFF7B5EA7),
];

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt';
  if (d.inHours < 24) return '${d.inHours} j';
  return '${d.inDays} h';
}

void toast(BuildContext c, String msg) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}

void copyText(BuildContext c, String text, String done) {
  Clipboard.setData(ClipboardData(text: text));
  toast(c, done);
}

// ───────────────────────── Model & state ─────────────────────────

class thridsPost {
  final String id, author, handle;
  final bool verified, isMine;
  final Color color;
  final DateTime time;
  String text;
  bool hasMedia;
  int likes, replyCount;
  bool liked = false, reposted = false;

  thridsPost({
    required this.id,
    required this.author,
    required this.handle,
    required this.text,
    required this.time,
    this.verified = false,
    this.isMine = false,
    this.hasMedia = false,
    this.likes = 0,
    this.replyCount = 0,
    this.color = const Color(0xFF3F7CAC),
  });
}

class replyItem {
  final String text, toHandle;
  final DateTime time;
  replyItem(this.text, this.toHandle, this.time);
}

class suggested {
  final String name, handle;
  final bool verified;
  final Color color;
  bool following = false;
  suggested(this.name, this.handle, this.verified, this.color);
}

class appState extends ChangeNotifier {
  String name = 'limitfungsii';
  String username = 'limitfungsii';
  String bio = '';
  String link = '';
  String note = '';
  int avatarColorIndex = 0;
  bool isPrivate = false;
  bool notifications = true;
  bool fediverse = false;
  String mentionWho = 'Semua orang';
  int unread = 1;

  final List<String> hiddenWords = [];
  final List<String> followers = ['alya.rn', 'dimas_p', 'nadiaaa', 'rizky.f'];
  final List<replyItem> replies = [];

  final List<suggested> suggestions = [
    suggested('Mak Sambung', 'mimisit', false, const Color(0xFF8A5A33)),
    suggested('Alan Walker', 'alanwalkermusic', true, const Color(0xFF8E3B2E)),
    suggested('Jerhemy Owen', 'jerhemynemo', true, const Color(0xFF5C6B7A)),
    suggested('United Nations', 'unitednations', true, const Color(0xFF1B7FC4)),
    suggested('Kopi Pagi', 'kopipagi.id', false, const Color(0xFF8A5A33)),
  ];

  // Kosongkan postingan contoh agar tidak ikut muncul di pencarian/profil.
  // Postingan hanya akan muncul setelah pengguna membuatnya sendiri.
  final List<thridsPost> thrids = [];

  Color get avatarColor => avatarColors[avatarColorIndex];
  List<thridsPost> get mine => thrids.where((t) => t.isMine).toList();
  int get totalLikes => mine.fold(0, (s, t) => s + t.likes);

  void _n() => notifyListeners();

  void addthrids(String text, bool media) {
    thrids.insert(
      0,
      thridsPost(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        author: name,
        handle: username,
        text: text,
        time: DateTime.now(),
        isMine: true,
        hasMedia: media,
        color: avatarColor,
      ),
    );
    _n();
  }

  void deletethrids(thridsPost p) {
    thrids.remove(p);
    _n();
  }

  void toggleLike(thridsPost p) {
    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
    _n();
  }

  void toggleRepost(thridsPost p) {
    p.reposted = !p.reposted;
    _n();
  }

  void addReply(thridsPost p, String text) {
    replies.insert(0, replyItem(text, p.handle, DateTime.now()));
    p.replyCount++;
    _n();
  }

  void toggleFollow(suggested s) {
    s.following = !s.following;
    _n();
  }

  void dismissSuggestion(suggested s) {
    suggestions.remove(s);
    _n();
  }

  void removeFollower(String f) {
    followers.remove(f);
    _n();
  }

  void setNote(String v) {
    note = v;
    _n();
  }

  void clearUnread() {
    if (unread != 0) {
      unread = 0;
      _n();
    }
  }

  void updateProfile({
    required String name,
    required String username,
    required String bio,
    required String link,
    required int colorIndex,
    required bool isPrivate,
  }) {
    this.name = name;
    this.username = username;
    this.bio = bio;
    this.link = link;
    avatarColorIndex = colorIndex;
    this.isPrivate = isPrivate;
    _n();
  }

  void setPrivate(bool v) {
    isPrivate = v;
    _n();
  }

  void setNotifications(bool v) {
    notifications = v;
    _n();
  }

  void setFediverse(bool v) {
    fediverse = v;
    _n();
  }

  void setMentionWho(String v) {
    mentionWho = v;
    _n();
  }

  void addHidden(String w) {
    if (w.isNotEmpty && !hiddenWords.contains(w)) {
      hiddenWords.add(w);
      _n();
    }
  }

  void removeHidden(String w) {
    hiddenWords.remove(w);
    _n();
  }
}

final appState app = appState();

// ───────────────────────── Widget kecil ─────────────────────────

class avatar extends StatelessWidget {
  final double size;
  final Color color;
  final String? label;
  const avatar({super.key, required this.size, required this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final dark = HSLColor.fromColor(color).withLightness(0.22).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, dark],
        ),
      ),
      child: Center(
        child: label != null && label!.isNotEmpty
            ? Text(label![0].toUpperCase(),
                style: TextStyle(
                    fontSize: size * 0.42, fontWeight: FontWeight.w700, color: Colors.white))
            : Icon(Icons.person_rounded, size: size * 0.58, color: Colors.white70),
      ),
    );
  }
}

class verifiedBadge extends StatelessWidget {
  final double size;
  const verifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified_rounded, size: size, color: kBlue);
}

class dashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  dashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant dashedBorderPainter old) => false;
}

// ───────────────────────── thrids (post) ─────────────────────────

class postTile extends StatelessWidget {
  final thridsPost post;
  final bool showRepostLabel;
  const postTile({super.key, required this.post, this.showRepostLabel = false});

  @override
  Widget build(BuildContext context) {
    final p = post;
    final author = p.isMine ? app.name : p.author;
    final handle = p.isMine ? app.username : p.handle;
    final color = p.isMine ? app.avatarColor : p.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRepostLabel)
            const Padding(
              padding: EdgeInsets.only(left: 52, bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 14, color: kMuted),
                  SizedBox(width: 4),
                  Text('Anda memposting ulang',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar(size: 40, color: color, label: p.isMine ? null : author),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        if (p.verified) ...[
                          const SizedBox(width: 4),
                          const verifiedBadge(size: 14),
                        ],
                        const SizedBox(width: 8),
                        Text(timeAgo(p.time),
                            style: const TextStyle(color: kMuted, fontSize: 14)),
                        const Spacer(),
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _menu(context),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.more_horiz_rounded, size: 22, color: kMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(p.text, style: const TextStyle(fontSize: 15, height: 1.35)),
                    if (p.hasMedia) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBorder),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2B3A4A), Color(0xFF1A1F26)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.image_outlined, size: 44, color: kMuted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        actButton(
                          icon: p.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: p.liked ? kRed : Colors.white,
                          label: p.likes > 0 ? '${p.likes}' : '',
                          onTap: () => app.toggleLike(p),
                        ),
                        actButton(
                          icon: Icons.mode_comment_outlined,
                          label: p.replyCount > 0 ? '${p.replyCount}' : '',
                          onTap: () => showReplySheet(context, p),
                        ),
                        actButton(
                          icon: Icons.repeat_rounded,
                          color: p.reposted ? const Color(0xFF3DDC84) : Colors.white,
                          label: '',
                          onTap: () {
                            app.toggleRepost(p);
                            toast(context, p.reposted ? 'Diposting ulang' : 'Repost dibatalkan');
                          },
                        ),
                        actButton(
                          icon: Icons.send_outlined,
                          label: '',
                          onTap: () => copyText(
                              context,
                              'https://www.thrids.net/@$handle/post/${p.id}',
                              'Tautan thrids disalin'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _menu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Salin teks'),
              onTap: () {
                Navigator.pop(ctx);
                copyText(context, post.text, 'Teks disalin');
              },
            ),
            if (post.isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: kRed),
                title: const Text('Hapus thrids', style: TextStyle(color: kRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  app.deletethrids(post);
                  toast(context, 'thrids dihapus');
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Sembunyikan'),
                onTap: () {
                  Navigator.pop(ctx);
                  app.deletethrids(post);
                  toast(context, 'thrids disembunyikan');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class actButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const actButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(color: kMuted, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}

void showReplySheet(BuildContext context, thridsPost p) {
  final c = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balas @${p.handle}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p.text,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Tulis balasan…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () {
                final t = c.text.trim();
                if (t.isEmpty) return;
                app.addReply(p, t);
                Navigator.pop(ctx);
                toast(context, 'Balasan terkirim');
              },
              child: const Text('Kirim'),
            ),
          ),
        ],
      ),
    ),
  );
}
