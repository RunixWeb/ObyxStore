import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/game.dart';
import '../providers/games_provider.dart';
import '../providers/download_provider.dart';
import '../widgets/game_card.dart';
import 'game_detail_screen.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamesProvider>().loadGames();
      context.read<DownloadProvider>().refreshCompletedDownloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<GamesProvider>(
        builder: (context, gamesProvider, _) {
          return RefreshIndicator(
            onRefresh: () async {
              await gamesProvider.refresh();
              await context.read<DownloadProvider>().refreshCompletedDownloads();
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  expandedHeight: 0,
                  toolbarHeight: 64,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  title: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'RunixIcon.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.videogame_asset_rounded,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ObyxStore',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                        size: 22,
                      ),
                      onPressed: () => context.read<ThemeProvider>().toggle(),
                      tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 22),
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      tooltip: 'Información',
                    ),
                    Consumer<DownloadCountProvider>(
                      builder: (context, countProvider, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download_outlined, size: 22),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                              ),
                              tooltip: 'Descargas',
                            ),
                            if (countProvider.activeCount > 0)
                              Positioned(
                                right: 6,
                                top: 8,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${countProvider.activeCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Juegos disponibles',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        letterSpacing: 0.5,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (gamesProvider.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Cargando juegos...'),
                        ],
                      ),
                    ),
                  )
                else if (gamesProvider.error != null)
                  SliverFillRemaining(
                    child: _buildErrorState(context, gamesProvider),
                  )
                else if (gamesProvider.games.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final game = gamesProvider.games[index];
                          return GameCard(
                            game: game,
                            onTap: () => _openGameDetail(context, game),
                          );
                        },
                        childCount: gamesProvider.games.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openGameDetail(BuildContext context, Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
    );
  }

  Widget _buildErrorState(BuildContext context, GamesProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar los juegos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              provider.error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => provider.loadGames(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gamepad_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay juegos disponibles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Revisa la conexión e intenta de nuevo',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => context.read<GamesProvider>().loadGames(),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
