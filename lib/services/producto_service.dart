import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/producto.dart';

class ProductoService {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  Future<List<dynamic>> fetchProductos() async {
    return await supabaseClient.from('productos').select();
  }

  Future<List<Producto>> getProductos() async {
    final data = await fetchProductos();
    return data.map<Producto>((e) => Producto.fromJson(e)).toList();
  }
}