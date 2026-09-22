import 'package:flutter/material.dart';

import '../models/producto.dart';

class ProductoStockPayload {
  final String nombre;
  final String tipo;
  final String subcategoria;
  final String? denominacionOrigen;
  final int stock;
  final int stockMinimo;

  const ProductoStockPayload({
    required this.nombre,
    required this.tipo,
    required this.subcategoria,
    required this.denominacionOrigen,
    required this.stock,
    required this.stockMinimo,
  });
}

class ProductoStockFormPage extends StatefulWidget {
  const ProductoStockFormPage({
    super.key,
    this.producto,
    required this.denominacionesOrigen,
  });

  final Producto? producto;
  final List<String> denominacionesOrigen;

  @override
  State<ProductoStockFormPage> createState() => _ProductoStockFormPageState();
}

class _ProductoStockFormPageState extends State<ProductoStockFormPage> {
  final _formKey = GlobalKey<FormState>();
  static const int stockMinimoBotellaPorDefecto = 4;
  static const int stockMinimoConservaPorDefecto = 10;

  late final TextEditingController _nombreController;
  late final TextEditingController _stockController;
  late final TextEditingController _stockMinimoController;

  late String _categoria;
  String? _denominacionSeleccionada;

  bool get _esEdicion => widget.producto != null;
  bool get _esVino => _categoria == 'vino';

  int _stockMinimoPorCategoria(String categoria) {
    return categoria == 'vino'
        ? stockMinimoBotellaPorDefecto
        : stockMinimoConservaPorDefecto;
  }

  @override
  void initState() {
    super.initState();

    final producto = widget.producto;

    _categoria = (producto?.tipo == 'conserva') ? 'conserva' : 'vino';

    _nombreController = TextEditingController(text: producto?.nombre ?? '');
    _stockController = TextEditingController(
      text: (producto?.stock ?? 0).toString(),
    );
    final stockMinimoInicial = producto?.stockMinimo;
    _stockMinimoController = TextEditingController(
      text: (stockMinimoInicial != null && stockMinimoInicial > 0)
          ? stockMinimoInicial.toString()
          : _stockMinimoPorCategoria(_categoria).toString(),
    );

    final denominacionInicial = producto?.denominacionOrigen?.trim();
    if (denominacionInicial != null && denominacionInicial.isNotEmpty) {
      _denominacionSeleccionada = denominacionInicial;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _stockController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  String? _validarEnteroNoNegativo(String? value, String campo) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 0) {
      return '$campo debe ser un entero mayor o igual a 0';
    }
    return null;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    if (_esVino &&
        (_denominacionSeleccionada == null ||
            _denominacionSeleccionada!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una D.O. para el vino')),
      );
      return;
    }

    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    final stock = int.parse(_stockController.text.trim());
    final stockMinimo = int.parse(_stockMinimoController.text.trim());

    final tipo = _esVino ? 'botella' : 'conserva';
    final denominacion = _esVino ? _denominacionSeleccionada!.trim() : null;
    final subcategoria = _esVino ? denominacion! : 'conserva';

    Navigator.of(context).pop(
      ProductoStockPayload(
        nombre: nombre,
        tipo: tipo,
        subcategoria: subcategoria,
        denominacionOrigen: denominacion,
        stock: stock,
        stockMinimo: stockMinimo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esEdicion ? 'Editar producto' : 'Nuevo producto';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Nombre obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'vino', child: Text('Vino')),
                  DropdownMenuItem(value: 'conserva', child: Text('Conserva')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _categoria = value;
                    if (!_esVino) {
                      _denominacionSeleccionada = null;
                    }

                    if (!_esEdicion) {
                      _stockMinimoController.text = _stockMinimoPorCategoria(
                        _categoria,
                      ).toString();
                    }
                  });
                },
              ),
              if (_esVino) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      widget.denominacionesOrigen.contains(
                        _denominacionSeleccionada,
                      )
                      ? _denominacionSeleccionada
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Denominacion de origen',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.denominacionesOrigen
                      .map(
                        (denominacion) => DropdownMenuItem<String>(
                          value: denominacion,
                          child: Text(denominacion),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _denominacionSeleccionada = value;
                    });
                  },
                  validator: (value) {
                    if (!_esVino) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Selecciona una D.O.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockMinimoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock minimo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    _validarEnteroNoNegativo(value, 'Stock minimo'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock actual',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    _validarEnteroNoNegativo(value, 'Stock actual'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _esEdicion ? 'Guardar cambios' : 'Crear producto',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
