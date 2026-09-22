import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/producto_service.dart';

class _FakeProductoService extends ProductoService {
  _FakeProductoService(this.data);

  final List<dynamic> data;

  @override
  Future<List<dynamic>> fetchProductos() async => data;
}

void main() {
  test('ProductoService maps productos from data source', () async {
    final service = _FakeProductoService([
      {
        'id': 'p1',
        'nombre': 'Rioja',
        'precio': 12,
        'tipo': 'botella',
        'subcategoria': 'Tinto',
      },
    ]);

    final productos = await service.getProductos();

    expect(productos.length, 1);
    expect(productos.first.nombre, 'Rioja');
    expect(productos.first.tipo, 'botella');
  });
}
