import 'package:flutter_test/flutter_test.dart';
import 'package:rentilly_mobile/main.dart';

void main() {
  testWidgets('Rentilly app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RentillyApp());
    // Advance time past the splash timer (2200ms)
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rentilly'), findsWidgets);
  });
}
