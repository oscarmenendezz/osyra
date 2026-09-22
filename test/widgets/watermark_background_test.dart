import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/widgets/watermark_background.dart';

void main() {
  group('WatermarkBackground', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WatermarkBackground(
            child: Text('contenido'),
          ),
        ),
      );

      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('renders gradient layer when colors are provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WatermarkBackground(
            gradientColors: [Color(0xFF111111), Color(0xFF222222)],
            child: SizedBox(),
          ),
        ),
      );

      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('does not crash with invalid image path', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WatermarkBackground(
            assetPath: 'assets/branding/inexistente.png',
            child: SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(WatermarkBackground), findsOneWidget);
    });
  });
}
