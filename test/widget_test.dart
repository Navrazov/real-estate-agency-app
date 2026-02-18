import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_app/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RealEstateApp());
    await tester.pump();
    expect(find.byType(RealEstateApp), findsOneWidget);
  });
}
