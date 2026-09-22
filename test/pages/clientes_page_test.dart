import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/cliente_afiliado.dart';
import 'package:osyra/pages/clientes_page.dart';

class _FakeClientesDataSource implements ClientesDataSource {
  _FakeClientesDataSource(this._clientes);

  final List<ClienteAfiliado> _clientes;
  bool throwOnListar = false;
  bool throwOnEliminar = false;
  bool throwOnEnviarCorreo = false;
  bool correoEnviado = true;

  @override
  Future<List<ClienteAfiliado>> listarClientes({String busqueda = ''}) async {
    if (throwOnListar) {
      throw Exception('fallo listar');
    }

    final term = busqueda.trim().toLowerCase();
    if (term.isEmpty) return List<ClienteAfiliado>.from(_clientes);

    return _clientes.where((c) {
      return c.nombre.toLowerCase().contains(term) ||
          c.dniCif.toLowerCase().contains(term) ||
          c.numeroAfiliado.toLowerCase().contains(term);
    }).toList();
  }

  @override
  Future<ClienteAfiliado> crearCliente({
    required String dniCif,
    required String nombreCompleto,
    String? direccion,
    String? codigoPostal,
    String? localidad,
    String? telefono,
    String? correoElectronico,
    String? qrAuthCodePreferido,
  }) async {
    final nuevo = ClienteAfiliado(
      id: 'c-${_clientes.length + 1}',
      nombre: nombreCompleto,
      dniCif: dniCif,
      numeroAfiliado: 'AF-${_clientes.length + 1}',
      direccion: direccion,
      codigoPostal: codigoPostal,
      localidad: localidad,
      telefono: telefono,
      email: correoElectronico,
      qrAuthCode: qrAuthCodePreferido ?? 'QR-NEW123456',
      zipRecuperacion: null,
      imagenPerfilUrl: null,
      visitasValidas: 0,
    );

    _clientes.insert(0, nuevo);
    return nuevo;
  }

  @override
  Future<bool> enviarCorreoAltaConQr(ClienteAfiliado cliente) async {
    if (throwOnEnviarCorreo) {
      throw Exception('fallo correo');
    }
    return correoEnviado;
  }

  @override
  Future<void> eliminarCliente({required String clienteId}) async {
    if (throwOnEliminar) {
      throw Exception('fallo eliminar');
    }

    _clientes.removeWhere((c) => c.id == clienteId);
  }
}

ClienteAfiliado _cliente({
  required String id,
  required String nombre,
  required String dni,
  required String afiliado,
  String? email,
  int visitas = 0,
}) {
  return ClienteAfiliado(
    id: id,
    nombre: nombre,
    dniCif: dni,
    numeroAfiliado: afiliado,
    direccion: 'Calle $id',
    codigoPostal: '41001',
    localidad: 'Sevilla',
    telefono: '600123123',
    email: email,
    qrAuthCode: 'QR-$id',
    zipRecuperacion: null,
    imagenPerfilUrl: null,
    visitasValidas: visitas,
  );
}

void main() {
  group('ClientesPage', () {
    testWidgets('renders loaded clients and metric chip', (tester) async {
      final fake = _FakeClientesDataSource([
        _cliente(id: '1', nombre: 'Oscar', dni: '12345678Z', afiliado: 'AF-1'),
        _cliente(id: '2', nombre: 'Emma', dni: '87654321X', afiliado: 'AF-2'),
      ]);

      await tester.pumpWidget(MaterialApp(home: ClientesPage(dataSource: fake)));
      await tester.pumpAndSettle();

      expect(find.text('Clientes afiliados'), findsOneWidget);
      expect(find.text('Oscar'), findsOneWidget);
      expect(find.text('Emma'), findsOneWidget);
      expect(find.text('Total: 2'), findsOneWidget);
    });

    testWidgets('search filters list by query', (tester) async {
      final fake = _FakeClientesDataSource([
        _cliente(id: '1', nombre: 'Oscar', dni: '12345678Z', afiliado: 'AF-1'),
        _cliente(id: '2', nombre: 'Emma', dni: '87654321X', afiliado: 'AF-2'),
      ]);

      await tester.pumpWidget(MaterialApp(home: ClientesPage(dataSource: fake)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'emma');
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Emma'), findsOneWidget);
      expect(find.text('Oscar'), findsNothing);
    });

    testWidgets('can delete a client with confirmation dialog', (tester) async {
      final fake = _FakeClientesDataSource([
        _cliente(id: '1', nombre: 'Oscar', dni: '12345678Z', afiliado: 'AF-1'),
      ]);

      await tester.pumpWidget(MaterialApp(home: ClientesPage(dataSource: fake)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar cliente'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Cliente eliminado: Oscar'), findsOneWidget);
      expect(find.text('Oscar'), findsNothing);
    });

    testWidgets('can create client from bottom sheet and show QR dialog', (
      tester,
    ) async {
      final fake = _FakeClientesDataSource([])..correoEnviado = false;

      await tester.pumpWidget(MaterialApp(home: ClientesPage(dataSource: fake)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Alta cliente'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'DNI/CIF'), '12345678Z');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'),
        'Perez Gomez, Ana',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Direccion'), 'Calle Real 1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Codigo postal'), '41001');
      await tester.enterText(find.widgetWithText(TextFormField, 'Localidad'), 'Sevilla');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numero de telefono'),
        '600123123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electronico'),
        'ana@test.com',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cliente'));
      await tester.pumpAndSettle();

      expect(find.text('QR del cliente creado'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cliente creado:'), findsOneWidget);
      expect(
        find.textContaining('Cliente creado: Perez Gomez, Ana (AF-1).'),
        findsOneWidget,
      );
    });

    testWidgets('shows load error snackbar when listar fails', (tester) async {
      final fake = _FakeClientesDataSource([])..throwOnListar = true;

      await tester.pumpWidget(MaterialApp(home: ClientesPage(dataSource: fake)));
      await tester.pumpAndSettle();

      expect(find.textContaining('No se pudo cargar clientes:'), findsOneWidget);
    });
  });
}
