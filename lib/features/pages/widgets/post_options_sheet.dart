import 'package:flutter/material.dart';

/// Pengaturan postingan dari sheet "Opsi postingan".
class PostOptions {
  /// anyone | followers | following | mentioned
  final String replyAudience;
  final bool approveReplies;

  const PostOptions({
    this.replyAudience = 'anyone',
    this.approveReplies = false,
  });

  PostOptions copyWith({String? replyAudience, bool? approveReplies}) {
    return PostOptions(
      replyAudience: replyAudience ?? this.replyAudience,
      approveReplies: approveReplies ?? this.approveReplies,
    );
  }
}

/// Sheet "Opsi postingan": siapa yang bisa membalas, tinjau balasan, audiens.
///
///   final result = await PostOptionsSheet.show(context, _options);
class PostOptionsSheet extends StatefulWidget {
  final PostOptions initial;

  const PostOptionsSheet({super.key, required this.initial});

  static Future<PostOptions?> show(BuildContext context, PostOptions initial) {
    return showModalBottomSheet<PostOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PostOptionsSheet(initial: initial),
    );
  }

  @override
  State<PostOptionsSheet> createState() => _PostOptionsSheetState();
}

class _PostOptionsSheetState extends State<PostOptionsSheet> {
  static const card = Color(0xFF2B2B2B);
  static const muted = Color(0xFF8A8A8A);

  static const _choices = <(String, String)>[
    ('anyone', 'Siapa saja'),
    ('followers', 'Pengikut Anda'),
    ('following', 'Profil yang Anda ikuti'),
    ('mentioned', 'Profil yang Anda sebutkan'),
  ];

  late PostOptions _options = widget.initial;

  Widget _radio(bool selected) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.white : Colors.transparent,
        border: Border.all(
          color: selected ? Colors.white : const Color(0xFF5A5A5A),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Text(text, style: const TextStyle(color: muted, fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A5A5A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Opsi postingan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: _label('Siapa yang bisa membalas dan mengutip'),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _choices.length; i++) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => setState(
                          () => _options =
                              _options.copyWith(replyAudience: _choices[i].$1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _choices[i].$2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              _radio(_options.replyAudience == _choices[i].$1),
                            ],
                          ),
                        ),
                      ),
                      if (i < _choices.length - 1)
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Color(0xFF3C3C3C),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tinjau dan setujui balasan',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                    Switch(
                      value: _options.approveReplies,
                      onChanged: (v) => setState(
                        () => _options = _options.copyWith(approveReplies: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Align(alignment: Alignment.centerLeft, child: _label('Audiens')),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Berbagi ke aplikasi lain belum tersedia.'),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Juga bagikan di',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Nonaktif',
                              style: TextStyle(color: muted, fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: muted, size: 28),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _options),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F5F7),
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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