import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/cliente_afiliado.dart';
import 'package:osyra/services/cliente_afiliado_service.dart';

class _FakeClienteAfiliadoService extends ClienteAfiliadoService {
  List<dynamic> lista = [];
  final Map<String, Map<String, dynamic>?> byField = {};
  Map<String, dynamic>? insertedPayload;
  Map<String, dynamic>? insertedResult;
  Map<String, dynamic> visitasResult = {'visitas_validas': 0};
  String? updatedClienteId;
  Map<String, dynamic>? updatedPayload;
  String? deletedClienteId;

  @override
  Future<List<dynamic>> fetchClientesLista({String busqueda = ''}) async {
    if (busqueda.trim().isEmpty) return lista;
    final term = busqueda.trim().toLowerCase();
    return lista.where((e) {
      final m = (e as Map<String, dynamic>);
      return (m['nombre'] as String?)?.toLowerCase().contains(term) == true ||
          (m['dni_cif'] as String?)?.toLowerCase().contains(term) == true ||
          (m['numero_afiliado'] as String?)?.toLowerCase().contains(term) == true;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchClienteByCampo({
    required String campo,
    required String valor,
  }) async {
    return byField['$campo:$valor'];
  }

  @override
  Future<Map<String, dynamic>> insertClientePayload(Map<String, dynamic> payload) async {
    insertedPayload = payload;
    return insertedResult ??
        {
          'id': 'c1',
          'nombre': payload['nombre'],
          'dni_cif': payload['dni_cif'],
          'numero_afiliado': 'AF-1',
          'visitas_validas': 0,
          'qr_auth_code': payload['qr_auth_code'],
          'email': payload['email'],
        };
  }

  @override
  Future<Map<String, dynamic>> fetchVisitasByClienteId({required String clienteId}) async {
    return visitasResult;
  }

  @override
  Future<void> updateClienteById({
    required String clienteId,
    required Map<String, dynamic> update,
  }) async {
    updatedClienteId = clienteId;
    updatedPayload = update;
  }

  @override
  Future<void> deleteClienteById({required String clienteId}) async {
    deletedClienteId = clienteId;
  }
}

void main() {
  group('ClienteAfiliadoService', () {
    test('listarClientes maps rows to model', () async {
      final service = _FakeClienteAfiliadoService()
        ..lista = [
          {
            'id': 'c1',
            'nombre': 'Oscar',
            'dni_cif': '12345678Z',
            'numero_afiliado': 'AF-1',
            'visitas_validas': 3,
          },
        ];

      final clientes = await service.listarClientes();

      expect(clientes.length, 1);
      expect(clientes.first.nombre, 'Oscar');
      expect(clientes.first.visitasValidas, 3);
    });

    test('crearCliente normalizes fields and generates tokens', () async {
      final service = _FakeClienteAfiliadoService();

      final creado = await service.crearCliente(
        dniCif: ' 12345678z ',
        nombreCompleto: '  Perez, Ana  ',
        direccion: ' Calle Real ',
        codigoPostal: ' 41001 ',
        localidad: ' Sevilla ',
        telefono: ' 600123123 ',
        correoElectronico: ' ANA@MAIL.COM ',
      );

      final payload = service.insertedPayload!;
      expect(payload['dni_cif'], '12345678Z');
      expect(payload['nombre'], 'Perez, Ana');
      expect(payload['email'], 'ana@mail.com');
      expect((payload['qr_auth_code'] as String).startsWith('QR-'), isTrue);
      expect((payload['wallet_token'] as String).length, 32);
      expect(creado.nombre, 'Perez, Ana');
    });

    test('buscarPorCredencial tries numero then dni', () async {
      final service = _FakeClienteAfiliadoService()
        ..byField['numero_afiliado:AF-9'] = null
        ..byField['dni_cif:12345678Z'] = {
          'id': 'c9',
          'nombre': 'Emma',
          'dni_cif': '12345678Z',
          'numero_afiliado': 'AF-9',
          'visitas_validas': 0,
        };

      final cliente = await service.buscarPorCredencial(
        numeroAfiliado: 'af-9',
        dniCif: '12345678z',
      );

      expect(cliente, isNotNull);
      expect(cliente!.nombre, 'Emma');
    });

    test('buscarPorCredencial returns first match by numero afiliado', () async {
      final service = _FakeClienteAfiliadoService()
        ..byField['numero_afiliado:AF-1'] = {
          'id': 'c1',
          'nombre': 'Oscar',
          'dni_cif': '12345678Z',
          'numero_afiliado': 'AF-1',
          'visitas_validas': 2,
        }
        ..byField['dni_cif:12345678Z'] = {
          'id': 'c2',
          'nombre': 'Otro',
          'dni_cif': '12345678Z',
          'numero_afiliado': 'AF-X',
          'visitas_validas': 0,
        };

      final cliente = await service.buscarPorCredencial(
        numeroAfiliado: 'af-1',
        dniCif: '12345678z',
      );

      expect(cliente, isNotNull);
      expect(cliente!.id, 'c1');
    });

    test('buscarPorQrAuthCode returns null for empty and finds normalized code', () async {
      final service = _FakeClienteAfiliadoService()
        ..byField['qr_auth_code:QR-ABC123'] = {
          'id': 'c1',
          'nombre': 'Oscar',
          'dni_cif': '12345678Z',
          'numero_afiliado': 'AF-1',
          'visitas_validas': 0,
        };

      expect(await service.buscarPorQrAuthCode('  '), isNull);
      final found = await service.buscarPorQrAuthCode('qr-abc123');
      expect(found, isNotNull);
      expect(found!.id, 'c1');
    });

    test('registrarCompra increments visits when total >= 30 and no discount', () async {
      final service = _FakeClienteAfiliadoService()
        ..visitasResult = {'visitas_validas': 2};

      await service.registrarCompra(
        clienteId: 'c1',
        totalAntesDescuento: 31,
        descuentoAplicado: false,
      );

      expect(service.updatedClienteId, 'c1');
      expect(service.updatedPayload!['visitas_validas'], 3);
    });

    test('registrarCompra resets visits when discount applied', () async {
      final service = _FakeClienteAfiliadoService()
        ..visitasResult = {'visitas_validas': 5};

      await service.registrarCompra(
        clienteId: 'c1',
        totalAntesDescuento: 50,
        descuentoAplicado: true,
      );

      expect(service.updatedPayload!['visitas_validas'], 0);
    });

    test('registrarCompra keeps visits when total is below threshold', () async {
      final service = _FakeClienteAfiliadoService()
        ..visitasResult = {'visitas_validas': 2};

      await service.registrarCompra(
        clienteId: 'c1',
        totalAntesDescuento: 29.99,
        descuentoAplicado: false,
      );

      expect(service.updatedPayload!['visitas_validas'], 2);
    });

    test('registrarCompra clamps max visits to 5', () async {
      final service = _FakeClienteAfiliadoService()
        ..visitasResult = {'visitas_validas': 5};

      await service.registrarCompra(
        clienteId: 'c1',
        totalAntesDescuento: 80,
        descuentoAplicado: false,
      );

      expect(service.updatedPayload!['visitas_validas'], 5);
    });

    test('eliminarCliente delegates to delete method', () async {
      final service = _FakeClienteAfiliadoService();

      await service.eliminarCliente(clienteId: 'c1');

      expect(service.deletedClienteId, 'c1');
    });

    test('enviarCorreoAltaConQr returns false when no email', () async {
      final service = _FakeClienteAfiliadoService();
      final cliente = ClienteAfiliado(
        id: 'c1',
        nombre: 'No mail',
        dniCif: '123',
        numeroAfiliado: 'AF-1',
        email: '',
        qrAuthCode: 'QR-ABC',
        visitasValidas: 0,
      );

      final sent = await service.enviarCorreoAltaConQr(cliente);

      expect(sent, isFalse);
    });

    test('enviarCorreoAltaConQr throws when qr auth code is missing', () async {
      final service = _FakeClienteAfiliadoService();
      final cliente = ClienteAfiliado(
        id: 'c1',
        nombre: 'Sin qr',
        dniCif: '123',
        numeroAfiliado: 'AF-1',
        email: 'x@test.com',
        qrAuthCode: '',
        visitasValidas: 0,
      );

      expect(
        () => service.enviarCorreoAltaConQr(cliente),
        throwsA(isA<Exception>()),
      );
    });
  });
}
