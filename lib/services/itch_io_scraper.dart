import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/game.dart';

class ItchIoScraper {
  final String profileUrl;
  final Dio _dio;

  ItchIoScraper({
    this.profileUrl = 'https://runix-yt.itch.io',
  }) : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36',
          },
        ));

  Future<List<Game>> fetchGames() async {
    try {
      final response = await _dio.get(profileUrl);
      if (response.statusCode != 200) {
        throw Exception('Error al cargar perfil: ${response.statusCode}');
      }

      final document = html_parser.parse(response.data as String);
      final links = document.querySelectorAll('a');
      final processedUrls = <String>{};
      final games = <Game>[];

      for (final link in links) {
        final href = link.attributes['href'] ?? '';
        if (href.startsWith('$profileUrl/') &&
            !href.contains('/download') &&
            !href.contains('/feed') &&
            !href.contains('/followers') &&
            !href.contains('/following') &&
            !href.contains('/library') &&
            !href.contains('/dashboard') &&
            !href.contains('/edit') &&
            !href.contains('javascript:') &&
            !href.contains('#') &&
            href != profileUrl &&
            !processedUrls.contains(href)) {
          final gameName = _extractGameName(link, document);
          if (gameName != null && gameName.isNotEmpty) {
            processedUrls.add(href);
            games.add(Game(
              name: gameName,
              description: _findTagline(link, document) ?? gameName,
              pageUrl: href,
              status: 'Unknown',
            ));
          }
        }
      }

      if (games.isEmpty) {
        return _fallbackGames();
      }
      return games;
    } catch (e) {
      throw Exception('Error al obtener juegos: $e');
    }
  }

  Future<Game> fetchGameDetails(Game game) async {
    try {
      final response = await _dio.get(game.pageUrl);
      if (response.statusCode != 200) {
        throw Exception('Error al cargar juego: ${response.statusCode}');
      }

      final document = html_parser.parse(response.data as String);

      return Game(
        name: game.name,
        description: _extractFullDescription(document) ?? game.description,
        tagline: game.tagline,
        pageUrl: game.pageUrl,
        thumbnailUrl: game.thumbnailUrl ?? _extractGameThumbnail(document),
        genres: _extractGenres(document),
        status: _extractStatus(document) ?? game.status,
        platforms: _extractDownloadLinks(document, game.pageUrl),
        lastUpdated: _extractDate(document, 'Updated'),
        publishedDate: _extractDate(document, 'Published'),
      );
    } catch (e) {
      throw Exception('Error al obtener detalles del juego: $e');
    }
  }

  List<GamePlatform> _extractDownloadLinks(dom.Document document, String baseUrl) {
    final platforms = <GamePlatform>[];
    final uploads = document.querySelectorAll('.upload');

    for (final upload in uploads) {
      final link = upload.querySelector('a.download_btn');
      if (link == null) continue;

      final uploadId = link.attributes['data-upload_id'];
      if (uploadId == null || uploadId.isEmpty) continue;

      final fileUrl = '$baseUrl/file/$uploadId?source=game_download&after_download_lightbox=1&as_props=1';

      final nameEl = upload.querySelector('.upload_name strong, .name');
      final fileName = nameEl?.text.trim() ?? nameEl?.attributes['title'] ?? 'Game File';

      final sizeEl = upload.querySelector('.file_size span, .file_size');
      final fileSize = sizeEl?.text.trim() ?? 'Unknown';

      String platformName = 'Unknown';
      final platformIcon = upload.querySelector('.download_platforms .icon, .download_platforms [class*="icon-"]');
      if (platformIcon != null) {
        final title = platformIcon.attributes['title'] ?? '';
        final className = platformIcon.attributes['class'] ?? '';
        if (title.toLowerCase().contains('windows') || className.contains('windows')) {
          platformName = 'Windows';
        } else if (title.toLowerCase().contains('android') || className.contains('android') || className.contains('phone')) {
          platformName = 'Android';
        } else if (title.toLowerCase().contains('linux') || className.contains('tux') || className.contains('linux')) {
          platformName = 'Linux';
        } else if (title.toLowerCase().contains('mac') || className.contains('apple') || className.contains('mac')) {
          platformName = 'macOS';
        }
      }

      if (platformName == 'Unknown') {
        final lowerName = fileName.toLowerCase();
        if (lowerName.endsWith('.exe')) {
          platformName = 'Windows';
        } else if (lowerName.endsWith('.apk')) {
          platformName = 'Android';
        } else if (lowerName.endsWith('.dmg') || lowerName.endsWith('.app')) {
          platformName = 'macOS';
        } else if (lowerName.endsWith('.x86_64') || lowerName.endsWith('.appimage') || lowerName.endsWith('.deb')) {
          platformName = 'Linux';
        } else if (lowerName.endsWith('.zip') || lowerName.endsWith('.rar') || lowerName.endsWith('.7z')) {
          platformName = 'Archive';
        }
      }

      platforms.add(GamePlatform(
        name: platformName,
        downloadUrl: fileUrl,
        fileSize: fileSize,
        fileName: fileName,
      ));
    }

    return platforms;
  }

  Map<String, String>? _parseDownloadText(String text) {
    final cleaned = text.replaceAll(RegExp(r'^Download\s+', caseSensitive: false), '').trim();
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(KB|MB|GB)$').firstMatch(cleaned);
    if (sizeMatch == null) return null;

    final fileName = cleaned.substring(0, sizeMatch.start).trim();
    final size = '${sizeMatch.group(1)} ${sizeMatch.group(2)}';
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    String platformName;
    switch (ext) {
      case 'exe':
        platformName = 'Windows';
        break;
      case 'apk':
        platformName = 'Android';
        break;
      case 'app':
        platformName = 'macOS';
        break;
      case 'x86_64':
      case 'appimage':
      case 'deb':
        platformName = 'Linux';
        break;
      case 'zip':
      case 'rar':
      case '7z':
        platformName = 'Archive';
        break;
      default:
        platformName = ext.isNotEmpty ? ext.toUpperCase() : 'Unknown';
    }

    return {'platform': platformName, 'size': size, 'fileName': fileName};
  }

  String? _extractGameName(dom.Element link, dom.Document doc) {
    final text = link.text.trim();
    if (text.isNotEmpty &&
        !text.contains('http') &&
        !text.contains('itch.io') &&
        text.length > 1 &&
        text.length < 50) {
      return text;
    }

    var parent = link.parent;
    int attempts = 0;
    while (parent != null && attempts < 5) {
      final titleEl = parent.querySelector('.game_title, .title, h2, h3, h4, [class*="title"]');
      if (titleEl != null) {
        final t = titleEl.text.trim();
        if (t.isNotEmpty) return t;
      }
      parent = parent.parent;
      attempts++;
    }
    return null;
  }

  String? _findTagline(dom.Element link, dom.Document doc) {
    var parent = link.parent;
    int attempts = 0;
    while (parent != null && attempts < 5) {
      final descEl = parent.querySelector(
          '.game_text, .description, .tagline, p, [class*="description"], [class*="tagline"]');
      if (descEl != null) {
        final t = descEl.text.trim();
        if (t.isNotEmpty && t != link.text.trim()) return t;
      }
      parent = parent.parent;
      attempts++;
    }
    return null;
  }

  List<Game> _fallbackGames() {
    const knownGames = ['TANQUE MINI', 'EverligH 86', 'Lightner'];
    return knownGames.map((name) {
      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
      return Game(name: name, description: name, pageUrl: '$profileUrl/$slug');
    }).toList();
  }

  String? _extractFullDescription(dom.Document document) {
    final meta = document.querySelector('meta[name="description"]');
    if (meta != null) {
      final c = meta.attributes['content'];
      if (c != null && c.isNotEmpty) return c;
    }
    final descEl = document.querySelector(
        '.game_description, .description, .formatted_description, [class*="description"]');
    return descEl?.text.trim();
  }

  String? _extractStatus(dom.Document document) {
    final String pageText = document.text ?? '';
    final match = RegExp(r'Status\s*\n*\s*([^\n]+)').firstMatch(pageText);
    if (match != null) {
      final s = match.group(1)?.trim();
      if (s != null && s.isNotEmpty) return s;
    }
    if (pageText.contains('Released')) return 'Released';
    if (pageText.contains('In Development')) return 'In Development';
    return null;
  }

  DateTime? _extractDate(dom.Document document, String label) {
    final String pageText = document.text ?? '';
    final pattern = RegExp('$label\\s*\\n*\\s*([^\\n]+)');
    final match = pattern.firstMatch(pageText);
    if (match == null) return null;

    final String? trimmed = match.group(1)?.trim();
    if (trimmed == null) return null;
    final String dateStr = trimmed;
    if (dateStr.isEmpty) return null;
    if (dateStr.contains('days ago') || dateStr.contains('hours ago') || dateStr.contains('minutes ago')) {
      return null;
    }
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  String? _extractGameThumbnail(dom.Document document) {
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      final content = ogImage.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }
    final imgs = document.querySelectorAll('img');
    for (final img in imgs) {
      final String? srcNullable = img.attributes['src'];
      if (srcNullable == null) continue;
      final String src = srcNullable;
      if (src.isEmpty) continue;
      if (src.contains('avatar') || src.contains('icon') || src.contains('logo')) continue;
      if (src.startsWith('http')) return src;
      if (src.startsWith('//')) return 'https:$src';
    }
    return null;
  }

  List<String> _extractGenres(dom.Document document) {
    final String pageText = document.text ?? '';
    final match = RegExp(r'Genre\s*\n*\s*([^\n]+)').firstMatch(pageText);
    if (match == null) return [];
    final genreText = match.group(1)?.trim() ?? '';
    if (genreText.isEmpty) return [];
    return genreText.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
  }

  Future<Map<String, String>> fetchCsrfAndCookie(String gameUrl) async {
    final response = await _dio.get(gameUrl);
    final setCookies = response.headers['set-cookie'] ?? [];
    String? itchioToken;
    for (final c in setCookies) {
      if (c.contains('itchio_token=')) {
        itchioToken = c.split(';').first;
      }
    }
    final document = html_parser.parse(response.data as String);
    final csrfMeta = document.querySelector('meta[name="csrf_token"]');
    final csrfToken = csrfMeta?.attributes['value'];
    return {
      'csrf_token': csrfToken ?? '',
      'cookie': itchioToken ?? '',
    };
  }

  Future<String> fetchDirectCdnUrl(String fileUrl, String gamePageUrl) async {
    final credentials = await fetchCsrfAndCookie(gamePageUrl);
    final csrfToken = credentials['csrf_token']!;
    final cookie = credentials['cookie']!;
    
    final response = await _dio.post(
      fileUrl,
      data: {'csrf_token': csrfToken},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Cookie': cookie,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': gamePageUrl,
        },
      ),
    );
    
    if (response.statusCode == 200) {
      final data = response.data;
      if (data is Map && data.containsKey('url')) {
        return data['url'] as String;
      } else if (data is Map && data.containsKey('errors')) {
        throw Exception(data['errors'].join(', '));
      }
    }
    throw Exception('Failed to get direct download URL');
  }
}
