// lib/widgets/moving_illustration_widget_2.dart

import 'package:flutter/material.dart';
import '../models/moving_illustration.dart';

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
      ],
    );
  }
}
