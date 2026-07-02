import 'package:flutter_test/flutter_test.dart';

import 'package:runix_store/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RunixStoreApp());
    expect(find.text('Runix Store'), findsWidgets);
  });
}
