import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/linea_pedido.dart';
import 'package:osyra/models/mesa.dart';
import 'package:osyra/models/producto.dart';

void main() {
  group('Mesa', () {
    test('fromJson maps values and defaults estado to libre', () {
      final mesa = Mesa.fromJson({
        'id': 'm1',
        'nombre': 'Mesa 1',
      });

      expect(mesa.id, 'm1');
      expect(mesa.nombre, 'Mesa 1');
      expect(mesa.estado, 'libre');
    });

    test('fromJson uses explicit estado when present', () {
      final mesa = Mesa.fromJson({
        'id': 'm2',
        'nombre': 'Mesa 2',
        'estado': 'ocupada',
      });

      expect(mesa.estado, 'ocupada');
    });
  });

  group('LineaPedido', () {
    test('defaults cantidad to 1', () {
      final producto = Producto(
        id: 'p1',
        nombre: 'Verdejo',
        precio: 2.5,
        tipo: 'copa',
        subcategoria: 'Blanco',
      );

      final linea = LineaPedido(producto: producto);

      expect(linea.cantidad, 1);
      expect(linea.producto.nombre, 'Verdejo');
    });

    test('allows changing cantidad', () {
      final producto = Producto(
        id: 'p2',
        nombre: 'Tempranillo',
        precio: 3.5,
        tipo: 'copa',
        subcategoria: 'Tinto',
      );

      final linea = LineaPedido(producto: producto, cantidad: 2);
      linea.cantidad = 4;

      expect(linea.cantidad, 4);
    });
  });
}
