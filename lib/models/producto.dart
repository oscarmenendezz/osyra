class Producto {
  final String id;
  final String nombre;
  final double precio;
  final String tipo;
  final String subcategoria;
  final String? denominacionOrigen;
  final double ivaTipo;
  final int stock;
  final int stockMinimo;

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.tipo,
    required this.subcategoria,
    this.denominacionOrigen,
    this.ivaTipo = 21,
    this.stock = 0,
    this.stockMinimo = 0,
  });

  Producto copyWith({
    String? id,
    String? nombre,
    double? precio,
    String? tipo,
    String? subcategoria,
    String? denominacionOrigen,
    double? ivaTipo,
    int? stock,
    int? stockMinimo,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      tipo: tipo ?? this.tipo,
      subcategoria: subcategoria ?? this.subcategoria,
      denominacionOrigen: denominacionOrigen ?? this.denominacionOrigen,
      ivaTipo: ivaTipo ?? this.ivaTipo,
      stock: stock ?? this.stock,
      stockMinimo: stockMinimo ?? this.stockMinimo,
    );
  }

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'],
      nombre: json['nombre'],
      precio: (json['precio'] as num).toDouble(),
      tipo: json['tipo'],
      subcategoria: json['subcategoria'] ?? "General",
      denominacionOrigen: json['denominacion_origen'],
      ivaTipo: (json['iva_tipo'] as num?)?.toDouble() ?? 21,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      stockMinimo: (json['stock_minimo'] as num?)?.toInt() ?? 0,
    );
  }
}
