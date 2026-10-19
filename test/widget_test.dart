import 'package:flutter_test/flutter_test.dart';
import 'package:thrids/main.dart';

void main() {
  testWidgets('ThridsApp berhasil ditampilkan', (WidgetTester tester) async {
    await tester.pumpWidget(const ThridsApp());

    expect(find.byType(ThridsApp), findsOneWidget);
  });
}
