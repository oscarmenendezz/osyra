import 'package:flutter/material.dart';

import '../models/producto.dart';
import 'producto_stock_form_page.dart';
import '../services/stock_service.dart';
import '../widgets/watermark_background.dart';

abstract class StockDataSource {
  Future<List<Producto>> getProductosConStock();

  Future<void> actualizarStock({
    required String productoId,
    required int nuevoStock,
  });

  Future<void> actualizarConfiguracionStock({
    required String productoId,
    int? stock,
    int? stockMinimo,
  });

  Future<void> actualizarProducto({
    required String productoId,
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  });

  Future<void> crearProducto({
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  });
}

class StockPage extends StatefulWidget {
  const StockPage({super.key, this.stockDataSource});

  final StockDataSource? stockDataSource;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final StockDataSource _stockDataSource;
  static const Set<String> tiposGestionStock = {'botella', 'conserva', 'tapa'};
  static const int stockMinimoBotellaPorDefecto = 4;
  static const int stockMinimoConservaPorDefecto = 10;
  static const List<String> denominacionesOrigenEspana = [
    'Abona',
    'Alella',
    'Alicante',
    'Almansa',
    'Arabako Txakolina',
    'Arlanza',
    'Arribes',
    'Bierzo',
    'Binissalem',
    'Bizkaiko Txakolina',
    'Bullas',
    'Calatayud',
    'Campo de Borja',
    'Cariñena',
    'Cava',
    'Cebreros',
    'Cigales',
    'Conca de Barbera',
    'Condado de Huelva',
    'Costers del Segre',
    'Cumbres del Guadiana',
    'El Hierro',
    'Emporda',
    'Getariako Txakolina',
    'Jerez-Xeres-Sherry',
    'Jumilla',
    'La Gomera',
    'La Mancha',
    'La Palma',
    'Lanzarote',
    'Leon',
    'Malaga',
    'Manchuela',
    'Mentrida',
    'Mondejar',
    'Monterrei',
    'Montilla-Moriles',
    'Montsant',
    'Navarra',
    'Pago de Otazu',
    'Penedes',
    'Pla de Bages',
    'Pla i Llevant',
    'Priorat',
    'Rias Baixas',
    'Ribeira Sacra',
    'Ribeiro',
    'Ribera del Duero',
    'Ribera del Guadiana',
    'Ribera del Jucar',
    'Rioja',
    'Rueda',
    'Sierra de Salamanca',
    'Sierras de Malaga',
    'Somontano',
    'Tacoronte-Acentejo',
    'Tarragona',
    'Terra Alta',
    'Tierra de Leon',
    'Tierra del Vino de Zamora',
    'Toro',
    'Ucles',
    'Utiel-Requena',
    'Valdeorras',
    'Valdepeñas',
    'Valencia',
    'Valle de Guimar',
    'Valle de La Orotava',
    'Vinos de Madrid',
    'Ycoden-Daute-Isora',
    'Yecla',
  ];

  List<Producto> productos = [];
  bool cargando = true;
  String busqueda = '';
  String filtroTipo = 'todos';
  String? filtroDenominacion;
  bool soloCriticos = false;
  final Set<String> guardandoProductoIds = {};

  @override
  void initState() {
    super.initState();
    _stockDataSource = widget.stockDataSource ?? _SupabaseStockDataSource();
    cargarProductos();
  }

