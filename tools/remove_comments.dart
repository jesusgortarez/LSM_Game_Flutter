import 'dart:io';

void main(List arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('Uso: dart remove_comments.dart <archivo.dart>');
    exit(1);
  }

  final file = File(arguments.first);
  if (!file.existsSync()) {
    stderr.writeln('El archivo ${arguments.first} no existe.');
    exit(1);
  }

  final content = file.readAsStringSync();
  final uncommented = removeComments(content);

  // Puedes optar por sobrescribir el archivo original o crear uno nuevo.
  // Aquí creamos uno nuevo agregando ".nocomments" antes de la extensión.
  final newFilePath = _newFileName(file.path);
  final newFile = File(newFilePath);
  newFile.writeAsStringSync(uncommented);
  stdout.writeln('Archivo generado sin comentarios: $newFilePath');
}

/// Función que elimina comentarios de código Dart.
/// Remueve tanto comentarios de línea (//...) como comentarios en bloque (/* ... */).
String removeComments(String input) {
  // Esta expresión regular busca:
  // • Comentarios de una sola línea: // hasta el final de la línea
  // • Comentarios de bloque: todo lo que esté entre / y /
  final commentPattern = RegExp(r'//.*?$|/\*[\s\S]*?\*/', multiLine: true);
  return input.replaceAll(commentPattern, '');
}

/// Función auxiliar para formar el nombre del nuevo archivo.
String _newFileName(String originalPath) {
  final file = File(originalPath);
  final dir = file.parent.path;
  final baseName = file.uri.pathSegments.last;
  final dot = baseName.lastIndexOf('.');
  final name = (dot != -1) ? baseName.substring(0, dot) : baseName;
  final ext = (dot != -1) ? baseName.substring(dot) : '';
  return '$dir/${name}.nocomments$ext';
}
