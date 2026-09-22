import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mesa.dart';

class MesaService {
  SupabaseClient get supabaseClient => Supabase.instance.client;

  Future<List<dynamic>> fetchMesas() async {
    return await supabaseClient.from('mesas').select();
  }

  Future<List<dynamic>> fetchPedidosAbiertos() async {
    return await supabaseClient
        .from('pedidos')
        .select('mesa_id')
        .eq('estado', 'abierto');
  }

  Future<void> updateMesaNombre({
    required String mesaId,
    required String nombre,
  }) async {
    await supabaseClient.from('mesas').update({'nombre': nombre}).eq('id', mesaId);
  }

  Future<List<Mesa>> getMesas() async {
    final mesasData = await fetchMesas();

    final pedidosAbiertos = await fetchPedidosAbiertos();

    final mesasOcupadasIds = pedidosAbiertos.map((p) => p['mesa_id']).toSet();

    return mesasData.map<Mesa>((m) {
      final ocupada = mesasOcupadasIds.contains(m['id']);

      return Mesa(
        id: m['id'],
        nombre: m['nombre'],
        estado: ocupada ? 'ocupada' : 'libre',
      );
    }).toList();
  }

  Future<void> actualizarNombreMesa({
    required String mesaId,
    required String nombre,
  }) async {
    await updateMesaNombre(mesaId: mesaId, nombre: nombre);
  }
}
