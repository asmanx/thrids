import 'package:flutter/material.dart';

void main() {
  runApp(const ThreadsApp());
}

const Color bgColor = Color(0xFF101010);
const Color cardColor = Color(0xFF171717);
const Color lineColor = Color(0xFF292929);
const Color mutedColor = Color(0xFF858585);

class ThreadsApp extends StatelessWidget {
  const ThreadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Threads',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgColor,
        colorScheme: const ColorScheme.dark(
          surface: bgColor,
          primary: Colors.white,
        ),
      ),
      home: const ThreadsHomePage(),
    );
  }
}

class ThreadsHomePage extends StatefulWidget {
  const ThreadsHomePage({super.key});

  @override
  State<ThreadsHomePage> createState() => _ThreadsHomePageState();
}

class _ThreadsHomePageState extends State<ThreadsHomePage> {
  bool menuOpen = false;
  int selectedNav = 0;
  String selectedFeed = 'For you';

  final List<Map<String, dynamic>> posts = [
    {
      'username': 'almaallivia_',
      'time': '16 jam',
      'text': 'jual tas punya mamahku, mo jual karna bosen 🫶🏻 ✨ yuk nego in guys..',
      'avatar': 'A',
      'likes': '30',
      'comments': '7',
      'image': 'assets/tas gucci 1.png',
    },
    {
      'username': 'widaasny',
      'time': '13 jam',
      'text': 'Maaf norak bangettt aku baru nyobain mandi pake kembang macan kerah karna liat mamah amandazahra & mbak yu pake ini. Ternyata beneran se nagih itu, after berendam jadi relax, badan kerasa enteng, dan mood happy OMG',
      'avatar': 'W',
      'likes': '12',
      'comments': '3',
      'image': 'assets/mandi macan kerah.jpeg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double drawerWidth = screenWidth * 0.75;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              left: menuOpen ? drawerWidth : 0,
              top: 0,
              bottom: 0,
              width: screenWidth,
              child: IgnorePointer(
                ignoring: menuOpen,
                child: HomeFeed(
                  selectedNav: selectedNav,
                  onNavTap: (index) {
                    setState(() => selectedNav = index);
                  },
                  onMenuTap: () {
                    setState(() => menuOpen = true);
                  },
                  posts: posts,
                ),
              ),
            ),

            if (menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => menuOpen = false),
                  child: Container(color: Colors.black.withValues(alpha: 0.48)),
                ),
              ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              left: menuOpen ? 0 : -drawerWidth,
              top: 0,
              bottom: 0,
              width: drawerWidth,
              child: FeedDrawer(
                selectedFeed: selectedFeed,
                onFeedTap: (feed) {
                  setState(() {
                    selectedFeed = feed;
                    menuOpen = false;
                  });
                },
                onClose: () {
                  setState(() => menuOpen = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= BERANDA =================

class HomeFeed extends StatelessWidget {
  final int selectedNav;
  final ValueChanged<int> onNavTap;
  final VoidCallback onMenuTap;
  final List<Map<String, dynamic>> posts;

  const HomeFeed({
    super.key,
    required this.selectedNav,
    required this.onNavTap,
    required this.onMenuTap,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // HEADER
        SizedBox(
          height: 54,
          width: double.infinity,
          child: Stack(
            children: [
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.alternate_email,
                    size: 43,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onMenuTap,
                  child: const SizedBox(
                    width: 40,
                    height: 54,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.menu, size: 32, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // PROFIL DAN WHAT'S NEW
        Container(
          padding: const EdgeInsets.fromLTRB(13, 7, 15, 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: lineColor, width: 0.7)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 33,
                backgroundColor: Color(0xFFE6E8ED),
                child: Icon(Icons.person, size: 52, color: Color(0xFF858B96)),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'kucnglusyu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "What's new?",
                      style: TextStyle(color: mutedColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // DAFTAR POSTINGAN
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostItem(post: posts[index]);
            },
          ),
        ),

        // NAVIGASI BAWAH
        Container(
          height: 57,
          decoration: const BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: lineColor, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              navIcon(Icons.home_filled, 0),
              navIcon(Icons.send_outlined, 1),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 83,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF303030),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF777777),
                    size: 34,
                  ),
                ),
              ),
              navIcon(Icons.favorite_border, 3, hasDot: true),
              navIcon(Icons.person_outline, 4, hasDot: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget navIcon(IconData icon, int index, {bool hasDot = false}) {
    final bool active = selectedNav == index;

    return GestureDetector(
      onTap: () => onNavTap(index),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 30,
              color: active ? Colors.white : const Color(0xFF777777),
            ),
            if (hasDot)
              const Positioned(
                top: 8,
                right: 7,
                child: CircleAvatar(
                  radius: 3.5,
                  backgroundColor: Color(0xFFFF3040),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= POSTINGAN =================

class PostItem extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 33,
                backgroundColor: const Color(0xFFD5C4B9),
                child: Text(
                  post['avatar'],
                  style: const TextStyle(color: Colors.black87, fontSize: 25),
                ),
              ),
              const Positioned(
                bottom: -2,
                right: -3,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: bgColor,
                  child: Icon(Icons.add_circle, size: 24, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post['username'],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      post['time'],
                      style: const TextStyle(color: mutedColor, fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(Icons.more_horiz, color: mutedColor, size: 22),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  post['text'],
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),

                // GAMBAR SESUAI POSTINGAN
                if (post['image'] != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      post['image'],
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 180,
                          color: cardColor,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 35,
                                color: mutedColor,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Gambar tidak ditemukan',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 13),

                Row(
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 24,
                      color: Color(0xFFBDBDBD),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      post['likes'],
                      style: const TextStyle(color: mutedColor),
                    ),
                    const SizedBox(width: 18),
                    const Icon(
                      Icons.mode_comment_outlined,
                      size: 23,
                      color: Color(0xFFBDBDBD),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      post['comments'],
                      style: const TextStyle(color: mutedColor),
                    ),
                    const SizedBox(width: 19),
                    const Icon(
                      Icons.repeat,
                      size: 24,
                      color: Color(0xFFBDBDBD),
                    ),
                    const SizedBox(width: 20),
                    const Icon(
                      Icons.send_outlined,
                      size: 23,
                      color: Color(0xFFBDBDBD),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MENU SAMPING =================

class FeedDrawer extends StatelessWidget {
  final String selectedFeed;
  final ValueChanged<String> onFeedTap;
  final VoidCallback onClose;

  const FeedDrawer({
    super.key,
    required this.selectedFeed,
    required this.onFeedTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // JUDUL MENU
          SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.only(left: 29, right: 24),
              child: Row(
                children: [
                  const Text(
                    'Feeds',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.add_circle_outline,
                      size: 31,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(width: 21),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 30,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FAVORIT DAN TERSIMPAN
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 0, 29, 12),
            child: Row(
              children: [
                Expanded(child: shortcutButton(Icons.favorite_border)),
                const SizedBox(width: 10),
                Expanded(child: shortcutButton(Icons.bookmark_border)),
              ],
            ),
          ),

          // PILIHAN FEED
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 29),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(color: lineColor, width: 1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  feedOption('For you'),
                  const Divider(height: 1, indent: 28, color: lineColor),
                  feedOption('Following'),
                  const Divider(height: 1, indent: 28, color: lineColor),
                  feedOption(
                    'Ghost posts',
                    icon: Icons.face_retouching_natural_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget shortcutButton(IconData icon) {
    return Container(
      height: 67,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: lineColor, width: 0.8),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Icon(icon, color: Colors.white, size: 29),
    );
  }

  Widget feedOption(String title, {IconData? icon}) {
    final bool selected = selectedFeed == title;

    return InkWell(
      onTap: () => onFeedTap(title),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 86,
        child: Padding(
          padding: const EdgeInsets.only(left: 29, right: 22),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, size: 30, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
