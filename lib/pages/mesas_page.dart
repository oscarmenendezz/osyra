import 'package:flutter/material.dart';
import '../models/mesa.dart';
import '../services/mesa_service.dart';
import 'tpv_page.dart';
import '../widgets/watermark_background.dart';

abstract class MesasDataSource {
  Future<List<Mesa>> getMesas();
  Future<void> actualizarNombreMesa({
    required String mesaId,
    required String nombre,
  });
}

class MesasPage extends StatefulWidget {
  const MesasPage({super.key, this.mesasDataSource});

  final MesasDataSource? mesasDataSource;

  @override
  State<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends State<MesasPage> {
  late final MesasDataSource _mesasDataSource;
  List<Mesa> mesas = [];

  static const _fondoSuperior = Color(0xFF2C1246);
  static const _fondoInferior = Color(0xFF25103B);
  static const _barraMadera = Color(0xFF6A1B9A);
  static const _ocupadaColor = Color(0xFF8E24AA);
  static const _libreColor = Color(0xFF5E35B1);

  String _nombreBaseCliente(int index) => 'Cliente ${index + 1}';

  @override
  void initState() {
    super.initState();
    _mesasDataSource = widget.mesasDataSource ?? _SupabaseMesasDataSource();
    cargarMesas();
  }

  Future<void> cargarMesas() async {
    final data = await _mesasDataSource.getMesas();
    if (!mounted) return;
    setState(() {
      mesas = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barra TPV')),
      body: WatermarkBackground(
        gradientColors: [_fondoSuperior, _fondoInferior],
        opacity: 0.1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 700
                ? 2
                : (constraints.maxWidth < 1080 ? 3 : 4);

            return Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE3FF).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFC9B6EA)),
                    ),
                    child: const Text(
                      'Barra de clientes · pulsa una persona para abrir su TPV',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 18,
                  decoration: BoxDecoration(
                    color: _barraMadera,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.08,
                    ),
                    itemCount: mesas.length,
                    itemBuilder: (context, index) {
                      final mesa = mesas[index];
                      final nombreBase = _nombreBaseCliente(index);
                      final nombreMostrado = mesa.estado == 'ocupada'
                          ? mesa.nombre
                          : nombreBase;

                      return _buildClienteSeat(
                        mesa: mesa,
                        nombreBase: nombreBase,
                        nombreMostrado: nombreMostrado,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildClienteSeat({
    required Mesa mesa,
    required String nombreBase,
    required String nombreMostrado,
  }) {
    final ocupada = mesa.estado == 'ocupada';
    final colorEstado = ocupada ? _ocupadaColor : _libreColor;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        var mesaParaTPV = mesa;

        if (mesa.estado == 'libre' && mesa.nombre != nombreBase) {
          try {
            await _mesasDataSource.actualizarNombreMesa(
              mesaId: mesa.id,
              nombre: nombreBase,
            );

            mesaParaTPV = Mesa(
              id: mesa.id,
              nombre: nombreBase,
              estado: mesa.estado,
            );
          } catch (_) {
            mesaParaTPV = Mesa(
              id: mesa.id,
              nombre: nombreBase,
              estado: mesa.estado,
            );
          }
        }

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TPVPage(mesa: mesaParaTPV, nombreBaseMesa: nombreBase),
          ),
        );

        if (!mounted) return;
        await cargarMesas();
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(color: colorEstado.withValues(alpha: 0.45)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorEstado,
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xAA2B1740),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  nombreMostrado,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ocupada ? 'Atendiendo' : 'Libre en barra',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _SupabaseMesasDataSource implements MesasDataSource {
  final MesaService _mesaService = MesaService();

  @override
  Future<List<Mesa>> getMesas() => _mesaService.getMesas();

  @override
  Future<void> actualizarNombreMesa({
    required String mesaId,
    required String nombre,
  }) {
    return _mesaService.actualizarNombreMesa(mesaId: mesaId, nombre: nombre);
  }
}
