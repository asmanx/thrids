import 'package:flutter/material.dart';
import '../komponenBersama.dart';

class AktivitasScreen extends StatefulWidget {
  const AktivitasScreen({super.key});

  @override
  State<AktivitasScreen> createState() => _AktivitasScreenState();
}

class _AktivitasScreenState extends State<AktivitasScreen> {
  int _selectedIndex = 0;

  final List<String> categories = [
    "Semua",
    "Mengikuti",
    "Percakapan",
    "Penyebutan",
    "Orang yang Anda Ikuti",
    "Postingan Ulang",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header 'Aktivitas'
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'Aktivitas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Filter Kategori (Horizontal Scroll)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : kBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.white : kBorder,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            categories[index],
                            style: TextStyle(
                              color: isSelected ? kBg : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Konten Kosong di Tengah
            const Expanded(
              child: Center(
                child: Text(
                  'Belum ada yang bisa dilihat di sini',
                  style: TextStyle(
                    color: kMuted, // Menggunakan kMuted dari komponen bersama
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }
}

// --- KOMPONEN NAV BAR ---
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Home Icon dengan Red Dot Indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              const IconButton(
                onPressed: null,
                icon: Icon(Icons.crop_square_rounded, color: kMuted, size: 28),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: kRed, // Menggunakan kRed dari komponen bersama
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          // 2. Paper Plane / Send Icon
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.send_outlined, color: kMuted, size: 26),
          ),

          // 3. Plus Icon dengan Rounded Card
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const IconButton(
              onPressed: null,
              icon: Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),

          // 4. Favorite (Heart) Solid Active Icon
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.favorite, color: Colors.white, size: 28),
          ),

          // 5. Profile Outline Icon
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.person_outline_rounded, color: kMuted, size: 28),
          ),
        ],
      ),
    );
  }
}