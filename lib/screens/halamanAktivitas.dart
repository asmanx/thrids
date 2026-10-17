import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aktivitas', // Title web/aplikasi
      home: AktivitasScreen(),
    ),
  );
}

class AktivitasScreen extends StatefulWidget {
  const AktivitasScreen({super.key});

  @override
  State<AktivitasScreen> createState() => _AktivitasScreenState();
}

class _AktivitasScreenState extends State<AktivitasScreen> {
  int _selectedCategoryIndex = 0;
  int _currentNavIndex = 3; // Default di Aktivitas (Love)

  final List<String> _categories = [
    'Semua',
    'Mengikuti',
    'Percakapan',
    'Penyebutan',
    'Orang yang Anda Ikuti',
    'Postingan Ulang',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Aktivitas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_categories.length, (index) {
                final isSelected = _selectedCategoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_categories[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                    selectedColor: Colors.white,
                    backgroundColor: Colors.black,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Teks Kosong di Tengah
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Belum ada yang bisa dilihat di sini',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home / Beranda (ikon persegi berliku dengan titik merah di atas)
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.crop_square_rounded, color: Colors.grey, size: 28),
                    Positioned(
                      top: 1,
                      left: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () => setState(() => _currentNavIndex = 0),
              ),

              // 2. Chat / Pesan (Ikon Kirim / Pesawat Kertas)
              IconButton(
                icon: Transform.rotate(
                  angle: -0.2, // Kemiringan ikon kirim/chat
                  child: Icon(
                    Icons.send_outlined,
                    color: _currentNavIndex == 1 ? Colors.white : Colors.grey,
                    size: 26,
                  ),
                ),
                onPressed: () => setState(() => _currentNavIndex = 1),
              ),

              // 3. Tombol Tambah (+)
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.grey, size: 24),
                ),
              ),

              // 4. Aktivitas / Love (Active)
              IconButton(
                icon: Icon(
                  _currentNavIndex == 3 ? Icons.favorite : Icons.favorite_border,
                  color: _currentNavIndex == 3 ? Colors.white : Colors.grey,
                  size: 28,
                ),
                onPressed: () => setState(() => _currentNavIndex = 3),
              ),

              // 5. Profil
              IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: _currentNavIndex == 4 ? Colors.white : Colors.grey,
                  size: 28,
                ),
                onPressed: () => setState(() => _currentNavIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}