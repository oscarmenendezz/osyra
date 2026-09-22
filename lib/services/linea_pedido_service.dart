import 'package:supabase_flutter/supabase_flutter.dart';

class LineaPedidoService {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  Future<Map<String, dynamic>?> _getProducto(String productoId) async {
    return await fetchProducto(productoId);
  }

  Future<int> _getStockProducto(String productoId) async {
    final producto = await fetchStockProducto(productoId);

    return (producto['stock'] as num?)?.toInt() ?? 0;
  }

  Future<void> _setStockProducto(String productoId, int nuevoStock) async {
    await updateStockProducto(productoId, nuevoStock.clamp(0, 999999));
  }

  Future<void> _asegurarStockDisponible(String productoId) async {
    final producto = await _getProducto(productoId);
    if (producto == null) {
      throw StateError('Producto no encontrado');
    }

    final tipo = producto['tipo'] as String?;

    if (tipo == 'copa') {
      final botellaOrigenId = producto['botella_origen_id'] as String?;
      if (botellaOrigenId == null) {
        throw StateError('Esta copa no tiene botella origen asociada');
      }

      final pendientes = await _getCopasPendientes(productoId);
      if (pendientes > 0) return;

      final stockBotella = await _getStockProducto(botellaOrigenId);
      if (stockBotella <= 0) {
        throw StateError('Sin stock: no quedan botellas para copeo');
      }
      return;
    }

    final stockActual = (producto['stock'] as num?)?.toInt() ?? 0;
    if (stockActual <= 0) {
      throw StateError('Sin stock disponible');
    }
  }

  Future<void> _ajustarStockNoCopa({
    required String productoId,
    required int delta,
  }) async {
    final producto = await _getProducto(productoId);
    if (producto == null) return;

    final tipo = producto['tipo'] as String?;
    if (tipo == 'copa') return;

    final stockActual = (producto['stock'] as num?)?.toInt() ?? 0;
    final nuevoStock = stockActual + delta;

    if (nuevoStock < 0) {
      throw StateError('Sin stock disponible');
    }

    await _setStockProducto(productoId, nuevoStock);
  }

  Future<int> _getCopasPendientes(String copaProductoId) async {
    final control = await fetchControlCopeo(copaProductoId);

    return (control?['copas_pendientes'] as num?)?.toInt() ?? 0;
  }

