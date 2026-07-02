import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/ObyxStore.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'RunixIcon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ObyxStore',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),

            // Sobre la tienda
            _buildSection(
              context,
              title: 'Sobre la tienda',
              child: Text(
                'ObyxStore es una biblioteca interactiva y gestor de descargas diseñado para explorar y jugar los juegos independientes creados por Runix_YT. Todos los juegos son de descarga gratuita y directa desde itch.io.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Información de la app
            _buildSection(
              context,
              title: 'Información de la app',
              child: Column(
                children: [
                  _buildInfoRow(context, 'Plataforma', 'Flutter & Dart'),
                  _buildInfoRow(context, 'Fuente de juegos', 'itch.io (scraper HTML)'),
                  _buildInfoRow(context, 'Descargas', 'Dio HTTP + SharedPreferences'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Créditos
            Text(
              'Créditos',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Runix - Juegos
            _buildCreditTile(
              context,
              name: 'Runix_YT',
              role: 'Creador de los juegos',
              icon: Icons.sports_esports,
            ),
            const SizedBox(height: 8),

            // dieegoleo - Desarrollador
            _buildCreditTile(
              context,
              name: 'LuPyther',
              role: 'Desarrollador de la app',
              icon: Icons.code,
            ),
            const SizedBox(height: 24),

            Text(
              '© 2026 ObyxStore',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditTile(
    BuildContext context, {
    required String name,
    required String role,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                role,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
