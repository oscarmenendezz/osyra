import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/producto.dart';
import 'package:osyra/pages/producto_stock_form_page.dart';

Finder _textFieldAt(int index) => find.byType(TextFormField).at(index);
Finder _dropdownAt(int index) => find.byType(DropdownButtonFormField<String>).at(index);

void main() {
  group('ProductoStockFormPage', () {
    testWidgets('new product defaults and validates required fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProductoStockFormPage(
            denominacionesOrigen: ['Rioja', 'Ribera del Duero'],
          ),
        ),
      );

      expect(find.text('Nuevo producto'), findsOneWidget);
      expect(find.text('Crear producto'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));

      final stockMinimoField = tester.widget<TextFormField>(_textFieldAt(1));
      expect(stockMinimoField.controller?.text, '4');

      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();

      expect(find.text('Nombre obligatorio'), findsOneWidget);
      expect(find.text('Selecciona una D.O.'), findsOneWidget);
    });

    testWidgets('switching category to conserva hides DO and updates stock minimo in create mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProductoStockFormPage(
            denominacionesOrigen: ['Rioja', 'Ribera del Duero'],
          ),
        ),
      );

      await tester.tap(_dropdownAt(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conserva').last);
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      final stockMinimoField = tester.widget<TextFormField>(_textFieldAt(1));
      expect(stockMinimoField.controller?.text, '10');
    });

    testWidgets('saving new vino returns expected payload', (tester) async {
      ProductoStockPayload? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<ProductoStockPayload>(
                        MaterialPageRoute(
                          builder: (_) => const ProductoStockFormPage(
                            denominacionesOrigen: ['Rioja', 'Ribera del Duero'],
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldAt(0), 'Vino de prueba');
      await tester.enterText(_textFieldAt(1), '6');
      await tester.enterText(_textFieldAt(2), '15');

      await tester.tap(_dropdownAt(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rioja').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.nombre, 'Vino de prueba');
      expect(result!.tipo, 'botella');
      expect(result!.subcategoria, 'Rioja');
      expect(result!.denominacionOrigen, 'Rioja');
      expect(result!.stock, 15);
      expect(result!.stockMinimo, 6);
    });

    testWidgets('edit mode keeps existing stock minimo when changing category', (tester) async {
      final producto = Producto(
        id: 'p1',
        nombre: 'Conserva edit',
        precio: 5,
        tipo: 'conserva',
        subcategoria: 'conserva',
        stock: 7,
        stockMinimo: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductoStockFormPage(
            producto: producto,
            denominacionesOrigen: const ['Rioja'],
          ),
        ),
      );

      expect(find.text('Editar producto'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);

      final stockMinimoBefore = tester.widget<TextFormField>(_textFieldAt(1));
      expect(stockMinimoBefore.controller?.text, '2');

      await tester.tap(_dropdownAt(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vino').last);
      await tester.pumpAndSettle();

      final stockMinimoAfter = tester.widget<TextFormField>(_textFieldAt(1));
      expect(stockMinimoAfter.controller?.text, '2');
    });
  });
}
