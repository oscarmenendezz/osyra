import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osyra/models/mesa.dart';
import 'package:osyra/pages/mesas_page.dart';

class _FakeMesasDataSource implements MesasDataSource {
  _FakeMesasDataSource(this._mesas);

  final List<Mesa> _mesas;
  int actualizarNombreMesaCalls = 0;

  @override
  Future<List<Mesa>> getMesas() async => _mesas;

  @override
  Future<void> actualizarNombreMesa({required String mesaId, required String nombre}) async {
    actualizarNombreMesaCalls += 1;
  }
}

void main() {
  group('MesasPage', () {
    testWidgets('renders app chrome and loaded seats', (tester) async {
      final fake = _FakeMesasDataSource([
        Mesa(id: 'm1', nombre: 'Cliente VIP', estado: 'ocupada'),
        Mesa(id: 'm2', nombre: 'Mesa original libre', estado: 'libre'),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: MesasPage(mesasDataSource: fake)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Barra TPV'), findsOneWidget);
      expect(find.text('Barra de clientes · pulsa una persona para abrir su TPV'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(2));
    });

    testWidgets('uses mesa name when occupied and base name when free', (tester) async {
      final fake = _FakeMesasDataSource([
        Mesa(id: 'm1', nombre: 'Cliente VIP', estado: 'ocupada'),
        Mesa(id: 'm2', nombre: 'Mesa original libre', estado: 'libre'),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: MesasPage(mesasDataSource: fake)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cliente VIP'), findsOneWidget);
      expect(find.text('Cliente 2'), findsOneWidget);
      expect(find.text('Atendiendo'), findsOneWidget);
      expect(find.text('Libre en barra'), findsOneWidget);
    });
  });
}
