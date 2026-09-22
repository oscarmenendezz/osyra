import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/pedido_service.dart';

class _FakePedidoService extends PedidoService {
  Map<String, dynamic>? pedidoAbierto;
  Map<String, dynamic>? nuevoPedido;
  Map<String, dynamic>? updatePayload;
  String? updatedPedidoId;

  List<dynamic> pedidosCerrados = [];
  List<dynamic> pedidosCliente = [];
  List<dynamic> mesas = [];
  List<dynamic> lineas = [];

  @override
  Future<Map<String, dynamic>?> fetchPedidoAbierto({required String mesaId}) async {
    return pedidoAbierto;
  }

  @override
  Future<Map<String, dynamic>> insertPedidoAbierto({required String mesaId}) async {
    return nuevoPedido ??
        {
          'id': 'nuevo-1',
          'mesa_id': mesaId,
          'estado': 'abierto',
          'total': 0,
        };
  }

  @override
  Future<void> updatePedidoById({
    required String pedidoId,
    required Map<String, dynamic> payload,
  }) async {
    updatedPedidoId = pedidoId;
    updatePayload = payload;
  }

  @override
  Future<List<dynamic>> fetchPedidosCerradosEnRango({
    required String inicioIso,
    required String finExclusivoIso,
  }) async {
    return pedidosCerrados;
  }

  @override
  Future<List<dynamic>> fetchPedidosClienteEnRango({
    required String clienteId,
    required String inicioIso,
    required String finExclusivoIso,
    required int limiteTickets,
  }) async {
    return pedidosCliente;
  }

  @override
  Future<List<dynamic>> fetchMesasByIds(List<String> mesaIds) async {
    return mesas;
  }

  @override
  Future<List<dynamic>> fetchLineasByPedidoIds(List<String> pedidoIds) async {
    return lineas;
  }
}

