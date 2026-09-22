import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/producto.dart';
import 'package:osyra/pages/stock_page.dart';

class _FakeStockDataSource implements StockDataSource {
  _FakeStockDataSource(this._productos);

  final List<Producto> _productos;
  bool throwOnGet = false;
  bool throwOnUpdateStock = false;
  bool throwOnUpdateMinimo = false;
  bool throwOnSaveProducto = false;

  @override
  Future<List<Producto>> getProductosConStock() async {
    if (throwOnGet) {
      throw Exception('fallo get');
    }

    return List<Producto>.from(_productos);
  }

  @override
  Future<void> actualizarConfiguracionStock({
    required String productoId,
    int? stock,
    int? stockMinimo,
  }) async {
    if (throwOnUpdateMinimo) {
      throw Exception('fallo minimo');
    }

    final index = _productos.indexWhere((p) => p.id == productoId);
    if (index == -1) return;

    _productos[index] = _productos[index].copyWith(
      stock: stock,
      stockMinimo: stockMinimo,
    );
  }

  @override
  Future<void> actualizarProducto({
    required String productoId,
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  }) async {
    if (throwOnSaveProducto) {
      throw Exception('fallo save producto');
    }

    final index = _productos.indexWhere((p) => p.id == productoId);
    if (index == -1) return;

    _productos[index] = _productos[index].copyWith(
      nombre: nombre,
      tipo: tipo,
      subcategoria: subcategoria,
      denominacionOrigen: denominacionOrigen,
      stock: stock,
      stockMinimo: stockMinimo,
      precio: precio,
    );
  }

  @override
  Future<void> actualizarStock({
    required String productoId,
    required int nuevoStock,
  }) async {
    if (throwOnUpdateStock) {
      throw Exception('fallo stock');
    }

    final index = _productos.indexWhere((p) => p.id == productoId);
    if (index == -1) return;

    _productos[index] = _productos[index].copyWith(stock: nuevoStock);
  }

  @override
  Future<void> crearProducto({
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  }) async {
    if (throwOnSaveProducto) {
      throw Exception('fallo save producto');
    }

    _productos.add(
      Producto(
        id: 'new-${_productos.length + 1}',
        nombre: nombre,
        precio: precio,
        tipo: tipo,
        subcategoria: subcategoria,
        denominacionOrigen: denominacionOrigen,
        stock: stock,
        stockMinimo: stockMinimo,
      ),
    );
  }
}

