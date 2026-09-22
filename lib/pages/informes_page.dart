// coverage:ignore-file
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_afiliado.dart';
import '../services/cliente_afiliado_service.dart';
import '../services/pedido_service.dart';
import '../widgets/watermark_background.dart';

enum TipoInforme { diario, semanal, mensual, anual, rango }

enum FiltroExportacionProductos { todos, botellas, conservas, copas }

class InformePunto {
  final String etiqueta;
  final double total;
  final DateTime inicio;
  final DateTime fin;

  const InformePunto({
    required this.etiqueta,
    required this.total,
    required this.inicio,
    required this.fin,
  });
}

class InformesPage extends StatefulWidget {
  const InformesPage({super.key});

  @override
  State<InformesPage> createState() => _InformesPageState();
}

class _InformesPageState extends State<InformesPage> {
  final PedidoService pedidoService = PedidoService();
  final ClienteAfiliadoService clienteAfiliadoService =
      ClienteAfiliadoService();
  final supabase = Supabase.instance.client;

  TipoInforme tipoSeleccionado = TipoInforme.diario;
  DateTime fechaInicio = _inicioDia(DateTime.now());
  DateTime fechaFin = _inicioDia(DateTime.now());

  bool cargando = false;
  List<TicketInforme> tickets = [];

  List<InformePunto> seriePrincipal = [];
  List<InformePunto> serieDetalle = [];
  List<InformePunto> serieSubDetalle = [];

  String? tituloDetalle;
  String? tituloSubDetalle;

  double totalVentas = 0;
  bool exportando = false;

  ClienteAfiliado? clienteInformeSeleccionado;
  DateTime fechaInicioCliente = _inicioDia(
    DateTime.now().subtract(const Duration(days: 30)),
  );
  DateTime fechaFinCliente = _inicioDia(DateTime.now());
  bool cargandoInformeCliente = false;
  bool imprimiendoInformeCliente = false;
  InformeClientePersonalizado? informeCliente;

  static const List<String> meses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  void initState() {
    super.initState();
    cargarInforme(TipoInforme.diario);
  }

