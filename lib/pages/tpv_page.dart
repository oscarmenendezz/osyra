// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/mesa.dart';
import '../models/producto.dart';
import '../models/cliente_afiliado.dart';
import 'scan_qr_page.dart';
import '../services/producto_service.dart';
import '../services/pedido_service.dart';
import '../services/linea_pedido_service.dart';
import '../services/mesa_service.dart';
import '../services/cliente_afiliado_service.dart';
import '../widgets/watermark_background.dart';

class TPVPage extends StatefulWidget {
  final Mesa mesa;
  final String nombreBaseMesa;

  const TPVPage({super.key, required this.mesa, required this.nombreBaseMesa});

  @override
  State<TPVPage> createState() => _TPVPageState();
}

class _TPVPageState extends State<TPVPage> {
  final ProductoService productoService = ProductoService();
  final PedidoService pedidoService = PedidoService();
  final LineaPedidoService lineaService = LineaPedidoService();
  final MesaService mesaService = MesaService();
  final ClienteAfiliadoService clienteAfiliadoService =
      ClienteAfiliadoService();

  List<Producto> productos = [];
  List<dynamic> lineas = [];

  String? pedidoId;
  bool cargando = true;

  String categoriaSeleccionada = "botella";
  String? subcategoriaSeleccionada;

  bool seleccionandoCaja = false;
  int cantidadCaja = 0;
  List<Producto> cajaTemporal = [];
  bool procesandoCaja = false;
  late String nombreMesaActual;
  ClienteAfiliado? clienteAfiliadoCargado;

  static const _vino = Color(0xFF5E35B1);
  static const _madera = Color(0xFF6A1B9A);
  static const _crema = Color(0xFFF2ECFB);
  static const _pizarra = Color(0xFF231733);
  static const _verde = Color(0xFF8E24AA);

  @override
  void initState() {
    super.initState();
    nombreMesaActual = widget.mesa.nombre;
    initTPV();
  }

