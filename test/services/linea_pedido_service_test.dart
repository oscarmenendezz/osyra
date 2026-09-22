import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/linea_pedido_service.dart';

class _FakeLineaPedidoService extends LineaPedidoService {
  final Map<String, Map<String, dynamic>> productos = {};
  final Map<String, int> controlCopeo = {};
  final List<Map<String, dynamic>> lineas = [];

  int _seq = 1;

  @override
  Future<Map<String, dynamic>?> fetchProducto(String productoId) async {
    return productos[productoId];
  }

  @override
  Future<Map<String, dynamic>> fetchStockProducto(String productoId) async {
    return {'stock': productos[productoId]?['stock'] ?? 0};
  }

  @override
  Future<void> updateStockProducto(String productoId, int nuevoStock) async {
    final producto = productos[productoId];
    if (producto != null) {
      producto['stock'] = nuevoStock;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchControlCopeo(String copaProductoId) async {
    if (!controlCopeo.containsKey(copaProductoId)) return null;
    return {'copas_pendientes': controlCopeo[copaProductoId]};
  }

  @override
  Future<void> upsertControlCopeo(Map<String, dynamic> payload) async {
    controlCopeo[payload['copa_producto_id'] as String] =
        (payload['copas_pendientes'] as num).toInt();
  }

  @override
  Future<List<dynamic>> fetchLineasPedido(String pedidoId) async {
    return lineas.where((l) => l['pedido_id'] == pedidoId).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchLineaExistente({
    required String pedidoId,
    required String productoId,
  }) async {
    for (final l in lineas) {
      if (l['pedido_id'] == pedidoId && l['producto_id'] == productoId) {
        return l;
      }
    }
    return null;
  }

  @override
  Future<void> updateLineaCantidad({
    required String lineaId,
    required int cantidad,
  }) async {
    for (final l in lineas) {
      if (l['id'] == lineaId) {
        l['cantidad'] = cantidad;
        break;
      }
    }
  }

  @override
  Future<void> insertLinea(Map<String, dynamic> payload) async {
    lineas.add({'id': 'l${_seq++}', ...payload});
  }

  @override
  Future<void> deleteLineaById(String lineaId) async {
    lineas.removeWhere((l) => l['id'] == lineaId);
  }

  @override
  Future<void> deleteLineasByPedidoId(String pedidoId) async {
    lineas.removeWhere((l) => l['pedido_id'] == pedidoId);
  }
}

void main() {
  group('LineaPedidoService', () {
    test('calcularTotal and calcularTotalItems compute aggregates', () {
      final service = _FakeLineaPedidoService();
      final lineas = [
        {'precio_unitario': 2.5, 'cantidad': 2},
        {'precio_unitario': 4, 'cantidad': 1},
      ];

      expect(service.calcularTotal(lineas), 9);
      expect(service.calcularTotalItems(lineas), 3);
    });

    test('anadirProducto inserts new line and decreases stock for non-copa', () async {
      final service = _FakeLineaPedidoService()
        ..productos['p1'] = {
          'id': 'p1',
          'tipo': 'botella',
          'stock': 3,
          'botella_origen_id': null,
          'copas_por_botella': null,
        };

      await service.anadirProducto(pedidoId: 'ped1', productoId: 'p1', precio: 5);

      expect(service.lineas.length, 1);
      expect(service.lineas.first['cantidad'], 1);
      expect(service.productos['p1']!['stock'], 2);
    });

    test('anadirProducto increments existing line quantity', () async {
      final service = _FakeLineaPedidoService()
        ..productos['p1'] = {
          'id': 'p1',
          'tipo': 'botella',
          'stock': 5,
          'botella_origen_id': null,
          'copas_por_botella': null,
        }
        ..lineas.add({
          'id': 'l1',
          'pedido_id': 'ped1',
          'producto_id': 'p1',
          'cantidad': 2,
          'precio_unitario': 5,
        });

      await service.anadirProducto(pedidoId: 'ped1', productoId: 'p1', precio: 5);

      expect(service.lineas.first['cantidad'], 3);
      expect(service.productos['p1']!['stock'], 4);
    });

    test('anadirProducto throws when non-copa stock is empty', () async {
      final service = _FakeLineaPedidoService()
        ..productos['p1'] = {
          'id': 'p1',
          'tipo': 'botella',
          'stock': 0,
          'botella_origen_id': null,
          'copas_por_botella': null,
        };

      expect(
        () => service.anadirProducto(pedidoId: 'ped1', productoId: 'p1', precio: 5),
        throwsA(isA<StateError>()),
      );
    });

    test('anadirProducto throws when product is missing', () async {
      final service = _FakeLineaPedidoService();

      expect(
        () => service.anadirProducto(
          pedidoId: 'ped1',
          productoId: 'missing',
          precio: 5,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('anadirProducto throws for copa without bottle origin', () async {
      final service = _FakeLineaPedidoService()
        ..productos['copa1'] = {
          'id': 'copa1',
          'tipo': 'copa',
          'stock': 0,
          'botella_origen_id': null,
          'copas_por_botella': 5,
        };

      expect(
        () => service.anadirProducto(pedidoId: 'ped1', productoId: 'copa1', precio: 3),
        throwsA(isA<StateError>()),
      );
    });

    test('anadirProducto allows copa when pending cups exist even with bottle stock 0', () async {
      final service = _FakeLineaPedidoService()
        ..productos['copa1'] = {
          'id': 'copa1',
          'tipo': 'copa',
          'stock': 0,
          'botella_origen_id': 'bot1',
          'copas_por_botella': 5,
        }
        ..productos['bot1'] = {
          'id': 'bot1',
          'tipo': 'botella',
          'stock': 0,
          'botella_origen_id': null,
          'copas_por_botella': null,
        }
        ..controlCopeo['copa1'] = 2;

      await service.anadirProducto(pedidoId: 'ped1', productoId: 'copa1', precio: 3);

      expect(service.lineas.length, 1);
      expect(service.controlCopeo['copa1'], 3);
      expect(service.productos['bot1']!['stock'], 0);
    });

    test('anadirProducto throws for copa when no pending and bottle stock 0', () async {
      final service = _FakeLineaPedidoService()
        ..productos['copa1'] = {
          'id': 'copa1',
          'tipo': 'copa',
          'stock': 0,
          'botella_origen_id': 'bot1',
          'copas_por_botella': 5,
        }
        ..productos['bot1'] = {
          'id': 'bot1',
          'tipo': 'botella',
          'stock': 0,
          'botella_origen_id': null,
          'copas_por_botella': null,
        }
        ..controlCopeo['copa1'] = 0;

      expect(
        () => service.anadirProducto(pedidoId: 'ped1', productoId: 'copa1', precio: 3),
        throwsA(isA<StateError>()),
      );
    });

    test('restarProducto decreases quantity and restores stock', () async {
      final service = _FakeLineaPedidoService()
        ..productos['p1'] = {
          'id': 'p1',
          'tipo': 'botella',
          'stock': 1,
          'botella_origen_id': null,
          'copas_por_botella': null,
        }
        ..lineas.add({
          'id': 'l1',
          'pedido_id': 'ped1',
          'producto_id': 'p1',
          'cantidad': 3,
          'precio_unitario': 5,
        });

      await service.restarProducto(
        lineaId: 'l1',
        cantidadActual: 3,
        productoId: 'p1',
      );

      expect(service.lineas.first['cantidad'], 2);
      expect(service.productos['p1']!['stock'], 2);
    });

    test('restarProducto with quantity 1 removes line', () async {
      final service = _FakeLineaPedidoService()
        ..productos['p1'] = {
          'id': 'p1',
          'tipo': 'botella',
          'stock': 2,
          'botella_origen_id': null,
          'copas_por_botella': null,
        }
        ..lineas.add({
          'id': 'l1',
          'pedido_id': 'ped1',
          'producto_id': 'p1',
          'cantidad': 1,
          'precio_unitario': 5,
        });

      await service.restarProducto(
        lineaId: 'l1',
        cantidadActual: 1,
        productoId: 'p1',
      );

      expect(service.lineas, isEmpty);
      expect(service.productos['p1']!['stock'], 3);
    });

    test('copa flow consumes bottle stock according to copas_por_botella', () async {
      final service = _FakeLineaPedidoService()
        ..productos['copa1'] = {
          'id': 'copa1',
          'tipo': 'copa',
          'stock': 0,
          'botella_origen_id': 'bot1',
          'copas_por_botella': 2,
        }
        ..productos['bot1'] = {
          'id': 'bot1',
          'tipo': 'botella',
          'stock': 1,
          'botella_origen_id': null,
          'copas_por_botella': null,
        };

      await service.anadirProducto(pedidoId: 'ped1', productoId: 'copa1', precio: 3);
      expect(service.controlCopeo['copa1'], 1);
      expect(service.productos['bot1']!['stock'], 1);

      await service.anadirProducto(pedidoId: 'ped1', productoId: 'copa1', precio: 3);
      expect(service.controlCopeo['copa1'], 0);
      expect(service.productos['bot1']!['stock'], 0);
    });

    test('restarProducto for copa can restore bottle stock when crossing boundary', () async {
      final service = _FakeLineaPedidoService()
        ..productos['copa1'] = {
          'id': 'copa1',
          'tipo': 'copa',
          'stock': 0,
          'botella_origen_id': 'bot1',
          'copas_por_botella': 2,
        }
        ..productos['bot1'] = {
          'id': 'bot1',
          'tipo': 'botella',
          'stock': 0,
          'botella_origen_id': null,
          'copas_por_botella': null,
        }
        ..controlCopeo['copa1'] = 0
        ..lineas.add({
          'id': 'l1',
          'pedido_id': 'ped1',
          'producto_id': 'copa1',
          'cantidad': 2,
          'precio_unitario': 3,
        });

      await service.restarProducto(
        lineaId: 'l1',
        cantidadActual: 2,
        productoId: 'copa1',
      );

      expect(service.controlCopeo['copa1'], 1);
      expect(service.productos['bot1']!['stock'], 1);
    });

    test('getLineas returns only lines for requested order', () async {
      final service = _FakeLineaPedidoService()
        ..lineas.addAll([
          {'id': 'l1', 'pedido_id': 'ped1', 'producto_id': 'p1', 'cantidad': 1},
          {'id': 'l2', 'pedido_id': 'ped2', 'producto_id': 'p2', 'cantidad': 1},
        ]);

      final lineas = await service.getLineas('ped1');

      expect(lineas.length, 1);
      expect(lineas.first['id'], 'l1');
    });

    test('limpiarPedido removes all lines for order', () async {
      final service = _FakeLineaPedidoService()
        ..lineas.addAll([
          {'id': 'l1', 'pedido_id': 'ped1', 'producto_id': 'p1', 'cantidad': 1},
          {'id': 'l2', 'pedido_id': 'ped2', 'producto_id': 'p2', 'cantidad': 1},
        ]);

      await service.limpiarPedido('ped1');

      expect(service.lineas.length, 1);
      expect(service.lineas.first['pedido_id'], 'ped2');
    });
  });
}
