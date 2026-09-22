import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/pages/home_page.dart';
import 'package:osyra/splash_screen.dart';

void main() {
  testWidgets('SplashScreen navigates to HomePage after delay', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });
}
