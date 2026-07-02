import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _themeKey = 'is_dark_theme';
  static const String _completedDownloadsKey = 'completed_downloads';

  static Future<bool> getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true; // Default: dark theme
  }

  static Future<void> setThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  static Future<List<CompletedDownload>> getCompletedDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_completedDownloadsKey) ?? [];
    return jsonList.map((json) => CompletedDownload.fromJson(jsonDecode(json))).toList();
  }

  static Future<void> saveCompletedDownload(CompletedDownload download) async {
    final prefs = await SharedPreferences.getInstance();
    final downloads = await getCompletedDownloads();
    
    // Evitar duplicados
    if (downloads.any((d) => d.fileName == download.fileName && d.platform == download.platform)) {
      return;
    }
    
    downloads.add(download);
    final jsonList = downloads.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_completedDownloadsKey, jsonList);
  }

  static Future<void> removeCompletedDownload(String fileName, String platform) async {
    final prefs = await SharedPreferences.getInstance();
    final downloads = await getCompletedDownloads();
    
    downloads.removeWhere((d) => d.fileName == fileName && d.platform == platform);
    final jsonList = downloads.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_completedDownloadsKey, jsonList);
  }

  static Future<void> clearCompletedDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedDownloadsKey);
  }
}

class CompletedDownload {
  final String gameName;
  final String fileName;
  final String platform;
  final String filePath;
  final String? publicPath;
  final DateTime downloadedAt;

  CompletedDownload({
    required this.gameName,
    required this.fileName,
    required this.platform,
    required this.filePath,
    this.publicPath,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'gameName': gameName,
    'fileName': fileName,
    'platform': platform,
    'filePath': filePath,
    'publicPath': publicPath,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory CompletedDownload.fromJson(Map<String, dynamic> json) => CompletedDownload(
    gameName: json['gameName'],
    fileName: json['fileName'],
    platform: json['platform'],
    filePath: json['filePath'],
    publicPath: json['publicPath'],
    downloadedAt: DateTime.parse(json['downloadedAt']),
  );
}
