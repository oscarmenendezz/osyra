import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/pages/scan_qr_page.dart';

void main() {
  testWidgets('ScanQrPage renders title and helper text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanQrPage()));

    expect(find.text('Escanear QR afiliado'), findsOneWidget);
    expect(
      find.text('Apunta al QR recibido en el email del cliente afiliado.'),
      findsOneWidget,
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
