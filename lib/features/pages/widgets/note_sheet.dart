import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import 'dashed_bubble.dart';

/// Sheet untuk menulis catatan (postingan sementara / hantu).
///
///   final ok = await NoteSheet.show(context, token: widget.token);
///   if (ok == true) { /* muat ulang feed */ }
class NoteSheet extends StatefulWidget {
  final String token;

  const NoteSheet({super.key, required this.token});

  static Future<bool?> show(BuildContext context, {required String token}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => NoteSheet(token: token),
    );
  }

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  static const _muted = Color(0xFF8A8A8A);
  static const _maxLength = 200;

  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ApiService.createPost(
        token: widget.token,
        content: text,
        isTemporary: true,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF5A5A5A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Catatan baru',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hilang otomatis dari feed setelah 24 jam.',
              style: TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            DashedBubble(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                maxLength: _maxLength,
                style: const TextStyle(color: Colors.white, fontSize: 17),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'Bagikan sesuatu...',
                  hintStyle: TextStyle(color: _muted),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF3040), fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _controller.text.trim().isEmpty || _sending
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F5F7),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF3A3A3A),
                  shape: const StadiumBorder(),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Bagikan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}