  static DateTime _inicioDia(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _inicioSemana(DateTime d) {
    final inicio = _inicioDia(d);
    return inicio.subtract(Duration(days: inicio.weekday - 1));
  }

  static DateTime _finSemana(DateTime d) {
    final inicio = _inicioSemana(d);
    return inicio.add(const Duration(days: 6));
  }

  static DateTime _inicioMes(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime _finMes(DateTime d) => DateTime(d.year, d.month + 1, 0);

  static DateTime _inicioAnio(DateTime d) => DateTime(d.year, 1, 1);

  static DateTime _finAnio(DateTime d) => DateTime(d.year, 12, 31);

  Future<void> cargarInforme(
    TipoInforme tipo, {
    DateTime? inicio,
    DateTime? fin,
  }) async {
    final ahora = DateTime.now();

    DateTime nuevoInicio;
    DateTime nuevoFin;

    if (inicio != null && fin != null) {
      nuevoInicio = _inicioDia(inicio);
      nuevoFin = _inicioDia(fin);
    } else {
      switch (tipo) {
        case TipoInforme.diario:
          nuevoInicio = _inicioDia(ahora);
          nuevoFin = _inicioDia(ahora);
          break;
        case TipoInforme.semanal:
          nuevoInicio = _inicioSemana(ahora);
          nuevoFin = _finSemana(ahora);
          break;
        case TipoInforme.mensual:
          nuevoInicio = _inicioMes(ahora);
          nuevoFin = _finMes(ahora);
          break;
        case TipoInforme.anual:
          nuevoInicio = _inicioAnio(ahora);
          nuevoFin = _finAnio(ahora);
          break;
        case TipoInforme.rango:
          nuevoInicio = fechaInicio;
          nuevoFin = fechaFin;
          break;
      }
    }

    setState(() {
      cargando = true;
      tipoSeleccionado = tipo;
      fechaInicio = nuevoInicio;
      fechaFin = nuevoFin;
      serieDetalle = [];
      serieSubDetalle = [];
      tituloDetalle = null;
      tituloSubDetalle = null;
    });

    try {
      final data = await pedidoService.getTicketsCerradosEnRango(
        inicio: nuevoInicio,
        fin: nuevoFin,
      );

      final total = data.fold<double>(0, (sum, t) => sum + t.total);

      List<InformePunto> principal = [];
      if (tipo == TipoInforme.semanal) {
        principal = construirSerieDiaria(nuevoInicio, nuevoFin, data);
      } else if (tipo == TipoInforme.mensual) {
        principal = construirSerieSemanas(nuevoInicio, nuevoFin, data);
      } else if (tipo == TipoInforme.anual) {
        principal = construirSerieMeses(nuevoInicio.year, data);
      } else if (tipo == TipoInforme.rango) {
        final dias = nuevoFin.difference(nuevoInicio).inDays + 1;
        if (dias <= 31) {
          principal = construirSerieDiaria(nuevoInicio, nuevoFin, data);
        } else {
          principal = construirSerieSemanas(nuevoInicio, nuevoFin, data);
        }
      }

      if (!mounted) return;

      setState(() {
        tickets = data;
        totalVentas = total;
        seriePrincipal = principal;
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los informes: $e')),
      );
    }
  }

  List<InformePunto> construirSerieDiaria(
    DateTime inicio,
    DateTime fin,
    List<TicketInforme> data,
  ) {
    final totals = <String, double>{};

    for (final ticket in data) {
      final d = _inicioDia(ticket.fecha);
      final key = '${d.year}-${d.month}-${d.day}';
      totals[key] = (totals[key] ?? 0) + ticket.total;
    }

    final puntos = <InformePunto>[];
    var cursor = _inicioDia(inicio);
    while (!cursor.isAfter(fin)) {
      final key = '${cursor.year}-${cursor.month}-${cursor.day}';
      final total = totals[key] ?? 0;
      puntos.add(
        InformePunto(
          etiqueta: '${cursor.day}',
          total: total,
          inicio: cursor,
          fin: cursor,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }

    return puntos;
  }

  List<InformePunto> construirSerieSemanas(
    DateTime inicio,
    DateTime fin,
    List<TicketInforme> data,
  ) {
    final puntos = <InformePunto>[];
    var indice = 1;
    var weekStart = _inicioSemana(inicio);

    while (!weekStart.isAfter(fin)) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final tramoInicio = weekStart.isBefore(inicio) ? inicio : weekStart;
      final tramoFin = weekEnd.isAfter(fin) ? fin : weekEnd;

      if (!tramoInicio.isAfter(tramoFin)) {
        final total = data
            .where((t) {
              final fecha = _inicioDia(t.fecha);
              return !fecha.isBefore(tramoInicio) && !fecha.isAfter(tramoFin);
            })
            .fold<double>(0, (sum, t) => sum + t.total);

        puntos.add(
          InformePunto(
            etiqueta: 'Sem $indice',
            total: total,
            inicio: tramoInicio,
            fin: tramoFin,
          ),
        );
        indice += 1;
      }

      weekStart = weekStart.add(const Duration(days: 7));
    }

    return puntos;
  }

  List<InformePunto> construirSerieMeses(int anio, List<TicketInforme> data) {
    final puntos = <InformePunto>[];

    for (var mes = 1; mes <= 12; mes++) {
      final inicio = DateTime(anio, mes, 1);
      final fin = DateTime(anio, mes + 1, 0);

      final total = data
          .where((t) {
            final fecha = _inicioDia(t.fecha);
            return !fecha.isBefore(inicio) && !fecha.isAfter(fin);
          })
          .fold<double>(0, (sum, t) => sum + t.total);

      puntos.add(
        InformePunto(
          etiqueta: meses[mes - 1],
          total: total,
          inicio: inicio,
          fin: fin,
        ),
      );
    }

    return puntos;
  }

  List<InformePunto> construirSerieCategorias(
    DateTime inicio,
    DateTime fin,
    List<TicketInforme> data,
  ) {
    final totals = <String, double>{
      'Conservas': 0,
      'Botellas': 0,
      'Copas': 0,
      'Otros': 0,
    };

    for (final ticket in data) {
      final fecha = _inicioDia(ticket.fecha);
      if (fecha.isBefore(inicio) || fecha.isAfter(fin)) continue;

      for (final linea in ticket.lineas) {
        final tipo = linea.productoTipo;
        final categoria = (tipo == 'conserva' || tipo == 'tapa')
            ? 'Conservas'
            : (tipo == 'botella')
            ? 'Botellas'
            : (tipo == 'copa')
            ? 'Copas'
            : 'Otros';
        totals[categoria] = (totals[categoria] ?? 0) + linea.totalLinea;
      }
    }

    return totals.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => InformePunto(
            etiqueta: entry.key,
            total: entry.value,
            inicio: inicio,
            fin: fin,
          ),
        )
        .toList();
  }

  Future<void> seleccionarRangoFechas() async {
    final inicio = await showDatePicker(
      context: context,
      initialDate: fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha de inicio',
    );

    if (inicio == null || !mounted) return;

    final fin = await showDatePicker(
      context: context,
      initialDate: fechaFin.isBefore(inicio) ? inicio : fechaFin,
      firstDate: inicio,
      lastDate: DateTime(2100),
      helpText: 'Fecha de fin',
    );

    if (fin == null) return;

    await cargarInforme(TipoInforme.rango, inicio: inicio, fin: fin);
  }

  void onTapPrincipal(int index) {
    if (index < 0 || index >= seriePrincipal.length) return;

    final punto = seriePrincipal[index];

    if (tipoSeleccionado == TipoInforme.mensual) {
      final detalle = construirSerieDiaria(punto.inicio, punto.fin, tickets);
      setState(() {
        serieDetalle = detalle;
        tituloDetalle = 'Detalle ${punto.etiqueta}';
        serieSubDetalle = [];
        tituloSubDetalle = null;
      });
      return;
    }

    if (tipoSeleccionado == TipoInforme.anual) {
      final detalle = construirSerieSemanas(punto.inicio, punto.fin, tickets);
      setState(() {
        serieDetalle = detalle;
        tituloDetalle = 'Semanas de ${punto.etiqueta}';
        serieSubDetalle = [];
        tituloSubDetalle = null;
      });
      return;
    }
  }

  void onTapDetalle(int index) {
    if (tipoSeleccionado != TipoInforme.anual) return;
    if (index < 0 || index >= serieDetalle.length) return;

    final punto = serieDetalle[index];
    final subDetalle = construirSerieDiaria(punto.inicio, punto.fin, tickets);

    setState(() {
      serieSubDetalle = subDetalle;
      tituloSubDetalle = 'Dias de ${punto.etiqueta}';
    });
  }

  String formatoFecha(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  String formatoHora(DateTime fecha) {
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  String formatoFechaHora(DateTime fecha) {
    return '${formatoFecha(fecha)} ${formatoHora(fecha)}';
  }

  Future<void> _seleccionarClienteInforme() async {
    final numeroController = TextEditingController();
    final dniController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Buscar cliente afiliado'),
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
              const SizedBox(height: 8),
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
              child: const Text('Buscar'),
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
        clienteInformeSeleccionado = cliente;
        informeCliente = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo buscar cliente: $e')));
    }
  }

  Future<void> _seleccionarFechaInicioCliente() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaInicioCliente,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Inicio informe cliente',
    );

    if (picked == null || !mounted) return;

    setState(() {
      fechaInicioCliente = _inicioDia(picked);
      if (fechaFinCliente.isBefore(fechaInicioCliente)) {
        fechaFinCliente = fechaInicioCliente;
      }
      informeCliente = null;
    });
  }

  Future<void> _seleccionarFechaFinCliente() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaFinCliente,
      firstDate: fechaInicioCliente,
      lastDate: DateTime.now(),
      helpText: 'Fin informe cliente',
    );

    if (picked == null || !mounted) return;

    setState(() {
      fechaFinCliente = _inicioDia(picked);
      informeCliente = null;
    });
  }

  Future<void> _generarInformeCliente() async {
    final cliente = clienteInformeSeleccionado;
    if (cliente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona un cliente afiliado')),
      );
      return;
    }

    setState(() {
      cargandoInformeCliente = true;
    });

