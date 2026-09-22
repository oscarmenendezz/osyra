import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_afiliado.dart';

class ClienteAfiliadoService {
  SupabaseClient get supabaseClient => Supabase.instance.client;
  final Random _random = Random.secure();
  static const String _selectCliente =
  'id, nombre, dni_cif, numero_afiliado, direccion, codigo_postal, localidad, telefono, email, qr_auth_code, zip_recuperacion, imagen_perfil_url, visitas_validas';

  String _normalizar(String value) {
    return value.trim().toUpperCase().replaceAll(' ', '');
  }

  String _generarQrAuthCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final codigo = List<String>.generate(
      12,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
    return 'QR-$codigo';
  }

  String _generarWalletToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      32,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  String _normalizarQrAuthCode(String value) {
    final normalizado = _normalizar(value);
    if (normalizado.isEmpty) return '';
    return normalizado.startsWith('QR-') ? normalizado : 'QR-$normalizado';
  }

  Future<ClienteAfiliado?> _buscarPorCampo({
    required String campo,
    required String valor,
  }) async {
    final data = await fetchClienteByCampo(campo: campo, valor: valor);

    if (data == null) return null;
    return ClienteAfiliado.fromJson(data);
  }

  Future<List<ClienteAfiliado>> listarClientes({String busqueda = ''}) async {
    final data = await fetchClientesLista(busqueda: busqueda);

    return data
        .map((item) => ClienteAfiliado.fromJson(item as Map<String, dynamic>))
        .toList();
  }

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
    final direccionTrim = direccion?.trim();
    final codigoPostalTrim = codigoPostal?.trim();
    final localidadTrim = localidad?.trim();
    final telefonoTrim = telefono?.trim();
    final correoTrim = correoElectronico?.trim().toLowerCase();
    final qrPreferido = qrAuthCodePreferido?.trim() ?? '';
    final qrAuthCode = qrPreferido.isEmpty
        ? _generarQrAuthCode()
        : _normalizarQrAuthCode(qrPreferido);
    final walletToken = _generarWalletToken();

    final creado = await insertClientePayload({
      'dni_cif': _normalizar(dniCif),
      'nombre': nombreCompleto.trim(),
      'direccion': direccionTrim == null || direccionTrim.isEmpty
        ? null
        : direccionTrim,
      'codigo_postal': codigoPostalTrim == null || codigoPostalTrim.isEmpty
        ? null
        : codigoPostalTrim,
      'localidad': localidadTrim == null || localidadTrim.isEmpty
        ? null
        : localidadTrim,
      'telefono': telefonoTrim == null || telefonoTrim.isEmpty
        ? null
        : telefonoTrim,
      'email': correoTrim == null || correoTrim.isEmpty ? null : correoTrim,
      'qr_auth_code': qrAuthCode,
      'wallet_token': walletToken,
      'updated_at': DateTime.now().toIso8601String(),
    });

    return ClienteAfiliado.fromJson(creado);
  }

  Future<bool> enviarCorreoAltaConQr(ClienteAfiliado cliente) async {
    final email = (cliente.email ?? '').trim();
    if (email.isEmpty) return false;

    final qrCode = (cliente.qrAuthCode ?? '').trim();
    if (qrCode.isEmpty) {
      throw Exception('El cliente no tiene qr_auth_code para el acceso.');
    }

    final response = await invokeSendClienteAfiliadoEmail(
      body: {
        'clienteId': cliente.id,
        'nombre': cliente.nombre,
        'email': email,
        'numeroAfiliado': cliente.numeroAfiliado,
        'dniCif': cliente.dniCif,
        'qrAuthCode': qrCode,
        'qrValue': 'osyra://afiliado-auth?code=$qrCode',
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        'Fallo enviando correo de afiliacion (${response.status}).',
      );
    }

    return true;
  }

  Future<ClienteAfiliado?> buscarPorQrAuthCode(String qrAuthCode) async {
    final normalizado = _normalizar(qrAuthCode);
    if (normalizado.isEmpty) return null;

    return _buscarPorCampo(campo: 'qr_auth_code', valor: normalizado);
  }

  Future<ClienteAfiliado?> buscarPorCredencial({
    String? numeroAfiliado,
    String? dniCif,
  }) async {
    final numeroNormalizado = numeroAfiliado == null
        ? ''
        : _normalizar(numeroAfiliado);
    final dniNormalizado = dniCif == null ? '' : _normalizar(dniCif);

    if (numeroNormalizado.isNotEmpty) {
      final porNumero = await _buscarPorCampo(
        campo: 'numero_afiliado',
        valor: numeroNormalizado,
      );
      if (porNumero != null) return porNumero;
    }

    if (dniNormalizado.isNotEmpty) {
      final porDni = await _buscarPorCampo(
        campo: 'dni_cif',
        valor: dniNormalizado,
      );
      if (porDni != null) return porDni;
    }

    return null;
  }

  Future<void> registrarCompra({
    required String clienteId,
    required double totalAntesDescuento,
    required bool descuentoAplicado,
  }) async {
    final actual = await fetchVisitasByClienteId(clienteId: clienteId);

    final visitasActuales = (actual['visitas_validas'] as num?)?.toInt() ?? 0;

    var nuevasVisitas = visitasActuales;
    if (descuentoAplicado) {
      nuevasVisitas = 0;
    } else if (totalAntesDescuento >= 30) {
      nuevasVisitas = (visitasActuales + 1).clamp(0, 5);
    }

    await updateClienteById(
      clienteId: clienteId,
      update: {
        'visitas_validas': nuevasVisitas,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> eliminarCliente({required String clienteId}) async {
    await deleteClienteById(clienteId: clienteId);
  }

  Future<Map<String, dynamic>?> fetchClienteByCampo({
    required String campo,
    required String valor,
  }) async {
    return await supabaseClient
        .from('clientes_afiliados')
        .select(_selectCliente)
        .eq(campo, valor)
        .maybeSingle();
  }

  Future<List<dynamic>> fetchClientesLista({String busqueda = ''}) async {
    var query = supabaseClient.from('clientes_afiliados').select(_selectCliente);

    final filtro = busqueda.trim();
    if (filtro.isNotEmpty) {
      final termino = filtro.replaceAll(',', '');
      query = query.or(
        'nombre.ilike.%$termino%,dni_cif.ilike.%$termino%,numero_afiliado.ilike.%$termino%,telefono.ilike.%$termino%,email.ilike.%$termino%',
      );
    }

    return await query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> insertClientePayload(
    Map<String, dynamic> payload,
  ) async {
    return await supabaseClient
        .from('clientes_afiliados')
        .insert(payload)
        .select(_selectCliente)
        .single();
  }

  Future<FunctionResponse> invokeSendClienteAfiliadoEmail({
    required Map<String, dynamic> body,
  }) async {
    return await supabaseClient.functions.invoke(
      'send-cliente-afiliado-email',
      body: body,
    );
  }

  Future<Map<String, dynamic>> fetchVisitasByClienteId({
    required String clienteId,
  }) async {
    return await supabaseClient
        .from('clientes_afiliados')
        .select('visitas_validas')
        .eq('id', clienteId)
        .single();
  }

  Future<void> updateClienteById({
    required String clienteId,
    required Map<String, dynamic> update,
  }) async {
    await supabaseClient
        .from('clientes_afiliados')
        .update(update)
        .eq('id', clienteId);
  }

  Future<void> deleteClienteById({required String clienteId}) async {
    await supabaseClient.from('clientes_afiliados').delete().eq('id', clienteId);
  }
}
