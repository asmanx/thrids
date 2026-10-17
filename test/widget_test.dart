import 'package:flutter_test/flutter_test.dart';
import 'package:thrids_beranda/main.dart';

void main() {
  testWidgets('Aplikasi Threads berhasil ditampilkan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ThreadsApp());

    expect(find.byType(ThreadsApp), findsOneWidget);
  });
}
