
import 'package:flutter_test/flutter_test.dart';
import 'package:thrids/main.dart';

void main() {
  testWidgets('Aplikasi Thrids dapat dibuka',
      (WidgetTester tester) async {
    await tester.pumpWidget(const thridsApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
