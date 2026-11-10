import 'package:flutter_test/flutter_test.dart';
import 'package:capstone_mobile_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArthropodTriageApp(cameras: []));
  });
}