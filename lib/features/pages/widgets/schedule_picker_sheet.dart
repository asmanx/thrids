import 'package:flutter/material.dart';

const List<String> _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Contoh: "Sen, 19 Okt".
String shortDateLabel(DateTime date) =>
    '${_dayNames[date.weekday - 1]}, ${date.day} ${_monthNames[date.month - 1]}';

/// Contoh: "Besok, pukul 15:00" / "Sen, 19 Okt, pukul 15:00".
String scheduleLabel(DateTime when) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final diff = day.difference(today).inDays;
  final time = 'pukul ${_two(when.hour)}:${_two(when.minute)}';

  if (diff == 0) return 'Hari ini, $time';
  if (diff == 1) return 'Besok, $time';

  return '${shortDateLabel(when)}, $time';
}

/// Sheet "Jadwalkan postingan": pemilih tanggal, jam, dan menit.
/// Mengembalikan [DateTime] (waktu lokal) yang dipilih.
class SchedulePickerSheet extends StatefulWidget {
  final DateTime? initial;

  const SchedulePickerSheet({super.key, this.initial});

  static Future<DateTime?> show(BuildContext context, {DateTime? initial}) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => SchedulePickerSheet(initial: initial),
    );
  }

  @override
  State<SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<SchedulePickerSheet> {
  static const int _days = 76; // hari ini + 75 hari
  static const double _itemExtent = 68;

  late final DateTime _today;
  late int _dayIndex;
  late int _hour;
  late int _minute;

  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  String? _hint;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    // Bawaan: jam penuh berikutnya (mis. 14.08 -> 15.00).
    final start = widget.initial ?? DateTime(now.year, now.month, now.day, now.hour + 1);

    _dayIndex = DateTime(start.year, start.month, start.day)
        .difference(_today)
        .inDays
        .clamp(0, _days - 1);
    _hour = start.hour;
    _minute = start.minute;

    _dayController = FixedExtentScrollController(initialItem: _dayIndex);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _submit() {
    final picked = DateTime(
      _today.year,
      _today.month,
      _today.day + _dayIndex,
      _hour,
      _minute,
    );

    if (picked.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      setState(() => _hint = 'Pilih waktu di masa depan.');
      return;
    }

    Navigator.of(context).pop(picked);
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
    required Alignment alignment,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemExtent,
        diameterRatio: 9,
        perspective: 0.0001,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          setState(() => _hint = null);
          onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final distance = (index - selected).abs();
            final alpha = distance == 0 ? 255 : (distance == 1 ? 120 : 60);

            return Container(
              alignment: alignment,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                label(index),
                style: TextStyle(
                  color: Color.fromARGB(alpha, 255, 255, 255),
                  fontSize: 22,
                  fontWeight: distance == 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF555555),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Jadwalkan postingan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: _itemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  Row(
                    children: [
                      _wheel(
                        controller: _dayController,
                        count: _days,
                        selected: _dayIndex,
                        label: (i) =>
                            shortDateLabel(_today.add(Duration(days: i))),
                        onChanged: (i) => setState(() => _dayIndex = i),
                        alignment: Alignment.centerRight,
                        flex: 5,
                      ),
                      _wheel(
                        controller: _hourController,
                        count: 24,
                        selected: _hour,
                        label: (i) => '$i',
                        onChanged: (i) => setState(() => _hour = i),
                        alignment: Alignment.center,
                        flex: 2,
                      ),
                      _wheel(
                        controller: _minuteController,
                        count: 60,
                        selected: _minute,
                        label: _two,
                        onChanged: (i) => setState(() => _minute = i),
                        alignment: Alignment.center,
                        flex: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _hint!,
                  style: const TextStyle(color: Color(0xFFFF5A5F), fontSize: 15),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F5F7),
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}