import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/stock_service.dart';

class _FakeStockService extends StockService {
  _FakeStockService(this.data);

  final List<dynamic> data;
  final List<Map<String, dynamic>> updates = [];
  final List<Map<String, dynamic>> inserts = [];

  @override
  Future<List<dynamic>> fetchProductosConStock() async => data;

  @override
  Future<void> updateProductoById({required String productoId, required Map<String, dynamic> update}) async {
    updates.add({'productoId': productoId, 'update': update});
  }

  @override
  Future<void> insertProducto(Map<String, dynamic> payload) async {
    inserts.add(payload);
  }
}

void main() {
  test('StockService maps products with stock', () async {
    final service = _FakeStockService([
      {
        'id': 'p1',
        'nombre': 'Conserva',
        'precio': 4,
        'tipo': 'conserva',
        'subcategoria': 'Conserva',
        'stock': 8,
        'stock_minimo': 2,
      },
    ]);

    final productos = await service.getProductosConStock();

    expect(productos.length, 1);
    expect(productos.first.stock, 8);
    expect(productos.first.stockMinimo, 2);
  });

  test('StockService updates stock config only when payload is not empty', () async {
    final service = _FakeStockService([]);

    await service.actualizarConfiguracionStock(productoId: 'p1');
    expect(service.updates, isEmpty);

    await service.actualizarConfiguracionStock(productoId: 'p1', stockMinimo: 5);
    expect(service.updates.length, 1);
    expect(service.updates.first['productoId'], 'p1');
  });

  test('StockService create and update product produce expected payloads', () async {
    final service = _FakeStockService([]);

    await service.crearProducto(
      nombre: 'Nuevo',
      tipo: 'botella',
      subcategoria: 'Rioja',
      denominacionOrigen: 'Rioja',
      stock: 7,
      stockMinimo: 2,
      precio: 10,
    );

    await service.actualizarProducto(
      productoId: 'p1',
      nombre: 'Editado',
      tipo: 'conserva',
      subcategoria: 'Conserva',
      denominacionOrigen: null,
      stock: 3,
      stockMinimo: 1,
      precio: 5,
    );

    expect(service.inserts.length, 1);
    expect(service.inserts.first['nombre'], 'Nuevo');
    expect(service.updates.length, 1);
    expect(service.updates.first['productoId'], 'p1');
  });
}
