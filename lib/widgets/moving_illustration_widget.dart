// lib/widgets/moving_illustration_widget.dart

import 'package:flutter/material.dart';
import '../models/moving_illustration.dart';
import '../constants/game_constants.dart';

// Widget que representa visualmente una ilustración cayendo, incluyendo la barra de tiempo.
class MovingIllustrationWidget extends StatelessWidget {
  final MovingIllustration illustration;

  const MovingIllustrationWidget({super.key, required this.illustration});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Para que la columna tome el tamaño mínimo
      children: [
        // La imagen
        Image.asset(
          illustration.illustration.path,
          width: illustration.size,
          height: illustration.size,
          fit: BoxFit.contain, // Asegura que la imagen se ajuste bien
          errorBuilder: (context, error, stackTrace) {
            // Muestra un widget placeholder en caso de error
            return Container(
              width: illustration.size,
              height: illustration.size,
              color: Colors.red.withAlpha((0.5 * 255).toInt()),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 30),
            );
          },
        ),
        const SizedBox(height: 4), // Pequeño espacio entre imagen y barra
        // La barra de tiempo
        Container(
          width: illustration.size,
          height: 6, // Un poco más visible
          clipBehavior: Clip.antiAlias, // Para redondear bien los bordes internos
          decoration: BoxDecoration(
            color: Colors.grey.shade300, // Color de fondo de la barra
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (illustration.timeLeft / GameConstants.ILLUSTRATION_LIFETIME[GameConstants.NIVEL]!).clamp(
              0.0,
              1.0,
            ), // Asegura que el factor esté entre 0 y 1
            child: Container(
              decoration: BoxDecoration(
                color: _getTimeBarColor(illustration.timeLeft),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Determina el color de la barra de tiempo basado en el tiempo restante
  Color _getTimeBarColor(double timeLeft) {
    final double percentage = timeLeft / GameConstants.ILLUSTRATION_LIFETIME[GameConstants.NIVEL]!;
    if (percentage < 0.3) return Colors.red.shade600; // Menos del 30%
    if (percentage < 0.6) return Colors.orange.shade600; // Menos del 60%
    return Colors.green.shade600; // 60% o más
  }
}
