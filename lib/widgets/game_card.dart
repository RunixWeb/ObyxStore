import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../providers/download_provider.dart';

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloadProvider = context.watch<DownloadProvider>();
    
    // Verificar si el juego tiene al menos una descarga completada
    final hasAnyDownload = downloadProvider.isGameDownloaded(game.name, 'Windows') ||
        downloadProvider.isGameDownloaded(game.name, 'Android') ||
        downloadProvider.isGameDownloaded(game.name, 'Linux') ||
        downloadProvider.isGameDownloaded(game.name, 'macOS');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      color: theme.cardTheme.color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Cover
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(),
                  // Gradiente overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Status badge
                  if (game.status != 'Unknown' && game.status.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: game.status == 'Released'
                              ? Colors.green.withOpacity(0.9)
                              : Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          game.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Downloaded check
                  if (hasAnyDownload)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Game info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (game.tagline != null && game.tagline!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      game.tagline!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Platform icons & Download indicator
                  Row(
                    children: [
                      if (game.isWindows)
                        _buildPlatformIcon(Icons.computer, 'Windows'),
                      if (game.isAndroid)
                        _buildPlatformIcon(Icons.phone_android, 'Android'),
                      if (game.isLinux)
                        _buildPlatformIcon(Icons.desktop_windows, 'Linux'),
                      if (game.isMac)
                        _buildPlatformIcon(Icons.apple, 'macOS'),
                      const Spacer(),
                      if (hasAnyDownload)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green.withOpacity(0.8),
                        )
                      else
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(IconData icon, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (game.thumbnailUrl != null && game.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: game.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          Icons.videogame_asset_outlined,
          size: 48,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
