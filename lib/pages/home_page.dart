import 'package:flutter/material.dart';
import 'mesas_page.dart';
import 'stock_page.dart';
import 'informes_page.dart';
import 'clientes_page.dart';
import '../widgets/watermark_background.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sistema Osyra')),
      body: WatermarkBackground(
        gradientColors: [
          Color(0xFF2C1246),
          Color(0xFF3A1860),
          Color(0xFF25103B),
        ],
        opacity: 0.11,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidePadding = constraints.maxWidth > 700 ? 36.0 : 20.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(context),
                    const SizedBox(height: 18),
                    _buildModuleCard(
                      context,
                      title: 'TPV',
                      tag: 'VENTA',
                      subtitle:
                          'Gestiona mesas, abre pedidos y cobra sin salir del flujo.',
                      icon: Icons.point_of_sale_rounded,
                      colors: const [Color(0xFF3A0B66), Color(0xFF6A1B9A)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MesasPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModuleCard(
                      context,
                      title: 'Gestion de Stock',
                      tag: 'ALMACEN',
                      subtitle:
                          'Controla existencias y alertas criticas por producto en tiempo real.',
                      icon: Icons.wine_bar_rounded,
                      colors: const [Color(0xFF1A237E), Color(0xFF3949AB)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StockPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModuleCard(
                      context,
                      title: 'Informes',
                      tag: 'ANALITICA',
                      subtitle:
                          'Analiza ventas, exporta resultados e imprime tickets del periodo.',
                      icon: Icons.query_stats_rounded,
                      colors: const [Color(0xFF4A148C), Color(0xFF8E24AA)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InformesPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildModuleCard(
                      context,
                      title: 'Clientes',
                      tag: 'AFILIACION',
                      subtitle:
                          'Da de alta nuevos clientes y consulta su ficha de contacto.',
                      icon: Icons.person_add_alt_1_rounded,
                      colors: const [Color(0xFF0B3D40), Color(0xFF1F7A7A)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientesPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD7D4CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Centro de operaciones',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Accede a TPV, stock e informes desde una sola vista.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF3B4A46)),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String tag,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0x44FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x25000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFFFFFF),
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
