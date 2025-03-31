// lib/models/illustration.dart

import 'package:flutter/foundation.dart'; // Necesario para @required

// Modelo base para una ilustración
@immutable // Asegura que la clase es inmutable
class Illustration {
  final String path;
  final String name;
  final String category;
  final int nivel;

  const Illustration({required this.path, required this.name, required this.category, required this.nivel});
}