  Future<void> editarNombreMesa() async {
    final controller = TextEditingController(text: nombreMesaActual);

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nombre del cliente'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nombre para esta mesa',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = controller.text.trim();
                if (nombre.isEmpty) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre no puede estar vacio'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(nombre);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (nuevoNombre == null || nuevoNombre == nombreMesaActual) return;

    try {
      await mesaService.actualizarNombreMesa(
        mesaId: widget.mesa.id,
        nombre: nuevoNombre,
      );

      if (!mounted) return;

      setState(() {
        nombreMesaActual = nuevoNombre;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el nombre: $e')),
      );
    }
  }

  Future<void> initTPV() async {
    try {
      final productosCargados = await productoService.getProductos();
      final pedido = await pedidoService.getOrCreatePedido(widget.mesa.id);

      pedidoId = pedido['id'];

      final lineasCargadas = await lineaService.getLineas(pedidoId!);

      setState(() {
        productos = productosCargados;
        lineas = lineasCargadas;
        cargando = false;
      });
    } catch (e) {
      setState(() {
        cargando = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error cargando TPV: $e")));
    }
  }

  Future<void> cargarLineas() async {
    if (pedidoId == null) return;

    final data = await lineaService.getLineas(pedidoId!);

    setState(() {
      lineas = data;
    });
  }

  List<Producto> get productosFiltrados {
    List<Producto> filtrados = productos
        .where((producto) => producto.tipo == categoriaSeleccionada)
        .toList();

    if (subcategoriaSeleccionada != null) {
      filtrados = filtrados
          .where(
            (producto) => producto.subcategoria == subcategoriaSeleccionada,
          )
          .toList();
    }

    return filtrados;
  }

  List<String> get subcategoriasBotellas {
    return productos
        .where((producto) => producto.tipo == "botella")
        .map((producto) => producto.subcategoria)
        .where((subcategoria) => subcategoria != "General")
        .toSet()
        .toList();
  }

  Future<void> anadirProducto(Producto producto) async {
    if (pedidoId == null) return;
    if (procesandoCaja) return;

    try {
      if (seleccionandoCaja && categoriaSeleccionada == "botella") {
        cajaTemporal.add(producto);

        if (cajaTemporal.length < cantidadCaja) {
          setState(() {});
          return;
        }

        final seleccionCaja = List<Producto>.from(cajaTemporal);

        setState(() {
          procesandoCaja = true;
        });

        for (final botella in seleccionCaja) {
          await lineaService.anadirProducto(
            pedidoId: pedidoId!,
            productoId: botella.id,
            precio: botella.precio,
          );
        }

        setState(() {
          procesandoCaja = false;
          seleccionandoCaja = false;
          cantidadCaja = 0;
          cajaTemporal.clear();
        });

        await cargarLineas();

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Caja añadida al pedido")));

        return;
      }

      await lineaService.anadirProducto(
        pedidoId: pedidoId!,
        productoId: producto.id,
        precio: producto.precio,
      );

      await cargarLineas();
    } catch (e) {
      if (procesandoCaja) {
        setState(() {
          procesandoCaja = false;
        });
      }

      if (_esErrorStock(e)) {
        await _mostrarDialogoErrorStock(e);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo anadir: $e')));
    }
  }

  void iniciarCaja(int cantidad) {
    setState(() {
      categoriaSeleccionada = "botella";
      subcategoriaSeleccionada = null;
      seleccionandoCaja = true;
      procesandoCaja = false;
      cantidadCaja = cantidad;
      cajaTemporal.clear();
    });
  }

  void cancelarCaja() {
    setState(() {
      seleccionandoCaja = false;
      procesandoCaja = false;
      cantidadCaja = 0;
      cajaTemporal.clear();
    });
  }

  void cambiarCategoria(String categoria) {
    setState(() {
      categoriaSeleccionada = categoria;
      subcategoriaSeleccionada = null;
      seleccionandoCaja = false;
      procesandoCaja = false;
      cantidadCaja = 0;
      cajaTemporal.clear();
    });
  }

  void cambiarSubcategoria(String subcategoria) {
    setState(() {
      if (subcategoriaSeleccionada == subcategoria) {
        subcategoriaSeleccionada = null;
      } else {
        subcategoriaSeleccionada = subcategoria;
      }
    });
  }

  bool _esErrorStock(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('sin stock') ||
        text.contains('stock disponible') ||
        text.contains('no quedan botellas');
  }

  String _detalleErrorStock(Object error) {
    final raw = error.toString().replaceFirst('Bad state:', '').trim();
    if (raw.isEmpty) {
      return 'No hay stock suficiente en inventario.';
    }
    return raw;
  }

  Future<void> _mostrarDialogoErrorStock(Object error) async {
    if (!mounted) return;

    final detalle = _detalleErrorStock(error);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          title: const Text('Stock insuficiente'),
          content: Text(
            'No se puede anadir el producto porque no hay inventario suficiente.\n\nDetalle: $detalle',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> restarLinea(dynamic linea) async {
    try {
      await lineaService.restarProducto(
        lineaId: linea['id'],
        cantidadActual: (linea['cantidad'] as num).toInt(),
        productoId: linea['producto_id'] as String,
      );

      await cargarLineas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo restar: $e')));
    }
  }

  Future<void> eliminarLinea(dynamic linea) async {
    try {
      await lineaService.eliminarLinea(
        linea['id'],
        productoId: linea['producto_id'] as String,
        cantidadEliminada: (linea['cantidad'] as num).toInt(),
      );

      await cargarLineas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  double get total {
    return lineaService.calcularTotal(lineas);
  }

  double get descuentoImporte {
    if (clienteAfiliadoCargado?.descuentoDisponible != true) return 0;
    return total * 0.10;
  }

  double get totalConDescuento {
    final resultado = total - descuentoImporte;
    return resultado < 0 ? 0 : resultado;
  }

  int get totalItems {
    return lineaService.calcularTotalItems(lineas);
  }

  Future<void> cargarClienteAfiliado() async {
    final numeroController = TextEditingController();
    final dniController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cargar cliente afiliado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numeroController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Numero de afiliado',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dniController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'DNI/CIF'),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Puedes introducir solo uno de los dos campos.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cargar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    final numero = numeroController.text.trim();
    final dni = dniController.text.trim();
    if (numero.isEmpty && dni.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica numero de afiliado o DNI/CIF')),
      );
      return;
    }

    try {
      final cliente = await clienteAfiliadoService.buscarPorCredencial(
        numeroAfiliado: numero,
        dniCif: dni,
      );

      if (!mounted) return;

      if (cliente == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente afiliado no encontrado')),
        );
        return;
      }

      setState(() {
        clienteAfiliadoCargado = cliente;
      });

      final mensaje = cliente.descuentoDisponible
          ? 'Cliente cargado. Tiene 10% disponible en esta compra.'
          : 'Cliente cargado. Visitas validas: ${cliente.visitasValidas}/5';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar cliente afiliado: $e')),
      );
    }
  }

  bool get _permiteEscanerCamara {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _extraerQrAuthCode(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return '';

    final uri = Uri.tryParse(raw);
    final fromQuery = uri?.queryParameters['code']?.trim() ?? '';
    if (fromQuery.isNotEmpty) return fromQuery;

    final compact = raw.toUpperCase().replaceAll(' ', '');
    if (compact.startsWith('QR-')) return compact;

    return raw;
  }

  Future<String?> _pedirCodigoQrManual() async {
    final controller = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Introducir QR afiliado'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Codigo QR o enlace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return null;
    return controller.text.trim();
  }

  Future<void> _mostrarMensajeCargaCliente(ClienteAfiliado cliente) async {
    final mensaje = cliente.descuentoDisponible
        ? 'Cliente cargado por QR. Tiene 10% disponible en esta compra.'
        : 'Cliente cargado por QR. Visitas validas: ${cliente.visitasValidas}/5';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _altaRapidaDesdeQr(String qrCode) async {
    final nombreController = TextEditingController();
    final dniController = TextEditingController();
    final emailController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Alta rapida de afiliado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dniController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'DNI/CIF'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nombreController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electronico (para enviar QR)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se asociara este cliente al QR escaneado y se intentara enviar su correo de afiliacion.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Crear y cargar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    final dni = dniController.text.trim();
    final nombre = nombreController.text.trim();
    final correo = emailController.text.trim();

    if (dni.isEmpty || nombre.isEmpty || correo.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DNI/CIF, nombre y correo son obligatorios.'),
        ),
      );
      return;
    }

    try {
      final creado = await clienteAfiliadoService.crearCliente(
        dniCif: dni,
        nombreCompleto: nombre,
        correoElectronico: correo,
        qrAuthCodePreferido: qrCode,
      );

      var correoEnviado = false;
      try {
        correoEnviado = await clienteAfiliadoService.enviarCorreoAltaConQr(
          creado,
        );
      } catch (_) {
        correoEnviado = false;
      }

      if (!mounted) return;

      setState(() {
        clienteAfiliadoCargado = creado;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            correoEnviado
                ? 'Cliente creado y cargado. Correo de QR enviado.'
                : 'Cliente creado y cargado. No se pudo enviar el correo (revisa configuracion de funcion/secrets).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear cliente desde QR: $e')),
      );
    }
  }

  Future<void> cargarClienteAfiliadoPorQr() async {
    try {
      String? raw;
      if (_permiteEscanerCamara) {
        raw = await Navigator.of(
          context,
        ).push<String>(MaterialPageRoute(builder: (_) => const ScanQrPage()));
      } else {
        raw = await _pedirCodigoQrManual();
      }

      if (raw == null || raw.trim().isEmpty) return;

      final qrCode = _extraerQrAuthCode(raw);
      if (qrCode.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR invalido. Intentalo de nuevo.')),
        );
        return;
      }

      final cliente = await clienteAfiliadoService.buscarPorQrAuthCode(qrCode);
      if (!mounted) return;

      if (cliente == null) {
        final crear = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('QR no registrado'),
              content: const Text(
                'No existe ningun cliente afiliado con ese QR. ¿Quieres darlo de alta ahora?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Alta rapida'),
                ),
              ],
            );
          },
        );

        if (crear == true) {
          await _altaRapidaDesdeQr(qrCode);
        }
        return;
      }

