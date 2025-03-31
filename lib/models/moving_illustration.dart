// lib/models/moving_illustration.dart

import 'illustration.dart';
import '../constants/game_constants.dart';

// Modelo para una ilustración que está actualmente en juego (cayendo o siendo arrastrada)
class MovingIllustration {
  final Illustration illustration; // La ilustración base
  double x; // Posición horizontal actual
  double y; // Posición vertical actual
  double size; // Tamaño de la ilustración en pantalla
  bool isBeingDragged; // Indica si el usuario la está arrastrando
  double timeLeft; // Tiempo restante antes de desaparecer

  MovingIllustration({
    required this.illustration,
    required this.x,
    required this.y,
    required this.size,
    this.isBeingDragged = false,
    double? initialTimeLeft,
  }) : timeLeft = initialTimeLeft ?? GameConstants.ILLUSTRATION_LIFETIME[GameConstants.NIVEL]!;
}
