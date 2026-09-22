import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  Future<void> insertDemoProducto(Map<String, dynamic> payload) async {
    await supabaseClient.from('productos').insert(payload);
  }

  Future<void> insertarProductoDemo() async {
    await insertDemoProducto({
      'nombre': 'Demo Flutter',
      'precio': 1.0,
      'tipo': 'botella',
      'subcategoria': 'Demo',
    });
  }
}