  Future<void> cargarProductos() async {
    try {
      final data = await _stockDataSource.getProductosConStock();

      if (!mounted) return;

      setState(() {
        productos = data
            .where((producto) => tiposGestionStock.contains(producto.tipo))
            .toList();
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando stock: $e')));
    }
  }

  List<Producto> get productosFiltrados {
    final texto = busqueda.trim().toLowerCase();

    return productos.where((producto) {
      final coincideTipo = filtroTipo == 'todos'
          ? true
          : filtroTipo == 'conserva_tapa'
          ? (producto.tipo == 'conserva' || producto.tipo == 'tapa')
          : producto.tipo == filtroTipo;
      final coincideVino =
          filtroDenominacion == null ||
          (producto.tipo == 'botella' &&
              _normalizar(
                _valorDenominacion(producto),
              ).contains(_normalizar(filtroDenominacion!)));
      final coincideBusqueda =
          texto.isEmpty ||
          producto.nombre.toLowerCase().contains(texto) ||
          producto.subcategoria.toLowerCase().contains(texto);
      final coincideCritico =
          !soloCriticos || producto.stock <= _stockMinimoEfectivo(producto);

      return coincideTipo &&
          coincideVino &&
          coincideBusqueda &&
          coincideCritico;
    }).toList();
  }

  int get totalCriticos {
    return productos.where((p) => p.stock <= _stockMinimoEfectivo(p)).length;
  }

  int _stockMinimoPorTipo(String tipo) {
    if (tipo == 'botella') {
      return stockMinimoBotellaPorDefecto;
    }
    if (tipo == 'conserva' || tipo == 'tapa') {
      return stockMinimoConservaPorDefecto;
    }
    return 0;
  }

  int _stockMinimoEfectivo(Producto producto) {
    if (producto.stockMinimo > 0) {
      return producto.stockMinimo;
    }
    return _stockMinimoPorTipo(producto.tipo);
  }

  String _normalizar(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  bool _hayVinosEnDenominacion(String denominacion) {
    final filtro = _normalizar(denominacion);
    return productos.any(
      (p) =>
          p.tipo == 'botella' &&
          _normalizar(_valorDenominacion(p)).contains(filtro),
    );
  }

  String _valorDenominacion(Producto producto) {
    final valor = producto.denominacionOrigen;
    if (valor != null && valor.trim().isNotEmpty) {
      return valor;
    }

    return producto.subcategoria;
  }

  Future<void> abrirSelectorDenominacion() async {
    var busquedaLocal = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final opciones = denominacionesOrigenEspana.where((denominacion) {
              if (busquedaLocal.trim().isEmpty) return true;

              return _normalizar(
                denominacion,
              ).contains(_normalizar(busquedaLocal.trim()));
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Denominacion de origen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (value) {
                          setModalState(() {
                            busquedaLocal = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar D.O. de Espana',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: opciones.length,
                          itemBuilder: (context, index) {
                            final denominacion = opciones[index];
                            final activa = filtroDenominacion == denominacion;
                            final disponible = _hayVinosEnDenominacion(
                              denominacion,
                            );

                            return ListTile(
                              enabled: true,
                              title: Text(denominacion),
                              subtitle: !disponible
                                  ? const Text(
                                      'Sin productos en stock con esta D.O.',
                                    )
                                  : null,
                              trailing: activa
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () {
                                setState(() {
                                  filtroTipo = 'botella';
                                  filtroDenominacion = denominacion;
                                });
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> ajustarStock(Producto producto, int delta) async {
    final stockActual = producto.stock;
    final nuevoStock = (stockActual + delta).clamp(0, 999999);

    if (stockActual == nuevoStock) return;

    setState(() {
      guardandoProductoIds.add(producto.id);
      productos = productos
          .map((p) => p.id == producto.id ? p.copyWith(stock: nuevoStock) : p)
          .toList();
    });

    try {
      await _stockDataSource.actualizarStock(
        productoId: producto.id,
        nuevoStock: nuevoStock,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        productos = productos
            .map(
              (p) => p.id == producto.id ? p.copyWith(stock: stockActual) : p,
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el stock: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardandoProductoIds.remove(producto.id);
        });
      }
    }
  }

  Future<void> editarStockExacto(Producto producto) async {
    final controller = TextEditingController(text: producto.stock.toString());

    final nuevoValor = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Stock actual de ${producto.nombre}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nuevo stock'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value < 0) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce un entero >= 0')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (nuevoValor == null || nuevoValor == producto.stock) return;

    await _persistirStock(producto: producto, nuevoStock: nuevoValor);
  }

  Future<void> editarStockMinimo(Producto producto) async {
    final controller = TextEditingController(
      text: _stockMinimoEfectivo(producto).toString(),
    );

    final nuevoMinimo = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Stock minimo de ${producto.nombre}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nuevo minimo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value < 0) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Introduce un entero >= 0')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (nuevoMinimo == null || nuevoMinimo == producto.stockMinimo) return;

    setState(() {
      guardandoProductoIds.add(producto.id);
      productos = productos
          .map(
            (p) =>
                p.id == producto.id ? p.copyWith(stockMinimo: nuevoMinimo) : p,
          )
          .toList();
    });

    try {
      await _stockDataSource.actualizarConfiguracionStock(
        productoId: producto.id,
        stockMinimo: nuevoMinimo,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        productos = productos
            .map(
              (p) => p.id == producto.id
                  ? p.copyWith(stockMinimo: producto.stockMinimo)
                  : p,
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el minimo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardandoProductoIds.remove(producto.id);
        });
      }
    }
  }

  Future<void> _persistirStock({
    required Producto producto,
    required int nuevoStock,
  }) async {
    final stockActual = producto.stock;

    setState(() {
      guardandoProductoIds.add(producto.id);
      productos = productos
          .map((p) => p.id == producto.id ? p.copyWith(stock: nuevoStock) : p)
          .toList();
    });

    try {
      await _stockDataSource.actualizarStock(
        productoId: producto.id,
        nuevoStock: nuevoStock,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        productos = productos
            .map(
              (p) => p.id == producto.id ? p.copyWith(stock: stockActual) : p,
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el stock: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          guardandoProductoIds.remove(producto.id);
        });
      }
    }
  }

  Future<void> abrirFormularioProducto({Producto? producto}) async {
    if (producto != null && producto.tipo == 'copa') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las copas se generan desde su botella y no se editan aqui.',
          ),
        ),
      );
      return;
    }

    final payload = await Navigator.of(context).push<ProductoStockPayload>(
      MaterialPageRoute(
        builder: (_) => ProductoStockFormPage(
          producto: producto,
          denominacionesOrigen: denominacionesOrigenEspana,
        ),
      ),
    );

    if (payload == null) return;

    try {
      if (producto == null) {
        await _stockDataSource.crearProducto(
          nombre: payload.nombre,
          tipo: payload.tipo,
          subcategoria: payload.subcategoria,
          denominacionOrigen: payload.denominacionOrigen,
          stock: payload.stock,
          stockMinimo: payload.stockMinimo,
          precio: 1.0,
        );
      } else {
        await _stockDataSource.actualizarProducto(
          productoId: producto.id,
          nombre: payload.nombre,
          tipo: payload.tipo,
          subcategoria: payload.subcategoria,
          denominacionOrigen: payload.denominacionOrigen,
          stock: payload.stock,
          stockMinimo: payload.stockMinimo,
          precio: producto.precio,
        );
      }

      if (!mounted) return;

      await cargarProductos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            producto == null
                ? 'Producto creado correctamente'
                : 'Producto actualizado correctamente',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el producto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control de stock')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormularioProducto(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: WatermarkBackground(
        gradientColors: const [Color(0xFFF2ECFB), Color(0xFFF7F3FF)],
        opacity: 0.07,
        child: cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildFiltros(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cargarProductos,
                      child: productosFiltrados.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 140),
                                Center(
                                  child: Text('No hay productos para mostrar'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: productosFiltrados.length,
                              itemBuilder: (context, index) {
                                final producto = productosFiltrados[index];
                                return _buildProductoCard(producto);
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                busqueda = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o subcategoría',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFiltroTipo('todos', 'Todos'),
              const SizedBox(width: 8),
              _buildFiltroTipo('botella', 'Botellas'),
              const SizedBox(width: 8),
              _buildFiltroTipo('conserva_tapa', 'Conservas/Tapas'),
            ],
          ),
          if (filtroTipo == 'botella' || filtroDenominacion != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: abrirSelectorDenominacion,
                    icon: const Icon(Icons.wine_bar_outlined),
                    label: Text(
                      filtroDenominacion == null
                          ? 'Filtrar por D.O. (Espana)'
                          : 'D.O.: $filtroDenominacion',
                    ),
                  ),
                ),
                if (filtroDenominacion != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Quitar filtro D.O.',
                    onPressed: () {
                      setState(() {
                        filtroDenominacion = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            if (filtroDenominacion != null &&
                !_hayVinosEnDenominacion(filtroDenominacion!)) ...[
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No hay productos cargados con esa D.O. en este momento.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      soloCriticos = !soloCriticos;
                    });
                  },
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: soloCriticos ? Colors.red : Colors.black87,
                  ),
                  label: Text(
                    soloCriticos ? 'Mostrando criticos' : 'Solo criticos',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildResumenCard(
                  label: 'Mostrados',
                  value: '${productosFiltrados.length}',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResumenCard(
                  label: 'Criticos',
                  value: '$totalCriticos',
                  color: totalCriticos > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroTipo(String value, String label) {
    final activo = filtroTipo == value;

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            filtroTipo = value;
            if (value != 'botella') {
              filtroDenominacion = null;
            }
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: activo ? Colors.black87 : Colors.grey.shade300,
          foregroundColor: activo ? Colors.white : Colors.black87,
          minimumSize: const Size(double.infinity, 42),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildProductoCard(Producto producto) {
    final guardando = guardandoProductoIds.contains(producto.id);
    final stockMinimoEfectivo = _stockMinimoEfectivo(producto);
    final stockBajo = producto.stock <= stockMinimoEfectivo;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onLongPress: guardando ? null : () => editarStockMinimo(producto),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(
          producto.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${producto.tipo} · ${producto.subcategoria}\nMin $stockMinimoEfectivo',
        ),
        trailing: SizedBox(
          width: 220,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: guardando ? null : () => ajustarStock(producto, -1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${producto.stock}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: stockBajo ? Colors.red : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: guardando ? null : () => ajustarStock(producto, 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: guardando
                    ? null
                    : () => abrirFormularioProducto(producto: producto),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (guardando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupabaseStockDataSource implements StockDataSource {
  final StockService _stockService = StockService();

  @override
  Future<List<Producto>> getProductosConStock() {
    return _stockService.getProductosConStock();
  }

  @override
  Future<void> actualizarStock({
    required String productoId,
    required int nuevoStock,
  }) {
    return _stockService.actualizarStock(
      productoId: productoId,
      nuevoStock: nuevoStock,
    );
  }

  @override
  Future<void> actualizarConfiguracionStock({
    required String productoId,
    int? stock,
    int? stockMinimo,
  }) {
    return _stockService.actualizarConfiguracionStock(
      productoId: productoId,
      stock: stock,
      stockMinimo: stockMinimo,
    );
  }

  @override
  Future<void> actualizarProducto({
    required String productoId,
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  }) {
    return _stockService.actualizarProducto(
      productoId: productoId,
      nombre: nombre,
      tipo: tipo,
      subcategoria: subcategoria,
      denominacionOrigen: denominacionOrigen,
      stock: stock,
      stockMinimo: stockMinimo,
      precio: precio,
    );
  }

  @override
  Future<void> crearProducto({
    required String nombre,
    required String tipo,
    required String subcategoria,
    String? denominacionOrigen,
    required int stock,
    required int stockMinimo,
    required double precio,
  }) {
    return _stockService.crearProducto(
      nombre: nombre,
      tipo: tipo,
      subcategoria: subcategoria,
      denominacionOrigen: denominacionOrigen,
      stock: stock,
      stockMinimo: stockMinimo,
      precio: precio,
    );
  }
}
