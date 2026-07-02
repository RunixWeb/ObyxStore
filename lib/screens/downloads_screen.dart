import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/download_provider.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Descargas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En progreso'),
              Tab(text: 'Completados'),
            ],
          ),
          actions: [
            Consumer<DownloadProvider>(
              builder: (context, provider, _) {
                if (provider.completedDownloads.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 22),
                    onPressed: () => _showClearAllDialog(context, provider),
                    tooltip: 'Limpiar todo',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _ProgressTab(),
            _CompletedTab(),
          ],
        ),
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar'),
        content: const Text('¿Eliminar todas las descargas completadas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              for (final download in provider.completedDownloads) {
                await provider.deleteDownload(download);
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
  }
}

// ─── Pestaña de Progreso ──────────────────────────────────────────────────────

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        if (provider.activeCount == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.downloading_outlined, size: 48, color: Colors.grey.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'Sin descargas activas',
                  style: TextStyle(fontSize: 16, color: Colors.grey.withOpacity(0.6)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: provider.activeDownloads.length,
          itemBuilder: (context, index) {
            final task = provider.activeDownloads[index];
            return _ProgressTile(
              task: task,
              onCancel: () => provider.cancelDownload(task.id),
            );
          },
        );
      },
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onCancel;
  const _ProgressTile({required this.task, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<DownloadProgress>(
      valueListenable: task.progress,
      builder: (context, progressData, _) {
        final progress = progressData;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.06), width: 0.5),
          ),
          color: theme.cardTheme.color,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.fileName,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${task.platform} - Descargando...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: Colors.red.withOpacity(0.7)),
                      onPressed: onCancel,
                      tooltip: 'Cancelar',
                    ),
                  ],
                ),
                if (progress.totalBytes > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.progress,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.formattedDownloaded} / ${progress.formattedSize}',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                      ),
                      Text(
                        progress.progressPercentage,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Pestaña de Completados ───────────────────────────────────────────────────

class _CompletedTab extends StatelessWidget {
  const _CompletedTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, _) {
        if (provider.completedDownloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'Sin descargas completadas',
                  style: TextStyle(fontSize: 16, color: Colors.grey.withOpacity(0.6)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: provider.completedDownloads.length,
          itemBuilder: (context, index) {
            final download = provider.completedDownloads[index];
            return _CompletedTile(download: download);
          },
        );
      },
    );
  }
}

class _CompletedTile extends StatelessWidget {
  final CompletedDownload download;
  const _CompletedTile({required this.download});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApk = download.fileName.toLowerCase().endsWith('.apk');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.06), width: 0.5),
      ),
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.fileName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${download.platform} - Listo para ${isApk ? "instalar" : "usar"}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isApk ? Icons.install_mobile : Icons.open_in_new,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => _handleOpen(context, download.fileName, download.filePath),
              tooltip: isApk ? 'Instalar' : 'Abrir',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.withOpacity(0.7)),
              onPressed: () => _showDeleteDialog(context, download),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CompletedDownload download) {
    final provider = context.read<DownloadProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${download.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await provider.deleteDownload(download);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpen(BuildContext context, String fileName, String filePath) async {
    if (!File(filePath).existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo no encontrado'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permiso requerido'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(label: 'Config.', onPressed: () => openAppSettings()),
            ),
          );
          return;
        }
      }
    }

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result.message}'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
