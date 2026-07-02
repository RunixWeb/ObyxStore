import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/games_provider.dart';
import 'providers/download_provider.dart';
import 'screens/home_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';

// ─── Theme Provider ──────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;
  bool get isDark => _isDark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isDark = await StorageService.getThemePreference();
    notifyListeners();
  }

  void toggle() {
    _isDark = !_isDark;
    StorageService.setThemePreference(_isDark);
    notifyListeners();
  }
}

// ─── Download Count Provider ──────────────────────────────────────────────────

class DownloadCountProvider extends ChangeNotifier {
  final DownloadProvider _downloadProvider;

  DownloadCountProvider(this._downloadProvider) {
    _downloadProvider.addListener(_onDownloadChanged);
  }

  int get activeCount => _downloadProvider.activeCount;

  void _onDownloadChanged() => notifyListeners();

  @override
  void dispose() {
    _downloadProvider.removeListener(_onDownloadChanged);
    super.dispose();
  }
}

// ─── Main ────────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RunixStoreApp());
}

class RunixStoreApp extends StatelessWidget {
  const RunixStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GamesProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              DownloadCountProvider(context.read<DownloadProvider>()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ObyxStore',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
            routes: {
              '/downloads': (context) => const DownloadsScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }

  // ── Dark theme (premium gaming) ──────────────────────────────────────────
  ThemeData _buildDarkTheme() {
    const bg = Color(0xFF080810);
    const card = Color(0xFF0F0F1A);
    const primary = Color(0xFF9D4EDD);
    const secondary = Color(0xFF00E5FF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: Color(0xFFFF3366),
        surface: bg,
        surfaceContainerHighest: Color(0xFF1A1A2E),
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: card,
        indicatorColor: primary.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      dividerColor: Colors.white.withOpacity(0.06),
    );
  }

  // ── Light theme (clean minimal) ───────────────────────────────────────────
  ThemeData _buildLightTheme() {
    const primary = Color(0xFF7B2CBF);
    const secondary = Color(0xFF0077B6);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5FA),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFFF5F5FA),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
