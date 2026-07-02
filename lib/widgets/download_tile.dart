import 'package:flutter/material.dart';
import '../providers/download_provider.dart';
import '../services/download_service.dart';

class DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onCancel;
  final VoidCallback? onOpen;

  const DownloadTile({
    super.key,
    required this.task,
    this.onCancel,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<DownloadProgress>(
      valueListenable: task.progress,
      builder: (context, progress, _) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.onSurface.withOpacity(0.06),
              width: 0.5,
            ),
          ),
          color: theme.cardTheme.color,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _statusIcon(progress.status),
                      color: _statusColor(progress.status),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.fileName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusText(progress),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _statusColor(progress.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (progress.status == DownloadStatus.downloading)
                      _buildCancelButton(context),
                    if (progress.status == DownloadStatus.completed)
                      _buildOpenButton(context),
                    if (progress.status == DownloadStatus.failed)
                      _buildRetryButton(context),
                  ],
                ),
                if (progress.status == DownloadStatus.downloading && progress.totalBytes > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.progress,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${progress.formattedDownloaded} / ${progress.formattedSize}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
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
                ] else if (progress.status == DownloadStatus.downloading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.close, size: 20),
      onPressed: onCancel,
      tooltip: 'Cancelar',
    );
  }

  Widget _buildOpenButton(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: TextButton.icon(
        onPressed: onOpen,
        icon: Icon(Icons.share_rounded, size: 16, color: theme.colorScheme.primary),
        label: Text(
          'Exportar',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh, size: 20),
      onPressed: () {
        // Reintentar descarga
        if (onCancel != null) {
          onCancel!();
        }
      },
      tooltip: 'Reintentar',
    );
  }

  Color _statusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.idle:
        return Colors.grey;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.paused:
        return Colors.orange;
    }
  }

  IconData _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.idle:
        return Icons.download_outlined;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.completed:
        return Icons.check_circle_outline;
      case DownloadStatus.failed:
        return Icons.error_outline;
      case DownloadStatus.paused:
        return Icons.pause_circle_outline;
    }
  }

  String _statusText(DownloadProgress progress) {
    switch (progress.status) {
      case DownloadStatus.idle:
        return 'Pendiente';
      case DownloadStatus.downloading:
        return progress.totalBytes == 0 ? 'Resolviendo enlace...' : 'Descargando...';
      case DownloadStatus.completed:
        return 'Completado';
      case DownloadStatus.failed:
        return 'Error: ${progress.errorMessage ?? "Desconocido"}';
      case DownloadStatus.paused:
        return 'Pausado';
    }
  }
}