void main() {
  group('PedidoService', () {
    test('getOrCreatePedido returns existing open order', () async {
      final service = _FakePedidoService()
        ..pedidoAbierto = {'id': 'p1', 'mesa_id': 'm1', 'estado': 'abierto'};

      final pedido = await service.getOrCreatePedido('m1');

      expect(pedido['id'], 'p1');
      expect(pedido['estado'], 'abierto');
    });

    test('getOrCreatePedido creates when no existing order', () async {
      final service = _FakePedidoService()
        ..pedidoAbierto = null
        ..nuevoPedido = {'id': 'p2', 'mesa_id': 'm2', 'estado': 'abierto'};

      final pedido = await service.getOrCreatePedido('m2');

      expect(pedido['id'], 'p2');
      expect(pedido['mesa_id'], 'm2');
    });

    test('cerrarPedido builds payload with defaults', () async {
      final service = _FakePedidoService();

      await service.cerrarPedido(pedidoId: 'p1', total: 33.5);

      expect(service.updatedPedidoId, 'p1');
      expect(service.updatePayload!['estado'], 'cerrado');
      expect(service.updatePayload!['subtotal'], 33.5);
      expect(service.updatePayload!['descuento_aplicado'], 0);
      expect(service.updatePayload!['descuento_porcentaje'], 0);
    });

    test('cerrarPedido preserves explicit discount and affiliate values', () async {
      final service = _FakePedidoService();

      await service.cerrarPedido(
        pedidoId: 'p2',
        total: 50,
        subtotal: 60,
        descuentoAplicado: 10,
        descuentoPorcentaje: 16.67,
        clienteAfiliadoId: 'c1',
        afiliadoNumero: 'AF-9',
      );

      expect(service.updatedPedidoId, 'p2');
      expect(service.updatePayload!['subtotal'], 60);
      expect(service.updatePayload!['descuento_aplicado'], 10);
      expect(service.updatePayload!['descuento_porcentaje'], 16.67);
      expect(service.updatePayload!['cliente_afiliado_id'], 'c1');
      expect(service.updatePayload!['afiliado_numero'], 'AF-9');
    });

    test('getTicketsCerradosEnRango returns empty list when no data', () async {
      final service = _FakePedidoService()..pedidosCerrados = [];

      final tickets = await service.getTicketsCerradosEnRango(
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 1, 31),
      );

      expect(tickets, isEmpty);
    });

    test('getTicketsCerradosEnRango maps mesas and lineas', () async {
      final service = _FakePedidoService()
        ..pedidosCerrados = [
          {
            'id': 'p1',
            'mesa_id': 'm1',
            'fecha': '2026-01-10T12:00:00.000Z',
            'total': 20,
          },
        ]
        ..mesas = [
          {'id': 'm1', 'nombre': 'Terraza'},
        ]
        ..lineas = [
          {
            'pedido_id': 'p1',
            'cantidad': 2,
            'precio_unitario': 5,
            'productos': {
              'nombre': 'Rioja',
              'tipo': 'botella',
              'iva_tipo': 21,
              'denominacion_origen': 'Rioja',
            },
          },
        ];

      final tickets = await service.getTicketsCerradosEnRango(
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 1, 31),
      );

      expect(tickets.length, 1);
      expect(tickets.first.mesaNombre, 'Terraza');
      expect(tickets.first.total, 20);
      expect(tickets.first.lineas.length, 1);
      expect(tickets.first.lineas.first.productoNombre, 'Rioja');
    });

    test('getTicketsCerradosEnRango uses mesa id fallback and filters total 0', () async {
      final service = _FakePedidoService()
        ..pedidosCerrados = [
          {
            'id': 'p1',
            'mesa_id': 'm1',
            'fecha': '2026-01-10T12:00:00.000Z',
            'total': 0,
          },
          {
            'id': 'p2',
            'mesa_id': 'm2',
            'fecha': '2026-01-10T12:00:00.000Z',
            'total': 10,
          },
        ]
        ..mesas = []
        ..lineas = [];

      final tickets = await service.getTicketsCerradosEnRango(
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 1, 31),
      );

      expect(tickets.length, 1);
      expect(tickets.first.id, 'p2');
      expect(tickets.first.mesaNombre, 'm2');
    });

    test('getInformePersonalizadoPorCliente returns zeroed report when no tickets', () async {
      final service = _FakePedidoService()..pedidosCliente = [];

      final informe = await service.getInformePersonalizadoPorCliente(
        clienteId: 'c1',
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 12, 31),
      );

      expect(informe.clienteId, 'c1');
      expect(informe.pedidos, 0);
      expect(informe.totalGastado, 0);
      expect(informe.totalAhorrado, 0);
      expect(informe.tickets, isEmpty);
    });

    test('getInformePersonalizadoPorCliente computes totals and ticketMedio', () async {
      final service = _FakePedidoService()
        ..pedidosCliente = [
          {
            'id': 'p1',
            'mesa_id': 'm1',
            'fecha': '2026-03-12T20:00:00.000Z',
            'subtotal': 30,
            'descuento_aplicado': 3,
            'descuento_porcentaje': 10,
            'total': 27,
          },
          {
            'id': 'p2',
            'mesa_id': 'm2',
            'fecha': '2026-03-13T20:00:00.000Z',
            'subtotal': 20,
            'descuento_aplicado': 0,
            'descuento_porcentaje': 0,
            'total': 20,
          },
        ]
        ..mesas = [
          {'id': 'm1', 'nombre': 'Salon 1'},
          {'id': 'm2', 'nombre': 'Salon 2'},
        ]
        ..lineas = [
          {
            'pedido_id': 'p1',
            'cantidad': 1,
            'precio_unitario': 27,
            'productos': {
              'nombre': 'Menu',
              'tipo': 'tapa',
              'iva_tipo': 10,
              'denominacion_origen': null,
            },
          },
        ];

      final informe = await service.getInformePersonalizadoPorCliente(
        clienteId: 'c1',
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 12, 31),
      );

      expect(informe.pedidos, 2);
      expect(informe.totalGastado, 47);
      expect(informe.totalAhorrado, 3);
      expect(informe.ticketMedio, 23.5);
      expect(informe.tickets.first.mesaNombre, 'Salon 1');
      expect(informe.tickets.first.lineas.length, 1);
    });

    test('getInformePersonalizadoPorCliente handles null fields and invalid dates', () async {
      final service = _FakePedidoService()
        ..pedidosCliente = [
          {
            'id': null,
            'mesa_id': null,
            'fecha': 'fecha-invalida',
            'subtotal': null,
            'descuento_aplicado': null,
            'descuento_porcentaje': null,
            'total': null,
          },
        ]
        ..mesas = []
        ..lineas = [
          {
            'pedido_id': null,
            'cantidad': 1,
            'precio_unitario': 1,
            'productos': {'nombre': 'X', 'tipo': 'tapa', 'iva_tipo': 10},
          },
        ];

      final informe = await service.getInformePersonalizadoPorCliente(
        clienteId: 'c1',
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 1, 31),
      );

      expect(informe.pedidos, 1);
      expect(informe.totalGastado, 0);
      expect(informe.totalAhorrado, 0);
      expect(informe.tickets.first.id, '');
      expect(informe.tickets.first.mesaNombre, '');
      expect(informe.tickets.first.lineas, isEmpty);
    });
  });
}
