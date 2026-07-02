import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadStatus { idle, downloading, completed, failed, paused }

class DownloadProgress {
  final String taskId;
  final String fileName;
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final DownloadStatus status;
  final String? errorMessage;
  final String? savedPath;
  final String? publicPath; // Ruta en carpeta de descargas pública

  DownloadProgress({
    required this.taskId,
    required this.fileName,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
    this.savedPath,
    this.publicPath,
  });

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get formattedSize {
    if (totalBytes == 0) return 'Unknown';
    return _formatBytes(totalBytes);
  }

  String get formattedDownloaded {
    return _formatBytes(receivedBytes);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  DownloadProgress copyWith({
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    DownloadStatus? status,
    String? errorMessage,
    String? savedPath,
    String? publicPath,
  }) {
    return DownloadProgress(
      taskId: taskId,
      fileName: fileName,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      errorMessage: errorMessage,
      savedPath: savedPath ?? this.savedPath,
      publicPath: publicPath ?? this.publicPath,
    );
  }
}

class DownloadService {
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
          followRedirects: true,
          maxRedirects: 5,
        ));

  /// Inicia una descarga con seguimiento de progreso
  Stream<DownloadProgress> downloadFile({
    required String taskId,
    required String url,
    required String fileName,
    String? subDirectory,
  }) {
    final controller = StreamController<DownloadProgress>();
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    _startDownloadWithController(
      controller: controller,
      taskId: taskId,
      url: url,
      fileName: fileName,
      subDirectory: subDirectory,
      cancelToken: cancelToken,
    );

    return controller.stream;
  }

  Future<void> _startDownloadWithController({
    required StreamController<DownloadProgress> controller,
    required String taskId,
    required String url,
    required String fileName,
    String? subDirectory,
    required CancelToken cancelToken,
  }) async {
    try {
      // Obtener el directorio de descargas de la app (privado)
      final directory = await getApplicationDocumentsDirectory();
      final downloadDir = subDirectory != null
          ? Directory('${directory.path}/$subDirectory')
          : Directory('${directory.path}/Downloads');

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filePath = '${downloadDir.path}/$fileName';
      final tempPath = '$filePath.part';

      // Verificar si ya existe
      if (await File(filePath).exists()) {
        // Copiar a carpeta pública si no existe
        final publicPath = await _copyToPublicDirectory(filePath, fileName);
        
        final fileSize = await File(filePath).length();
        controller.add(DownloadProgress(
          taskId: taskId,
          fileName: fileName,
          progress: 1.0,
          receivedBytes: fileSize,
          totalBytes: fileSize,
          status: DownloadStatus.completed,
          savedPath: filePath,
          publicPath: publicPath,
        ));
        controller.close();
        return;
      }

      controller.add(DownloadProgress(
        taskId: taskId,
        fileName: fileName,
        status: DownloadStatus.downloading,
      ));

      await _dio.download(
        url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (controller.isClosed) return;
          final progressValue = total > 0 ? received / total : 0.0;
          controller.add(DownloadProgress(
            taskId: taskId,
            fileName: fileName,
            progress: progressValue,
            receivedBytes: received,
            totalBytes: total,
            status: DownloadStatus.downloading,
          ));
        },
      );

      // Mover archivo temporal a destino final
      await File(tempPath).rename(filePath);

      final file = File(filePath);
      final fileSize = await file.length();

      // Copiar a carpeta pública de Downloads
      final publicPath = await _copyToPublicDirectory(filePath, fileName);

      controller.add(DownloadProgress(
        taskId: taskId,
        fileName: fileName,
        progress: 1.0,
        receivedBytes: fileSize,
        totalBytes: fileSize,
        status: DownloadStatus.completed,
        savedPath: filePath,
        publicPath: publicPath,
      ));
      controller.close();
    } on DioException catch (e) {
      if (cancelToken.isCancelled) {
        controller.add(DownloadProgress(
          taskId: taskId,
          fileName: fileName,
          status: DownloadStatus.paused,
        ));
      } else {
        controller.add(DownloadProgress(
          taskId: taskId,
          fileName: fileName,
          status: DownloadStatus.failed,
          errorMessage: e.message ?? 'Error de descarga',
        ));
      }
      controller.close();
    } catch (e) {
      controller.add(DownloadProgress(
        taskId: taskId,
        fileName: fileName,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
      controller.close();
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  /// Copia el archivo a la carpeta pública de Downloads
  Future<String?> _copyToPublicDirectory(String sourcePath, String fileName) async {
    try {
      // Intentar obtener el directorio externo de Downloads
      Directory? externalDir;
      
      if (Platform.isAndroid) {
        // En Android, usar getExternalStorageDirectory
        externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navegar a la carpeta Download
          final downloadDir = Directory('/storage/emulated/0/Download/RunixStore');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          final destPath = '${downloadDir.path}/$fileName';
          await File(sourcePath).copy(destPath);
          return destPath;
        }
      }
      
      // Fallback: usar directorio temporal
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await File(sourcePath).copy(tempPath);
      return tempPath;
    } catch (e) {
      // Si falla, retornar null pero la descarga privada sigue siendo válida
      return null;
    }
  }

  /// Cancela una descarga en curso
  void cancelDownload(String taskId) {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null) {
      cancelToken.cancel();
      _cancelTokens.remove(taskId);
    }
  }

  /// Obtiene la ruta donde se guardó un archivo
  Future<String?> getDownloadedFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Downloads/$fileName');
    if (await file.exists()) {
      return file.path;
    }
    // Buscar en subdirectorios
    final dir = Directory('${directory.path}/Downloads');
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith(fileName)) {
          return entity.path;
        }
      }
    }
    return null;
  }

  /// Limpia el directorio de descargas
  Future<void> clearDownloads() async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${directory.path}/Downloads');
    if (await downloadDir.exists()) {
      await downloadDir.delete(recursive: true);
    }
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
  }
}
