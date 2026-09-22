class Mesa {
  final String id;
  final String nombre;
  final String estado;

  Mesa({
    required this.id,
    required this.nombre,
    required this.estado,
  });

  factory Mesa.fromJson(Map<String, dynamic> json) {
    return Mesa(
      id: json['id'],
      nombre: json['nombre'],
      estado: json['estado'] ?? 'libre',
    );
  }
}