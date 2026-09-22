import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_afiliado.dart';
import '../services/cliente_afiliado_service.dart';
import '../widgets/watermark_background.dart';

abstract class ClientesDataSource {
  Future<List<ClienteAfiliado>> listarClientes({String busqueda = ''});

  Future<ClienteAfiliado> crearCliente({
    required String dniCif,
    required String nombreCompleto,
    String? direccion,
    String? codigoPostal,
    String? localidad,
    String? telefono,
    String? correoElectronico,
    String? qrAuthCodePreferido,
  });

  Future<bool> enviarCorreoAltaConQr(ClienteAfiliado cliente);

  Future<void> eliminarCliente({required String clienteId});
}

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key, this.dataSource});

  final ClientesDataSource? dataSource;

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  late final ClientesDataSource _clientesDataSource;
  final TextEditingController busquedaController = TextEditingController();

  List<ClienteAfiliado> clientes = [];
  bool cargando = true;
  final Set<String> eliminandoIds = <String>{};

  @override
  void initState() {
    super.initState();
    _clientesDataSource =
        widget.dataSource ?? _ClienteAfiliadoServiceAdapter(ClienteAfiliadoService());
    cargarClientes();
  }

  @override
  void dispose() {
    busquedaController.dispose();
    super.dispose();
  }

  Future<void> cargarClientes() async {
    setState(() {
      cargando = true;
    });

    try {
      final data = await _clientesDataSource.listarClientes(
        busqueda: busquedaController.text,
      );

      if (!mounted) return;
      setState(() {
        clientes = data;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cargar clientes: $e')));
    }
  }

  Future<void> abrirAltaCliente() async {
    final resultado = await showModalBottomSheet<_AltaClienteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AltaClienteSheet(dataSource: _clientesDataSource),
    );

    if (resultado == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado.correoEnviado
              ? 'Cliente creado y correo enviado: ${resultado.cliente.nombre} (${resultado.cliente.numeroAfiliado})'
              : (resultado.correoError == null ||
                        resultado.correoError!.trim().isEmpty
                    ? 'Cliente creado: ${resultado.cliente.nombre} (${resultado.cliente.numeroAfiliado}). Correo pendiente de configurar/envio.'
                    : 'Cliente creado: ${resultado.cliente.nombre} (${resultado.cliente.numeroAfiliado}). No se pudo enviar correo: ${resultado.correoError}'),
        ),
      ),
    );

    await _mostrarQrAlta(resultado.cliente);

    await cargarClientes();
  }

  Future<void> eliminarCliente(ClienteAfiliado cliente) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar cliente'),
          content: Text(
            'Se eliminara a ${cliente.nombre} (${cliente.numeroAfiliado}). Esta accion no se puede deshacer.\n\n¿Quieres continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true || !mounted) return;

    setState(() {
      eliminandoIds.add(cliente.id);
    });

    try {
      await _clientesDataSource.eliminarCliente(clienteId: cliente.id);

      if (!mounted) return;
      setState(() {
        clientes.removeWhere((item) => item.id == cliente.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cliente eliminado: ${cliente.nombre}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mensajeErrorEliminar(e))));
    } finally {
      if (mounted) {
        setState(() {
          eliminandoIds.remove(cliente.id);
        });
      }
    }
  }

  String _mensajeErrorEliminar(Object error) {
    if (error is PostgrestException && error.code == '23503') {
      return 'No se puede eliminar: el cliente tiene datos asociados.';
    }
    return 'No se pudo eliminar el cliente: $error';
  }

  Future<void> _mostrarQrAlta(ClienteAfiliado cliente) async {
    final qrCode = (cliente.qrAuthCode ?? '').trim();
    if (qrCode.isEmpty) return;

    final qrValue = 'osyra://afiliado-auth?code=$qrCode';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'QR del cliente creado',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cliente.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: QrImageView(
                          data: qrValue,
                          size: 220,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0F2730),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0F2730),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Codigo: $qrCode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Este QR se usa para identificar al cliente afiliado en tienda.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes afiliados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirAltaCliente,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Alta cliente'),
      ),
      body: WatermarkBackground(
        gradientColors: const [
          Color(0xFF14323D),
          Color(0xFF1D4D5D),
          Color(0xFF0F2730),
        ],
        opacity: 0.09,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0DBDF)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: busquedaController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => cargarClientes(),
                          decoration: const InputDecoration(
                            labelText: 'Buscar por nombre, DNI/CIF o afiliado',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: cargarClientes,
                        tooltip: 'Buscar',
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MetricChip(
                      icon: Icons.groups_rounded,
                      label: 'Total',
                      value: '${clientes.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: cargando
                      ? const Center(child: CircularProgressIndicator())
                      : clientes.isEmpty
                      ? const Center(
                          child: Text('No hay clientes con ese filtro.'),
                        )
                      : RefreshIndicator(
                          onRefresh: cargarClientes,
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: clientes.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final cliente = clientes[index];
                              return _ClienteCard(
                                cliente: cliente,
                                eliminando: eliminandoIds.contains(cliente.id),
                                onEliminar: () => eliminarCliente(cliente),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AltaClienteSheet extends StatefulWidget {
  final ClientesDataSource dataSource;

  const _AltaClienteSheet({required this.dataSource});

  @override
  State<_AltaClienteSheet> createState() => _AltaClienteSheetState();
}

class _AltaClienteSheetState extends State<_AltaClienteSheet> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController dniController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController codigoPostalController = TextEditingController();
  final TextEditingController localidadController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool guardando = false;

  @override
  void dispose() {
    dniController.dispose();
    nombreController.dispose();
    direccionController.dispose();
    codigoPostalController.dispose();
    localidadController.dispose();
    telefonoController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> guardarCliente() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() {
      guardando = true;
    });

    try {
      final creado = await widget.dataSource.crearCliente(
        dniCif: dniController.text,
        nombreCompleto: nombreController.text,
        direccion: direccionController.text,
        codigoPostal: codigoPostalController.text,
        localidad: localidadController.text,
        telefono: telefonoController.text,
        correoElectronico: emailController.text,
      );

      var correoEnviado = false;
      String? correoError;
      try {
        correoEnviado = await widget.dataSource.enviarCorreoAltaConQr(creado);
        if (!correoEnviado) {
          correoError = 'Cliente sin email o configuracion incompleta.';
        }
      } catch (e) {
        correoEnviado = false;
        correoError = '$e';
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        _AltaClienteResult(
          cliente: creado,
          correoEnviado: correoEnviado,
          correoError: correoError,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        guardando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mensajeErrorAlta(e))));
    }
  }

  String? _validarRequerido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _validarDni(String? value) {
    final base = _validarRequerido(value);
    if (base != null) return base;

    final limpio = value!.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{8,15}$').hasMatch(limpio)) {
      return 'Formato invalido';
    }
    return null;
  }

  String? _validarCodigoPostal(String? value) {
    final base = _validarRequerido(value);
    if (base != null) return base;

    if (!RegExp(r'^\d{5}$').hasMatch(value!.trim())) {
      return 'Debe tener 5 digitos';
    }
    return null;
  }

  String? _validarTelefono(String? value) {
    final base = _validarRequerido(value);
    if (base != null) return base;

    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value!.trim())) {
      return 'Telefono invalido';
    }
    return null;
  }

  String? _validarEmail(String? value) {
    final base = _validarRequerido(value);
    if (base != null) return base;

    if (!RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value!.trim())) {
      return 'Correo no valido';
    }
    return null;
  }

  String _mensajeErrorAlta(Object error) {
    if (error is PostgrestException && error.code == '23505') {
      final detalle = '${error.message} ${error.details ?? ''}'.toLowerCase();
      if (detalle.contains('dni_cif')) {
        return 'Ya existe un cliente con ese DNI/CIF.';
      }
      if (detalle.contains('email')) {
        return 'Ya existe un cliente con ese correo electronico.';
      }
      return 'Registro duplicado, revisa los datos.';
    }
    return 'No se pudo dar de alta el cliente: $error';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, insets.bottom + 16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alta de cliente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dniController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'DNI/CIF'),
                  validator: _validarDni,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    helperText:
                        'Formato: Primer apellido, segundo apellido, nombre',
                  ),
                  validator: _validarRequerido,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: direccionController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Direccion'),
                  validator: _validarRequerido,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: codigoPostalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Codigo postal'),
                  validator: _validarCodigoPostal,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: localidadController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Localidad'),
                  validator: _validarRequerido,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numero de telefono',
                  ),
                  validator: _validarTelefono,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electronico',
                  ),
                  validator: _validarEmail,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: guardando
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: guardando ? null : guardarCliente,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF6B7280),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          guardando ? Icons.hourglass_top : Icons.save_alt_rounded,
                        ),
                        label: Text(
                          guardando ? 'Guardando...' : 'Crear cliente',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClienteAfiliadoServiceAdapter implements ClientesDataSource {
  _ClienteAfiliadoServiceAdapter(this._service);

  final ClienteAfiliadoService _service;

  @override
  Future<List<ClienteAfiliado>> listarClientes({String busqueda = ''}) {
    return _service.listarClientes(busqueda: busqueda);
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
  }) {
    return _service.crearCliente(
      dniCif: dniCif,
      nombreCompleto: nombreCompleto,
      direccion: direccion,
      codigoPostal: codigoPostal,
      localidad: localidad,
      telefono: telefono,
      correoElectronico: correoElectronico,
      qrAuthCodePreferido: qrAuthCodePreferido,
    );
  }

  @override
  Future<bool> enviarCorreoAltaConQr(ClienteAfiliado cliente) {
    return _service.enviarCorreoAltaConQr(cliente);
  }

  @override
  Future<void> eliminarCliente({required String clienteId}) {
    return _service.eliminarCliente(clienteId: clienteId);
  }
}