    try {
      final resultado = await pedidoService.getInformePersonalizadoPorCliente(
        clienteId: cliente.id,
        inicio: fechaInicioCliente,
        fin: fechaFinCliente,
      );

      if (!mounted) return;

      setState(() {
        informeCliente = resultado;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el informe del cliente: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          cargandoInformeCliente = false;
        });
      }
    }
  }

  Future<List<int>> _crearPdfTicketsCliente({
    required InformeClientePersonalizado informe,
    required String titulo,
  }) async {
    final pdf = pw.Document();
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final cliente = clienteInformeSeleccionado;
    final nombreCliente = cliente?.nombre ?? 'Cliente afiliado';
    final identificador = cliente?.numeroAfiliado ?? informe.clienteId;

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              titulo,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Cliente: $nombreCliente ($identificador)'),
            pw.Text(
              'Rango: ${formatoFecha(informe.inicio)} - ${formatoFecha(informe.fin)}',
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Pedidos: ${informe.pedidos}'),
                  pw.Text(
                    'Total gastado: ${informe.totalGastado.toStringAsFixed(2)}€',
                  ),
                  pw.Text(
                    'Total ahorrado: ${informe.totalAhorrado.toStringAsFixed(2)}€',
                  ),
                  pw.Text(
                    'Ticket medio: ${informe.ticketMedio.toStringAsFixed(2)}€',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            if (informe.tickets.isEmpty)
              pw.Text('No hay tickets para este rango de fechas.')
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Fecha',
                  'Mesa',
                  'Subtotal',
                  'Descuento',
                  'Total',
                ],
                data: informe.tickets
                    .map(
                      (ticket) => [
                        '${formatoFecha(ticket.fecha)} ${formatoHora(ticket.fecha)}',
                        ticket.mesaNombre,
                        '${ticket.subtotal.toStringAsFixed(2)}€',
                        '${ticket.descuentoAplicado.toStringAsFixed(2)}€ (${ticket.descuentoPorcentaje.toStringAsFixed(0)}%)',
                        '${ticket.total.toStringAsFixed(2)}€',
                      ],
                    )
                    .toList(),
              ),
            if (informe.tickets.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Detalle de productos por pedido',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              for (final ticket in informe.tickets) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Ticket ${ticket.id.length >= 8 ? ticket.id.substring(0, 8) : ticket.id} · ${ticket.mesaNombre}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${formatoFecha(ticket.fecha)} ${formatoHora(ticket.fecha)} · Total ${ticket.total.toStringAsFixed(2)}€',
                      ),
                      pw.SizedBox(height: 4),
                      if (ticket.lineas.isEmpty)
                        pw.Text('Sin lineas de producto')
                      else
                        pw.TableHelper.fromTextArray(
                          headers: const [
                            'Producto',
                            'Cant.',
                            'P.Unit',
                            'Importe',
                          ],
                          data: ticket.lineas
                              .map(
                                (linea) => [
                                  linea.productoNombre,
                                  '${linea.cantidad}',
                                  '${linea.precioUnitario.toStringAsFixed(2)}€',
                                  '${linea.totalLinea.toStringAsFixed(2)}€',
                                ],
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> imprimirInformeCliente() async {
    final informe = informeCliente;
    if (informe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Genera primero el informe del cliente')),
      );
      return;
    }

    if (informe.tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay tickets de cliente para imprimir'),
        ),
      );
      return;
    }

    setState(() {
      imprimiendoInformeCliente = true;
    });

    try {
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(
          await _crearPdfTicketsCliente(
            informe: informe,
            titulo: 'Tickets de cliente por rango',
          ),
        ),
      );
    } on MissingPluginException {
      try {
        final bytes = await _crearPdfTicketsCliente(
          informe: informe,
          titulo: 'Tickets de cliente por rango',
        );
        final afiliado =
            clienteInformeSeleccionado?.numeroAfiliado ?? 'cliente';
        await _guardarPdfImpresionFallback(
          bytes,
          nombreBase:
              'tickets_cliente_${_slugArchivo(afiliado)}_${_fechaArchivo(informe.inicio)}_a_${_fechaArchivo(informe.fin)}',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF del cliente: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo imprimir el informe de cliente: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          imprimiendoInformeCliente = false;
        });
      }
    }
  }

  Widget _buildDatoInformeCliente(String etiqueta, String valor) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD2BBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget buildInformeClienteCard() {
    final cliente = clienteInformeSeleccionado;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Informe personalizado por cliente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _seleccionarClienteInforme,
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(cliente == null ? 'Buscar cliente' : 'Cambiar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (cliente == null)
              const Text(
                'Selecciona un cliente afiliado para generar su informe.',
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD7C3F3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${cliente.nombre} · ${cliente.numeroAfiliado}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              clienteInformeSeleccionado = null;
                              informeCliente = null;
                            });
                          },
                          child: const Text('Quitar'),
                        ),
                      ],
                    ),
                    Text('DNI/CIF: ${cliente.dniCif}'),
                    Text('Visitas validas: ${cliente.visitasValidas}/5'),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _seleccionarFechaInicioCliente,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Inicio: ${formatoFecha(fechaInicioCliente)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _seleccionarFechaFinCliente,
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Fin: ${formatoFecha(fechaFinCliente)}'),
                ),
                ElevatedButton.icon(
                  onPressed: cargandoInformeCliente
                      ? null
                      : _generarInformeCliente,
                  icon: cargandoInformeCliente
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.insights_outlined),
                  label: Text(
                    cargandoInformeCliente ? 'Generando...' : 'Generar informe',
                  ),
                ),
              ],
            ),
            if (informeCliente != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDatoInformeCliente(
                    'Pedidos',
                    '${informeCliente!.pedidos}',
                  ),
                  _buildDatoInformeCliente(
                    'Gastado',
                    '${informeCliente!.totalGastado.toStringAsFixed(2)}€',
                  ),
                  _buildDatoInformeCliente(
                    'Ahorrado',
                    '${informeCliente!.totalAhorrado.toStringAsFixed(2)}€',
                  ),
                  _buildDatoInformeCliente(
                    'Ticket medio',
                    '${informeCliente!.ticketMedio.toStringAsFixed(2)}€',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tickets del cliente (${informeCliente!.tickets.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: imprimiendoInformeCliente
                        ? null
                        : imprimirInformeCliente,
                    icon: imprimiendoInformeCliente
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 18),
                    label: Text(
                      imprimiendoInformeCliente
                          ? 'Imprimiendo...'
                          : 'Imprimir PDF',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (informeCliente!.tickets.isEmpty)
                const Text('No hay compras para ese cliente en este rango.'),
              if (informeCliente!.tickets.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: informeCliente!.tickets.length,
                  separatorBuilder: (_, index) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final ticket = informeCliente!.tickets[index];
                    final totalUnidades = ticket.lineas.fold<int>(
                      0,
                      (sum, l) => sum + l.cantidad,
                    );

                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        '${ticket.total.toStringAsFixed(2)}€ · ${ticket.mesaNombre}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${formatoFechaHora(ticket.fecha)} · Ticket ${ticket.id.length >= 8 ? ticket.id.substring(0, 8) : ticket.id}\n'
                        'Subtotal: ${ticket.subtotal.toStringAsFixed(2)}€ · '
                        'Descuento: ${ticket.descuentoAplicado.toStringAsFixed(2)}€ (${ticket.descuentoPorcentaje.toStringAsFixed(0)}%) · '
                        'Productos: ${ticket.lineas.length} · Unidades: $totalUnidades',
                      ),
                      children: [
                        if (ticket.lineas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Sin detalle de productos en este pedido',
                              ),
                            ),
                          ),
                        for (final linea in ticket.lineas)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${linea.cantidad} x ${linea.productoNombre}',
                                  ),
                                ),
                                Text(
                                  '${linea.precioUnitario.toStringAsFixed(2)}€ c/u',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${linea.totalLinea.toStringAsFixed(2)}€',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _fechaArchivo(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '${fecha.year}-$m-$d';
  }

  String _mesNombreArchivo(int month) {
    const nombres = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    if (month < 1 || month > 12) return 'mes';
    return nombres[month - 1];
  }

  String _ordinalSemana(int n) {
    switch (n) {
      case 1:
        return 'primera';
      case 2:
        return 'segunda';
      case 3:
        return 'tercera';
      case 4:
        return 'cuarta';
      case 5:
        return 'quinta';
      default:
        return '${n}a';
    }
  }

  String _slugArchivo(String input) {
    var s = input.toLowerCase();
    s = s
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');

    final buffer = StringBuffer();
    var prevUnderscore = false;
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final isAlphaNum =
          (rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57);
      if (isAlphaNum) {
        buffer.write(ch);
        prevUnderscore = false;
      } else {
        if (!prevUnderscore) {
          buffer.write('_');
          prevUnderscore = true;
        }
      }
    }

    final out = buffer.toString().replaceAll(RegExp(r'^_+|_+$'), '');
    return out.isEmpty ? 'archivo' : out;
  }

  String _descriptorInformeArchivo() {
    switch (tipoSeleccionado) {
      case TipoInforme.anual:
        return 'anual_${fechaInicio.year}';
      case TipoInforme.mensual:
        return 'mensual_${_mesNombreArchivo(fechaInicio.month)}_${fechaInicio.year}';
      case TipoInforme.semanal:
        final semanaEnMes = ((fechaInicio.day - 1) ~/ 7) + 1;
        return 'semanal_${_ordinalSemana(semanaEnMes)}_semana_${_mesNombreArchivo(fechaInicio.month)}_${fechaInicio.year}';
      case TipoInforme.diario:
        return 'diario_${_fechaArchivo(fechaInicio)}';
      case TipoInforme.rango:
        return 'rango_${_fechaArchivo(fechaInicio)}_a_${_fechaArchivo(fechaFin)}';
    }
  }

  String etiquetaFiltro(FiltroExportacionProductos filtro) {
    switch (filtro) {
      case FiltroExportacionProductos.todos:
        return 'Todos los productos';
      case FiltroExportacionProductos.botellas:
        return 'Solo botellas de vino';
      case FiltroExportacionProductos.conservas:
        return 'Solo conservas';
      case FiltroExportacionProductos.copas:
        return 'Solo copas';
    }
  }

  bool _lineaCumpleFiltro(
    TicketLineaInforme linea,
    FiltroExportacionProductos filtro,
  ) {
    if (filtro == FiltroExportacionProductos.todos) return true;
    if (filtro == FiltroExportacionProductos.botellas) {
      return linea.productoTipo == 'botella';
    }
    if (filtro == FiltroExportacionProductos.copas) {
      return linea.productoTipo == 'copa';
    }

    return linea.productoTipo == 'conserva' || linea.productoTipo == 'tapa';
  }

  List<TicketInforme> _ticketsFiltradosParaExportar(
    FiltroExportacionProductos filtro,
  ) {
    final resultado = <TicketInforme>[];

    for (final ticket in tickets) {
      final lineasFiltradas = ticket.lineas
          .where((l) => _lineaCumpleFiltro(l, filtro))
          .toList();

      if (lineasFiltradas.isEmpty) continue;

      final totalFiltrado = lineasFiltradas.fold<double>(
        0,
        (sum, l) => sum + l.totalLinea,
      );

      if (totalFiltrado <= 0) continue;

      resultado.add(
        TicketInforme(
          id: ticket.id,
          mesaId: ticket.mesaId,
          mesaNombre: ticket.mesaNombre,
          fecha: ticket.fecha,
          total: totalFiltrado,
          lineas: lineasFiltradas,
        ),
      );
    }

    return resultado;
  }

  Future<FiltroExportacionProductos?> _seleccionarFiltroExportacion() async {
    var seleccion = FiltroExportacionProductos.todos;

    return showDialog<FiltroExportacionProductos>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Exportar informes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<FiltroExportacionProductos>(
                    initialValue: seleccion,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar productos para exportar',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in FiltroExportacionProductos.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(etiquetaFiltro(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        seleccion = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(seleccion),
                  child: const Text('Exportar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> exportarInformes() async {
    if (tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay tickets para exportar')),
      );
      return;
    }

    final filtro = await _seleccionarFiltroExportacion();
    if (filtro == null) return;

    if (!mounted) return;

    final exportTickets = _ticketsFiltradosParaExportar(filtro);
    if (exportTickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos para el filtro seleccionado'),
        ),
      );
      return;
    }

    setState(() {
      exportando = true;
    });

    try {
      final bytesProductos = _crearExcelProductos(exportTickets, filtro);
      final bytesResumen = await _crearPdfResumen(exportTickets, filtro);

      final dir = await _obtenerDirectorioDescargas();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final descriptor = _descriptorInformeArchivo();

      final pathProductos =
          '${dir.path}${Platform.pathSeparator}informe_productos_${descriptor}_$ts.xlsx';
      final pathResumen =
          '${dir.path}${Platform.pathSeparator}informe_resumen_${descriptor}_$ts.pdf';

      await File(pathProductos).writeAsBytes(bytesProductos, flush: true);
      await File(pathResumen).writeAsBytes(bytesResumen, flush: true);

      var correoAnualEnviado = false;
      if (tipoSeleccionado == TipoInforme.anual) {
        correoAnualEnviado = await _enviarCorreoInformeAnual(
          totalTickets: exportTickets.length,
          totalVentas: exportTickets.fold<double>(0, (sum, t) => sum + t.total),
          filtro: etiquetaFiltro(filtro),
          pathProductos: pathProductos,
          pathResumen: pathResumen,
          nombreArchivoProductos: 'informe_productos_${descriptor}_$ts.xlsx',
          nombreArchivoResumen: 'informe_resumen_${descriptor}_$ts.pdf',
          contenidoProductosBase64: base64Encode(bytesProductos),
          contenidoResumenBase64: base64Encode(bytesResumen),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tipoSeleccionado == TipoInforme.anual
                ? (correoAnualEnviado
                      ? 'Archivos exportados y correo anual enviado:\n$pathProductos\n$pathResumen'
                      : 'Archivos exportados. No se pudo enviar el correo anual (revisa function/secrets).\n$pathProductos\n$pathResumen')
                : 'Archivos exportados:\n$pathProductos\n$pathResumen',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exportando informes: $e')));
    } finally {
      if (mounted) {
        setState(() {
          exportando = false;
        });
      }
    }
  }

  Future<bool> _enviarCorreoInformeAnual({
    required int totalTickets,
    required double totalVentas,
    required String filtro,
    required String pathProductos,
    required String pathResumen,
    required String nombreArchivoProductos,
    required String nombreArchivoResumen,
    required String contenidoProductosBase64,
    required String contenidoResumenBase64,
  }) async {
    try {
      final response = await supabase.functions.invoke(
        'send-informe-anual-email',
        body: {
          'anio': fechaInicio.year,
          'fechaInicio': formatoFecha(fechaInicio),
          'fechaFin': formatoFecha(fechaFin),
          'totalTickets': totalTickets,
          'totalVentas': totalVentas,
          'filtro': filtro,
          'generatedAt': DateTime.now().toIso8601String(),
          'pathProductos': pathProductos,
          'pathResumen': pathResumen,
          'productosFilename': nombreArchivoProductos,
          'productosBase64': contenidoProductosBase64,
          'resumenFilename': nombreArchivoResumen,
          'resumenBase64': contenidoResumenBase64,
        },
      );

      return response.status >= 200 && response.status < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _obtenerDirectorioDescargas() async {
    final fromProvider = await getDownloadsDirectory();
    if (fromProvider != null) {
      if (!await fromProvider.exists()) {
        await fromProvider.create(recursive: true);
      }
      return fromProvider;
    }

    final env = Platform.environment;
    String? basePath;

    if (Platform.isWindows) {
      basePath = env['USERPROFILE'];
    } else {
      basePath = env['HOME'];
    }

    if (basePath != null && basePath.trim().isNotEmpty) {
      final downloads = Directory(
        '$basePath${Platform.pathSeparator}Downloads',
      );
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      return downloads;
    }

    return getTemporaryDirectory();
  }

  List<int> _crearExcelProductos(
    List<TicketInforme> exportTickets,
    FiltroExportacionProductos filtro,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel['ProductosVendidos'];
    excel.delete('Sheet1');

    final incluirFecha = tipoSeleccionado == TipoInforme.mensual;
    final separarPorMes = tipoSeleccionado == TipoInforme.anual;
    final incluirMesEnClave = separarPorMes || incluirFecha;

    if (incluirFecha) {
      sheet.setColumnWidth(0, 16);
      sheet.setColumnWidth(1, 52);
      sheet.setColumnWidth(2, 14);
      sheet.setColumnWidth(3, 18);
    } else {
      sheet.setColumnAutoFit(0);
      sheet.setColumnWidth(0, 52);
      sheet.setColumnWidth(1, 14);
      sheet.setColumnWidth(2, 18);
    }

    final separadorStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.green,
      fontColorHex: ExcelColor.white,
    );
    final cabeceraStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blueGrey,
      fontColorHex: ExcelColor.white,
    );
    final separadorMesStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
    );
    final separadorFechaStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.lightBlue,
      fontColorHex: ExcelColor.black,
    );
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.grey,
    );

    var rowIndex = 0;
    final columnas = incluirFecha ? 4 : 3;

    List<CellValue> filaVacia() {
      return List<CellValue>.generate(columnas, (_) => TextCellValue(''));
    }

    List<CellValue> filaTitulo(String texto) {
      final row = filaVacia();
      row[0] = TextCellValue(texto);
      return row;
    }

    void appendStyledRow(List<CellValue> row, {CellStyle? style}) {
      sheet.appendRow(row);
      if (style != null) {
        for (var col = 0; col < row.length; col++) {
          sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: col,
                      rowIndex: rowIndex,
                    ),
                  )
                  .cellStyle =
              style;
        }
      }
      rowIndex += 1;
    }

    final resumenProductos = <String, Map<String, dynamic>>{};
    for (final ticket in exportTickets) {
      final fechaVenta = DateTime(
        ticket.fecha.year,
        ticket.fecha.month,
        ticket.fecha.day,
      );
      final mesNumero = fechaVenta.month.toString().padLeft(2, '0');
      final mesClave = '${fechaVenta.year}-$mesNumero';
      final mesEtiqueta =
          '${_mesNombreArchivo(fechaVenta.month)} ${fechaVenta.year}';
      final fechaEtiqueta = formatoFecha(fechaVenta);
      final fechaClave = _fechaArchivo(fechaVenta);

      for (final linea in ticket.lineas) {
        final categoria = _categoriaEtiqueta(linea.productoTipo);
        final subgrupo = separarPorMes ? 'General' : _subgrupoEtiqueta(linea);
        final key = incluirMesEnClave
            ? (incluirFecha
                  ? '$mesClave|$fechaClave|$categoria|$subgrupo|${linea.productoNombre}'
                  : '$mesClave|$categoria|$subgrupo|${linea.productoNombre}')
            : '$categoria|$subgrupo|${linea.productoNombre}';

        final item = resumenProductos.putIfAbsent(
          key,
          () => {
            'mesClave': mesClave,
            'mesEtiqueta': mesEtiqueta,
            'fechaClave': fechaClave,
            'fechaEtiqueta': fechaEtiqueta,
            'categoria': categoria,
            'subgrupo': subgrupo,
            'producto': linea.productoNombre,
            'cantidad': 0,
            'total': 0.0,
          },
        );
        item['cantidad'] = (item['cantidad'] as int) + linea.cantidad;
        item['total'] = (item['total'] as double) + linea.totalLinea;
      }
    }

    final filas = resumenProductos.entries.toList()
      ..sort((a, b) {
        if (incluirMesEnClave) {
          final mesCmp = (a.value['mesClave'] as String).compareTo(
            b.value['mesClave'] as String,
          );
          if (mesCmp != 0) return mesCmp;

          if (!incluirFecha) {
            final catCmp = (a.value['categoria'] as String).compareTo(
              b.value['categoria'] as String,
            );
            if (catCmp != 0) return catCmp;

            final subCmp = (a.value['subgrupo'] as String).compareTo(
              b.value['subgrupo'] as String,
            );
            if (subCmp != 0) return subCmp;

            return (a.value['producto'] as String).compareTo(
              b.value['producto'] as String,
            );
          }

          final fechaCmp = (a.value['fechaClave'] as String).compareTo(
            b.value['fechaClave'] as String,
          );
          if (fechaCmp != 0) return fechaCmp;
        }

        final catCmp = (a.value['categoria'] as String).compareTo(
          b.value['categoria'] as String,
        );
        if (catCmp != 0) return catCmp;

        final subCmp = (a.value['subgrupo'] as String).compareTo(
          b.value['subgrupo'] as String,
        );
        if (subCmp != 0) return subCmp;

        return (a.value['producto'] as String).compareTo(
          b.value['producto'] as String,
        );
      });

    appendStyledRow(filaTitulo('Listado de productos vendidos'));
    appendStyledRow(filaTitulo('Filtro: ${etiquetaFiltro(filtro)}'));
    appendStyledRow(
      filaTitulo(
        'Rango: ${formatoFecha(fechaInicio)} - ${formatoFecha(fechaFin)}',
      ),
    );
    appendStyledRow(filaVacia());

    appendStyledRow(
      incluirFecha
          ? [
              TextCellValue('Fecha'),
              TextCellValue('Producto'),
              TextCellValue('Cantidad'),
              TextCellValue('Importe'),
            ]
          : [
              TextCellValue('Producto'),
              TextCellValue('Cantidad'),
              TextCellValue('Importe'),
            ],
      style: cabeceraStyle,
    );

    String? mesActual;
    String? fechaActual;
    String? categoriaActual;
    String? subgrupoActual;

    for (final fila in filas) {
      final mesEtiqueta = fila.value['mesEtiqueta'] as String;
      final fechaEtiqueta = fila.value['fechaEtiqueta'] as String;
      final categoria = fila.value['categoria'] as String;
      final subgrupo = fila.value['subgrupo'] as String;

      if (separarPorMes && mesActual != mesEtiqueta) {
        if (mesActual != null) {
          appendStyledRow(filaVacia());
        }
        appendStyledRow(
          filaTitulo('Mes: $mesEtiqueta'),
          style: separadorMesStyle,
        );
        mesActual = mesEtiqueta;
        fechaActual = null;
        categoriaActual = null;
        subgrupoActual = null;
      }

      if (incluirFecha && fechaActual != fechaEtiqueta) {
        appendStyledRow(
          filaTitulo('Fecha: $fechaEtiqueta'),
          style: separadorFechaStyle,
        );
        fechaActual = fechaEtiqueta;
        categoriaActual = null;
        subgrupoActual = null;
      }

      if (categoriaActual != categoria) {
        if (categoriaActual != null) {
          appendStyledRow(filaVacia());
        }
        appendStyledRow(
          filaTitulo('Categoria: $categoria'),
          style: separadorStyle,
        );
        categoriaActual = categoria;
        subgrupoActual = null;
      }

      if (subgrupoActual != subgrupo) {
        appendStyledRow(
          filaTitulo('  ${_subgrupoTitulo(categoria, subgrupo)}'),
          style: separadorStyle,
        );
        subgrupoActual = subgrupo;
      }

      if (incluirFecha) {
        appendStyledRow([
          TextCellValue(fechaEtiqueta),
          TextCellValue('    ${fila.value['producto']}'),
          IntCellValue(fila.value['cantidad'] as int),
          DoubleCellValue(fila.value['total'] as double),
        ]);
      } else {
        appendStyledRow([
          TextCellValue('    ${fila.value['producto']}'),
          IntCellValue(fila.value['cantidad'] as int),
          DoubleCellValue(fila.value['total'] as double),
        ]);
      }
    }

    final totalCantidad = filas.fold<int>(
      0,
      (sum, f) => sum + (f.value['cantidad'] as int),
    );
    final totalImporte = filas.fold<double>(
      0,
      (sum, f) => sum + (f.value['total'] as double),
    );

    appendStyledRow(filaVacia());
    appendStyledRow(
      incluirFecha
          ? [
              TextCellValue(''),
              TextCellValue('TOTAL'),
              IntCellValue(totalCantidad),
              DoubleCellValue(totalImporte),
            ]
          : [
              TextCellValue('TOTAL'),
              IntCellValue(totalCantidad),
              DoubleCellValue(totalImporte),
            ],
      style: totalStyle,
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el Excel de productos');
    }

    return bytes;
  }

  String _categoriaEtiqueta(String tipo) {
    if (tipo == 'botella') return 'Botellas de vino';
    if (tipo == 'copa') return 'Copas';
    if (tipo == 'conserva' || tipo == 'tapa') return 'Conservas/Tapas';
    return 'Otros';
  }

  String _subgrupoEtiqueta(TicketLineaInforme linea) {
    if (linea.productoTipo == 'botella') {
      final doValue = linea.productoDenominacionOrigen?.trim();
      if (doValue != null && doValue.isNotEmpty) {
        return doValue;
      }
      return 'Sin D.O.';
    }
    return 'General';
  }

  String _subgrupoTitulo(String categoria, String subgrupo) {
    if (categoria == 'Botellas de vino') {
      return 'D.O.: $subgrupo';
    }
    return subgrupo;
  }

  String _mesEtiqueta(DateTime fecha) {
    final mes = _mesNombreArchivo(fecha.month);
    final mesCapitalizado = mes.isEmpty
        ? 'Mes'
        : '${mes[0].toUpperCase()}${mes.substring(1)}';
    return '$mesCapitalizado ${fecha.year}';
  }

  Future<List<int>> _crearPdfResumen(
    List<TicketInforme> exportTickets,
    FiltroExportacionProductos filtro,
  ) async {
    final pdf = pw.Document();
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final totalConIva = exportTickets.fold<double>(
      0,
      (sum, t) => sum + t.total,
    );
    var totalSinIva = 0.0;
    var totalIva = 0.0;
    final ivaPorTipo = <double, double>{};

    for (final ticket in exportTickets) {
      for (final linea in ticket.lineas) {
        final totalLinea = linea.totalLinea;
        final ratio = 1 + (linea.ivaTipo / 100);
        final base = ratio > 0 ? totalLinea / ratio : totalLinea;
        final cuotaIva = totalLinea - base;

        totalSinIva += base;
        totalIva += cuotaIva;
        ivaPorTipo[linea.ivaTipo] = (ivaPorTipo[linea.ivaTipo] ?? 0) + cuotaIva;
      }
    }

    final ivaRows = ivaPorTipo.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final incluirDetalleAnual = tipoSeleccionado == TipoInforme.anual;
    final detalleAnualMap = <String, Map<String, dynamic>>{};

    if (incluirDetalleAnual) {
      for (final ticket in exportTickets) {
        final mesKey =
            '${ticket.fecha.year}-${ticket.fecha.month.toString().padLeft(2, '0')}';
        final mesEtiqueta = _mesEtiqueta(ticket.fecha);

        for (final linea in ticket.lineas) {
          final categoria = _categoriaEtiqueta(linea.productoTipo);
          final subgrupo = _subgrupoTitulo(categoria, _subgrupoEtiqueta(linea));
          final key = '$mesKey|$categoria|$subgrupo|${linea.productoNombre}';

          final item = detalleAnualMap.putIfAbsent(
            key,
            () => {
              'mesKey': mesKey,
              'mesEtiqueta': mesEtiqueta,
              'categoria': categoria,
              'subgrupo': subgrupo,
              'producto': linea.productoNombre,
              'cantidad': 0,
              'total': 0.0,
            },
          );

          item['cantidad'] = (item['cantidad'] as int) + linea.cantidad;
          item['total'] = (item['total'] as double) + linea.totalLinea;
        }
      }
    }

    final detalleAnualOrdenado = detalleAnualMap.values.toList()
      ..sort((a, b) {
        final mesCmp = (a['mesKey'] as String).compareTo(b['mesKey'] as String);
        if (mesCmp != 0) return mesCmp;

        final catCmp = (a['categoria'] as String).compareTo(
          b['categoria'] as String,
        );
        if (catCmp != 0) return catCmp;

        final subCmp = (a['subgrupo'] as String).compareTo(
          b['subgrupo'] as String,
        );
        if (subCmp != 0) return subCmp;

        return (a['producto'] as String).compareTo(b['producto'] as String);
      });

    final detalleAnualPorMes = <String, List<Map<String, dynamic>>>{};
    final etiquetaMesByKey = <String, String>{};
    for (final item in detalleAnualOrdenado) {
      final mesKey = item['mesKey'] as String;
      final mesEtiqueta = item['mesEtiqueta'] as String;
      etiquetaMesByKey[mesKey] = mesEtiqueta;
      detalleAnualPorMes.putIfAbsent(mesKey, () => []);
      detalleAnualPorMes[mesKey]!.add(item);
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              'Resumen de tickets',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Filtro: ${etiquetaFiltro(filtro)}'),
            pw.Text(
              'Rango: ${formatoFecha(fechaInicio)} - ${formatoFecha(fechaFin)}',
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Tickets: ${exportTickets.length}'),
                  pw.Text('Total sin IVA: ${totalSinIva.toStringAsFixed(2)}€'),
                  pw.Text('IVA total: ${totalIva.toStringAsFixed(2)}€'),
                  pw.Text('Total con IVA: ${totalConIva.toStringAsFixed(2)}€'),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Detalle de IVA',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Tipo IVA', 'Cuota'],
              data: ivaRows
                  .map(
                    (e) => [
                      '${e.key.toStringAsFixed(0)}%',
                      '${e.value.toStringAsFixed(2)}€',
                    ],
                  )
                  .toList(),
            ),
            if (incluirDetalleAnual && detalleAnualPorMes.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Detalle anual por meses',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              for (final mesKey
                  in (detalleAnualPorMes.keys.toList()..sort())) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  color: PdfColors.blue50,
                  child: pw.Text(
                    'Mes: ${etiquetaMesByKey[mesKey] ?? mesKey}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Categoria',
                    'Grupo',
                    'Producto',
                    'Cantidad',
                    'Importe',
                  ],
                  data: detalleAnualPorMes[mesKey]!
                      .map(
                        (fila) => [
                          fila['categoria'] as String,
                          fila['subgrupo'] as String,
                          fila['producto'] as String,
                          '${fila['cantidad']}',
                          '${(fila['total'] as double).toStringAsFixed(2)}€',
                        ],
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total mes: ${detalleAnualPorMes[mesKey]!.fold<double>(0, (sum, fila) => sum + (fila['total'] as double)).toStringAsFixed(2)}€',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<List<int>> _crearPdfTickets({
    required List<TicketInforme> ticketsParaImprimir,
    required String titulo,
  }) async {
    final pdf = pw.Document();
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              titulo,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            for (final ticket in ticketsParaImprimir) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Mesa: ${ticket.mesaNombre}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Ticket ${ticket.id.substring(0, 8)}'),
                    pw.Text(
                      'Emitido: ${formatoFecha(ticket.fecha)} ${formatoHora(ticket.fecha)}',
                    ),
                    pw.SizedBox(height: 6),
                    pw.TableHelper.fromTextArray(
                      headers: const ['Producto', 'Cant.', 'P.Unit', 'Importe'],
                      data: ticket.lineas
                          .map(
                            (linea) => [
                              linea.productoNombre,
                              '${linea.cantidad}',
                              '${linea.precioUnitario.toStringAsFixed(2)}€',
                              '${linea.totalLinea.toStringAsFixed(2)}€',
                            ],
                          )
                          .toList(),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Total: ${ticket.total.toStringAsFixed(2)}€',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> imprimirTicket(TicketInforme ticket) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(
          await _crearPdfTickets(
            ticketsParaImprimir: [ticket],
            titulo: 'Ticket ${ticket.id.substring(0, 8)}',
          ),
        ),
      );
    } on MissingPluginException {
      try {
        final bytes = await _crearPdfTickets(
          ticketsParaImprimir: [ticket],
          titulo: 'Ticket ${ticket.id.substring(0, 8)}',
        );
        await _guardarPdfImpresionFallback(
          bytes,
          nombreBase:
              'ticket_${_fechaArchivo(ticket.fecha)}_${_slugArchivo(ticket.mesaNombre)}_${ticket.id.substring(0, 8)}',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el ticket en PDF: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo imprimir ticket: $e')));
    }
  }

  Future<void> imprimirTodosLosTickets() async {
    if (tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay tickets para imprimir')),
      );
      return;
    }

    try {
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(
          await _crearPdfTickets(
            ticketsParaImprimir: tickets,
            titulo: 'Tickets del informe',
          ),
        ),
      );
    } on MissingPluginException {
      try {
        final bytes = await _crearPdfTickets(
          ticketsParaImprimir: tickets,
          titulo: 'Tickets del informe',
        );
        await _guardarPdfImpresionFallback(
          bytes,
          nombreBase: 'tickets_${_descriptorInformeArchivo()}',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar el PDF de tickets: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron imprimir los tickets: $e')),
      );
    }
  }

  Future<void> _guardarPdfImpresionFallback(
    List<int> bytes, {
    required String nombreBase,
  }) async {
    final dir = await _obtenerDirectorioDescargas();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}${Platform.pathSeparator}${nombreBase}_$ts.pdf';

    await File(path).writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se detecta el plugin de impresión en esta ejecución. PDF guardado en: $path',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Widget buildBarChart({
    required String titulo,
    required List<InformePunto> puntos,
    void Function(int index)? onTap,
  }) {
    if (puntos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sin datos para mostrar'),
            ],
          ),
        ),
      );
    }

    final maxTotal = puntos.fold<double>(0, (m, p) => math.max(m, p.total));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < puntos.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: onTap == null ? null : () => onTap(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                puntos[i].total.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: maxTotal == 0
                                    ? 6
                                    : 8 + (puntos[i].total / maxTotal) * 130,
                                decoration: BoxDecoration(
                                  color: onTap == null
                                      ? Colors.blueGrey
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                puntos[i].etiqueta,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTicketsDesglosados() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tickets desglosados (${tickets.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: tickets.isEmpty ? null : imprimirTodosLosTickets,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimir todos'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (tickets.isEmpty)
              const Text('No hay tickets en este periodo')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tickets.length,
                separatorBuilder: (_, index) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final t = tickets[index];
                  return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      '${formatoFecha(t.fecha)} ${formatoHora(t.fecha)} · ${t.mesaNombre}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Ticket ${t.id.substring(0, 8)} · Hora ${formatoHora(t.fecha)}',
                    ),
                    trailing: SizedBox(
                      width: 130,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${t.total.toStringAsFixed(2)}€',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            tooltip: 'Imprimir ticket',
                            onPressed: () => imprimirTicket(t),
                            icon: const Icon(Icons.print_outlined),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      for (final linea in t.lineas)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${linea.cantidad} x ${linea.productoNombre}',
                                ),
                              ),
                              Text(
                                '${linea.totalLinea.toStringAsFixed(2)}€',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget buildBotonPeriodo({
    required String label,
    required TipoInforme tipo,
    required VoidCallback onPressed,
  }) {
    final activo = tipoSeleccionado == tipo;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: activo ? Colors.black87 : Colors.grey.shade300,
        foregroundColor: activo ? Colors.white : Colors.black87,
        minimumSize: const Size(120, 42),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informes')),
      body: WatermarkBackground(
        gradientColors: const [Color(0xFFF2ECFB), Color(0xFFF7F3FF)],
        opacity: 0.07,
        child: cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => cargarInforme(
                  tipoSeleccionado,
                  inicio: fechaInicio,
                  fin: fechaFin,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        buildBotonPeriodo(
                          label: 'Diario',
                          tipo: TipoInforme.diario,
                          onPressed: () => cargarInforme(TipoInforme.diario),
                        ),
                        buildBotonPeriodo(
                          label: 'Semanal',
                          tipo: TipoInforme.semanal,
                          onPressed: () => cargarInforme(TipoInforme.semanal),
                        ),
                        buildBotonPeriodo(
                          label: 'Mensual',
                          tipo: TipoInforme.mensual,
                          onPressed: () => cargarInforme(TipoInforme.mensual),
                        ),
                        buildBotonPeriodo(
                          label: 'Anual',
                          tipo: TipoInforme.anual,
                          onPressed: () => cargarInforme(TipoInforme.anual),
                        ),
                        buildBotonPeriodo(
                          label: 'Rango fechas',
                          tipo: TipoInforme.rango,
                          onPressed: seleccionarRangoFechas,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${formatoFecha(fechaInicio)} - ${formatoFecha(fechaFin)}',
                                  ),
                                ),
                                Text(
                                  '${totalVentas.toStringAsFixed(2)}€',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: exportando ? null : exportarInformes,
                                icon: exportando
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.file_download_outlined),
                                label: Text(
                                  exportando
                                      ? 'Exportando...'
                                      : 'Exportar (Excel + PDF)',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (tipoSeleccionado == TipoInforme.diario)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ventas del dia',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${totalVentas.toStringAsFixed(2)}€',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final tipoConDobleGrafica =
                              tipoSeleccionado == TipoInforme.mensual ||
                              tipoSeleccionado == TipoInforme.anual;
                          final mostrarParalelo =
                              tipoConDobleGrafica && serieDetalle.isNotEmpty;

                          if (!mostrarParalelo) {
                            return buildBarChart(
                              titulo: 'Grafica principal',
                              puntos: seriePrincipal,
                              onTap: tipoConDobleGrafica
                                  ? onTapPrincipal
                                  : null,
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final dosColumnas = constraints.maxWidth >= 980;

                              final principal = buildBarChart(
                                titulo: 'Grafica principal',
                                puntos: seriePrincipal,
                                onTap: onTapPrincipal,
                              );

                              final detalle = buildBarChart(
                                titulo: tituloDetalle ?? 'Detalle',
                                puntos: serieDetalle,
                                onTap: tipoSeleccionado == TipoInforme.anual
                                    ? onTapDetalle
                                    : null,
                              );

                              if (!dosColumnas) {
                                return Column(
                                  children: [
                                    principal,
                                    const SizedBox(height: 8),
                                    detalle,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: principal),
                                  const SizedBox(width: 8),
                                  Expanded(child: detalle),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    if (serieDetalle.isNotEmpty &&
                        tipoSeleccionado != TipoInforme.mensual &&
                        tipoSeleccionado != TipoInforme.anual) ...[
                      const SizedBox(height: 8),
                      buildBarChart(
                        titulo: tituloDetalle ?? 'Detalle',
                        puntos: serieDetalle,
                      ),
                    ],
                    if (serieSubDetalle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      buildBarChart(
                        titulo: tituloSubDetalle ?? 'Subdetalle',
                        puntos: serieSubDetalle,
                      ),
                    ],
                    const SizedBox(height: 8),
                    buildInformeClienteCard(),
                    const SizedBox(height: 8),
                    buildTicketsDesglosados(),
                  ],
                ),
              ),
      ),
    );
  }
}
