import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/game.dart';
import '../providers/download_provider.dart';
import '../services/itch_io_scraper.dart';
import '../utils/platform_utils.dart';

class GameDetailScreen extends StatefulWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Game _game;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _loadDetailsIfNeeded();
    
    // Escuchar cambios en el provider para actualizar UI inmediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadProvider>().addListener(_onDownloadChanged);
    });
  }

  @override
  void dispose() {
    // Remover listener al salir
    try {
      context.read<DownloadProvider>().removeListener(_onDownloadChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onDownloadChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDetailsIfNeeded() async {
    if (_game.platforms.isEmpty && !_isLoadingDetails) {
      setState(() => _isLoadingDetails = true);
      try {
        final scraper = ItchIoScraper();
        final detailed = await scraper.fetchGameDetails(_game);
        if (mounted && detailed.platforms.isNotEmpty) {
          setState(() {
            _game = detailed;
            _isLoadingDetails = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _startDownload(String url, String fileName, String platform) async {
    final provider = context.read<DownloadProvider>();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Iniciando descarga de $fileName...'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
              Navigator.pushNamed(context, '/downloads');
            },
          ),
        ),
      );
    }

    await provider.startDownload(
      gameName: _game.name,
      url: url,
      gamePageUrl: _game.pageUrl,
      fileName: fileName,
      platform: platform,
    );
  }

  void _showDeleteDialog(String gameName, String platform) {
    final provider = context.read<DownloadProvider>();
    final download = provider.completedDownloads.firstWhere(
      (d) => d.gameName == gameName && d.platform == platform,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar descarga'),
        content: Text('¿Eliminar "$gameName" para $platform del dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteDownload(download);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$gameName eliminado de $platform'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInstall(String gameName, String platform, String filePath) async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Se necesitan permisos para instalar'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Configuración',
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }
    }

    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo instalar: ${result.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al instalar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final downloadProvider = context.watch<DownloadProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: size.height * 0.35,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderImage(),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _game.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_game.status.isNotEmpty && _game.status != 'Unknown')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _game.status == 'Released'
                                ? Colors.green.withOpacity(0.15)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _game.status,
                            style: TextStyle(
                              color: _game.status == 'Released' ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_game.tagline != null && _game.tagline!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _game.tagline!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_game.description.isNotEmpty) ...[
                    Text(
                      'Descripción',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _game.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Descargar para',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingDetails)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_game.platforms.isEmpty)
                    _buildFallbackDownloads(downloadProvider)
                  else
                    ..._buildPlatformDownloads(_game.platforms, downloadProvider),
                  const SizedBox(height: 24),
                  if (_game.genres.isNotEmpty || _game.lastUpdated != null) ...[
                    Text(
                      'Información',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_game.genres.isNotEmpty)
                      _buildInfoRow(Icons.category_outlined, 'Géneros', _game.genres.join(', ')),
                    if (_game.lastUpdated != null)
                      _buildInfoRow(Icons.update_outlined, 'Actualizado', _formatDate(_game.lastUpdated!)),
                    if (_game.publishedDate != null)
                      _buildInfoRow(Icons.calendar_today_outlined, 'Publicado', _formatDate(_game.publishedDate!)),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage() {
    if (_game.thumbnailUrl != null && _game.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _game.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildHeaderPlaceholder(),
        errorWidget: (context, url, error) => _buildHeaderPlaceholder(),
      );
    }
    return _buildHeaderPlaceholder();
  }

  Widget _buildHeaderPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videogame_asset_outlined,
          size: 80,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  List<Widget> _buildPlatformDownloads(List<dynamic> platforms, DownloadProvider downloadProvider) {
    final List<Widget> widgets = [];
    final compatiblePlatforms = <String>[];

    for (final platform in platforms) {
      final isCompatible = PlatformUtils.isCompatible(platform.name);
      compatiblePlatforms.add(platform.name);

      if (isCompatible) {
        widgets.add(_buildDownloadButton(
          context,
          platform: platform.name,
          url: platform.downloadUrl,
          fileName: platform.fileName ?? '${_game.name}.zip',
          size: platform.fileSize,
          icon: _platformIcon(platform.name),
          downloadProvider: downloadProvider,
        ));
      }
    }

    // Mostrar mensaje si no hay plataformas compatibles
    if (widgets.isEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No disponible para ${PlatformUtils.currentPlatform}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plataformas disponibles: ${compatiblePlatforms.join(", ")}',
                      style: TextStyle(fontSize: 12, color: Colors.orange.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildDownloadButton(
    BuildContext context, {
    required String platform,
    required String url,
    required String fileName,
    required String size,
    required IconData icon,
    required DownloadProvider downloadProvider,
  }) {
    final theme = Theme.of(context);
    final isDownloaded = downloadProvider.isGameDownloaded(_game.name, platform);
    final isApk = fileName.toLowerCase().endsWith('.apk');

    String? downloadedFilePath;
    if (isDownloaded) {
      try {
        final download = downloadProvider.completedDownloads.firstWhere(
          (d) => d.gameName == _game.name && d.platform == platform,
        );
        downloadedFilePath = download.filePath;
      } catch (_) {}
    }

    // Verificar si hay una descarga en progreso
    final activeTask = downloadProvider.tasks.where(
      (t) => t.gameName == _game.name && t.platform == platform,
    );
    final isDownloading = activeTask.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDownloaded
            ? Colors.green.withOpacity(0.05)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isDownloaded
              ? (isApk && downloadedFilePath != null
                  ? () => _handleInstall(_game.name, platform, downloadedFilePath!)
                  : null)
              : (isDownloading ? null : () => _startDownload(url, fileName, platform)),
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          highlightColor: theme.colorScheme.primary.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDownloaded
                    ? Colors.green.withOpacity(0.3)
                    : theme.colorScheme.onSurface.withOpacity(0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDownloaded ? Icons.check_circle : icon,
                  color: isDownloaded ? Colors.green : theme.colorScheme.secondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDownloaded
                            ? (isApk ? 'Toca para instalar' : 'Descargado')
                            : (isDownloading ? 'Descargando...' : fileName),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDownloaded
                              ? Colors.green.withOpacity(0.7)
                              : (isDownloading
                                  ? theme.colorScheme.primary.withOpacity(0.7)
                                  : theme.colorScheme.onSurface.withOpacity(0.4)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDownloaded
                          ? Colors.green.withOpacity(0.1)
                          : theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDownloaded ? (isApk ? 'Instalar' : 'Listo') : size,
                          style: TextStyle(
                            color: isDownloaded ? Colors.green : theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isDownloaded
                              ? (isApk ? Icons.install_mobile : Icons.check)
                              : Icons.arrow_downward_rounded,
                          color: isDownloaded ? Colors.green : theme.colorScheme.primary,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackDownloads(DownloadProvider downloadProvider) {
    final knownDownloads = _getKnownDownloads();
    final compatible = knownDownloads.where((dl) => PlatformUtils.isCompatible(dl['platform']!)).toList();

    if (compatible.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No disponible para ${PlatformUtils.currentPlatform}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: compatible.map((dl) {
        return _buildDownloadButton(
          context,
          platform: dl['platform']!,
          url: dl['url']!,
          fileName: dl['fileName']!,
          size: dl['size']!,
          icon: dl['platform'] == 'Android' ? Icons.phone_android : Icons.computer,
          downloadProvider: downloadProvider,
        );
      }).toList(),
    );
  }

  List<Map<String, String>> _getKnownDownloads() {
    final name = _game.name;
    final baseUrl = _game.pageUrl;

    if (name == 'TANQUE MINI') {
      return [
        {'platform': 'Windows', 'url': '$baseUrl/download/TANQUE.MINI.exe', 'fileName': 'TANQUE MINI.exe', 'size': '98 MB'},
        {'platform': 'Linux', 'url': '$baseUrl/download/TANQUE.MINI.x86_64', 'fileName': 'TANQUE MINI.x86_64', 'size': '70 MB'},
      ];
    } else if (name == 'EverligH 86') {
      return [
        {'platform': 'Windows', 'url': '$baseUrl/download/EverligH86.exe', 'fileName': 'EverligH 86.exe', 'size': '~120 MB'},
        {'platform': 'Linux', 'url': '$baseUrl/download/EverligH86.x86_64', 'fileName': 'EverligH 86.x86_64', 'size': '~90 MB'},
        {'platform': 'Android', 'url': '$baseUrl/download/EverligH86.apk', 'fileName': 'EverligH 86.apk', 'size': '~60 MB'},
      ];
    } else if (name == 'Lightner') {
      return [
        {'platform': 'Android', 'url': '$baseUrl/download/Lightner.apk', 'fileName': 'Lightner.apk', 'size': '~80 MB'},
      ];
    }
    return [];
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android': return Icons.phone_android;
      case 'windows': return Icons.computer;
      case 'linux': return Icons.desktop_windows;
      case 'macos': case 'mac': return Icons.apple;
      default: return Icons.download_outlined;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
