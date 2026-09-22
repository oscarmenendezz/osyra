import 'package:supabase_flutter/supabase_flutter.dart';

class TicketLineaInforme {
  final String productoNombre;
  final String productoTipo;
  final String? productoDenominacionOrigen;
  final double ivaTipo;
  final int cantidad;
  final double precioUnitario;

  TicketLineaInforme({
    required this.productoNombre,
    required this.productoTipo,
    this.productoDenominacionOrigen,
    required this.ivaTipo,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get totalLinea => cantidad * precioUnitario;
}

class TicketInforme {
  final String id;
  final String mesaId;
  final String mesaNombre;
  final DateTime fecha;
  final double total;
  final List<TicketLineaInforme> lineas;

  TicketInforme({
    required this.id,
    required this.mesaId,
    required this.mesaNombre,
    required this.fecha,
    required this.total,
    List<TicketLineaInforme>? lineas,
  }) : lineas = lineas ?? const <TicketLineaInforme>[];
}

class TicketClienteInforme {
  final String id;
  final DateTime fecha;
  final String mesaNombre;
  final double subtotal;
  final double descuentoAplicado;
  final double descuentoPorcentaje;
  final double total;
  final List<TicketLineaInforme> lineas;

  TicketClienteInforme({
    required this.id,
    required this.fecha,
    required this.mesaNombre,
    required this.subtotal,
    required this.descuentoAplicado,
    required this.descuentoPorcentaje,
    required this.total,
    List<TicketLineaInforme>? lineas,
  }) : lineas = lineas ?? const <TicketLineaInforme>[];
}

class InformeClientePersonalizado {
  final String clienteId;
  final DateTime inicio;
  final DateTime fin;
  final int pedidos;
  final double totalGastado;
  final double totalAhorrado;
  final double ticketMedio;
  final List<TicketClienteInforme> tickets;

  InformeClientePersonalizado({
    required this.clienteId,
    required this.inicio,
    required this.fin,
    required this.pedidos,
    required this.totalGastado,
    required this.totalAhorrado,
    required this.ticketMedio,
    required this.tickets,
  });
}

class PedidoService {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  Future<Map<String, dynamic>> getOrCreatePedido(String mesaId) async {
    final existing = await fetchPedidoAbierto(mesaId: mesaId);

    if (existing != null) {
      return existing;
    }

    final nuevo = await insertPedidoAbierto(mesaId: mesaId);

    return nuevo;
  }

  Future<void> cerrarPedido({
    required String pedidoId,
    required double total,
    double? subtotal,
    double? descuentoAplicado,
    double? descuentoPorcentaje,
    String? clienteAfiliadoId,
    String? afiliadoNumero,
  }) async {
    final payload = <String, dynamic>{
      'estado': 'cerrado',
      'total': total,
      'subtotal': subtotal ?? total,
      'descuento_aplicado': descuentoAplicado ?? 0,
      'descuento_porcentaje': descuentoPorcentaje ?? 0,
      'cliente_afiliado_id': clienteAfiliadoId,
      'afiliado_numero': afiliadoNumero,
    };

    await updatePedidoById(pedidoId: pedidoId, payload: payload);
  }

  Future<List<TicketInforme>> getTicketsCerradosEnRango({
    required DateTime inicio,
    required DateTime fin,
  }) async {
    final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
    final finExclusivo = DateTime(fin.year, fin.month, fin.day + 1);

    final pedidosData = await fetchPedidosCerradosEnRango(
      inicioIso: inicioDia.toIso8601String(),
      finExclusivoIso: finExclusivo.toIso8601String(),
    );

    if (pedidosData.isEmpty) {
      return [];
    }

    final pedidoIds = pedidosData
        .map<String>((p) => p['id'] as String)
        .toList();
    final mesaIds = pedidosData
        .map<String>((p) => p['mesa_id'] as String)
        .toSet()
        .toList();

    final mesasData = mesaIds.isEmpty
        ? []
        : await fetchMesasByIds(mesaIds);

    final lineasData = await fetchLineasByPedidoIds(pedidoIds);

    final nombreMesaById = <String, String>{
      for (final mesa in mesasData)
        mesa['id'] as String: mesa['nombre'] as String,
    };

    final lineasPorPedido = <String, List<TicketLineaInforme>>{};
    for (final linea in lineasData) {
      final pedidoId = linea['pedido_id'] as String;
      final cantidad = (linea['cantidad'] as num).toInt();
      final precioUnitario = (linea['precio_unitario'] as num).toDouble();
      final productoNombre =
          linea['productos']?['nombre'] as String? ?? 'Producto';
      final productoTipo =
          linea['productos']?['tipo'] as String? ?? 'desconocido';
      final productoDenominacionOrigen =
          linea['productos']?['denominacion_origen'] as String?;
      final ivaTipo =
          (linea['productos']?['iva_tipo'] as num?)?.toDouble() ?? 21;

      lineasPorPedido.putIfAbsent(pedidoId, () => []);
      lineasPorPedido[pedidoId]!.add(
        TicketLineaInforme(
          productoNombre: productoNombre,
          productoTipo: productoTipo,
          productoDenominacionOrigen: productoDenominacionOrigen,
          ivaTipo: ivaTipo,
          cantidad: cantidad,
          precioUnitario: precioUnitario,
        ),
      );
    }

    return pedidosData
        .where((pedido) {
          final total = (pedido['total'] as num?)?.toDouble() ?? 0;
          return total > 0;
        })
        .map<TicketInforme>((pedido) {
          final id = pedido['id'] as String;
          final mesaId = pedido['mesa_id'] as String;
          final fechaRaw = pedido['fecha'] as String?;

          return TicketInforme(
            id: id,
            mesaId: mesaId,
            mesaNombre: nombreMesaById[mesaId] ?? mesaId,
            fecha: DateTime.tryParse(fechaRaw ?? '') ?? DateTime.now(),
            total: (pedido['total'] as num?)?.toDouble() ?? 0,
            lineas: lineasPorPedido[id] ?? const <TicketLineaInforme>[],
          );
        })
        .toList();
  }

  Future<InformeClientePersonalizado> getInformePersonalizadoPorCliente({
    required String clienteId,
    required DateTime inicio,
    required DateTime fin,
    int limiteTickets = 100,
  }) async {
    final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
    final finExclusivo = DateTime(fin.year, fin.month, fin.day + 1);

    final pedidosData = await fetchPedidosClienteEnRango(
      clienteId: clienteId,
      inicioIso: inicioDia.toIso8601String(),
      finExclusivoIso: finExclusivo.toIso8601String(),
      limiteTickets: limiteTickets,
    );

    if (pedidosData.isEmpty) {
      return InformeClientePersonalizado(
        clienteId: clienteId,
        inicio: inicioDia,
        fin: DateTime(fin.year, fin.month, fin.day),
        pedidos: 0,
        totalGastado: 0,
        totalAhorrado: 0,
        ticketMedio: 0,
        tickets: const [],
      );
    }

    final mesaIds = pedidosData
        .map<String?>((p) => p['mesa_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final mesasData = mesaIds.isEmpty
        ? []
          : await fetchMesasByIds(mesaIds);

    final pedidoIds = pedidosData
        .map<String?>((p) => p['id'] as String?)
        .whereType<String>()
        .toList();

    final lineasData = pedidoIds.isEmpty
        ? []
        : await fetchLineasByPedidoIds(pedidoIds);

    final nombreMesaById = <String, String>{
      for (final mesa in mesasData)
        mesa['id'] as String: mesa['nombre'] as String? ?? 'Mesa',
    };

    final lineasPorPedido = <String, List<TicketLineaInforme>>{};
    for (final linea in lineasData) {
      final pedidoId = linea['pedido_id'] as String?;
      if (pedidoId == null) continue;

      final cantidad = (linea['cantidad'] as num?)?.toInt() ?? 0;
      final precioUnitario =
          (linea['precio_unitario'] as num?)?.toDouble() ?? 0;
      final productoNombre =
          linea['productos']?['nombre'] as String? ?? 'Producto';
      final productoTipo =
          linea['productos']?['tipo'] as String? ?? 'desconocido';
      final productoDenominacionOrigen =
          linea['productos']?['denominacion_origen'] as String?;
      final ivaTipo =
          (linea['productos']?['iva_tipo'] as num?)?.toDouble() ?? 21;

      lineasPorPedido.putIfAbsent(pedidoId, () => []);
      lineasPorPedido[pedidoId]!.add(
        TicketLineaInforme(
          productoNombre: productoNombre,
          productoTipo: productoTipo,
          productoDenominacionOrigen: productoDenominacionOrigen,
          ivaTipo: ivaTipo,
          cantidad: cantidad,
          precioUnitario: precioUnitario,
        ),
      );
    }

    final tickets = pedidosData.map<TicketClienteInforme>((pedido) {
      final mesaId = pedido['mesa_id'] as String? ?? '';
      final fechaRaw = pedido['fecha'] as String?;

      return TicketClienteInforme(
        id: pedido['id'] as String? ?? '',
        fecha: DateTime.tryParse(fechaRaw ?? '') ?? DateTime.now(),
        mesaNombre: nombreMesaById[mesaId] ?? mesaId,
        subtotal: (pedido['subtotal'] as num?)?.toDouble() ?? 0,
        descuentoAplicado:
            (pedido['descuento_aplicado'] as num?)?.toDouble() ?? 0,
        descuentoPorcentaje:
            (pedido['descuento_porcentaje'] as num?)?.toDouble() ?? 0,
        total: (pedido['total'] as num?)?.toDouble() ?? 0,
        lineas:
            lineasPorPedido[pedido['id'] as String? ?? ''] ??
            const <TicketLineaInforme>[],
      );
    }).toList();

    final totalGastado = tickets.fold<double>(0, (sum, t) => sum + t.total);
    final totalAhorrado = tickets.fold<double>(
      0,
      (sum, t) => sum + t.descuentoAplicado,
    );
    final pedidos = tickets.length;
    final ticketMedio = pedidos == 0 ? 0.0 : totalGastado / pedidos;

    return InformeClientePersonalizado(
      clienteId: clienteId,
      inicio: inicioDia,
      fin: DateTime(fin.year, fin.month, fin.day),
      pedidos: pedidos,
      totalGastado: totalGastado,
      totalAhorrado: totalAhorrado,
      ticketMedio: ticketMedio,
      tickets: tickets,
    );
  }

  Future<Map<String, dynamic>?> fetchPedidoAbierto({required String mesaId}) async {
    return await supabaseClient
        .from('pedidos')
        .select()
        .eq('mesa_id', mesaId)
        .eq('estado', 'abierto')
        .maybeSingle();
  }

  Future<Map<String, dynamic>> insertPedidoAbierto({required String mesaId}) async {
    return await supabaseClient
        .from('pedidos')
        .insert({
          'mesa_id': mesaId,
          'estado': 'abierto',
          'fecha': DateTime.now().toIso8601String(),
          'total': 0,
        })
        .select()
        .single();
  }

  Future<void> updatePedidoById({
    required String pedidoId,
    required Map<String, dynamic> payload,
  }) async {
    await supabaseClient.from('pedidos').update(payload).eq('id', pedidoId);
  }

  Future<List<dynamic>> fetchPedidosCerradosEnRango({
    required String inicioIso,
    required String finExclusivoIso,
  }) async {
    return await supabaseClient
        .from('pedidos')
        .select('id, mesa_id, fecha, total')
        .eq('estado', 'cerrado')
        .gt('total', 0)
        .gte('fecha', inicioIso)
        .lt('fecha', finExclusivoIso)
        .order('fecha', ascending: false);
  }

  Future<List<dynamic>> fetchPedidosClienteEnRango({
    required String clienteId,
    required String inicioIso,
    required String finExclusivoIso,
    required int limiteTickets,
  }) async {
    return await supabaseClient
        .from('pedidos')
        .select(
          'id, mesa_id, fecha, total, subtotal, descuento_aplicado, descuento_porcentaje',
        )
        .eq('estado', 'cerrado')
        .eq('cliente_afiliado_id', clienteId)
        .gt('total', 0)
        .gte('fecha', inicioIso)
        .lt('fecha', finExclusivoIso)
        .order('fecha', ascending: false)
        .limit(limiteTickets);
  }

  Future<List<dynamic>> fetchMesasByIds(List<String> mesaIds) async {
    return await supabaseClient
        .from('mesas')
        .select('id, nombre')
        .inFilter('id', mesaIds);
  }

  Future<List<dynamic>> fetchLineasByPedidoIds(List<String> pedidoIds) async {
    return await supabaseClient
        .from('lineas_pedido')
        .select(
          'pedido_id, cantidad, precio_unitario, productos(nombre, tipo, iva_tipo, denominacion_origen)',
        )
        .inFilter('pedido_id', pedidoIds);
  }
}
