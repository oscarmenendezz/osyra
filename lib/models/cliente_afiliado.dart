class ClienteAfiliado {
  final String id;
  final String nombre;
  final String dniCif;
  final String numeroAfiliado;
  final String? direccion;
  final String? codigoPostal;
  final String? localidad;
  final String? telefono;
  final String? email;
  final String? qrAuthCode;
  final String? zipRecuperacion;
  final String? imagenPerfilUrl;
  final int visitasValidas;

  ClienteAfiliado({
    required this.id,
    required this.nombre,
    required this.dniCif,
    required this.numeroAfiliado,
    this.direccion,
    this.codigoPostal,
    this.localidad,
    this.telefono,
    this.email,
    this.qrAuthCode,
    this.zipRecuperacion,
    this.imagenPerfilUrl,
    required this.visitasValidas,
  });

  bool get descuentoDisponible => visitasValidas >= 5;

  factory ClienteAfiliado.fromJson(Map<String, dynamic> json) {
    return ClienteAfiliado(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      dniCif: json['dni_cif'] as String? ?? '',
      numeroAfiliado: json['numero_afiliado'] as String? ?? '',
      direccion: json['direccion'] as String?,
      codigoPostal: json['codigo_postal'] as String?,
      localidad: json['localidad'] as String?,
      telefono: json['telefono'] as String?,
      email: json['email'] as String?,
      qrAuthCode: json['qr_auth_code'] as String?,
      zipRecuperacion: json['zip_recuperacion'] as String?,
      imagenPerfilUrl: json['imagen_perfil_url'] as String?,
      visitasValidas: (json['visitas_validas'] as num?)?.toInt() ?? 0,
    );
  }
}
