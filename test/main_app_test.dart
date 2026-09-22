import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/main.dart';
import 'package:osyra/splash_screen.dart';

void main() {
  testWidgets('OsyraApp configures MaterialApp and theme', (tester) async {
    await tester.pumpWidget(const OsyraApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.title, 'Osyra');
    expect(app.home, isA<SplashScreen>());
    expect(app.theme, isNotNull);
    expect(app.theme!.useMaterial3, isTrue);
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFFF2ECFB));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
