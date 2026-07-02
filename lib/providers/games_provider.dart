import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../services/itch_io_scraper.dart';

class GamesProvider extends ChangeNotifier {
  final ItchIoScraper _scraper = ItchIoScraper();

  List<Game> _games = [];
  bool _isLoading = false;
  String? _error;
  bool _hasDetails = false;

  List<Game> get games => _games;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasDetails => _hasDetails;

  /// Carga la lista de juegos desde itch.io
  Future<void> loadGames() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _games = await _scraper.fetchGames();
      _isLoading = false;

      if (_games.isNotEmpty) {
        // Comenzar a cargar detalles en segundo plano
        _loadDetailsBackground();
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Error al cargar juegos: $e';
      notifyListeners();
    }
  }

  /// Carga los detalles de los juegos en segundo plano
  Future<void> _loadDetailsBackground() async {
    for (int i = 0; i < _games.length; i++) {
      try {
        final details = await _scraper.fetchGameDetails(_games[i]);
        _games[i] = details;
        notifyListeners();
      } catch (_) {
        // Ignorar errores de detalle, tenemos la info básica
      }
    }
    _hasDetails = true;
    notifyListeners();
  }

  /// Obtiene detalles completos de un juego específico
  Future<Game?> getGameDetails(Game game) async {
    try {
      return await _scraper.fetchGameDetails(game);
    } catch (e) {
      _error = 'Error al cargar detalles: $e';
      notifyListeners();
      return null;
    }
  }

  /// Refresca la lista de juegos
  Future<void> refresh() async {
    _hasDetails = false;
    await loadGames();
  }
}
