import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/producto.dart';

void main() {
  group('Producto', () {
    test('fromJson maps all fields', () {
      final producto = Producto.fromJson({
        'id': 'p1',
        'nombre': 'Rioja Crianza',
        'precio': 12,
        'tipo': 'botella',
        'subcategoria': 'Tinto',
        'denominacion_origen': 'Rioja',
        'iva_tipo': 10,
        'stock': 8,
        'stock_minimo': 2,
      });

      expect(producto.id, 'p1');
      expect(producto.nombre, 'Rioja Crianza');
      expect(producto.precio, 12);
      expect(producto.tipo, 'botella');
      expect(producto.subcategoria, 'Tinto');
      expect(producto.denominacionOrigen, 'Rioja');
      expect(producto.ivaTipo, 10);
      expect(producto.stock, 8);
      expect(producto.stockMinimo, 2);
    });

    test('fromJson applies defaults', () {
      final producto = Producto.fromJson({
        'id': 'p2',
        'nombre': 'Vino casa',
        'precio': 3.5,
        'tipo': 'copa',
      });

      expect(producto.subcategoria, 'General');
      expect(producto.denominacionOrigen, isNull);
      expect(producto.ivaTipo, 21);
      expect(producto.stock, 0);
      expect(producto.stockMinimo, 0);
    });

    test('copyWith overrides selected fields and keeps others', () {
      final base = Producto(
        id: 'p3',
        nombre: 'Original',
        precio: 9.5,
        tipo: 'botella',
        subcategoria: 'Blanco',
        denominacionOrigen: 'Rias Baixas',
        ivaTipo: 21,
        stock: 4,
        stockMinimo: 1,
      );

      final updated = base.copyWith(
        nombre: 'Actualizado',
        precio: 11,
        stock: 10,
      );

      expect(updated.id, 'p3');
      expect(updated.nombre, 'Actualizado');
      expect(updated.precio, 11);
      expect(updated.tipo, 'botella');
      expect(updated.subcategoria, 'Blanco');
      expect(updated.denominacionOrigen, 'Rias Baixas');
      expect(updated.ivaTipo, 21);
      expect(updated.stock, 10);
      expect(updated.stockMinimo, 1);
    });
  });
}
