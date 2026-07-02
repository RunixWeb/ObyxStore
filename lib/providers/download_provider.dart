import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/download_service.dart';
import '../services/itch_io_scraper.dart';
import '../services/storage_service.dart';

class DownloadTask {
  final String id;
  final String gameName;
  final String url;
  final String gamePageUrl;
  final String fileName;
  final String platform;
  final String fileSize;
  final ValueNotifier<DownloadProgress> progress;

  DownloadTask({
    required this.id,
    required this.gameName,
    required this.url,
    required this.gamePageUrl,
    required this.fileName,
    required this.platform,
    this.fileSize = 'Unknown',
    DownloadProgress? progress,
  }) : progress = ValueNotifier<DownloadProgress>(
          progress ??
              DownloadProgress(
                taskId: id,
                fileName: fileName,
                status: DownloadStatus.idle,
              ),
        );
}

class DownloadProvider extends ChangeNotifier {
  final DownloadService _downloadService = DownloadService();
  final ItchIoScraper _scraper = ItchIoScraper();
  final List<DownloadTask> _tasks = [];
  final Map<String, StreamSubscription> _subscriptions = {};
  final List<CompletedDownload> _completedDownloads = [];
  bool _isLoaded = false;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<CompletedDownload> get completedDownloads => List.unmodifiable(_completedDownloads);
  List<DownloadTask> get activeDownloads =>
      _tasks.where((t) => t.progress.value.status == DownloadStatus.downloading).toList();

  int get activeCount => activeDownloads.length;
  int get completedCount => _completedDownloads.length;

  DownloadProvider() {
    _loadCompletedDownloads();
  }

  Future<void> _loadCompletedDownloads() async {
    if (_isLoaded) return;
    final downloads = await StorageService.getCompletedDownloads();
    _completedDownloads.addAll(downloads);
    _isLoaded = true;
    notifyListeners();
  }

  bool isGameDownloaded(String gameName, String platform) {
    return _completedDownloads.any(
      (d) => d.gameName == gameName && d.platform == platform,
    );
  }

  /// Recarga la lista de descargas completadas desde el almacenamiento
  Future<void> refreshCompletedDownloads() async {
    final downloads = await StorageService.getCompletedDownloads();
    _completedDownloads.clear();
    _completedDownloads.addAll(downloads);
    notifyListeners();
  }

  Future<void> deleteDownload(CompletedDownload download) async {
    try {
      if (download.publicPath != null) {
        final publicFile = File(download.publicPath!);
        if (await publicFile.exists()) {
          await publicFile.delete();
        }
      }
      final privFile = File(download.filePath);
      if (await privFile.exists()) {
        await privFile.delete();
      }
      await StorageService.removeCompletedDownload(download.fileName, download.platform);
      _completedDownloads.removeWhere(
        (d) => d.fileName == download.fileName && d.platform == download.platform,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error al eliminar descarga: $e');
    }
  }

  Future<void> startDownload({
    required String gameName,
    required String url,
    required String gamePageUrl,
    required String fileName,
    required String platform,
    String fileSize = 'Unknown',
  }) async {
    final taskId = '${gameName}_${platform}_${DateTime.now().millisecondsSinceEpoch}';

    if (isGameDownloaded(gameName, platform)) {
      return;
    }

    final task = DownloadTask(
      id: taskId,
      gameName: gameName,
      url: url,
      gamePageUrl: gamePageUrl,
      fileName: fileName,
      platform: platform,
      fileSize: fileSize,
      progress: DownloadProgress(
        taskId: taskId,
        fileName: fileName,
        status: DownloadStatus.idle,
      ),
    );

    _tasks.add(task);
    notifyListeners();

    _resolveAndDownload(task);
  }

  Future<void> _resolveAndDownload(DownloadTask task) async {
    try {
      task.progress.value = DownloadProgress(
        taskId: task.id,
        fileName: task.fileName,
        status: DownloadStatus.downloading,
        receivedBytes: 0,
        totalBytes: 0,
      );
      notifyListeners();

      final cdnUrl = await _scraper.fetchDirectCdnUrl(task.url, task.gamePageUrl);

      final stream = _downloadService.downloadFile(
        taskId: task.id,
        url: cdnUrl,
        fileName: task.fileName,
        subDirectory: 'Downloads/${task.gameName}',
      );

      final subscription = stream.listen(
        (progress) {
          task.progress.value = progress;

          if (progress.status == DownloadStatus.completed && progress.savedPath != null) {
            _tasks.removeWhere((t) => t.id == task.id);
            _subscriptions.remove(task.id);
            // Guardar primero y luego notificar
            _saveCompletedDownload(task, progress.savedPath!, progress.publicPath).then((_) {
              notifyListeners();
            });
          } else if (progress.status == DownloadStatus.failed) {
            notifyListeners();
          }
        },
        onError: (error) {
          task.progress.value = task.progress.value.copyWith(
            status: DownloadStatus.failed,
            errorMessage: error.toString(),
          );
          notifyListeners();
        },
        onDone: () {
          _subscriptions.remove(task.id);
        },
      );

      _subscriptions[task.id] = subscription;
    } catch (e) {
      task.progress.value = DownloadProgress(
        taskId: task.id,
        fileName: task.fileName,
        status: DownloadStatus.failed,
        errorMessage: 'Error al resolver URL: $e',
      );
      notifyListeners();
    }
  }

  Future<void> _saveCompletedDownload(DownloadTask task, String filePath, String? publicPath) async {
    final download = CompletedDownload(
      gameName: task.gameName,
      fileName: task.fileName,
      platform: task.platform,
      filePath: filePath,
      publicPath: publicPath,
      downloadedAt: DateTime.now(),
    );

    await StorageService.saveCompletedDownload(download);
    _completedDownloads.add(download);
  }

  void cancelDownload(String taskId) {
    _downloadService.cancelDownload(taskId);
    _subscriptions[taskId]?.cancel();
    _subscriptions.remove(taskId);
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  Future<String?> getDownloadedFilePath(String fileName) async {
    return await _downloadService.getDownloadedFilePath(fileName);
  }

  Future<void> clearCompleted() async {
    _tasks.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _downloadService.dispose();
    super.dispose();
  }
}
