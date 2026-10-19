import 'package:flutter/material.dart';

enum PostMenuAction {
  askAi,
  copyLink,
  createWithTag,
  pin,
  archive,
  hideCounts,
  postOptions,
  delete,
  save,
  interested,
  notInterested,
  mute,
  restrict,
  block,
  report,
}

/// Menu titik tiga pada postingan.
///
///  - postingan biasa : Tanya AI, Salin tautan, Simpan/Tertarik/Tidak tertarik,
///                      Senyapkan/Batasi/Blokir/Laporkan
///  - catatan         : tanpa Tanya AI dan Salin tautan
///  - postingan milik sendiri: hanya bagian atas (tanpa Senyapkan dst.)
///
///   final action = await PostMenuSheet.show(context, isNote: false, ...);
class PostMenuSheet extends StatelessWidget {
  final bool isNote;
  final bool isMine;
  final bool isSaved;

  const PostMenuSheet({
    super.key,
    required this.isNote,
    required this.isMine,
    required this.isSaved,
  });

  static Future<PostMenuAction?> show(
    BuildContext context, {
    required bool isNote,
    required bool isMine,
    required bool isSaved,
  }) {
    return showModalBottomSheet<PostMenuAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PostMenuSheet(
        isNote: isNote,
        isMine: isMine,
        isSaved: isSaved,
      ),
    );
  }

  static const _card = Color(0xFF2B2B2B);
  static const _muted = Color(0xFF8A8A8A);
  static const _danger = Color(0xFFFF3040);

  Widget _group(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: Color(0xFF3C3C3C),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    IconData icon,
    PostMenuAction action, {
    bool danger = false,
    bool muted = false,
  }) {
    final color = danger ? _danger : Colors.white;
    final iconColor = muted ? _muted : color;

    return InkWell(
      onTap: () => Navigator.pop(context, action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(icon, color: iconColor, size: muted ? 28 : 26),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
            if (!isNote) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context, PostMenuAction.askAi),
                child: Container(
                  height: 58,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(29),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: _muted, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tanya Meta AI tentang postingan ini...',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _group([
                _row(context, 'Salin tautan', Icons.link_rounded,
                    PostMenuAction.copyLink),
                if (isMine)
                  _row(context, 'Buat dengan tagar', Icons.tag,
                      PostMenuAction.createWithTag),
              ]),
            ],
            if (isMine)
              _group([
                _row(
                  context,
                  isSaved ? 'Hapus simpanan' : 'Simpan',
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  PostMenuAction.save,
                ),
                if (!isNote) ...[
                  _row(context, 'Sematkan ke profil', Icons.push_pin_outlined,
                      PostMenuAction.pin),
                  _row(context, 'Arsipkan', Icons.history_rounded,
                      PostMenuAction.archive),
                  _row(
                      context,
                      'Sembunyikan jumlah suka dan jumlah dibagikan',
                      Icons.heart_broken_outlined,
                      PostMenuAction.hideCounts),
                  _row(context, 'Opsi postingan', Icons.chevron_right,
                      PostMenuAction.postOptions,
                      muted: true),
                ],
              ])
            else
              _group([
                _row(
                  context,
                  isSaved ? 'Hapus simpanan' : 'Simpan',
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  PostMenuAction.save,
                ),
                _row(context, 'Tertarik', Icons.visibility_outlined,
                    PostMenuAction.interested),
                _row(context, 'Tidak tertarik', Icons.visibility_off_outlined,
                    PostMenuAction.notInterested),
              ]),
            if (isMine)
              _group([
                _row(context, 'Hapus', Icons.delete_outline,
                    PostMenuAction.delete,
                    danger: true),
              ])
            else
              _group([
                _row(context, 'Senyapkan', Icons.person_off_outlined,
                    PostMenuAction.mute),
                _row(context, 'Batasi', Icons.group_outlined,
                    PostMenuAction.restrict),
                _row(context, 'Blokir', Icons.block, PostMenuAction.block,
                    danger: true),
                _row(context, 'Laporkan', Icons.report_gmailerrorred_outlined,
                    PostMenuAction.report,
                    danger: true),
              ]),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}