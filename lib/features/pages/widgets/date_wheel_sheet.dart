import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Pemilih tanggal berupa bottom sheet dengan tiga roda (bulan, tanggal,
/// tahun) dan tombol "Selesai".
///
///   final date = await DateWheelSheet.show(
///     context,
///     title: 'Sebelum tanggal',
///     initial: DateTime.now(),
///   );
///   if (date != null) { ... }   // null = sheet ditutup tanpa memilih
class DateWheelSheet extends StatefulWidget {
  final String title;
  final DateTime initial;
  final DateTime min;
  final DateTime max;

  const DateWheelSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required String title,
    DateTime? initial,
    DateTime? min,
    DateTime? max,
  }) {
    final now = DateTime.now();
    final last = max ?? DateTime(now.year, now.month, now.day);
    final first = min ?? DateTime(2020);
    var start = initial ?? last;

    if (start.isAfter(last)) start = last;
    if (start.isBefore(first)) start = first;

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (_) => DateWheelSheet(
        title: title,
        initial: DateTime(start.year, start.month, start.day),
        min: first,
        max: last,
      ),
    );
  }

  @override
  State<DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<DateWheelSheet> {
  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const _itemExtent = 56.0;

  late int _year = widget.initial.year;
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;

  late final FixedExtentScrollController _monthCtrl =
      FixedExtentScrollController(initialItem: _month - 1);
  late final FixedExtentScrollController _dayCtrl =
      FixedExtentScrollController(initialItem: _day - 1);
  late final FixedExtentScrollController _yearCtrl =
      FixedExtentScrollController(initialItem: _year - widget.min.year);

  int get _yearCount => widget.max.year - widget.min.year + 1;

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  /// Kalau tanggal terpilih melewati jumlah hari bulan itu (mis. 31 Februari),
  /// geser roda tanggal ke hari terakhir.
  void _clampDay() {
    final max = _daysInMonth;

    if (_day > max) {
      _day = max;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dayCtrl.hasClients) _dayCtrl.jumpToItem(max - 1);
      });
    }
  }

  void _done() {
    var result = DateTime(_year, _month, _day);

    if (result.isAfter(widget.max)) result = widget.max;
    if (result.isBefore(widget.min)) result = widget.min;

    Navigator.of(context).pop(result);
  }

  Color _colorFor(int index, int selected) {
    final distance = (index - selected).abs();

    if (distance == 0) return Colors.white;
    if (distance == 1) return const Color(0xFF8A8A8A);
    return const Color(0xFF4A4A4A);
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required String Function(int index) label,
    required ValueChanged<int> onChanged,
    required Alignment alignment,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: _itemExtent,
      diameterRatio: 2.2,
      squeeze: 1.0,
      useMagnifier: false,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onChanged,
      childCount: count,
      itemBuilder: (_, index) => Align(
        alignment: alignment,
        child: Text(
          label(index),
          style: TextStyle(
            color: _colorFor(index, selected),
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF5A5A5A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: _itemExtent * 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sorotan baris terpilih.
                Container(
                  height: _itemExtent,
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: _wheel(
                            controller: _monthCtrl,
                            count: 12,
                            selected: _month - 1,
                            label: (i) => _months[i],
                            alignment: Alignment.centerRight,
                            onChanged: (i) => setState(() {
                              _month = i + 1;
                              _clampDay();
                            }),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _wheel(
                          controller: _dayCtrl,
                          count: _daysInMonth,
                          selected: _day - 1,
                          label: (i) => '${i + 1}',
                          alignment: Alignment.center,
                          onChanged: (i) => setState(() => _day = i + 1),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _wheel(
                          controller: _yearCtrl,
                          count: _yearCount,
                          selected: _year - widget.min.year,
                          label: (i) => '${widget.min.year + i}',
                          alignment: Alignment.center,
                          onChanged: (i) => setState(() {
                            _year = widget.min.year + i;
                            _clampDay();
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: SizedBox(
              width: double.infinity,
              height: 66,
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F5F7),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}