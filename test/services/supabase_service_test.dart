import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/supabase_service.dart';

class _FakeSupabaseService extends SupabaseService {
  final List<Map<String, dynamic>> inserted = [];

  @override
  Future<void> insertDemoProducto(Map<String, dynamic> payload) async {
    inserted.add(payload);
  }
}

void main() {
  test('SupabaseService inserts demo product payload', () async {
    final service = _FakeSupabaseService();

    await service.insertarProductoDemo();

    expect(service.inserted.length, 1);
    expect(service.inserted.first['nombre'], 'Demo Flutter');
    expect(service.inserted.first['tipo'], 'botella');
  });
}
