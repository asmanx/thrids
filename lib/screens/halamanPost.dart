import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color bg = Color(0xFF000000);
const Color surface = Color(0xFF171717);
const Color surface2 = Color(0xFF242424);
const Color muted = Color(0xFF858585);
const Color line = Color(0xFF303030);

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _postController = TextEditingController();

  final List<TextEditingController> _threadControllers = [];
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  bool _showExtraOptions = false;
  bool _isPosting = false;
  bool _reviewReplies = false;
  bool _shareElsewhere = false;

  String _replyPermission = 'Siapa saja';

  bool get _hasContent =>
      _postController.text.trim().isNotEmpty ||
      _threadControllers.any((c) => c.text.trim().isNotEmpty) ||
      _images.isNotEmpty;

  @override
  void dispose() {
    _postController.dispose();

    for (final controller in _threadControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF242424),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final selected = await _picker.pickMultiImage();

      if (!mounted || selected.isEmpty) return;

      setState(() {
        _images.addAll(selected);
      });
    } catch (_) {
      _message('Tidak dapat membuka galeri.');
    }
  }

  void _post() {
    if (!_hasContent || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    _message('Postingan siap diproses.');

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  Widget _iconButton(
    IconData icon, {
    required VoidCallback onTap,
    double size = 25,
    Color color = muted,
  }) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, size: size, color: color),
    );
  }

  // MENU TITIK TIGA DI BAGIAN HEADER
  // Menu ini digunakan untuk menghapus draf.
  void _showDraftMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.white),
            title: const Text(
              'Hapus draf',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(sheetContext);

              setState(() {
                _postController.clear();

                for (final controller in _threadControllers) {
                  controller.dispose();
                }

                _threadControllers.clear();
                _images.clear();
                _showExtraOptions = false;
                _isPosting = false;
              });
            },
          ),
        );
      },
    );
  }

  // MENU TITIK TIGA DI SEBELAH IKON LAGU
  void _selectExtraOption(String value) {
    switch (value) {
      case 'Teks':
        _message('Mode teks dipilih.');
        break;
      case 'Kutipan':
        _message('Fitur kutipan belum tersedia.');
        break;
      case 'Polling':
        _message('Fitur polling belum tersedia.');
        break;
      case 'Lokasi':
        _message('Fitur lokasi belum tersedia.');
        break;
    }
  }

  Widget _extraMenu() {
    return PopupMenuButton<String>(
      color: surface,
      elevation: 8,
      icon: const Icon(Icons.more_horiz, size: 28, color: muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: _selectExtraOption,
      itemBuilder: (context) => [
        _menuItem('Teks', Icons.article_outlined),
        _menuItem('Kutipan', Icons.format_quote),
        _menuItem('Polling', Icons.poll_outlined),
        _menuItem('Lokasi', Icons.location_on_outlined),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String title, IconData icon) {
    return PopupMenuItem<String>(
      value: title,
      child: SizedBox(
        width: 240,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            Icon(icon, color: Colors.white, size: 25),
          ],
        ),
      ),
    );
  }

  // BOTTOM SHEET OPSI POSTINGAN
  void _showPostOptions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      barrierColor: Colors.black.withOpacity(0.60),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Opsi postingan',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Siapa yang bisa membalas dan mengutip',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          children:
                              [
                                'Siapa saja',
                                'Pengikut Anda',
                                'Profil yang Anda ikuti',
                                'Profil yang Anda sebutkan',
                              ].map((option) {
                                return RadioListTile<String>(
                                  value: option,
                                  groupValue: _replyPermission,
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setState(() {
                                      _replyPermission = value;
                                    });

                                    setSheetState(() {});
                                  },
                                  title: Text(
                                    option,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  activeColor: Colors.white,
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  dense: true,
                                );
                              }).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: SwitchListTile(
                          value: _reviewReplies,
                          onChanged: (value) {
                            setState(() {
                              _reviewReplies = value;
                            });

                            setSheetState(() {});
                          },
                          title: const Text(
                            'Tinjau dan setujui balasan',
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                          activeColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Audiens',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: SwitchListTile(
                          value: _shareElsewhere,
                          onChanged: (value) {
                            setState(() {
                              _shareElsewhere = value;
                            });

                            setSheetState(() {});
                          },
                          title: const Text(
                            'Juga bagikan di',
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                          subtitle: Text(
                            _shareElsewhere ? 'Aktif' : 'Nonaktif',
                            style: const TextStyle(color: muted),
                          ),
                          activeColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _threadInput(TextEditingController controller, {bool first = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Column(
            children: [
              CircleAvatar(
                radius: first ? 18 : 5,
                backgroundColor: first
                    ? const Color(0xFF292C31)
                    : const Color(0xFF555555),
                child: first
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFFB7BBC2),
                        size: 25,
                      )
                    : null,
              ),
              if (!first) Container(width: 2, height: 40, color: line),
            ],
          ),
        ),

        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: null,
            onChanged: (_) {
              setState(() {});
            },
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: first ? 'Apa yang baru?' : 'Tambahkan ke utas',
              hintStyle: const TextStyle(color: muted, fontSize: 16),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 8, bottom: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 8, bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_images.length, (index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_images[index].path),
                  width: 145,
                  height: 145,
                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                right: 5,
                top: 5,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _images.removeAt(index);
                    });
                  },
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 17),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        canvasColor: surface,
        dividerColor: line,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: surface,
          onSurface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // HEADER TANPA GARIS PEMISAH
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: 12),

                    _iconButton(
                      Icons.close,
                      color: Colors.white,
                      size: 29,
                      onTap: () {
                        Navigator.of(context).maybePop();
                      },
                    ),

                    const SizedBox(width: 18),

                    const Expanded(
                      child: Text(
                        'Utas baru',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    _iconButton(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 27,
                      onTap: () {
                        _message('Draf belum disimpan.');
                      },
                    ),

                    // TITIK TIGA HEADER: HAPUS DRAF
                    _iconButton(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 30,
                      onTap: _showDraftMenu,
                    ),

                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // TIDAK ADA DIVIDER PUTIH DI SINI
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(15, 20, 15, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 37,
                            backgroundColor: Color(0xFF292C31),
                            child: Icon(
                              Icons.person,
                              color: Color(0xFFB7BBC2),
                              size: 48,
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'kakanetizen_',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    const Icon(
                                      Icons.chevron_right,
                                      color: muted,
                                      size: 21,
                                    ),

                                    Flexible(
                                      child: GestureDetector(
                                        onTap: () {
                                          _message(
                                            'Fitur tag komunitas belum tersedia.',
                                          );
                                        },
                                        child: const Text(
                                          'Tag komunitas',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                _threadInput(_postController, first: true),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // TOOLBAR
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 77,
                          top: 5,
                          right: 8,
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _iconButton(
                              Icons.image_outlined,
                              onTap: _pickImage,
                              size: 28,
                            ),

                            _iconButton(
                              Icons.gif_box_outlined,
                              onTap: () {
                                _message('Pemilihan GIF belum tersedia.');
                              },
                              size: 27,
                            ),

                            _iconButton(
                              Icons.sticky_note_2_outlined,
                              onTap: () {
                                _message('Fitur stiker belum tersedia.');
                              },
                              size: 27,
                            ),

                            _iconButton(
                              Icons.music_note_outlined,
                              onTap: () {
                                _message('Fitur musik belum tersedia.');
                              },
                              size: 29,
                            ),

                            // TITIK TIGA DI SEBELAH LAGU
                            _extraMenu(),
                          ],
                        ),
                      ),

                      // OPSI TAMBAHAN
                      if (_showExtraOptions)
                        Padding(
                          padding: const EdgeInsets.only(left: 77, top: 5),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ActionChip(
                                label: const Text('Lokasi'),
                                onPressed: () {
                                  _message('Fitur lokasi belum tersedia.');
                                },
                              ),
                              ActionChip(
                                label: const Text('Polling'),
                                onPressed: () {
                                  _message('Fitur polling belum tersedia.');
                                },
                              ),
                            ],
                          ),
                        ),

                      _buildImagePreview(),

                      // UTAS TAMBAHAN YANG SUDAH ADA
                      ..._threadControllers.map(
                        (controller) => Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _threadInput(controller),
                        ),
                      ),

                      // TIDAK BISA DIKLIK
                      const Padding(
                        padding: EdgeInsets.only(left: 48, top: 18),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 19,
                              color: Color(0xFF3D3D3D),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tambahkan ke utas',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF3D3D3D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // FOOTER
              Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                color: bg,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      _iconButton(
                        Icons.tune,
                        onTap: _showPostOptions,
                        size: 26,
                      ),

                      GestureDetector(
                        onTap: _showPostOptions,
                        child: const Text(
                          'Opsi postingan',
                          style: TextStyle(fontSize: 16, color: muted),
                        ),
                      ),

                      const Spacer(),

                      Container(
                        width: 72,
                        height: 43,
                        decoration: BoxDecoration(
                          color: surface2,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: IconButton(
                          onPressed: () {
                            _message('Fitur tambahan belum tersedia.');
                          },
                          icon: const Icon(
                            Icons.face_retouching_natural_outlined,
                            color: muted,
                            size: 23,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      SizedBox(
                        height: 43,
                        child: ElevatedButton(
                          onPressed: _hasContent && !_isPosting ? _post : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF292929),
                            foregroundColor: Colors.black,
                            disabledForegroundColor: const Color(0xFF777777),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            _isPosting ? 'Memproses' : 'Posting',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ENTRY POINT AGAR FILE BISA DIJALANKAN SENDIRI
void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: PostPage()),
  );
}
