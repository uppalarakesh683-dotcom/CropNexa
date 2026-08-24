import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets(
    'CropNexa app loads successfully',
    (WidgetTester tester) async {
      await tester.pumpWidget(const CropNexaApp());

      await tester.pumpAndSettle();

      expect(find.text('CROP NEXA'), findsWidgets);
    },
  );
}