  Future<void> _setCopasPendientes(
    String copaProductoId,
    int copasPendientes,
  ) async {
    await upsertControlCopeo(
      {
        'copa_producto_id': copaProductoId,
        'copas_pendientes': copasPendientes,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> _ajustarBotellasDesdeCopas({
    required String productoId,
    required int deltaCopas,
  }) async {
    if (deltaCopas == 0) return;

    final producto = await _getProducto(productoId);
    if (producto == null) return;

    final tipo = producto['tipo'] as String?;
    if (tipo != 'copa') return;

    final botellaOrigenId = producto['botella_origen_id'] as String?;
    if (botellaOrigenId == null) return;

    final copasPorBotella =
        (producto['copas_por_botella'] as num?)?.toInt() ?? 5;

    var pendientes = await _getCopasPendientes(productoId);

    if (deltaCopas > 0) {
      final total = pendientes + deltaCopas;
      final botellasConsumidas = total ~/ copasPorBotella;
      final nuevoPendiente = total % copasPorBotella;

      await _setCopasPendientes(productoId, nuevoPendiente);

      if (botellasConsumidas > 0) {
        final stockActual = await _getStockProducto(botellaOrigenId);
        final nuevoStock = (stockActual - botellasConsumidas).clamp(0, 999999);

        await _setStockProducto(botellaOrigenId, nuevoStock);
      }

      return;
    }

    var porRevertir = -deltaCopas;
    var botellasAReponer = 0;

    while (porRevertir > 0) {
      if (pendientes > 0) {
        pendientes -= 1;
      } else {
        pendientes = copasPorBotella - 1;
        botellasAReponer += 1;
      }
      porRevertir -= 1;
    }

    await _setCopasPendientes(productoId, pendientes);

    if (botellasAReponer > 0) {
      final stockActual = await _getStockProducto(botellaOrigenId);
      final nuevoStock = (stockActual + botellasAReponer).clamp(0, 999999);

      await _setStockProducto(botellaOrigenId, nuevoStock);
    }
  }

  /// Obtener todas las líneas de un pedido con el nombre del producto
  Future<List<dynamic>> getLineas(String pedidoId) async {
    final data = await fetchLineasPedido(pedidoId);

    return data;
  }

  /// Añadir producto al pedido.
  /// Si ya existe ese producto en el pedido, suma 1 a la cantidad.
  /// Si no existe, crea una nueva línea.
  Future<void> anadirProducto({
    required String pedidoId,
    required String productoId,
    required double precio,
  }) async {
    await _asegurarStockDisponible(productoId);

    final existing = await fetchLineaExistente(
      pedidoId: pedidoId,
      productoId: productoId,
    );

    if (existing != null) {
      final cantidadActual = (existing['cantidad'] as num).toInt();

      await updateLineaCantidad(
        lineaId: existing['id'] as String,
        cantidad: cantidadActual + 1,
      );
    } else {
      await insertLinea({
        'pedido_id': pedidoId,
        'producto_id': productoId,
        'cantidad': 1,
        'precio_unitario': precio,
      });
    }

    await _ajustarBotellasDesdeCopas(
      productoId: productoId,
      deltaCopas: 1,
    );

    await _ajustarStockNoCopa(
      productoId: productoId,
      delta: -1,
    );
  }

  /// Restar producto.
  /// Si la cantidad es mayor que 1, resta 1.
  /// Si la cantidad es 1, elimina la línea completa.
  Future<void> restarProducto({
    required String lineaId,
    required int cantidadActual,
    required String productoId,
  }) async {
    if (cantidadActual > 1) {
      await updateLineaCantidad(
        lineaId: lineaId,
        cantidad: cantidadActual - 1,
      );

      await _ajustarBotellasDesdeCopas(
        productoId: productoId,
        deltaCopas: -1,
      );

      await _ajustarStockNoCopa(
        productoId: productoId,
        delta: 1,
      );
    } else {
      await eliminarLinea(
        lineaId,
        productoId: productoId,
        cantidadEliminada: 1,
      );
    }
  }

  /// Eliminar línea completa
  Future<void> eliminarLinea(
    String lineaId, {
    required String productoId,
    required int cantidadEliminada,
  }) async {
    await deleteLineaById(lineaId);

    await _ajustarBotellasDesdeCopas(
      productoId: productoId,
      deltaCopas: -cantidadEliminada,
    );

    await _ajustarStockNoCopa(
      productoId: productoId,
      delta: cantidadEliminada,
    );
  }

  /// Calcular total desde las líneas cargadas
  double calcularTotal(List<dynamic> lineas) {
    return lineas.fold(0.0, (sum, linea) {
      final precio = (linea['precio_unitario'] as num).toDouble();
      final cantidad = (linea['cantidad'] as num).toInt();

      return sum + (precio * cantidad);
    });
  }

  /// Calcular número total de productos
  int calcularTotalItems(List<dynamic> lineas) {
    return lineas.fold(0, (sum, linea) {
      final cantidad = (linea['cantidad'] as num).toInt();
      return sum + cantidad;
    });
  }

  /// Limpiar todas las líneas de un pedido
  Future<void> limpiarPedido(String pedidoId) async {
    await deleteLineasByPedidoId(pedidoId);
  }

  Future<Map<String, dynamic>?> fetchProducto(String productoId) async {
    return await supabaseClient
        .from('productos')
        .select('id, tipo, stock, botella_origen_id, copas_por_botella')
        .eq('id', productoId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> fetchStockProducto(String productoId) async {
    return await supabaseClient
        .from('productos')
        .select('stock')
        .eq('id', productoId)
        .single();
  }

  Future<void> updateStockProducto(String productoId, int nuevoStock) async {
    await supabaseClient
        .from('productos')
        .update({'stock': nuevoStock})
        .eq('id', productoId);
  }

  Future<Map<String, dynamic>?> fetchControlCopeo(String copaProductoId) async {
    return await supabaseClient
        .from('control_copeo')
        .select('copas_pendientes')
        .eq('copa_producto_id', copaProductoId)
        .maybeSingle();
  }

  Future<void> upsertControlCopeo(Map<String, dynamic> payload) async {
    await supabaseClient.from('control_copeo').upsert(payload);
  }

  Future<List<dynamic>> fetchLineasPedido(String pedidoId) async {
    return await supabaseClient
        .from('lineas_pedido')
        .select('*, productos(nombre)')
        .eq('pedido_id', pedidoId)
        .order('id', ascending: true);
  }

  Future<Map<String, dynamic>?> fetchLineaExistente({
    required String pedidoId,
    required String productoId,
  }) async {
    return await supabaseClient
        .from('lineas_pedido')
        .select()
        .eq('pedido_id', pedidoId)
        .eq('producto_id', productoId)
        .maybeSingle();
  }

  Future<void> updateLineaCantidad({
    required String lineaId,
    required int cantidad,
  }) async {
    await supabaseClient
        .from('lineas_pedido')
        .update({'cantidad': cantidad})
        .eq('id', lineaId);
  }

  Future<void> insertLinea(Map<String, dynamic> payload) async {
    await supabaseClient.from('lineas_pedido').insert(payload);
  }

  Future<void> deleteLineaById(String lineaId) async {
    await supabaseClient
        .from('lineas_pedido')
        .delete()
        .eq('id', lineaId);
  }

  Future<void> deleteLineasByPedidoId(String pedidoId) async {
    await supabaseClient
        .from('lineas_pedido')
        .delete()
        .eq('pedido_id', pedidoId);
  }
}