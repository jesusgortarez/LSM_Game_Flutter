import 'dart:async'; // Importa funcionalidades asíncronas como Timer.
import 'dart:math'; // Importa funcionalidades matemáticas como Random y max.

import 'package:flutter/material.dart'; // Importa los widgets y herramientas de Flutter.
import 'package:intl/intl.dart'; // Importa herramientas para internacionalización y formato (fechas, números).

import '../constants/game_constants.dart'; // Importa constantes definidas para el juego.
import '../models/illustration.dart'; // Importa el modelo de datos para una ilustración.
import '../models/moving_illustration.dart'; // Importa el modelo para una ilustración que se puede mover.
import '../data/illustration_data.dart' as data; // Importa los datos de las ilustraciones, usando un alias 'data'.
import '../widgets/moving_illustration_widget_2.dart'; // Importa un widget personalizado para mostrar ilustraciones móviles.

// --- INICIO SECCIÓN TUTORIAL ---

class TutorialOverlay extends StatefulWidget {
  final double screenWidth;
  final double screenHeight;

  const TutorialOverlay({Key? key, required this.screenWidth, required this.screenHeight}) : super(key: key);

  @override
  TutorialOverlayState createState() => TutorialOverlayState();
}

class TutorialOverlayState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // Duración de la animación de arrastre
      vsync: this,
    )..repeat(reverse: true);

    // Calcular puntos de inicio y fin para la animación
    // Inicia en el centro de la zona de destino izquierda (aproximado)
    final startX = widget.screenWidth / 6; // Centro horizontal de la zona izquierda (1/3 de ancho total)
    final startY = widget.screenHeight * 0.6; // Centro vertical de la zona izquierda (un poco más abajo de la mitad)
    // Terminar cerca del centro superior (donde aparecen las ilustraciones)
    final endX = widget.screenWidth / 2;
    final endY = widget.screenHeight * 0.15; // Un poco más abajo del borde superior

    _animation = Tween<Offset>(begin: Offset(startX, startY), end: Offset(endX, endY)).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic, // Movimiento suave
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer evita que la capa del tutorial intercepte los toques del usuario
    return IgnorePointer(
      child: Stack(
        children: [
          // Icono de mano animado
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                // Restamos la mitad del tamaño del icono para centrarlo en la posición de la animación
                left: _animation.value.dx - 25,
                top: _animation.value.dy - 25,
                child: Icon(
                  Icons.touch_app, // Icono de mano/toque
                  size: 50, // Tamaño del icono
                  color: Colors.white.withOpacity(0.85), // Color semi-transparente
                  shadows: const [
                    // Sombra para mejorar visibilidad
                    Shadow(blurRadius: 4.0, color: Colors.black54, offset: Offset(1.0, 1.0)),
                  ],
                ),
              );
            },
          ),

          // Leyenda "TUTORIAL"
          Positioned(
            top: 15, // Cerca del borde superior
            left: 0,
            right: 0,
            child: Container(
              // Fondo semi-transparente para el texto
              color: Colors.black.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: Text(
                'TUTORIAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  // Tamaño de fuente responsivo básico
                  fontSize: max(14.0, widget.screenWidth / 30),
                  letterSpacing: 2.0, // Espaciado entre letras
                  shadows: const [
                    // Sombra para el texto
                    Shadow(blurRadius: 2.0, color: Colors.black87, offset: Offset(0.5, 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- FIN SECCIÓN TUTORIAL ---

// Clase que maneja la lógica principal del juego.
class GameController {
  // Notificador para la puntuación actual del jugador.
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  // Notificador para el estado de pausa del juego.
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  // Notificador para indicar si el nivel ha terminado.
  final ValueNotifier<bool> levelEndedNotifier = ValueNotifier<bool>(false);
  // Notificador para contar las ilustraciones que han sido calificadas (correcta o incorrectamente).
  final ValueNotifier<int> qualifiedIllustrationsCountNotifier = ValueNotifier<int>(0);
  // Notificador para la lista de ilustraciones actualmente visibles y arrastrables en la pantalla.
  final ValueNotifier<List<MovingIllustration>> availableIllustrationsNotifier = ValueNotifier<List<MovingIllustration>>([]);
  // Notificador para el tiempo restante en el nivel actual.
  final ValueNotifier<Duration> remainingTimeNotifier = ValueNotifier(Duration.zero);
  // Callback para solicitar una actualización del estado de la UI (setState).
  final VoidCallback requestSetState;
  // Función para mostrar un diálogo al final del nivel.
  final Function(String title, String message, bool levelWon) showEndLevelDialog;
  // Función para mostrar un SnackBar (mensaje temporal).
  final Function(String message, bool isSuccess, double x, double y) showSnackBar;
  // Contexto de construcción de Flutter, necesario para operaciones como precacheImage y mostrar diálogos.
  final BuildContext context;
  final ValueNotifier<bool> showTutorialNotifier = ValueNotifier<bool>(true); // Notificador para visibilidad del tutorial

  // Generador de números aleatorios para barajar ilustraciones.
  final Random _random = Random();
  // Lista de datos de ilustraciones específicas para el nivel actual.
  List<Illustration> _illustrationsDataForLevel = [];
  // Lista de ilustraciones de referencia (objetivos) para el nivel actual.
  List<Illustration> _availableReferenceForLevel = [];

  // Temporizador para la cuenta regresiva del nivel.
  Timer? _levelTimer;
  // Duración total asignada para el nivel actual.
  Duration _levelDuration = Duration.zero;
  // Bandera para indicar si el nivel terminó por tiempo agotado.
  bool _timedOut = false;

  // Ancho actual de la pantalla del juego.
  double screenWidth = 0;
  // Alto actual de la pantalla del juego.
  double screenHeight = 0;

  // Relleno (padding) general usado en cálculos de layout.
  final double padding = 10.0;

  // Constructor de la clase GameController.
  GameController({
    required this.requestSetState,
    required this.showEndLevelDialog,
    required this.showSnackBar,
    required this.context,
  });

  // Inicializa o actualiza el juego con las dimensiones de la pantalla.
  void initializeGame(double width, double height) {
    // Verifica si las dimensiones de la pantalla han cambiado.
    bool dimensionsChanged = screenWidth != width || screenHeight != height;
    screenWidth = width;
    screenHeight = height;

    // Procede solo si las dimensiones son válidas.
    if (width > 0 && height > 0) {
      // Precarga las imágenes necesarias para el nivel actual.
      _precacheImages();
      // Si las dimensiones cambiaron o es la primera inicialización, carga los datos del nivel.
      if (dimensionsChanged || _illustrationsDataForLevel.isEmpty) {
        _initializeLevelData(); // Carga datos como ilustraciones, referencias y duración.
        _populateStaticIllustrations(); // Calcula posiciones y tamaños de las ilustraciones.

        // Inicia el temporizador si el juego no está pausado.
        if (!isPausedNotifier.value) {
          _startTimer();
        }
      } else {
        // Si las dimensiones no cambiaron pero hay datos, solo repopula las ilustraciones.
        _populateStaticIllustrations();
        // Reinicia el temporizador si no estaba activo y el juego no está pausado ni terminado.
        if (!isPausedNotifier.value && _levelTimer == null && !levelEndedNotifier.value) {
          _startTimer();
        }
      }
    } else {
      // Manejo de caso donde las dimensiones no son válidas (opcional).
    }
  }

  // Precarga las imágenes de las ilustraciones y referencias del nivel actual en la caché.
  void _precacheImages() {
    // Precarga imágenes de referencia.
    for (var illustration in data.availableReference.where((il) => il.nivel == GameConstants.NIVEL)) {
      precacheImage(AssetImage(illustration.path), context);
    }
    // Precarga imágenes de ilustraciones arrastrables.
    for (var illustration in data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL)) {
      precacheImage(AssetImage(illustration.path), context);
    }
  }

  // Carga y configura los datos específicos para el nivel actual.
  void _initializeLevelData() {
    // Obtiene todas las ilustraciones disponibles para el nivel actual.
    List<Illustration> allIllustrationsForLevel =
        data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL).toList();
    // Baraja las ilustraciones aleatoriamente.
    allIllustrationsForLevel.shuffle(_random);

    // Determina cuántas ilustraciones usar para este nivel según las constantes.
    int limit = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL] ?? allIllustrationsForLevel.length;
    // Selecciona el número limitado de ilustraciones.
    _illustrationsDataForLevel = allIllustrationsForLevel.take(limit).toList();

    // Obtiene las ilustraciones de referencia para el nivel actual.
    _availableReferenceForLevel = data.availableReference.where((il) => il.nivel == GameConstants.NIVEL).toList();

    // Obtiene la duración del nivel desde las constantes.
    _levelDuration = GameConstants.LEVEL_DURATION[GameConstants.NIVEL] ?? const Duration(seconds: 60);

    // Inicializa el tiempo restante y la bandera de tiempo agotado.
    remainingTimeNotifier.value = _levelDuration;
    _timedOut = false;
  }

  // Calcula las posiciones y tamaños de las ilustraciones estáticas (arrastrables) en la zona inferior.
  void _populateStaticIllustrations() {
    // No hace nada si las dimensiones no son válidas o no hay ilustraciones.
    if (screenWidth <= 0 || screenHeight <= 0 || _illustrationsDataForLevel.isEmpty) {
      availableIllustrationsNotifier.value = [];
      return;
    }

    // Parámetros para calcular el tamaño óptimo de las ilustraciones.
    double initialTargetSize = 60.0; // Tamaño inicial deseado.
    double minSize = 30.0; // Tamaño mínimo permitido.
    double sizeStep = 5.0; // Paso para reducir el tamaño si no caben.
    double currentSize = initialTargetSize;
    double finalIllustrationSize = minSize; // Tamaño final calculado.

    // Define la zona inferior donde se colocarán las ilustraciones.
    final double bottomZoneStartY = screenHeight / 2;
    final double availableWidth = screenWidth - padding * 2; // Ancho útil.
    final double availableHeight = (screenHeight / 2) - padding * 2; // Alto útil.

    // No hace nada si el área disponible no es válida.
    if (availableWidth <= 0 || availableHeight <= 0) {
      availableIllustrationsNotifier.value = [];
      return;
    }

    // Bucle para encontrar el tamaño más grande posible que permita mostrar todas las ilustraciones.
    while (currentSize >= minSize) {
      // Calcula cuántos ítems caben por fila con el tamaño actual.
      int itemsPerRow = (availableWidth + padding) ~/ (currentSize + padding);
      itemsPerRow = max(1, itemsPerRow); // Asegura al menos 1 por fila.
      int totalItems = _illustrationsDataForLevel.length;
      // Calcula cuántas filas se necesitarían.
      int rowsNeeded = (totalItems / itemsPerRow).ceil();
      // Calcula la altura total requerida.
      double requiredHeight = (rowsNeeded * currentSize) + (max(0, rowsNeeded - 1) * padding);

      // Si la altura requerida cabe en el espacio disponible, usa este tamaño.
      if (requiredHeight <= availableHeight) {
        finalIllustrationSize = currentSize;
        break;
      }
      // Si no cabe, reduce el tamaño e intenta de nuevo.
      currentSize -= sizeStep;
    }

    // Si ni el tamaño mínimo cabe, usa el mínimo.
    if (currentSize < minSize) {
      finalIllustrationSize = minSize;
    }

    // Crea la lista de objetos MovingIllustration con sus posiciones calculadas.
    List<MovingIllustration> staticIllustrations = [];
    // Recalcula ítems por fila con el tamaño final.
    int itemsPerRow = (availableWidth + padding) ~/ (finalIllustrationSize + padding);
    itemsPerRow = max(1, itemsPerRow); // Asegura al menos 1.
    double currentX = padding; // Posición X inicial.
    double currentY = bottomZoneStartY + padding; // Posición Y inicial.

    // Itera sobre los datos de las ilustraciones para crear los objetos visuales.
    for (int i = 0; i < _illustrationsDataForLevel.length; i++) {
      final illustrationData = _illustrationsDataForLevel[i];
      // Detiene si la siguiente ilustración se saldría de la pantalla verticalmente.
      if (currentY + finalIllustrationSize > screenHeight - padding) {
        break;
      }
      // Crea el objeto MovingIllustration con datos y posición.
      final illustrationObject = MovingIllustration(
        illustration: illustrationData,
        x: currentX,
        y: currentY,
        size: finalIllustrationSize,
      );
      staticIllustrations.add(illustrationObject);
      // Actualiza la posición X para la siguiente ilustración.
      currentX += finalIllustrationSize + padding;
      // Si se llegó al final de la fila, reinicia X y avanza Y.
      if (currentX + finalIllustrationSize > screenWidth - padding) {
        currentX = padding;
        currentY += finalIllustrationSize + padding;
      }
    }
    // Actualiza el notificador con la lista de ilustraciones posicionadas.
    availableIllustrationsNotifier.value = staticIllustrations;
  }

  // Pausa el juego.
  void pauseGame() {
    // Solo pausa si no está ya pausado y el nivel no ha terminado.
    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = true; // Actualiza el notificador de pausa.
      _cancelTimer(); // Detiene el temporizador del nivel.
    }
  }

  // Reanuda el juego.
  void resumeGame() {
    // Solo reanuda si está pausado y el nivel no ha terminado.
    if (isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = false; // Actualiza el notificador de pausa.
      _startTimer(); // Reinicia el temporizador del nivel.
    }
  }

  // Reinicia el nivel actual.
  void resetGame() {
    _cancelTimer(); // Cancela cualquier temporizador activo.
    // Resetea todos los estados del juego a sus valores iniciales.
    scoreNotifier.value = 0;
    availableIllustrationsNotifier.value = [];
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    _timedOut = false;

    // Si las dimensiones son válidas, reinicializa los datos y elementos del nivel.
    if (screenWidth > 0 && screenHeight > 0) {
      _initializeLevelData(); // Carga datos del nivel.
      _populateStaticIllustrations(); // Posiciona ilustraciones.
      _startTimer(); // Inicia el temporizador.
    } else {
      // Manejo si las dimensiones no son válidas (opcional).
    }
  }

  // Avanza al siguiente nivel.
  void nextLevel() {
    _cancelTimer(); // Cancela temporizador actual.
    // Incrementa el nivel si no se ha alcanzado el máximo.
    if (GameConstants.NIVEL < GameConstants.MAX_LEVEL) {
      GameConstants.NIVEL++;
    } else {
      // Si ya es el último nivel, no hace nada.
      return;
    }

    // Resetea los estados del juego para el nuevo nivel.
    scoreNotifier.value = 0;
    availableIllustrationsNotifier.value = [];
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    _timedOut = false;

    // Si las dimensiones son válidas, carga los datos y elementos del nuevo nivel.
    if (screenWidth > 0 && screenHeight > 0) {
      _precacheImages(); // Precarga imágenes del nuevo nivel.
      _initializeLevelData(); // Carga datos del nuevo nivel.
      _populateStaticIllustrations(); // Posiciona ilustraciones.
      _startTimer(); // Inicia temporizador.
    }
  }

  // Maneja el evento cuando una ilustración es soltada sobre una zona de referencia.
  void handleDrop(MovingIllustration illustration, double dropX, double dropY, int targetIndex) {
    // No procesa si el nivel ya terminó.
    if (levelEndedNotifier.value) {
      return;
    }

    // Verifica si el índice de la referencia es válido.
    if (_availableReferenceForLevel.isEmpty || targetIndex < 0 || targetIndex >= _availableReferenceForLevel.length) {
      showSnackBar('Error: Referencia no válida', false, dropX, dropY); // Muestra error.
      _removeIllustration(illustration); // Elimina la ilustración de la pantalla.
      _checkLevelEndConditions(); // Verifica si el nivel terminó.
      return;
    }

    // Obtiene la ilustración de referencia correspondiente al índice.
    final Illustration targetReference = _availableReferenceForLevel[targetIndex];
    // Compara la categoría de la ilustración soltada con la de la referencia.
    bool correctMatch = illustration.illustration.category == targetReference.category;

    // Actualiza puntuación y muestra mensaje según si el match fue correcto.
    if (correctMatch) {
      scoreNotifier.value++; // Incrementa puntuación.
      showSnackBar('¡Correcto!', true, dropX, dropY); // Muestra mensaje de éxito.
    } else {
      showSnackBar('¡Incorrecto!', false, dropX, dropY); // Muestra mensaje de error.
    }

    _removeIllustration(illustration); // Elimina la ilustración de la pantalla.
    _checkLevelEndConditions(); // Verifica si el nivel terminó.
  }

  // Elimina una ilustración de la lista de ilustraciones disponibles.
  void _removeIllustration(MovingIllustration illustrationToRemove) {
    // Crea una copia mutable de la lista actual.
    final currentList = List<MovingIllustration>.from(availableIllustrationsNotifier.value);
    // Intenta remover la ilustración.
    bool removed = currentList.remove(illustrationToRemove);
    // Si se removió exitosamente, actualiza el notificador y el contador de calificadas.
    if (removed) {
      availableIllustrationsNotifier.value = currentList;
      qualifiedIllustrationsCountNotifier.value++;
    }
  }

  // Verifica si se cumplen las condiciones para terminar el nivel.
  void _checkLevelEndConditions() {
    // Obtiene el número total de ilustraciones que había al inicio del nivel.
    final totalIllustrationsForLevel = _illustrationsDataForLevel.length;

    // Condición 1: Todas las ilustraciones iniciales han sido calificadas.
    if (totalIllustrationsForLevel > 0 &&
        qualifiedIllustrationsCountNotifier.value >= totalIllustrationsForLevel &&
        !levelEndedNotifier.value) {
      // Y el nivel no había terminado antes.
      _cancelTimer(); // Detiene el temporizador.
      levelEndedNotifier.value = true; // Marca el nivel como terminado.
      _endLevel(); // Ejecuta la lógica de fin de nivel.
    }
    // Condición 2: No había ilustraciones al inicio (caso borde).
    else if (totalIllustrationsForLevel == 0 && !levelEndedNotifier.value) {
      _cancelTimer();
      levelEndedNotifier.value = true;
      _endLevel();
    }
  }

  // Inicia o reinicia el temporizador de cuenta regresiva del nivel.
  void _startTimer() {
    _cancelTimer(); // Asegura que no haya otro temporizador activo.

    // No inicia el temporizador si la duración es cero, el juego está pausado o ya terminó.
    if (_levelDuration <= Duration.zero || isPausedNotifier.value || levelEndedNotifier.value) {
      return;
    }

    // Si el tiempo restante actual no es válido, lo resetea a la duración total del nivel.
    if (remainingTimeNotifier.value <= Duration.zero || remainingTimeNotifier.value > _levelDuration) {
      remainingTimeNotifier.value = _levelDuration;
    }

    // Crea un temporizador periódico que se ejecuta cada segundo.
    _levelTimer = Timer.periodic(const Duration(seconds: 1), _timerTick);
  }

  // Función que se ejecuta cada segundo por el temporizador del nivel.
  void _timerTick(Timer timer) {
    // Si el juego se pausa o termina mientras el timer está activo, lo cancela.
    if (isPausedNotifier.value || levelEndedNotifier.value) {
      _cancelTimer();
      return;
    }

    // Calcula el nuevo tiempo restante.
    final newTime = remainingTimeNotifier.value - const Duration(seconds: 1);

    // Si el tiempo llega a cero o menos.
    if (newTime <= Duration.zero) {
      remainingTimeNotifier.value = Duration.zero; // Asegura que no sea negativo.
      timer.cancel(); // Detiene este temporizador.
      _triggerTimeOutEnd(); // Ejecuta la lógica de fin de nivel por tiempo agotado.
    } else {
      // Si aún queda tiempo, actualiza el notificador.
      remainingTimeNotifier.value = newTime;
    }
  }

  // Cancela el temporizador del nivel si está activo.
  void _cancelTimer() {
    if (_levelTimer?.isActive ?? false) {
      _levelTimer!.cancel();
      _levelTimer = null; // Libera la referencia al timer.
    }
  }

  // Activa el fin de nivel debido a tiempo agotado.
  void _triggerTimeOutEnd() {
    // Solo actúa si el nivel no había terminado por otra razón.
    if (!levelEndedNotifier.value) {
      _timedOut = true; // Marca que terminó por tiempo.
      levelEndedNotifier.value = true; // Marca el nivel como terminado.
      pauseGame(); // Pausa el juego (aunque ya terminó, buena práctica).
      _endLevel(); // Ejecuta la lógica de fin de nivel.
    }
  }

  // Lógica que se ejecuta al finalizar un nivel (por tiempo o por completar ilustraciones).
  void _endLevel() {
    _cancelTimer(); // Asegura que el temporizador esté detenido.
    pauseGame(); // Pausa el juego.

    // Determina el puntaje necesario para ganar el nivel.
    final winningScore = GameConstants.WINNING_SCORE_THRESHOLD[GameConstants.NIVEL] ?? _illustrationsDataForLevel.length;
    // Obtiene el puntaje actual.
    final score = scoreNotifier.value;

    // Determina si el jugador ganó el nivel (puntaje suficiente Y no se agotó el tiempo).
    final bool levelWon = score >= winningScore && !_timedOut;

    // Prepara el título y mensaje para el diálogo de fin de nivel.
    String title;
    String message;

    if (_timedOut) {
      title = "¡Tiempo Agotado!";
      message = "Se acabó el tiempo. Tu puntuación: $score puntos.";
    } else if (levelWon) {
      title = "¡Excelente!";
      message = "Ganaste este nivel con $score puntos.";
    } else {
      title = "Nivel Terminado";
      message = "No alcanzaste la puntuación mínima ($winningScore).\nTu puntuación: $score puntos.";
    }

    // Llama a la función interna para mostrar el diálogo.
    _showEndLevelDialogInternal(title, message, levelWon);
  }

  // Muestra el diálogo de fin de nivel usando la función proporcionada en el constructor.
  void _showEndLevelDialogInternal(String title, String message, bool levelWon) {
    // Usa Future.delayed para asegurar que se ejecute después del frame actual (evita errores de build).
    Future.delayed(const Duration(milliseconds: 150), () {
      // Verifica si el widget asociado al context sigue montado.
      if (context.mounted) {
        showEndLevelDialog(title, message, levelWon); // Llama a la función externa.
      } else {
        // Manejo si el contexto ya no es válido (opcional).
      }
    });
  }

  // Getter para obtener la lista actual de referencias (inmutable).
  List<Illustration> get currentReferences => List.unmodifiable(_availableReferenceForLevel);

  // Libera los recursos utilizados por el controlador (notificadores, temporizador).
  void dispose() {
    _cancelTimer();
    scoreNotifier.dispose();
    isPausedNotifier.dispose();
    levelEndedNotifier.dispose();
    qualifiedIllustrationsCountNotifier.dispose();
    availableIllustrationsNotifier.dispose();
    remainingTimeNotifier.dispose();
    showTutorialNotifier.dispose(); // Liberar el notificador del tutorial
  }
}

// StatefulWidget que representa la pantalla principal del juego.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  GameScreenState createState() => GameScreenState();
}

// State class para GameScreen. Maneja la UI, interacciones y ciclo de vida.
class GameScreenState extends State<GameScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // Instancia del controlador de lógica del juego.
  late final GameController _gameController;
  // Timestamp de la última actualización del scroll del carrusel (para cálculo de delta).
  DateTime? _lastScrollUpdateTime;

  // Índice de la sección de referencia actualmente resaltada (cuando se arrastra sobre ella).
  int? _highlightedReferenceIndex;
  // Ancho de la pantalla almacenado en el estado.
  double _screenWidth = 0;
  // Alto de la pantalla almacenado en el estado.
  double _screenHeight = 0;
  // La ilustración que está siendo arrastrada actualmente.
  MovingIllustration? _draggedIllustration;
  // Posición original de la ilustración antes de empezar a arrastrarla.
  Offset? _originalPosition;

  // Controlador de animación para el movimiento automático del carrusel.
  late AnimationController _carouselAnimationController;
  // Controlador de scroll para el ListView horizontal del carrusel.
  late ScrollController _carouselScrollController;

  // Ancho total calculado de todas las referencias en el carrusel.
  double _totalReferenceWidth = 0;

  // Formateador para mostrar el tiempo restante en formato mm:ss.
  final DateFormat _timeFormatter = DateFormat('mm:ss');

  @override
  void initState() {
    super.initState();
    // Registra este State como observador del ciclo de vida de la app.
    WidgetsBinding.instance.addObserver(this);
    // Crea la instancia del GameController, pasándole callbacks y el contexto.
    _gameController = GameController(
      context: context,
      // Callback para solicitar setState desde el controller.
      requestSetState: () {
        if (mounted) setState(() {}); // Llama a setState solo si el widget está montado.
      },
      // Callback para mostrar el diálogo de fin de nivel.
      showEndLevelDialog: _showEndLevelDialog,
      // Callback para mostrar el SnackBar.
      showSnackBar: _showSnackBar,
    );

    // Inicializa el controlador de scroll del carrusel.
    _carouselScrollController = ScrollController();
    // Inicializa el controlador de animación del carrusel.
    _carouselAnimationController = AnimationController(duration: const Duration(seconds: 10), vsync: this)
      // Añade un listener que se llama en cada tick de la animación.
      ..addListener(_scrollListener);

    // Ejecuta código después de que el primer frame ha sido renderizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Obtiene las dimensiones e inicializa el juego.
      _initializeDimensionsAndGame();
      // Si hay referencias y el juego no está pausado, calcula ancho y empieza animación.
      if (_gameController.currentReferences.isNotEmpty && !_gameController.isPausedNotifier.value) {
        _calculateTotalReferenceWidth();
        if (!_carouselAnimationController.isAnimating) {
          _startCarouselAnimation();
        }
      }
    });
  }

  // Calcula la velocidad del carrusel en píxeles por segundo basada en RPM.
  double _calculateCarouselSpeedPixelsPerSecond(double rpm) {
    // Retorna 0 si no hay ancho total o las RPM son 0.
    if (_totalReferenceWidth <= 0 || rpm <= 0) {
      return 0.0;
    }
    // Calcula la velocidad: (revoluciones por segundo) * (ancho total por revolución).
    double speed = (rpm / 60.0) * _totalReferenceWidth;
    return speed;
  }

  // Listener llamado por el AnimationController del carrusel en cada tick.
  void _scrollListener() {
    // No hace nada si el scroll controller no está listo, no hay ancho, o la animación no corre.
    if (!_carouselScrollController.hasClients || _totalReferenceWidth <= 0 || !_carouselAnimationController.isAnimating) {
      _lastScrollUpdateTime = null; // Resetea el timestamp.
      return;
    }

    // Calcula el tiempo delta desde la última actualización.
    final DateTime now = DateTime.now();
    double deltaSeconds = 0;

    if (_lastScrollUpdateTime != null) {
      deltaSeconds = now.difference(_lastScrollUpdateTime!).inMilliseconds / 1000.0;
    }

    _lastScrollUpdateTime = now; // Actualiza el timestamp.

    // Maneja casos donde deltaSeconds es inválido o muy grande (ej. al volver a la app).
    const double maxDeltaThreshold = 0.1; // Umbral máximo de delta (100ms).
    const double fallbackDelta = 1.0 / 60.0; // Delta por defecto (asume 60 FPS).
    if (deltaSeconds <= 0 || deltaSeconds > maxDeltaThreshold) {
      deltaSeconds = fallbackDelta;
    }

    // Calcula la velocidad actual en píxeles por segundo.
    double speedPixelsPerSecond = _calculateCarouselSpeedPixelsPerSecond(
      GameConstants.CAROUSEL_RPM[GameConstants.NIVEL] ?? 0.0, // Obtiene RPM del nivel actual.
    );

    // Calcula cuánto debe moverse el scroll en este frame.
    double moveAmount = speedPixelsPerSecond * deltaSeconds;

    // No hace nada si el movimiento es cero.
    if (moveAmount == 0) return;

    // Calcula la nueva posición del scroll.
    double currentOffset = _carouselScrollController.offset;
    // Usa un rango muy grande para el módulo para simular scroll infinito.
    double largeRange = _totalReferenceWidth * 5000;
    double newOffset = (currentOffset + moveAmount) % largeRange;

    // Mueve el scroll a la nueva posición si el controlador está listo.
    if (_carouselScrollController.hasClients) {
      _carouselScrollController.jumpTo(newOffset); // jumpTo evita animación de scroll.
    }
  }

  // Inicia la animación de scroll automático del carrusel.
  void _startCarouselAnimation() {
    // Verifica condiciones: hay referencias, widget montado, juego no pausado/terminado.
    if (_gameController.currentReferences.isNotEmpty &&
        mounted &&
        !_gameController.isPausedNotifier.value &&
        !_gameController.levelEndedNotifier.value) {
      _calculateTotalReferenceWidth(); // Asegura que el ancho esté calculado.
      // Inicia la animación si hay ancho y no está ya animando.
      if (_totalReferenceWidth > 0 && !_carouselAnimationController.isAnimating) {
        _lastScrollUpdateTime = null; // Resetea timestamp.
        _carouselAnimationController.repeat(); // Inicia la animación en bucle.
      }
    }
  }

  // Detiene la animación de scroll automático del carrusel.
  void _stopCarouselAnimation() {
    if (_carouselAnimationController.isAnimating) {
      _carouselAnimationController.stop(); // Detiene la animación.
    }
    _lastScrollUpdateTime = null; // Resetea timestamp.
  }

  // Calcula el ancho total que ocuparían todas las referencias si se pusieran una al lado de la otra.
  void _calculateTotalReferenceWidth() {
    final references = _gameController.currentReferences;
    final numberOfReferences = references.length;
    // Calcula el ancho de cada sección y lo multiplica por el número de referencias.
    if (numberOfReferences > 0 && _screenWidth > 0) {
      final double sectionWidth = _screenWidth / numberOfReferences;
      _totalReferenceWidth = sectionWidth * numberOfReferences;
    } else {
      _totalReferenceWidth = 0; // Si no hay referencias o ancho de pantalla, el ancho total es 0.
    }
  }

  // Obtiene las dimensiones actuales de la pantalla e inicializa/actualiza el juego.
  void _initializeDimensionsAndGame() {
    if (!mounted) return; // No hace nada si el widget no está montado.
    final mediaQuery = MediaQuery.of(context); // Obtiene datos del MediaQuery.

    // Calcula el alto útil de la pantalla restando la barra de app y el padding superior.
    final double appBarHeight = AppBar().preferredSize.height;
    final double topPadding = mediaQuery.padding.top;
    final double currentScreenHeight = mediaQuery.size.height - topPadding - appBarHeight;
    final double currentScreenWidth = mediaQuery.size.width;

    // Verifica si las dimensiones han cambiado respecto a las almacenadas.
    bool dimensionsChanged = currentScreenWidth != _screenWidth || currentScreenHeight != _screenHeight;

    // Procede si las dimensiones actuales son válidas.
    if (currentScreenWidth > 0 && currentScreenHeight > 0) {
      // Si las dimensiones cambiaron o es la primera vez, actualiza todo.
      if (dimensionsChanged || _gameController.currentReferences.isEmpty) {
        _screenWidth = currentScreenWidth;
        _screenHeight = currentScreenHeight;
        // Llama al inicializador del GameController.
        _gameController.initializeGame(_screenWidth, _screenHeight);

        // Recalcula ancho del carrusel y reinicia la animación.
        _calculateTotalReferenceWidth();
        _stopCarouselAnimation();
        if (!_gameController.isPausedNotifier.value && !_gameController.levelEndedNotifier.value) {
          _startCarouselAnimation();
        }
        // Llama a setState si las dimensiones cambiaron para redibujar.
        if (mounted && dimensionsChanged) setState(() {});
      } else {
        // Si las dimensiones no cambiaron pero la animación no corre, la inicia.
        if (!_gameController.isPausedNotifier.value &&
            !_gameController.levelEndedNotifier.value &&
            _gameController.currentReferences.isNotEmpty &&
            !_carouselAnimationController.isAnimating) {
          _startCarouselAnimation();
        }
      }
    } else {
      // Si las dimensiones no son válidas, detiene la animación.
      _stopCarouselAnimation();
    }
  }

  @override
  void dispose() {
    // Se desregistra como observador del ciclo de vida.
    WidgetsBinding.instance.removeObserver(this);
    // Remueve el listener y libera los controladores de animación y scroll.
    _carouselAnimationController.removeListener(_scrollListener);
    _carouselAnimationController.dispose();
    _carouselScrollController.dispose();
    // Libera los recursos del GameController.
    _gameController.dispose();
    super.dispose();
  }

  @override
  // Método llamado cuando cambia el estado del ciclo de vida de la app.
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Si la app pasa a segundo plano o se cierra.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _gameController.pauseGame(); // Pausa el juego.
      _stopCarouselAnimation(); // Detiene la animación del carrusel.
    }
    // Si la app vuelve a primer plano.
    else if (state == AppLifecycleState.resumed) {
      // Si el nivel no había terminado.
      if (!_gameController.levelEndedNotifier.value) {
        // Si no estaba explícitamente pausado por el usuario.
        if (!_gameController.isPausedNotifier.value) {
          _gameController.resumeGame(); // Reanuda el juego.
          _startCarouselAnimation(); // Reinicia la animación del carrusel.
        }
      }
    }
  }

  // Se llama cuando el usuario empieza a arrastrar una ilustración.
  void _onPanStart(MovingIllustration illustration) {
    // No permite arrastrar si el juego está pausado o terminado.
    if (_gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value) {
      return;
    }

    // Actualiza el estado para reflejar que esta ilustración se está arrastrando.
    setState(() {
      _draggedIllustration = illustration; // Guarda la ilustración arrastrada.
      illustration.isBeingDragged = true; // Marca la ilustración como arrastrada.
      _originalPosition = Offset(illustration.x, illustration.y); // Guarda su posición inicial.

      // Mueve la ilustración arrastrada al final de la lista en el notificador
      // para que se dibuje encima de las demás.
      final currentList = List<MovingIllustration>.from(_gameController.availableIllustrationsNotifier.value);
      if (currentList.remove(illustration)) {
        // La quita de su posición actual.
        currentList.add(illustration); // La añade al final.
        _gameController.availableIllustrationsNotifier.value = currentList; // Actualiza el notificador.
      }
      // Ocultar tutorial al iniciar el primer arrastre
      if (_gameController.showTutorialNotifier.value) {
        _gameController.showTutorialNotifier.value = false;
      }
    });
  }

  // Se llama continuamente mientras el usuario arrastra la ilustración.
  void _onPanUpdate(DragUpdateDetails details, MovingIllustration illustration) {
    // Verifica que la ilustración que se actualiza es la que se está arrastrando
    // y que el juego no esté pausado/terminado.
    if (_draggedIllustration != illustration ||
        _gameController.isPausedNotifier.value ||
        _gameController.levelEndedNotifier.value) {
      return;
    }
    // Actualiza la posición de la ilustración según el movimiento del dedo.
    setState(() {
      illustration.x += details.delta.dx; // Actualiza X.
      illustration.y += details.delta.dy; // Actualiza Y.
      // Limita la posición para que no se salga de la pantalla.
      illustration.x = illustration.x.clamp(0.0, _screenWidth - illustration.size);
      illustration.y = illustration.y.clamp(0.0, _screenHeight - illustration.size);
      // Actualiza la sección de referencia resaltada según la posición actual del arrastre.
      _updateHighlightedSection(illustration.x + illustration.size / 2, illustration.y + illustration.size / 2);
    });
  }

  // Se llama cuando el usuario suelta la ilustración.
  void _onPanEnd(DragEndDetails details, MovingIllustration illustration) {
    // Verifica que la ilustración que se soltó es la que se estaba arrastrando.
    if (_draggedIllustration != illustration || _draggedIllustration == null) {
      return;
    }

    // Guarda referencias a la ilustración y estado actual antes de modificar el estado.
    final MovingIllustration endedIllustration = _draggedIllustration!;
    final bool wasPausedOrEnded = _gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value;
    final double dropX = endedIllustration.x + endedIllustration.size / 2; // Centro X al soltar.
    final double dropY = endedIllustration.y + endedIllustration.size / 2; // Centro Y al soltar.
    final Offset? originalPos = _originalPosition; // Posición original guardada.

    // Resetea el estado de arrastre en setState.
    setState(() {
      endedIllustration.isBeingDragged = false; // Desmarca la ilustración.
      _draggedIllustration = null; // Limpia la referencia a la ilustración arrastrada.
      _originalPosition = null; // Limpia la posición original.
      _resetHighlightedSection(); // Quita cualquier resaltado de la zona de referencia.
    });

    // Si el juego se pausó o terminó mientras se arrastraba, devuelve la ilustración a su lugar.
    if (wasPausedOrEnded) {
      if (originalPos != null) {
        _snapIllustrationBack(endedIllustration, originalPos);
      }
      return;
    }

    // Determina la altura de la zona superior (zona de drop).
    final double dropZoneHeight = _screenHeight / 2;
    // Verifica si la ilustración se soltó en la zona superior.
    final bool droppedInTop = dropY < dropZoneHeight;

    // Si se soltó en la zona superior.
    if (droppedInTop) {
      int targetIndex = -1; // Índice de la referencia sobre la que se soltó.
      final references = _gameController.currentReferences;
      final numberOfReferences = references.length;
      // Calcula el índice si hay referencias, ancho y el scroll controller está listo.
      if (numberOfReferences > 0 && _screenWidth > 0 && _carouselScrollController.hasClients) {
        // Ancho de cada sección de referencia.
        final double sectionWidth = _screenWidth / numberOfReferences;
        // Posición X relativa al inicio visible de la lista (no afectada por scroll).
        final double listRelativeX = dropX;

        // Calcula la posición X absoluta dentro del carrusel completo (considerando el scroll).
        final double scrolledX = listRelativeX + _carouselScrollController.offset;
        // Calcula el índice potencial dividiendo por el ancho de sección.
        final int potentialIndex = (scrolledX / sectionWidth).floor();

        // Usa el módulo para obtener el índice real dentro del rango de referencias disponibles.
        targetIndex = potentialIndex % numberOfReferences;
      }
      // Llama al método del controlador para manejar el drop.
      _gameController.handleDrop(endedIllustration, dropX, dropY, targetIndex);
    } else {
      // Si se soltó fuera de la zona superior, la devuelve a su posición original.
      if (originalPos != null) {
        _snapIllustrationBack(endedIllustration, originalPos);
      }
    }
  }

  // Devuelve una ilustración a su posición original (animación implícita por setState).
  void _snapIllustrationBack(MovingIllustration illustration, Offset originalPosition) {
    // Restaura las coordenadas X e Y.
    illustration.x = originalPosition.dx;
    illustration.y = originalPosition.dy;

    // Asegura que la ilustración esté en la lista del notificador (podría haberse quitado temporalmente).
    final currentList = List<MovingIllustration>.from(_gameController.availableIllustrationsNotifier.value);
    int index = currentList.indexWhere((item) => item == illustration);
    // Si no está en la lista (raro, pero por seguridad), no la añade de nuevo aquí.
    // Si está, actualiza el notificador para forzar redibujo en la posición correcta.
    if (index != -1) {
      // Crear una nueva lista fuerza la actualización del ValueListenableBuilder.
      _gameController.availableIllustrationsNotifier.value = List.from(currentList);
    }

    // Llama a setState si el widget sigue montado para asegurar el redibujo visual.
    if (mounted) {
      setState(() {});
    }
  }

  // Actualiza qué sección de referencia debe resaltarse según la posición del arrastre.
  void _updateHighlightedSection(double currentX, double currentY) {
    // Si el nivel terminó o las dimensiones no son válidas, quita cualquier resaltado.
    if (_gameController.levelEndedNotifier.value || _screenHeight <= 0 || _screenWidth <= 0) {
      if (_highlightedReferenceIndex != null) _resetHighlightedSection();
      return;
    }

    int? newHighlightIndex; // Índice a resaltar (puede ser null).

    // Solo calcula el resaltado si hay una ilustración siendo arrastrada.
    if (_draggedIllustration != null) {
      final double dropZoneHeight = _screenHeight / 2;
      // Verifica si la ilustración está sobre la zona superior.
      final bool isInTopZone = currentY < dropZoneHeight;

      if (isInTopZone) {
        final references = _gameController.currentReferences;
        final numberOfReferences = references.length;
        // Calcula el índice de la sección bajo la ilustración (similar a _onPanEnd).
        if (numberOfReferences > 0 && _carouselScrollController.hasClients) {
          final double sectionWidth = _screenWidth / numberOfReferences;
          final double listRelativeX = currentX;
          final double scrolledX = listRelativeX + _carouselScrollController.offset;
          final int potentialIndex = (scrolledX / sectionWidth).floor();
          final int sectionIndex = potentialIndex % numberOfReferences;
          newHighlightIndex = sectionIndex; // Asigna el índice calculado.
        }
      }
    }

    // Si el índice resaltado cambió, actualiza el estado.
    if (newHighlightIndex != _highlightedReferenceIndex) {
      if (mounted) {
        setState(() {
          _highlightedReferenceIndex = newHighlightIndex;
        });
      }
    }
  }

  // Quita el resaltado de cualquier sección de referencia.
  void _resetHighlightedSection() {
    // Solo actualiza el estado si había una sección resaltada.
    if (_highlightedReferenceIndex != null) {
      if (mounted) {
        setState(() {
          _highlightedReferenceIndex = null;
        });
      }
    }
  }

  // Muestra el diálogo de fin de nivel.
  void _showEndLevelDialog(String title, String message, bool levelWon) {
    // No muestra el diálogo si el widget no está montado o las dimensiones son inválidas.
    if (!mounted || _screenWidth <= 0) return;
    _stopCarouselAnimation(); // Detiene el carrusel al mostrar el diálogo.

    // Determina si es el último nivel.
    final maxLevel = GameConstants.MAX_LEVEL;
    final bool isLastLevel = (GameConstants.NIVEL >= maxLevel);

    // Calcula tamaños de fuente responsivos basados en el ancho de pantalla.
    final int newsize = 10; // Factor de ajuste para el tamaño.
    final double dialogTitleSize = max(16.0, _screenWidth / (20 + newsize));
    final double dialogMessageSize = max(13.0, _screenWidth / (25 + newsize));
    final double dialogButtonSize = max(13.0, _screenWidth / (25 + newsize));

    // Muestra el diálogo usando showDialog.
    showDialog(
      context: context,
      barrierDismissible: false, // Impide cerrar el diálogo tocando fuera.
      builder: (BuildContext dialogContext) {
        // Construye el contenido del AlertDialog.
        return AlertDialog(
          title: Text(title, style: TextStyle(fontSize: dialogTitleSize)),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Ajusta el tamaño al contenido.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: TextStyle(fontSize: dialogMessageSize)),
              // Muestra texto adicional según si se ganó, perdió o es el último nivel.
              if (levelWon && !isLastLevel) ...[
                const SizedBox(height: 15),
                Text("¿Continuar con el siguiente nivel?", style: TextStyle(fontSize: dialogMessageSize)),
              ] else if (levelWon && isLastLevel) ...[
                const SizedBox(height: 15),
                Text("¡Has completado todos los niveles!", style: TextStyle(fontSize: dialogMessageSize)),
              ] else if (!levelWon) ...[
                const SizedBox(height: 15),
                Text("¿Quieres intentarlo de nuevo?", style: TextStyle(fontSize: dialogMessageSize)),
              ],
            ],
          ),
          actions: <Widget>[
            // Botón para reintentar el nivel o reiniciar el juego.
            TextButton(
              child: Text(
                // Cambia el texto del botón según la situación.
                !levelWon ? "Reintentar Nivel" : (isLastLevel ? "Reiniciar Juego" : "Reintentar Nivel"),
                style: TextStyle(fontSize: dialogButtonSize),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo.
                _gameController.resetGame(); // Reinicia el juego/nivel.
                _startCarouselAnimation(); // Reinicia la animación del carrusel.
              },
            ),
            // Botón para pasar al siguiente nivel (solo si se ganó y no es el último).
            if (levelWon && !isLastLevel)
              TextButton(
                child: Text("Siguiente Nivel", style: TextStyle(fontSize: dialogButtonSize)),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Cierra el diálogo.
                  _gameController.nextLevel(); // Pasa al siguiente nivel.
                  _startCarouselAnimation(); // Reinicia la animación del carrusel.
                },
              ),
          ],
        );
      },
    );
  }

  // Muestra un SnackBar con un mensaje (usado para feedback de correcto/incorrecto).
  void _showSnackBar(String message, bool isSuccess, double x, double y) {
    // No muestra si el widget no está montado o las dimensiones son inválidas.
    if (!mounted || _screenHeight <= 0 || _screenWidth <= 0) return;

    // Estimaciones para calcular la posición del SnackBar.
    final snackBarHeightEstimate = 50.0;
    final snackBarWidthEstimate = 180.0;
    final screenPadding = 10.0; // Padding para evitar que toque los bordes.

    // Calcula el margen inferior para posicionar el SnackBar cerca de donde se soltó la ilustración.
    double bottomMargin = _screenHeight - y - (snackBarHeightEstimate / 2);
    // Limita el margen para que no se salga de la pantalla.
    bottomMargin = bottomMargin.clamp(screenPadding, _screenHeight - snackBarHeightEstimate - screenPadding);

    // Calcula los márgenes horizontales para centrar el SnackBar horizontalmente
    // cerca de la posición X donde se soltó.
    double horizontalMargin = (_screenWidth - snackBarWidthEstimate) / 2;
    double leftTarget = x - (snackBarWidthEstimate / 2);
    double rightTarget = _screenWidth - x - (snackBarWidthEstimate / 2);

    // Limita los márgenes izquierdo y derecho.
    double finalLeftMargin = leftTarget.clamp(screenPadding, _screenWidth - snackBarWidthEstimate - screenPadding);
    double finalRightMargin = rightTarget.clamp(screenPadding, _screenWidth - snackBarWidthEstimate - screenPadding);

    // Si los márgenes calculados no caben, lo centra horizontalmente.
    if (finalLeftMargin + finalRightMargin + snackBarWidthEstimate > _screenWidth) {
      finalLeftMargin = horizontalMargin;
      finalRightMargin = horizontalMargin;
    }

    // Calcula tamaño de fuente responsivo para el SnackBar.
    final double snackBarFontSize = max(12.0, _screenWidth / 60);

    // Elimina cualquier SnackBar anterior antes de mostrar el nuevo.
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    // Muestra el SnackBar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: snackBarFontSize)),
        duration: const Duration(milliseconds: 800), // Duración corta.
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600, // Color según éxito/error.
        behavior: SnackBarBehavior.floating, // Hace que flote sobre el contenido.
        // Aplica los márgenes calculados para posicionarlo.
        margin: EdgeInsets.only(bottom: bottomMargin, left: finalLeftMargin, right: finalRightMargin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), // Bordes redondeados.
        elevation: 6.0, // Sombra.
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Llama a la inicialización en cada build para manejar cambios de orientación/tamaño.
    _initializeDimensionsAndGame();

    // Calcula tamaños de fuente responsivos para la AppBar.
    final int newsize = 10; // Factor de ajuste.
    final double appBarTitleSize = max(10.0, _screenWidth / (22 + newsize));
    final double appBarScoreSize = max(9.0, _screenWidth / (25 + newsize));
    final double appBarActionSize = max(6.0, _screenWidth / (25 + newsize));

    // Construye la UI principal de la pantalla.
    return Scaffold(
      appBar: AppBar(
        // Título que muestra el nivel actual (usa ValueListenableBuilder para actualizar si cambia).
        title: ValueListenableBuilder<int>(
          valueListenable: _gameController.qualifiedIllustrationsCountNotifier, // Escucha cambios en el contador.
          builder: (context, _, __) {
            // El builder se reconstruye cuando el valor cambia.
            return Text("LSM Game - Nivel ${GameConstants.NIVEL}", style: TextStyle(fontSize: appBarTitleSize));
          },
        ),
        actions: [
          // Muestra el tiempo restante (usa ValueListenableBuilder).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Center(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _gameController.remainingTimeNotifier,
                builder: (context, remainingTime, _) {
                  // Formatea la duración a mm:ss.
                  String formattedTime = _timeFormatter.format(DateTime(0).add(remainingTime));
                  return Text(
                    "Tiempo: $formattedTime",
                    style: TextStyle(
                      fontSize: appBarActionSize,
                      // Cambia a color rojo si quedan 10 segundos o menos.
                      color: remainingTime.inSeconds <= 10 ? Colors.redAccent : Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          // Muestra la puntuación actual (usa ValueListenableBuilder).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.scoreNotifier,
                builder: (context, score, _) => Text("Puntos: $score", style: TextStyle(fontSize: appBarScoreSize)),
              ),
            ),
          ),
          // Botón de Pausa/Reanudar (usa ValueListenableBuilder anidados para estado de pausa y fin de nivel).
          ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  return IconButton(
                    // Cambia el icono según si está pausado.
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                    tooltip: isPaused ? "Reanudar" : "Pausar",
                    // Deshabilita el botón si el nivel ha terminado.
                    onPressed:
                        levelEnded
                            ? null
                            : () {
                              // Acción al presionar: pausa o reanuda el juego y la animación.
                              if (isPaused) {
                                _gameController.resumeGame();
                                _startCarouselAnimation();
                              } else {
                                _gameController.pauseGame();
                                _stopCarouselAnimation();
                              }
                            },
                  );
                },
              );
            },
          ),
        ],
      ),
      // Cuerpo principal de la pantalla.
      body: ValueListenableBuilder<List<MovingIllustration>>(
        // Escucha la lista de ilustraciones disponibles.
        valueListenable: _gameController.availableIllustrationsNotifier,
        builder: (context, availableIllustrations, _) {
          // Anida builders para escuchar también el estado de pausa y fin de nivel.
          return ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  // Muestra un indicador de carga si las dimensiones aún no son válidas.
                  if (_screenWidth <= 0 || _screenHeight <= 0) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Usa un Stack para superponer elementos: fondo, zonas, ilustraciones, overlay de pausa.
                  return ValueListenableBuilder<bool>(
                    valueListenable: _gameController.showTutorialNotifier,
                    builder: (context, showTutorial, _) {
                      return Stack(
                        children: [
                          // Construye el fondo y las zonas de drop (carrusel superior).
                          _buildDropZonesAndBackground(),
                          // Construye los widgets de las ilustraciones arrastrables.
                          ..._buildDraggableIllustrations(availableIllustrations),
                          // Muestra el overlay de pausa si el juego está pausado y no ha terminado.
                          if (isPaused && !levelEnded) _buildPauseOverlay(),

                          // Mostrar la capa del tutorial si showTutorial es true y el juego no está pausado/terminado
                          if (showTutorial && !isPaused && !levelEnded && _screenWidth > 0 && _screenHeight > 0)
                            TutorialOverlay(screenWidth: _screenWidth, screenHeight: _screenHeight),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Construye el widget que contiene el carrusel de referencias (zona superior) y el fondo de la zona inferior.
  Widget _buildDropZonesAndBackground() {
    // No construye nada si las dimensiones no son válidas.
    if (_screenWidth <= 0 || _screenHeight <= 0) return const SizedBox.shrink();

    // Calcula la altura de cada zona (superior e inferior).
    final double zoneHeight = _screenHeight / 2;
    final references = _gameController.currentReferences;
    final numberOfReferences = references.length;

    // Positioned.fill para que ocupe todo el espacio del body.
    return Positioned.fill(
      child: Column(
        // Organiza las dos zonas verticalmente.
        children: [
          // Zona superior (carrusel de referencias).
          SizedBox(
            height: zoneHeight,
            width: double.infinity, // Ocupa todo el ancho.
            // Usa un ListView.builder si hay referencias.
            child:
                numberOfReferences > 0
                    ? ListView.builder(
                      controller: _carouselScrollController, // Asigna el controlador de scroll.
                      scrollDirection: Axis.horizontal, // Scroll horizontal.
                      // itemCount muy grande para simular scroll infinito.
                      itemCount: 10000 * numberOfReferences,
                      itemBuilder: (context, index) {
                        // Calcula el índice real usando módulo.
                        final actualIndex = index % numberOfReferences;
                        final reference = references[actualIndex];
                        // Calcula el ancho de esta sección.
                        final double sectionWidth = _screenWidth / numberOfReferences;
                        // Construye el widget para esta sección de referencia.
                        return _buildReferenceSection(
                          reference: reference,
                          index: actualIndex,
                          height: zoneHeight,
                          width: sectionWidth,
                          // Indica si esta sección debe resaltarse.
                          isHighlighted: _highlightedReferenceIndex == actualIndex,
                        );
                      },
                    )
                    // Si no hay referencias (cargando), muestra un placeholder.
                    : Container(
                      height: zoneHeight,
                      width: double.infinity,
                      color: Colors.blueGrey.withAlpha((0.12 * 255).toInt()), // Color de fondo.
                      alignment: Alignment.center,
                      child: _buildPlaceholderReference(60.0 * 1.5, "Cargando..."), // Widget placeholder.
                    ),
          ),
          // Zona inferior (donde aparecen las ilustraciones arrastrables).
          Container(
            width: double.infinity,
            height: zoneHeight,
            decoration: BoxDecoration(
              // Color de fondo ligeramente diferente.
              color: Colors.blueGrey.withAlpha((0.05 * 255).toInt()),
              // Borde superior para separar visualmente las zonas.
              border: Border(top: BorderSide(color: Colors.grey.withAlpha((0.15 * 255).toInt()), width: 1)),
            ),
          ),
        ],
      ),
    );
  }

  // Construye una sección individual del carrusel de referencias.
  Widget _buildReferenceSection({
    required Illustration reference,
    required int index,
    required double height,
    required double width,
    required bool isHighlighted,
  }) {
    // Calcula el tamaño de la imagen de referencia dentro de la sección.
    final double referenceImageSize = min(width * 0.5, height * 0.4);

    // Usa ValueListenableBuilder para cambiar el color si el nivel termina mientras está resaltado.
    return ValueListenableBuilder<bool>(
      valueListenable: _gameController.levelEndedNotifier,
      builder: (context, levelEnded, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            // Cambia el color de fondo si está resaltado y el nivel no ha terminado.
            color:
                isHighlighted && !levelEnded
                    ? Colors.amber.withAlpha((0.3 * 255).toInt()) // Color resaltado.
                    : Colors.blueGrey.withAlpha((0.12 * 255).toInt()), // Color normal.
            // Borde derecho para separar secciones.
            border: Border(right: BorderSide(color: Colors.grey.withAlpha((0.2 * 255).toInt()), width: 1)),
          ),
          alignment: Alignment.center, // Centra la imagen de referencia.
          // Construye el widget de la imagen de referencia.
          child: _buildReferenceWidget(reference, referenceImageSize),
        );
      },
    );
  }

  // Construye el widget que muestra la imagen de una referencia.
  Widget _buildReferenceWidget(Illustration reference, double size) {
    return Padding(
      padding: const EdgeInsets.all(4.0), // Pequeño padding alrededor.
      child: Opacity(
        opacity: 0.9, // Ligera transparencia.
        child: Image.asset(
          reference.path, // Ruta de la imagen.
          width: size,
          height: size,
          fit: BoxFit.contain, // Ajusta la imagen manteniendo la proporción.
          // Widget que se muestra si hay un error al cargar la imagen.
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              color: Colors.pink.shade100, // Fondo rosa.
              child: Icon(Icons.error_outline, size: size * 0.6, color: Colors.pink.shade700), // Icono de error.
            );
          },
        ),
      ),
    );
  }

  // Construye un widget placeholder para mostrar cuando las referencias aún no cargan.
  Widget _buildPlaceholderReference(double size, String text) {
    // Tamaño de fuente responsivo para el texto del placeholder.
    final double placeholderFontSize = max(8.0, size / 6.6);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300.withAlpha((0.5 * 255).toInt()), // Fondo gris semitransparente.
        borderRadius: BorderRadius.circular(8), // Bordes redondeados.
        border: Border.all(color: Colors.grey.shade400.withAlpha((0.7 * 255).toInt())), // Borde gris.
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700, fontSize: placeholderFontSize),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Genera la lista de widgets Positioned para cada ilustración arrastrable.
  List<Widget> _buildDraggableIllustrations(List<MovingIllustration> illustrations) {
    // Mapea cada objeto MovingIllustration a un widget Positioned.
    return illustrations.map((illustration) {
      // Tamaño actual de la ilustración (puede cambiar si se redimensiona la pantalla).
      final double currentIllustrationSize = illustration.size;

      // Positioned permite colocar el widget en coordenadas X, Y específicas dentro del Stack.
      return Positioned(
        // Usa ValueKey para ayudar a Flutter a identificar este widget si la lista cambia.
        key: ValueKey(illustration.illustration.name),
        left: illustration.x, // Posición X.
        top: illustration.y, // Posición Y.
        width: currentIllustrationSize,
        height: currentIllustrationSize,
        // GestureDetector detecta los eventos de arrastre (pan).
        child: GestureDetector(
          onPanStart: (_) => _onPanStart(illustration), // Llama a _onPanStart al iniciar arrastre.
          onPanUpdate: (details) => _onPanUpdate(details, illustration), // Llama a _onPanUpdate durante arrastre.
          onPanEnd: (details) => _onPanEnd(details, illustration), // Llama a _onPanEnd al soltar.
          // El widget hijo es el que muestra visualmente la ilustración móvil.
          child: MovingIllustrationWidget(illustration: illustration),
        ),
      );
    }).toList(); // Convierte el iterable resultante en una lista de Widgets.
  }

  // Construye el overlay oscuro que se muestra cuando el juego está pausado.
  Widget _buildPauseOverlay() {
    // No construye nada si el ancho no es válido.
    if (_screenWidth <= 0) return const SizedBox.shrink();

    // Calcula tamaños responsivos para texto y botón del overlay.
    final double pauseTitleSize = max(22.0, _screenWidth / 25);
    final double pauseButtonTextSize = max(16.0, _screenWidth / 20);
    final double pauseButtonIconSize = max(24.0, _screenWidth / 18);

    // Container semitransparente que cubre toda la pantalla.
    return Container(
      color: Colors.black.withAlpha((0.75 * 255).toInt()), // Negro con 75% de opacidad.
      alignment: Alignment.center, // Centra el contenido.
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ajusta el tamaño al contenido.
        children: [
          // Texto "JUEGO PAUSADO".
          Text(
            "JUEGO PAUSADO",
            style: TextStyle(
              color: Colors.white, // Texto blanco.
              fontSize: pauseTitleSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5, // Espaciado entre letras.
              // Sombra para mejorar legibilidad.
              shadows: [Shadow(blurRadius: 10.0, color: Colors.black54, offset: Offset(2.0, 2.0))],
            ),
          ),
          const SizedBox(height: 40), // Espacio vertical.
          // Botón para continuar el juego.
          ElevatedButton.icon(
            icon: Icon(Icons.play_arrow, size: pauseButtonIconSize), // Icono de play.
            label: const Text("Continuar"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18), // Padding interno.
              textStyle: TextStyle(fontSize: pauseButtonTextSize, fontWeight: FontWeight.bold), // Estilo del texto.
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Botón redondeado.
            ),
            onPressed: () {
              // Al presionar, reanuda el juego y la animación del carrusel si es necesario.
              _gameController.resumeGame();
              if (!_gameController.levelEndedNotifier.value && _gameController.currentReferences.isNotEmpty) {
                _startCarouselAnimation();
              }
            },
          ),
        ],
      ),
    );
  }
}
