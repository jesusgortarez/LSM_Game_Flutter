// tool/generate_illustrations.dart
import 'dart:io';
import 'package:path/path.dart' as p; // Necesitas añadir 'path' a pubspec.yaml (en dev_dependencies)

// --- Configuración ---
// Directorio raíz donde buscar las ilustraciones (relativo a la raíz del proyecto)
const String illustrationsSourceDir = 'assets';
// Archivo Dart donde se generará la lista (relativo a la raíz del proyecto)
const String outputDartFile = 'lib/data/illustration_data.dart';
// Marcadores en el archivo Dart para saber dónde insertar el código generado
const String startMarker = '// --- START GENERATED ILLUSTRATIONS ---';
const String endMarker = '// --- END GENERATED ILLUSTRATIONS ---';
// Extensiones de archivo permitidas
const Set<String> allowedExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
// --- Fin Configuración ---

void main() async {
  final illustrationList = <String>[];
  final sourceDir = Directory(illustrationsSourceDir);

  if (!await sourceDir.exists()) {
    print('Error: El directorio fuente "$illustrationsSourceDir" no existe.');
    exit(1);
  }

  print('Buscando ilustraciones en "$illustrationsSourceDir"...');

  // Recorre los directorios de Nivel (Nivel_1, Nivel_2, etc.)
  await for (final levelEntity in sourceDir.list()) {
    if (levelEntity is Directory) {
      final levelDirName = p.basename(levelEntity.path); // "Nivel_1"
      final levelMatch = RegExp(r'^Nivel_(\d+)$').firstMatch(levelDirName);

      if (levelMatch != null) {
        final nivel = int.tryParse(levelMatch.group(1)!);
        if (nivel == null) {
          print('Advertencia: No se pudo parsear el nivel de "$levelDirName".');
          continue;
        }

        print('  Procesando $levelDirName (Nivel $nivel)...');

        // Recorre los directorios de Categoría (A6_ilustraciones, B_ilustraciones, etc.)
        await for (final categoryEntity in levelEntity.list()) {
          if (categoryEntity is Directory) {
            final categoryDirName = p.basename(categoryEntity.path); // "A6_ilustraciones"
            final categoryMatch = RegExp(r'^(.+)_ilustraciones$').firstMatch(categoryDirName);

            if (categoryMatch != null) {
              final category = categoryMatch.group(1)!; // "A6"
              print('    Procesando categoría "$category"...');

              // Recorre los archivos de imagen dentro del directorio de categoría
              await for (final fileEntity in categoryEntity.list()) {
                if (fileEntity is File) {
                  final fileName = p.basename(fileEntity.path); // "11.jpg"
                  final fileExtension = p.extension(fileName).toLowerCase(); // ".jpg"

                  if (allowedExtensions.contains(fileExtension)) {
                    final name = p.basenameWithoutExtension(fileName); // "11"
                    // La ruta para Image.asset debe ser relativa a la raíz del proyecto,
                    // empezando desde 'assets/...' o como esté declarado en pubspec.yaml
                    final assetPath = p
                        .join(illustrationsSourceDir, levelDirName, categoryDirName, fileName)
                        .replaceAll(r'\', '/'); // Asegura separadores '/'

                    print('Encontrada: $assetPath (Nombre: $name, Cat: $category, Nivel: $nivel)');

                    // Formatea la entrada para la lista Dart
                    illustrationList.add(
                      '  const Illustration(\n'
                      '    path: "$assetPath",\n'
                      '    name: "$name",\n'
                      '    category: "$category",\n'
                      '    nivel: $nivel,\n'
                      '  ),',
                    );
                  }
                }
              } // Fin recorrido archivos
            } // Fin if categoryMatch
          } // Fin if categoryEntity is Directory
        } // Fin recorrido directorios categoría
      } // Fin if levelMatch
    } // Fin if levelEntity is Directory
  } // Fin recorrido directorios nivel

  print('Generación de datos completada. Escribiendo en "$outputDartFile"...');
  await _updateDartFile(illustrationList);
  print('¡Archivo Dart actualizado exitosamente!');
}

Future<void> _updateDartFile(List<String> generatedEntries) async {
  final outputFile = File(outputDartFile);
  if (!await outputFile.exists()) {
    print('Error: El archivo de salida "$outputDartFile" no existe.');
    print('Asegúrate de que el archivo exista y contenga los marcadores:');
    print(startMarker);
    print('// Aquí va el código generado...');
    print(endMarker);
    exit(1);
  }

  final originalContent = await outputFile.readAsString();
  final startIndex = originalContent.indexOf(startMarker);
  final endIndex = originalContent.indexOf(endMarker);

  if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
    print('Error: No se encontraron los marcadores "$startMarker" y "$endMarker" en "$outputDartFile".');
    exit(1);
  }

  // Construye el nuevo contenido CORRECTAMENTE
  final before = originalContent.substring(0, startIndex + startMarker.length);
  final after = originalContent.substring(endIndex); // Guarda desde el endMarker hasta el final
  final generatedCode = generatedEntries.join('\n');

  // Usa 'after' aquí para incluir el endMarker y todo lo que sigue
  final newContent = '$before\n$generatedCode\n$after';

  // Escribe el nuevo contenido en el archivo
  await outputFile.writeAsString(newContent);
}
