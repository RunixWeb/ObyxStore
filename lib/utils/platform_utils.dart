import 'dart:io';

class PlatformUtils {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;

  static String get currentPlatform {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }

  /// Verifica si una plataforma de descarga es compatible con el dispositivo actual
  static bool isCompatible(String platform) {
    final p = platform.toLowerCase();
    if (isAndroid) return p == 'android';
    if (isIOS) return p == 'android' || p == 'ios'; // iOS puede emular APKs con某些 apps
    if (isWindows) return p == 'windows';
    if (isLinux) return p == 'linux';
    if (isMacOS) return p == 'macos' || p == 'mac';
    return false;
  }

  /// Verifica si un archivo es compatible con el sistema actual
  static bool isFileCompatible(String fileName) {
    final f = fileName.toLowerCase();
    if (isAndroid) return f.endsWith('.apk');
    if (isWindows) return f.endsWith('.exe') || f.endsWith('.msi');
    if (isLinux) return f.endsWith('.x86_64') || f.endsWith('.appimage');
    if (isMacOS) return f.endsWith('.dmg') || f.endsWith('.app');
    return false;
  }
}
