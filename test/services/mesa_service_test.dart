import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/services/mesa_service.dart';

class _FakeMesaService extends MesaService {
  _FakeMesaService({required this.mesas, required this.pedidosAbiertos});

  final List<dynamic> mesas;
  final List<dynamic> pedidosAbiertos;
  String? updatedMesaId;
  String? updatedNombre;

  @override
  Future<List<dynamic>> fetchMesas() async => mesas;

  @override
  Future<List<dynamic>> fetchPedidosAbiertos() async => pedidosAbiertos;

  @override
  Future<void> updateMesaNombre({required String mesaId, required String nombre}) async {
    updatedMesaId = mesaId;
    updatedNombre = nombre;
  }
}

void main() {
  test('MesaService marks occupied mesas based on open orders', () async {
    final service = _FakeMesaService(
      mesas: [
        {'id': 'm1', 'nombre': 'Mesa 1'},
        {'id': 'm2', 'nombre': 'Mesa 2'},
      ],
      pedidosAbiertos: [
        {'mesa_id': 'm2'},
      ],
    );

    final mesas = await service.getMesas();

    expect(mesas.firstWhere((m) => m.id == 'm1').estado, 'libre');
    expect(mesas.firstWhere((m) => m.id == 'm2').estado, 'ocupada');
  });

  test('MesaService delegates name updates', () async {
    final service = _FakeMesaService(mesas: [], pedidosAbiertos: []);

    await service.actualizarNombreMesa(mesaId: 'm1', nombre: 'Cliente 1');

    expect(service.updatedMesaId, 'm1');
    expect(service.updatedNombre, 'Cliente 1');
  });
}
