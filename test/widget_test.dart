import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/app.dart';

void main() {
  testWidgets('Login screen renders expected fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MediCare Login'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text("Don't have an account? Register"), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