      setState(() {
        clienteAfiliadoCargado = cliente;
      });

      await _mostrarMensajeCargaCliente(cliente);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar cliente por QR: $e')),
      );
    }
  }

  Future<void> cobrar() async {
    if (pedidoId == null || lineas.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirmar cobro"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subtotal: ${total.toStringAsFixed(2)}€'),
              if (descuentoImporte > 0)
                Text(
                  'Descuento afiliacion (10%): -${descuentoImporte.toStringAsFixed(2)}€',
                ),
              const SizedBox(height: 6),
              Text(
                'Total a cobrar: ${totalConDescuento.toStringAsFixed(2)}€',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text("Cobrar"),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await pedidoService.cerrarPedido(
        pedidoId: pedidoId!,
        total: totalConDescuento,
        subtotal: total,
        descuentoAplicado: descuentoImporte,
        descuentoPorcentaje: descuentoImporte > 0 ? 10 : 0,
        clienteAfiliadoId: clienteAfiliadoCargado?.id,
        afiliadoNumero: clienteAfiliadoCargado?.numeroAfiliado,
      );

      if (clienteAfiliadoCargado != null) {
        await clienteAfiliadoService.registrarCompra(
          clienteId: clienteAfiliadoCargado!.id,
          totalAntesDescuento: total,
          descuentoAplicado: descuentoImporte > 0,
        );
      }

      await mesaService.actualizarNombreMesa(
        mesaId: widget.mesa.id,
        nombre: widget.nombreBaseMesa,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido cobrado correctamente")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cobrar el pedido: $e')),
      );
    }
  }

  Future<void> liberarMesa() async {
    if (pedidoId == null) return;
    if (lineas.isNotEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Liberar mesa"),
          content: const Text(
            "La mesa no tiene productos. Se cerrara el pedido vacio y volvera a libre.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text("Liberar"),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await pedidoService.cerrarPedido(pedidoId: pedidoId!, total: 0);

      await mesaService.actualizarNombreMesa(
        mesaId: widget.mesa.id,
        nombre: widget.nombreBaseMesa,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mesa liberada correctamente")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo liberar la mesa: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return Scaffold(
        appBar: AppBar(
          title: Text('TPV - $nombreMesaActual'),
          actions: [
            IconButton(
              tooltip: 'Renombrar mesa',
              onPressed: editarNombreMesa,
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('TPV - $nombreMesaActual'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9DEFB), Color(0xFFF3EDFF)],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Renombrar mesa',
            onPressed: editarNombreMesa,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: WatermarkBackground(
        gradientColors: const [Color(0xFFEDE5FF), Color(0xFFF6F1FF)],
        opacity: 0.09,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final esMovil = constraints.maxWidth < 980;

            if (esMovil) {
              return Container(
                color: _crema,
                child: Column(
                  children: [
                    Expanded(flex: 3, child: _buildProductosPanel()),
                    Expanded(flex: 2, child: _buildPedidoPanel()),
                  ],
                ),
              );
            }

            return Container(
              color: _crema,
              child: Row(
                children: [
                  Expanded(flex: 2, child: _buildProductosPanel()),
                  Expanded(flex: 1, child: _buildPedidoPanel()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductosPanel() {
    return Container(
      color: _crema,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCategorias(),

          const SizedBox(height: 12),

          if (categoriaSeleccionada == "botella") _buildCajas(),

          if (categoriaSeleccionada == "botella" &&
              subcategoriasBotellas.isNotEmpty)
            _buildSubcategoriasBotellas(),

          if (seleccionandoCaja) _buildAvisoCaja(),

          const SizedBox(height: 12),

          Expanded(
            child: productosFiltrados.isEmpty
                ? const Center(
                    child: Text("No hay productos en esta categoría"),
                  )
                : GridView.builder(
                    itemCount: productosFiltrados.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                    itemBuilder: (context, index) {
                      final producto = productosFiltrados[index];

                      final colorCategoria = categoriaSeleccionada == 'botella'
                          ? _vino
                          : categoriaSeleccionada == 'copa'
                          ? _madera
                          : _verde;

                      return ElevatedButton(
                        onPressed: procesandoCaja
                            ? null
                            : () => anadirProducto(producto),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorCategoria,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 92),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              producto.nombre,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${producto.precio.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorias() {
    return Row(
      children: [
        _buildCategoriaButton("botella", "Botellas"),
        const SizedBox(width: 8),
        _buildCategoriaButton("copa", "Copas"),
        const SizedBox(width: 8),
        _buildCategoriaButton("conserva", "Tapas / Conservas"),
      ],
    );
  }

  Widget _buildCategoriaButton(String categoria, String texto) {
    final bool activa = categoriaSeleccionada == categoria;

    final color = categoria == 'botella'
        ? _vino
        : categoria == 'copa'
        ? _madera
        : _verde;

    return Expanded(
      child: ElevatedButton(
        onPressed: () => cambiarCategoria(categoria),
        style: ElevatedButton.styleFrom(
          elevation: activa ? 0 : 0,
          backgroundColor: activa ? color : Colors.white,
          foregroundColor: activa ? Colors.white : _pizarra,
          side: BorderSide(color: activa ? color : const Color(0xFFC9B6EA)),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCajas() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => iniciarCaja(3),
              style: ElevatedButton.styleFrom(backgroundColor: _madera),
              child: const Text("Caja 3"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => iniciarCaja(6),
              style: ElevatedButton.styleFrom(backgroundColor: _madera),
              child: const Text("Caja 6"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => iniciarCaja(12),
              style: ElevatedButton.styleFrom(backgroundColor: _madera),
              child: const Text("Caja 12"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoriasBotellas() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subcategoriasBotellas.length,
        itemBuilder: (context, index) {
          final subcategoria = subcategoriasBotellas[index];
          final activa = subcategoriaSeleccionada == subcategoria;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => cambiarSubcategoria(subcategoria),
              style: ElevatedButton.styleFrom(
                backgroundColor: activa ? _vino : Colors.white,
                foregroundColor: activa ? Colors.white : _pizarra,
                side: BorderSide(
                  color: activa ? _vino : const Color(0xFFC9B6EA),
                ),
              ),
              child: Text(subcategoria),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvisoCaja() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _madera),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              procesandoCaja
                  ? "Procesando caja..."
                  : "Selecciona botellas para caja de $cantidadCaja "
                        "(${cajaTemporal.length}/$cantidadCaja)",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(onPressed: cancelarCaja, child: const Text("Cancelar")),
        ],
      ),
    );
  }

  Widget _buildPedidoPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comanda',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _pizarra,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _vino,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              nombreMesaActual,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cargarClienteAfiliado,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Manual'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: cargarClienteAfiliadoPorQr,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F2937),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF6B7280),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR'),
                ),
              ),
            ],
          ),

          if (clienteAfiliadoCargado != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _madera),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${clienteAfiliadoCargado!.nombre} · ${clienteAfiliadoCargado!.numeroAfiliado}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            clienteAfiliadoCargado = null;
                          });
                        },
                        child: const Text('Quitar'),
                      ),
                    ],
                  ),
                  Text(
                    'Visitas validas: ${clienteAfiliadoCargado!.visitasValidas}/5',
                  ),
                  Text(
                    clienteAfiliadoCargado!.descuentoDisponible
                        ? 'Descuento 10% disponible en esta compra'
                        : 'Aun no aplica descuento',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: clienteAfiliadoCargado!.descuentoDisponible
                          ? Colors.green
                          : _pizarra,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),

          Expanded(
            child: lineas.isEmpty
                ? const Center(child: Text("Todavía no hay productos"))
                : ListView.builder(
                    itemCount: lineas.length,
                    itemBuilder: (context, index) {
                      final linea = lineas[index];

                      final nombreProducto =
                          linea['productos']?['nombre'] ?? 'Producto';

                      final cantidad = (linea['cantidad'] as num).toInt();

                      final precioUnitario = (linea['precio_unitario'] as num)
                          .toDouble();

                      final totalLinea = precioUnitario * cantidad;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: const Color(0xFFFEFBF7),
                        child: ListTile(
                          title: Text(
                            nombreProducto,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${precioUnitario.toStringAsFixed(2)}€ c/u",
                          ),
                          trailing: Text(
                            "x$cantidad\n${totalLinea.toStringAsFixed(2)}€",
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () => restarLinea(linea),
                          onLongPress: () => eliminarLinea(linea),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Productos:", style: TextStyle(fontSize: 16)),
              Text(
                "$totalItems",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                "${total.toStringAsFixed(2)}€",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (descuentoImporte > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Descuento afiliacion (10%):',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '-${descuentoImporte.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total con descuento:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${totalConDescuento.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: lineas.isEmpty ? null : cobrar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "COBRAR",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (lineas.isEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: liberarMesa,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "LIBERAR MESA",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            "Toca una línea para restar. Mantén pulsado para eliminar.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
