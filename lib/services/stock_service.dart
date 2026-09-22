import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/producto.dart';

class StockService {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  Future<List<dynamic>> fetchProductosConStock() async {
    return await supabaseClient
        .from('productos')
        .select(
          'id, nombre, precio, tipo, subcategoria, denominacion_origen, iva_tipo, stock, stock_minimo',
        )
        .order('nombre', ascending: true);
  }

  Future<void> updateProductoById({
    required String productoId,
    required Map<String, dynamic> update,
  }) async {
    await supabaseClient.from('productos').update(update).eq('id', productoId);
  }

  Future<void> insertProducto(Map<String, dynamic> payload) async {
    await supabaseClient.from('productos').insert(payload);
  }

  Future<List<Producto>> getProductosConStock() async {
    final data = await fetchProductosConStock();

    return data.map<Producto>((json) => Producto.fromJson(json)).toList();
  }

  Future<void> actualizarStock({
    required String productoId,
    required int nuevoStock,
  }) async {
    await updateProductoById(productoId: productoId, update: {'stock': nuevoStock});
  }

  Future<void> actualizarConfiguracionStock({
    required String productoId,
    int? stock,
    int? stockMinimo,
  }) async {
    final update = <String, dynamic>{};

    if (stock != null) {
      update['stock'] = stock;
    }

    if (stockMinimo != null) {
      update['stock_minimo'] = stockMinimo;
    }

    if (update.isEmpty) return;

    await updateProductoById(productoId: productoId, update: update);
  }

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
    await updateProductoById(
      productoId: productoId,
      update: {
        'nombre': nombre,
        'tipo': tipo,
        'subcategoria': subcategoria,
        'denominacion_origen': denominacionOrigen,
        'stock': stock,
        'stock_minimo': stockMinimo,
        'precio': precio,
      },
    );
  }

  Future<void> crearProducto({
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  }) async {
    await insertProducto({
      'nombre': nombre,
      'tipo': tipo,
      'subcategoria': subcategoria,
      'denominacion_origen': denominacionOrigen,
      'iva_tipo': 21,
      'stock': stock,
      'stock_minimo': stockMinimo,
      'precio': precio,
    });
  }
}
