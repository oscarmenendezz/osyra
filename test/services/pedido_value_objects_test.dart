import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/pedido_service.dart';

void main() {
  group('Pedido value objects', () {
    test('TicketLineaInforme computes totalLinea', () {
      final linea = TicketLineaInforme(
        productoNombre: 'Albariño',
        productoTipo: 'copa',
        productoDenominacionOrigen: 'Rias Baixas',
        ivaTipo: 21,
        cantidad: 3,
        precioUnitario: 2.5,
      );

      expect(linea.totalLinea, 7.5);
    });

    test('TicketInforme uses empty line list by default', () {
      final ticket = TicketInforme(
        id: 't1',
        mesaId: 'm1',
        mesaNombre: 'Terraza 1',
        fecha: DateTime(2026, 1, 1),
        total: 42,
      );

      expect(ticket.lineas, isEmpty);
      expect(ticket.total, 42);
    });

    test('TicketClienteInforme keeps provided lines', () {
      final lineas = [
        TicketLineaInforme(
          productoNombre: 'Mencia',
          productoTipo: 'botella',
          ivaTipo: 21,
          cantidad: 1,
          precioUnitario: 18,
        ),
      ];

      final ticket = TicketClienteInforme(
        id: 'tc1',
        fecha: DateTime(2026, 2, 10),
        mesaNombre: 'Sala',
        subtotal: 18,
        descuentoAplicado: 2,
        descuentoPorcentaje: 10,
        total: 16,
        lineas: lineas,
      );

      expect(ticket.lineas.length, 1);
      expect(ticket.lineas.first.productoNombre, 'Mencia');
      expect(ticket.total, 16);
    });

    test('InformeClientePersonalizado stores aggregate values', () {
      final informe = InformeClientePersonalizado(
        clienteId: 'cli-1',
        inicio: DateTime(2026, 1, 1),
        fin: DateTime(2026, 12, 31),
        pedidos: 4,
        totalGastado: 120,
        totalAhorrado: 9,
        ticketMedio: 30,
        tickets: const [],
      );

      expect(informe.clienteId, 'cli-1');
      expect(informe.pedidos, 4);
      expect(informe.totalGastado, 120);
      expect(informe.totalAhorrado, 9);
      expect(informe.ticketMedio, 30);
      expect(informe.tickets, isEmpty);
    });
  });
}
