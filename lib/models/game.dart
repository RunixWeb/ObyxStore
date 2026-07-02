class GamePlatform {
  final String name;
  final String downloadUrl;
  final String fileSize;
  final String? fileName;

  GamePlatform({
    required this.name,
    required this.downloadUrl,
    required this.fileSize,
    this.fileName,
  });

  factory GamePlatform.fromJson(Map<String, dynamic> json) {
    return GamePlatform(
      name: json['name'] as String,
      downloadUrl: json['downloadUrl'] as String,
      fileSize: json['fileSize'] as String,
      fileName: json['fileName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'downloadUrl': downloadUrl,
      'fileSize': fileSize,
      'fileName': fileName,
    };
  }
}

class Game {
  final String name;
  final String description;
  final String? tagline;
  final String pageUrl;
  final String? thumbnailUrl;
  final List<String> genres;
  final String status; // Released, In Development, etc.
  final List<GamePlatform> platforms;
  final DateTime? lastUpdated;
  final DateTime? publishedDate;

  Game({
    required this.name,
    required this.description,
    this.tagline,
    required this.pageUrl,
    this.thumbnailUrl,
    this.genres = const [],
    this.status = 'Unknown',
    this.platforms = const [],
    this.lastUpdated,
    this.publishedDate,
  });

  bool get isAndroid => platforms.any((p) => p.name.toLowerCase().contains('android'));

  bool get isWindows => platforms.any((p) => p.name.toLowerCase().contains('windows'));

  bool get isLinux => platforms.any((p) => p.name.toLowerCase().contains('linux'));

  bool get isMac => platforms.any((p) => p.name.toLowerCase().contains('mac'));

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      name: json['name'] as String,
      description: json['description'] as String,
      tagline: json['tagline'] as String?,
      pageUrl: json['pageUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'Unknown',
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => GamePlatform.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
      publishedDate: json['publishedDate'] != null
          ? DateTime.parse(json['publishedDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'tagline': tagline,
      'pageUrl': pageUrl,
      'thumbnailUrl': thumbnailUrl,
      'genres': genres,
      'status': status,
      'platforms': platforms.map((p) => p.toJson()).toList(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'publishedDate': publishedDate?.toIso8601String(),
    };
  }
}
