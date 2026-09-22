import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/cliente_afiliado.dart';

void main() {
  group('ClienteAfiliado', () {
    test('fromJson maps values and enables discount at 5 visits', () {
      final cliente = ClienteAfiliado.fromJson({
        'id': 'c1',
        'nombre': 'Oscar',
        'dni_cif': '12345678Z',
        'numero_afiliado': 'AF-001',
        'direccion': 'Calle Vino 1',
        'codigo_postal': '41001',
        'localidad': 'Sevilla',
        'telefono': '600123123',
        'email': 'test@example.com',
        'qr_auth_code': 'QR-123',
        'zip_recuperacion': 'ZIP-1',
        'imagen_perfil_url': 'https://img.test/a.png',
        'visitas_validas': 5,
      });

      expect(cliente.id, 'c1');
      expect(cliente.nombre, 'Oscar');
      expect(cliente.dniCif, '12345678Z');
      expect(cliente.numeroAfiliado, 'AF-001');
      expect(cliente.direccion, 'Calle Vino 1');
      expect(cliente.codigoPostal, '41001');
      expect(cliente.localidad, 'Sevilla');
      expect(cliente.telefono, '600123123');
      expect(cliente.email, 'test@example.com');
      expect(cliente.qrAuthCode, 'QR-123');
      expect(cliente.zipRecuperacion, 'ZIP-1');
      expect(cliente.imagenPerfilUrl, 'https://img.test/a.png');
      expect(cliente.visitasValidas, 5);
      expect(cliente.descuentoDisponible, isTrue);
    });

    test('fromJson applies defaults and descuento false under 5 visits', () {
      final cliente = ClienteAfiliado.fromJson({
        'id': 'c2',
      });

      expect(cliente.nombre, '');
      expect(cliente.dniCif, '');
      expect(cliente.numeroAfiliado, '');
      expect(cliente.direccion, isNull);
      expect(cliente.visitasValidas, 0);
      expect(cliente.descuentoDisponible, isFalse);
    });

    test('visitas_validas numeric value is converted to int', () {
      final cliente = ClienteAfiliado.fromJson({
        'id': 'c3',
        'visitas_validas': 6.9,
      });

      expect(cliente.visitasValidas, 6);
      expect(cliente.descuentoDisponible, isTrue);
    });
  });
}
