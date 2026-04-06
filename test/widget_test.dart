import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_app/main.dart';

void main() {
  testWidgets('Pesa Budget app loads successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PesaBudgetApp());
    expect(find.text('Pesa Budget Tracker'), findsOneWidget);
  });
}
