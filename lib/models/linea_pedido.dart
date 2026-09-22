import 'producto.dart';

class LineaPedido {
  final Producto producto;
  int cantidad;

  LineaPedido({
    required this.producto,
    this.cantidad = 1,
  });
}