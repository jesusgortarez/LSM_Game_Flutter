// lib/constants/game_constants.dart

class GameConstants {
  // Constantes de ambos juegos
  static int NIVEL = 1; // Nivel actual del juego
  static Map<int, int> ILLUSTRATIONS_PER_LEVEL = {1: 20, 2: 21};
  static final Map<int, int> WINNING_SCORE_THRESHOLD = {1: 14, 2: 15};
  static int MAX_LEVEL = 2; // Número máximo de niveles

  // Constantes del juego 1
  static Duration GAME_TICK = Duration(milliseconds: 33); // 30 FPS
  static final Map<int, double> TARGET_FALL_DURATION_SECONDS = {1: 4.0, 2: 3.43};
  static final Map<int, double> ILLUSTRATION_LIFETIME = {1: 4.0, 2: 3.43};
  static final Map<int, int> MAX_FALLING_ILLUSTRATIONS = {1: 1, 2: 1};
  static final Map<int, Duration> SPAWN_INTERVAL = {
    1: Duration(seconds: 4),
    2: Duration(seconds: 3, milliseconds: 430),
  };
  static bool SEEMATCH = false; // Modo Seematch activado/desactivado

  //Constantes del juego 2
  static const Map<int, double> CAROUSEL_RPM = {1: 2.0, 2: 3.0};

  static final Map<int, Duration> LEVEL_DURATION = {
    1: Duration(minutes: 1, seconds: 30), // Ejemplo: 90 segundos para nivel 1
    2: Duration(minutes: 1, seconds: 15), // Ejemplo: 75 segundos para nivel 2
    // Añade duraciones para otros niveles
  };
}