void main() {
  List<Producto> sampleProductos() {
    return [
      Producto(
        id: 'p1',
        nombre: 'Rioja Reserva',
        precio: 12,
        tipo: 'botella',
        subcategoria: 'Rioja',
        denominacionOrigen: 'Rioja',
        stock: 2,
        stockMinimo: 4,
      ),
      Producto(
        id: 'p2',
        nombre: 'Sardinillas Premium',
        precio: 5,
        tipo: 'conserva',
        subcategoria: 'Conserva',
        stock: 14,
        stockMinimo: 10,
      ),
      Producto(
        id: 'p3',
        nombre: 'Anchoa en tapa',
        precio: 4,
        tipo: 'tapa',
        subcategoria: 'Tapas',
        stock: 5,
        stockMinimo: 10,
      ),
      Producto(
        id: 'p4',
        nombre: 'No gestionado',
        precio: 2,
        tipo: 'copa',
        subcategoria: 'Copas',
        stock: 99,
      ),
    ];
  }

  group('StockPage', () {
    testWidgets('renders stock screen and excludes unsupported product types', (
      tester,
    ) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Control de stock'), findsOneWidget);
      expect(find.text('Nuevo producto'), findsOneWidget);
      expect(find.text('Rioja Reserva'), findsOneWidget);
      expect(find.text('Sardinillas Premium'), findsOneWidget);
      expect(find.text('Anchoa en tapa'), findsOneWidget);
      expect(find.text('No gestionado'), findsNothing);
      expect(find.text('Mostrados'), findsOneWidget);
      expect(find.text('Criticos'), findsOneWidget);
    });

    testWidgets('search and type filters update visible products', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'rioja');
      await tester.pumpAndSettle();

      expect(find.text('Rioja Reserva'), findsOneWidget);
      expect(find.text('Sardinillas Premium'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Conservas/Tapas'));
      await tester.pumpAndSettle();

      expect(find.text('Sardinillas Premium'), findsOneWidget);
      expect(find.text('Anchoa en tapa'), findsOneWidget);
      expect(find.text('Rioja Reserva'), findsNothing);
    });

    testWidgets('critical toggle keeps only low-stock products', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Solo criticos'));
      await tester.pumpAndSettle();

      expect(find.text('Rioja Reserva'), findsOneWidget);
      expect(find.text('Anchoa en tapa'), findsOneWidget);
      expect(find.text('Sardinillas Premium'), findsNothing);
    });

    testWidgets('can increase and decrease stock', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      expect(fake._productos.firstWhere((p) => p.id == 'p1').stock, 2);

      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();
      expect(fake._productos.firstWhere((p) => p.id == 'p1').stock, 3);

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();
      expect(fake._productos.firstWhere((p) => p.id == 'p1').stock, 2);
    });

    testWidgets('can filter by denominacion de origen and clear filter', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Botellas'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Filtrar por D.O. (Espana)'));
      await tester.pumpAndSettle();

      expect(find.text('Denominacion de origen'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar D.O. de Espana'),
        'rioja',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rioja'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'D.O.: Rioja'), findsOneWidget);
      expect(find.text('Rioja Reserva'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Filtrar por D.O. (Espana)'), findsOneWidget);
    });

    testWidgets('can create and edit product from form flow', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nuevo producto'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Berberechos nuevos');
      await tester.enterText(find.byType(TextFormField).at(1), '8');
      await tester.enterText(find.byType(TextFormField).at(2), '20');

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abona').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();

      expect(find.text('Producto creado correctamente'), findsOneWidget);
      expect(
        fake._productos.any((p) => p.nombre == 'Berberechos nuevos'),
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Rioja Editado');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(
        fake._productos.any((p) => p.nombre == 'Rioja Editado'),
        isTrue,
      );
    });

    testWidgets('long press edits stock minimo and validates invalid values', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Rioja Reserva'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '-1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Introduce un entero >= 0'), findsOneWidget);

      await tester.longPress(find.text('Rioja Reserva'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('botella · Rioja\nMin 1'), findsOneWidget);
    });

    testWidgets('shows snackbar and rollback when stock update fails', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos())..throwOnUpdateStock = true;

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      expect(fake._productos.firstWhere((p) => p.id == 'p1').stock, 2);

      await tester.tap(find.byIcon(Icons.add_circle_outline).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo actualizar el stock:'), findsOneWidget);
      expect(fake._productos.firstWhere((p) => p.id == 'p1').stock, 2);
    });

    testWidgets('shows snackbar and rollback when minimo update fails', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos())..throwOnUpdateMinimo = true;

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Rioja Reserva'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo actualizar el minimo:'), findsOneWidget);
      expect(find.text('botella · Rioja\nMin 4'), findsOneWidget);
    });

    testWidgets('shows snackbar when create product fails', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos())..throwOnSaveProducto = true;

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Nuevo producto'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Berberechos nuevos');
      await tester.enterText(find.byType(TextFormField).at(1), '8');
      await tester.enterText(find.byType(TextFormField).at(2), '20');

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abona').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo guardar el producto:'), findsOneWidget);
    });

    testWidgets('shows empty state when filters exclude all products', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos());

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'producto inexistente');
      await tester.pumpAndSettle();

      expect(find.text('No hay productos para mostrar'), findsOneWidget);
    });

    testWidgets('shows snackbar when loading fails', (tester) async {
      final fake = _FakeStockDataSource(sampleProductos())..throwOnGet = true;

      await tester.pumpWidget(
        MaterialApp(home: StockPage(stockDataSource: fake)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Error cargando stock:'), findsOneWidget);
    });
  });
}
