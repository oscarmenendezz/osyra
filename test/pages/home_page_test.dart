import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/pages/home_page.dart';

void main() {
  testWidgets('HomePage renders modules and hero texts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('Sistema Osyra'), findsOneWidget);
    expect(find.text('Centro de operaciones'), findsOneWidget);
    expect(find.text('TPV'), findsOneWidget);
    expect(find.text('Gestion de Stock'), findsOneWidget);
    expect(find.text('Informes'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wine_bar_rounded), findsOneWidget);
    expect(find.byIcon(Icons.query_stats_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
  });

  testWidgets('HomePage supports compact and wide layouts', (tester) async {
    tester.view.devicePixelRatio = 1.0;

    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('Accede a TPV, stock e informes desde una sola vista.'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 844);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.byType(InkWell), findsNWidgets(4));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNWidgets(4));
  });
}
