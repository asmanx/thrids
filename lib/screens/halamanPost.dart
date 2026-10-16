import 'package:flutter/material.dart';

void bukaHalamanPost(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const halamanPost(),
    ),
  );
}

class halamanPost extends StatelessWidget {
  const halamanPost({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // Isi halaman sengaja dikosongkan.
      // Navigasi dan tombol kembali tetap berfungsi.
      body: const SizedBox.expand(),
    );
  }
}