class _AltaClienteResult {
  final ClienteAfiliado cliente;
  final bool correoEnviado;
  final String? correoError;

  const _AltaClienteResult({
    required this.cliente,
    required this.correoEnviado,
    this.correoError,
  });
}

class _ClienteCard extends StatelessWidget {
  final ClienteAfiliado cliente;
  final bool eliminando;
  final VoidCallback onEliminar;

  const _ClienteCard({
    required this.cliente,
    required this.eliminando,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E8EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cliente.nombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text('DNI/CIF: ${cliente.dniCif}'),
          Text('Afiliado: ${cliente.numeroAfiliado}'),
          if ((cliente.direccion ?? '').isNotEmpty)
            Text('Direccion: ${cliente.direccion}'),
          Row(
            children: [
              Expanded(
                child: Text(
                  'CP: ${cliente.codigoPostal ?? '-'} · ${cliente.localidad ?? '-'}',
                ),
              ),
            ],
          ),
          Text('Telefono: ${cliente.telefono ?? '-'}'),
          Text('Correo: ${cliente.email ?? '-'}'),
          const SizedBox(height: 4),
          Text(
            'Visitas validas: ${cliente.visitasValidas}/5',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: eliminando ? null : onEliminar,
              icon: eliminando
                  ? const Icon(Icons.hourglass_top)
                  : const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                eliminando ? 'Eliminando...' : 'Eliminar',
                style: TextStyle(
                  color: eliminando ? null : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD5DFE3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF204A58)),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
