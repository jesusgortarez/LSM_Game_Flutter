// lib/screens/game_screen_2.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Los imports originales se mantienen, asumiendo que son correctos en tu proyecto.
import '../constants/game_constants.dart';
import '../models/illustration.dart';
import '../models/moving_illustration.dart';
import '../data/illustration_data.dart' as data;
import '../widgets/moving_illustration_widget_2.dart';

//****************************************************************************
// Clase Controller para la Lógica del Juego (Layout Rotado: Arriba/Abajo)
//****************************************************************************
class GameController {
  // --- Notificadores y Callbacks ---
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> levelEndedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> qualifiedIllustrationsCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<MovingIllustration>> availableIllustrationsNotifier =
      ValueNotifier<List<MovingIllustration>>([]);
  final ValueNotifier<Duration> remainingTimeNotifier = ValueNotifier(Duration.zero);
  final VoidCallback requestSetState;
  final Function(String title, String message, bool levelWon) showEndLevelDialog;
  final Function(String message, bool isSuccess, double x, double y) showSnackBar;
  final BuildContext context;

  // --- Estado Interno ---
  final Random _random = Random();
  List<Illustration> _illustrationsDataForLevel = [];
  List<Illustration> _availableReferenceForLevel = [];

  // --- Temporizador ---
  Timer? _levelTimer;
  Duration _levelDuration = Duration.zero; // Duración total para el nivel actual
  bool _timedOut = false; // Indica si el nivel terminó por tiempo

  // --- Dimensiones ---
  double screenWidth = 0;
  double screenHeight = 0;

  // --- Constantes Layout ---
  final double padding = 10.0;

  // --- Constructor ---
  GameController({
    required this.requestSetState,
    required this.showEndLevelDialog,
    required this.showSnackBar,
    required this.context,
  });

  // --- Inicialización ---
  void initializeGame(double width, double height) {
    bool dimensionsChanged = screenWidth != width || screenHeight != height;
    screenWidth = width;
    screenHeight = height;

    if (width > 0 && height > 0) {
      _precacheImages();
      if (dimensionsChanged || _illustrationsDataForLevel.isEmpty) {
        _initializeLevelData(); // Carga datos y configura duración
        _populateStaticIllustrations();
        // *** NUEVO: Inicia el timer si el juego no está pausado al inicio ***
        if (!isPausedNotifier.value) {
          _startTimer();
        }
      } else {
        _populateStaticIllustrations();
        if (!isPausedNotifier.value && _levelTimer == null && !levelEndedNotifier.value) {
          _startTimer();
        }
      }
    } else {
      // Initialization skipped: Invalid dimensions.
    }
  }

  void _precacheImages() {
    try {
      for (var illustration in data.availableReference.where((il) => il.nivel == GameConstants.NIVEL)) {
        try {
          precacheImage(AssetImage(illustration.path), context);
        } catch (e) {
          // Error precaching ref image ${illustration.path}: $e
        }
      }
      for (var illustration in data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL)) {
        try {
          precacheImage(AssetImage(illustration.path), context);
        } catch (e) {
          // Error precaching ill image ${illustration.path}: $e
        }
      }
    } catch (e) {
      // Error accessing illustration data during precache: $e
    }
  }

  void _initializeLevelData() {
    try {
      List<Illustration> allIllustrationsForLevel =
          data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL).toList();
      allIllustrationsForLevel.shuffle(_random);

      int limit = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL] ?? allIllustrationsForLevel.length;
      _illustrationsDataForLevel = allIllustrationsForLevel.take(limit).toList();

      _availableReferenceForLevel = data.availableReference.where((il) => il.nivel == GameConstants.NIVEL).toList();

      // *** LÍNEA MODIFICADA: Obtiene directamente la Duration del Map ***
      // Ya no se convierte de segundos, y se usa la nueva constante LEVEL_DURATION
      _levelDuration =
          GameConstants.LEVEL_DURATION[GameConstants.NIVEL] ?? const Duration(seconds: 60); // Default Duration(60s)

      remainingTimeNotifier.value = _levelDuration; // Inicializa el notificador
      _timedOut = false; // Resetea el flag de timeout

      if (_availableReferenceForLevel.isEmpty) {
        // Warning: No references found for level ${GameConstants.NIVEL}
      }
      // Level data initialized with ${_illustrationsDataForLevel.length} illustrations and duration $_levelDuration.
    } catch (e) {
      // Error accessing illustration data during level initialization: $e
      _illustrationsDataForLevel = [];
      _availableReferenceForLevel = [];
      _levelDuration = Duration.zero;
      remainingTimeNotifier.value = Duration.zero;
    }
  }

  void _populateStaticIllustrations() {
    if (screenWidth <= 0 || screenHeight <= 0 || _illustrationsDataForLevel.isEmpty) {
      availableIllustrationsNotifier.value = [];
      return;
    }

    double initialTargetSize = 60.0;
    double minSize = 30.0;
    double sizeStep = 5.0;
    double currentSize = initialTargetSize;
    double finalIllustrationSize = minSize;

    final double bottomZoneStartY = screenHeight / 2;
    final double availableWidth = screenWidth - padding * 2;
    final double availableHeight = (screenHeight / 2) - padding * 2;

    if (availableWidth <= 0 || availableHeight <= 0) {
      availableIllustrationsNotifier.value = [];
      return;
    }

    while (currentSize >= minSize) {
      int itemsPerRow = (availableWidth + padding) ~/ (currentSize + padding);
      itemsPerRow = max(1, itemsPerRow);
      int totalItems = _illustrationsDataForLevel.length;
      int rowsNeeded = (totalItems / itemsPerRow).ceil();
      double requiredHeight = (rowsNeeded * currentSize) + (max(0, rowsNeeded - 1) * padding);

      if (requiredHeight <= availableHeight) {
        finalIllustrationSize = currentSize;
        break;
      }
      currentSize -= sizeStep;
    }

    if (currentSize < minSize) {
      finalIllustrationSize = minSize;
    }

    List<MovingIllustration> staticIllustrations = [];
    int itemsPerRow = (availableWidth + padding) ~/ (finalIllustrationSize + padding);
    itemsPerRow = max(1, itemsPerRow);
    double currentX = padding;
    double currentY = bottomZoneStartY + padding;

    for (int i = 0; i < _illustrationsDataForLevel.length; i++) {
      final illustrationData = _illustrationsDataForLevel[i];
      if (currentY + finalIllustrationSize > screenHeight - padding) {
        break;
      }
      final illustrationObject = MovingIllustration(
        illustration: illustrationData,
        x: currentX,
        y: currentY,
        size: finalIllustrationSize,
      );
      staticIllustrations.add(illustrationObject);
      currentX += finalIllustrationSize + padding;
      if (currentX + finalIllustrationSize > screenWidth - padding) {
        currentX = padding;
        currentY += finalIllustrationSize + padding;
      }
    }
    availableIllustrationsNotifier.value = staticIllustrations;
  }

  // --- Control del Juego ---
  void pauseGame() {
    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = true;
      _cancelTimer();
    }
  }

  void resumeGame() {
    if (isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = false;
      _startTimer();
    }
  }

  void resetGame() {
    // Resetting game...
    _cancelTimer();
    scoreNotifier.value = 0;
    availableIllustrationsNotifier.value = [];
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    _timedOut = false; // Resetea flag

    if (screenWidth > 0 && screenHeight > 0) {
      _initializeLevelData(); // Recarga datos y duración
      _populateStaticIllustrations();
      _startTimer(); // *** NUEVO: Inicia timer para el nivel reseteado ***
    } else {
      // Warning: Cannot reset properly, screen dimensions unknown.
    }
    // Game reset complete.
  }

  void nextLevel() {
    _cancelTimer();
    if (GameConstants.NIVEL < GameConstants.MAX_LEVEL) {
      GameConstants.NIVEL++;
    } else {
      return;
    }

    scoreNotifier.value = 0;
    availableIllustrationsNotifier.value = [];
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    _timedOut = false; // Resetea flag

    if (screenWidth > 0 && screenHeight > 0) {
      _precacheImages();
      _initializeLevelData(); // Recarga datos y duración para el nuevo nivel
      _populateStaticIllustrations();
      _startTimer();
    }
  }

  // --- Manejo de Interacción (Drop en Zona SUPERIOR) ---
  void handleDrop(MovingIllustration illustration, double dropX, double dropY, int targetIndex) {
    if (levelEndedNotifier.value) {
      return;
    }

    if (_availableReferenceForLevel.isEmpty || targetIndex < 0 || targetIndex >= _availableReferenceForLevel.length) {
      showSnackBar('Error: Referencia no válida', false, dropX, dropY);
      _removeIllustration(illustration);
      _checkLevelEndConditions(); // Solo verifica si se acabaron las ilustraciones
      return;
    }

    final Illustration targetReference = _availableReferenceForLevel[targetIndex];
    bool correctMatch = illustration.illustration.category == targetReference.category;

    if (correctMatch) {
      scoreNotifier.value++;
      showSnackBar('¡Correcto!', true, dropX, dropY);
    } else {
      showSnackBar('¡Incorrecto!', false, dropX, dropY);
    }

    _removeIllustration(illustration);
    _checkLevelEndConditions(); // Solo verifica si se acabaron las ilustraciones
  }

  void _removeIllustration(MovingIllustration illustrationToRemove) {
    final currentList = List<MovingIllustration>.from(availableIllustrationsNotifier.value);
    bool removed = currentList.remove(illustrationToRemove);
    if (removed) {
      availableIllustrationsNotifier.value = currentList;
      qualifiedIllustrationsCountNotifier.value++;
    }
  }

  // --- Lógica de fin de nivel ---

  // *** MODIFICADO: Ahora solo verifica si se procesaron todas las ilustraciones ***
  // La condición de tiempo agotado se maneja en _timerTick
  void _checkLevelEndConditions() {
    final totalIllustrationsForLevel = _illustrationsDataForLevel.length;
    // Checking level end (illustrations): ${qualifiedIllustrationsCountNotifier.value} processed out of $totalIllustrationsForLevel total.

    // Si todas las ilustraciones se procesaron Y el nivel aún no ha terminado (por tiempo u otra razón)
    if (totalIllustrationsForLevel > 0 &&
        qualifiedIllustrationsCountNotifier.value >= totalIllustrationsForLevel &&
        !levelEndedNotifier.value) {
      // Level end condition met (all illustrations processed)!
      _cancelTimer(); // Detiene el timer si se gana por completar
      levelEndedNotifier.value = true;
      _endLevel(); // Muestra el diálogo (probablemente ganado)
    } else if (totalIllustrationsForLevel == 0 && !levelEndedNotifier.value) {
      // Warning: Checking level end conditions but no illustrations were loaded.
      _cancelTimer();
      levelEndedNotifier.value = true;
      _endLevel(); // Termina el nivel si no había ilustraciones
    }
  }

  // *** NUEVO: Inicia o reanuda el temporizador del nivel ***
  void _startTimer() {
    // Cancela cualquier timer existente
    _cancelTimer();

    // No iniciar si la duración es cero, el juego está pausado o terminado
    if (_levelDuration <= Duration.zero || isPausedNotifier.value || levelEndedNotifier.value) {
      return;
    }

    // Asegura que el tiempo restante sea la duración total al iniciar
    // (o el tiempo que quedaba si se reanuda - aunque pauseGame/resumeGame lo manejan)
    if (remainingTimeNotifier.value <= Duration.zero || remainingTimeNotifier.value > _levelDuration) {
      remainingTimeNotifier.value = _levelDuration;
    }

    // Starting timer with duration: ${remainingTimeNotifier.value}
    _levelTimer = Timer.periodic(const Duration(seconds: 1), _timerTick);
  }

  // *** NUEVO: Callback que se ejecuta cada segundo por el timer ***
  void _timerTick(Timer timer) {
    if (isPausedNotifier.value || levelEndedNotifier.value) {
      // No hacer nada si está pausado o ya terminó
      _cancelTimer(); // Asegura cancelación por si acaso
      return;
    }

    final newTime = remainingTimeNotifier.value - const Duration(seconds: 1);
    // Timer tick. Remaining: $newTime

    if (newTime <= Duration.zero) {
      remainingTimeNotifier.value = Duration.zero;
      timer.cancel(); // Detiene este timer
      _triggerTimeOutEnd(); // Llama a la función de fin por tiempo
    } else {
      remainingTimeNotifier.value = newTime; // Actualiza el notificador
    }
  }

  // *** NUEVO: Cancela el temporizador si está activo ***
  void _cancelTimer() {
    if (_levelTimer?.isActive ?? false) {
      // Cancelling active timer.
      _levelTimer!.cancel();
      _levelTimer = null;
    }
  }

  // *** NUEVO: Función específica para terminar el nivel por tiempo agotado ***
  void _triggerTimeOutEnd() {
    if (!levelEndedNotifier.value) {
      // Evita doble ejecución
      // Time's up! Triggering level end.
      _timedOut = true; // Marca que terminó por tiempo
      levelEndedNotifier.value = true; // Marca el nivel como terminado
      pauseGame(); // Pausa el juego lógicamente (aunque el timer ya paró)
      _endLevel(); // Muestra el diálogo (será de derrota)
    }
  }

  // MODIFICADO: Maneja la condición de timeout
  void _endLevel() {
    _cancelTimer(); // Asegura que el timer esté cancelado
    pauseGame(); // Pausa el juego

    final winningScore =
        GameConstants.WINNING_SCORE_THRESHOLD[GameConstants.NIVEL] ?? _illustrationsDataForLevel.length;
    final score = scoreNotifier.value;
    // Determina si ganó: debe alcanzar el score Y NO haber perdido por tiempo
    final bool levelWon = score >= winningScore && !_timedOut;

    // Level ended. Score: $score, Required: $winningScore, Timed Out: $_timedOut, Won: $levelWon

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

    _showEndLevelDialogInternal(title, message, levelWon);
  }

  void _showEndLevelDialogInternal(String title, String message, bool levelWon) {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (context.mounted) {
        showEndLevelDialog(title, message, levelWon);
      } else {
        // Dialog not shown: Context is no longer mounted.
      }
    });
  }

  // --- Getters ---
  List<Illustration> get currentReferences => List.unmodifiable(_availableReferenceForLevel);

  // --- Limpieza ---
  void dispose() {
    // Disposing GameController
    _cancelTimer(); // *** NUEVO: Asegura cancelar timer al hacer dispose ***
    scoreNotifier.dispose();
    isPausedNotifier.dispose();
    levelEndedNotifier.dispose();
    qualifiedIllustrationsCountNotifier.dispose();
    availableIllustrationsNotifier.dispose();
    remainingTimeNotifier.dispose(); // *** NUEVO: Dispose del nuevo notifier ***
  }
}

//****************************************************************************
// Widget GameScreen (UI)
//****************************************************************************
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final GameController _gameController;
  DateTime? _lastScrollUpdateTime;

  // --- Estado UI ---
  int? _highlightedReferenceIndex;
  double _screenWidth = 0;
  double _screenHeight = 0;
  MovingIllustration? _draggedIllustration;
  Offset? _originalPosition;

  // --- Estado Animación Carrusel ---
  late AnimationController _carouselAnimationController;
  late ScrollController _carouselScrollController;
  // final double _carouselScrollSpeed = 30.0; // <-- ELIMINADO
  double _totalReferenceWidth = 0;

  // *** NUEVO: Formateador para el tiempo ***
  final DateFormat _timeFormatter = DateFormat('mm:ss');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameController = GameController(
      context: context,
      requestSetState: () {
        if (mounted) setState(() {});
      },
      showEndLevelDialog: _showEndLevelDialog,
      showSnackBar: _showSnackBar,
    );

    _carouselScrollController = ScrollController();
    _carouselAnimationController = AnimationController(
      // Usamos una duración más larga para reducir la frecuencia del listener si es posible
      duration: const Duration(seconds: 10),
      vsync: this,
    )..addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDimensionsAndGame();
      if (_gameController.currentReferences.isNotEmpty && !_gameController.isPausedNotifier.value) {
        _calculateTotalReferenceWidth();
        if (!_carouselAnimationController.isAnimating) {
          _startCarouselAnimation();
        }
      }
    });
  }

  // *** NUEVA FUNCIÓN: Calcula la velocidad en píxeles por segundo basada en RPM ***
  double _calculateCarouselSpeedPixelsPerSecond(double rpm) {
    if (_totalReferenceWidth <= 0 || rpm <= 0) {
      return 0.0;
    }
    // Velocidad (px/s) = (rpm / 60 segundos/minuto) * (_totalReferenceWidth píxeles/revolución)
    double speed = (rpm / 60.0) * _totalReferenceWidth;
    return speed;
  }

  void _scrollListener() {
    // Verifica si es seguro continuar
    if (!_carouselScrollController.hasClients ||
        _totalReferenceWidth <= 0 ||
        !_carouselAnimationController.isAnimating) {
      _lastScrollUpdateTime = null; // Resetea si no está animando
      return;
    }

    final DateTime now = DateTime.now();
    double deltaSeconds = 0;

    // Calcula el tiempo transcurrido desde la última vez
    if (_lastScrollUpdateTime != null) {
      deltaSeconds = now.difference(_lastScrollUpdateTime!).inMilliseconds / 1000.0;
    }

    // Actualiza la marca de tiempo para la próxima llamada
    _lastScrollUpdateTime = now;

    // --- Medida de seguridad ---
    // Evita saltos enormes si hubo una pausa larga o lag (ej. > 100ms)
    // En esos casos, usa un valor típico (ej., asumiendo 60 FPS)
    // Ajusta este umbral si es necesario.
    const double maxDeltaThreshold = 0.1; // 100 ms
    const double fallbackDelta = 1.0 / 60.0; // Asume 60 FPS
    if (deltaSeconds <= 0 || deltaSeconds > maxDeltaThreshold) {
      // Si es la primera vez, o si el tiempo es muy grande/inválido, usa el fallback
      deltaSeconds = fallbackDelta;
    }
    // --- Fin Medida de seguridad ---

    // Obtiene la velocidad teórica en px/s
    double speedPixelsPerSecond = _calculateCarouselSpeedPixelsPerSecond(
      GameConstants.CAROUSEL_RPM[GameConstants.NIVEL] ?? 0.0,
    );

    // Calcula cuánto mover basado en el tiempo REAL transcurrido
    double moveAmount = speedPixelsPerSecond * deltaSeconds;

    if (moveAmount == 0) return;

    double currentOffset = _carouselScrollController.offset;
    double largeRange = _totalReferenceWidth * 5000; // Para el bucle
    double newOffset = (currentOffset + moveAmount) % largeRange;

    // Mueve el scroll
    if (_carouselScrollController.hasClients) {
      _carouselScrollController.jumpTo(newOffset);
    }
  }

  void _startCarouselAnimation() {
    if (_gameController.currentReferences.isNotEmpty &&
        mounted &&
        !_gameController.isPausedNotifier.value &&
        !_gameController.levelEndedNotifier.value) {
      _calculateTotalReferenceWidth();
      if (_totalReferenceWidth > 0 && !_carouselAnimationController.isAnimating) {
        _lastScrollUpdateTime = null; // ¡Importante! Resetea antes de empezar
        _carouselAnimationController.repeat();
      }
    }
  }

  void _stopCarouselAnimation() {
    if (_carouselAnimationController.isAnimating) {
      _carouselAnimationController.stop();
    }
    _lastScrollUpdateTime = null; // Resetea al parar
  }

  void _calculateTotalReferenceWidth() {
    final references = _gameController.currentReferences;
    final numberOfReferences = references.length;
    if (numberOfReferences > 0 && _screenWidth > 0) {
      // Asume que cada referencia ocupa una fracción igual del ancho
      final double sectionWidth = _screenWidth / numberOfReferences;
      _totalReferenceWidth = sectionWidth * numberOfReferences; // Igual a _screenWidth
    } else {
      _totalReferenceWidth = 0;
    }
  }

  void _initializeDimensionsAndGame() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.of(context);
    // Asegurarse de que kToolbarHeight sea accesible o usar un valor por defecto
    final double appBarHeight = AppBar().preferredSize.height;
    final double topPadding = mediaQuery.padding.top;
    final double currentScreenHeight = mediaQuery.size.height - topPadding - appBarHeight;
    final double currentScreenWidth = mediaQuery.size.width;

    bool dimensionsChanged = currentScreenWidth != _screenWidth || currentScreenHeight != _screenHeight;

    if (currentScreenWidth > 0 && currentScreenHeight > 0) {
      if (dimensionsChanged || _gameController.currentReferences.isEmpty) {
        _screenWidth = currentScreenWidth;
        _screenHeight = currentScreenHeight;
        _gameController.initializeGame(_screenWidth, _screenHeight);

        _calculateTotalReferenceWidth();
        _stopCarouselAnimation();
        if (!_gameController.isPausedNotifier.value && !_gameController.levelEndedNotifier.value) {
          _startCarouselAnimation();
        }
        if (mounted && dimensionsChanged) setState(() {}); // Solo setState si las dimensiones cambiaron
      } else {
        // Asegurar que la animación corra si no lo hacía y debería
        if (!_gameController.isPausedNotifier.value &&
            !_gameController.levelEndedNotifier.value &&
            _gameController.currentReferences.isNotEmpty &&
            !_carouselAnimationController.isAnimating) {
          _startCarouselAnimation();
        }
      }
    } else {
      _stopCarouselAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carouselAnimationController.removeListener(_scrollListener);
    _carouselAnimationController.dispose();
    _carouselScrollController.dispose();
    _gameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _gameController.pauseGame(); // Pausa el juego y el timer interno
      _stopCarouselAnimation(); // Detiene animación visual
    } else if (state == AppLifecycleState.resumed) {
      // Solo reanuda si NO ha terminado el nivel
      if (!_gameController.levelEndedNotifier.value) {
        // No llamamos a resumeGame directamente si el usuario lo pausó manualmente
        // El botón de play lo hará. Pero sí reanudamos la animación si no estaba pausado.
        if (!_gameController.isPausedNotifier.value) {
          _gameController.resumeGame(); // Esto reiniciará el timer interno si es necesario
          _startCarouselAnimation();
        }
      }
    }
  }

  // --- Manejo de Interacción (Drag & Drop) ---

  void _onPanStart(MovingIllustration illustration) {
    if (_gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value) {
      return;
    }
    // Ya no detenemos la animación del carrusel aquí
    setState(() {
      _draggedIllustration = illustration;
      illustration.isBeingDragged = true;
      _originalPosition = Offset(illustration.x, illustration.y);

      // Mueve la ilustración arrastrada al final de la lista para dibujarla encima
      final currentList = List<MovingIllustration>.from(_gameController.availableIllustrationsNotifier.value);
      if (currentList.remove(illustration)) {
        currentList.add(illustration);
        _gameController.availableIllustrationsNotifier.value = currentList;
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details, MovingIllustration illustration) {
    if (_draggedIllustration != illustration ||
        _gameController.isPausedNotifier.value ||
        _gameController.levelEndedNotifier.value) {
      return;
    }
    setState(() {
      illustration.x += details.delta.dx;
      illustration.y += details.delta.dy;
      illustration.x = illustration.x.clamp(0.0, _screenWidth - illustration.size);
      illustration.y = illustration.y.clamp(0.0, _screenHeight - illustration.size);
      _updateHighlightedSection(illustration.x + illustration.size / 2, illustration.y + illustration.size / 2);
    });
  }

  void _onPanEnd(DragEndDetails details, MovingIllustration illustration) {
    if (_draggedIllustration != illustration || _draggedIllustration == null) {
      return;
    }

    final MovingIllustration endedIllustration = _draggedIllustration!;
    final bool wasPausedOrEnded = _gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value;
    final double dropX = endedIllustration.x + endedIllustration.size / 2;
    final double dropY = endedIllustration.y + endedIllustration.size / 2;
    final Offset? originalPos = _originalPosition;

    setState(() {
      endedIllustration.isBeingDragged = false;
      _draggedIllustration = null;
      _originalPosition = null;
      _resetHighlightedSection();
    });

    // La animación del carrusel no se detuvo, así que no necesita reiniciarse aquí

    if (wasPausedOrEnded) {
      if (originalPos != null) {
        _snapIllustrationBack(endedIllustration, originalPos);
      }
      return;
    }

    final double dropZoneHeight = _screenHeight / 2;
    final bool droppedInTop = dropY < dropZoneHeight;

    if (droppedInTop) {
      int targetIndex = -1;
      final references = _gameController.currentReferences;
      final numberOfReferences = references.length;
      if (numberOfReferences > 0 && _screenWidth > 0 && _carouselScrollController.hasClients) {
        final double sectionWidth = _screenWidth / numberOfReferences;
        final double listRelativeX = dropX;
        // Ajusta la posición X considerando el scroll actual del carrusel
        final double scrolledX = listRelativeX + _carouselScrollController.offset;
        final int potentialIndex = (scrolledX / sectionWidth).floor();
        // Usa módulo para obtener el índice real debido al bucle simulado
        targetIndex = potentialIndex % numberOfReferences;
      }
      _gameController.handleDrop(endedIllustration, dropX, dropY, targetIndex);
    } else {
      // Si se soltó abajo, regresa a la posición original
      if (originalPos != null) {
        _snapIllustrationBack(endedIllustration, originalPos);
      }
    }
  }

  void _snapIllustrationBack(MovingIllustration illustration, Offset originalPosition) {
    // Restaura la posición
    illustration.x = originalPosition.dx;
    illustration.y = originalPosition.dy;

    // Notifica al ValueNotifier para que la UI se actualice si depende de la lista
    final currentList = List<MovingIllustration>.from(_gameController.availableIllustrationsNotifier.value);
    int index = currentList.indexWhere((item) => item == illustration);
    if (index != -1) {
      // Reinserta en su posición original si es necesario o simplemente actualiza el notifier
      // En este caso, solo actualizar el notifier debería ser suficiente si el widget Positioned
      // reacciona a los cambios de x, y. Forzamos la actualización de la lista.
      _gameController.availableIllustrationsNotifier.value = List.from(currentList);
    }
    // Forzar redraw si el widget está montado, ya que el cambio de propiedad interna (x,y)
    // podría no dispararlo automáticamente si no se redibuja el Stack completo.
    if (mounted) {
      setState(() {});
    }
  }

  void _updateHighlightedSection(double currentX, double currentY) {
    if (_gameController.levelEndedNotifier.value || _screenHeight <= 0 || _screenWidth <= 0) {
      if (_highlightedReferenceIndex != null) _resetHighlightedSection();
      return;
    }

    int? newHighlightIndex;

    if (_draggedIllustration != null) {
      final double dropZoneHeight = _screenHeight / 2;
      final bool isInTopZone = currentY < dropZoneHeight;

      if (isInTopZone) {
        final references = _gameController.currentReferences;
        final numberOfReferences = references.length;

        if (numberOfReferences > 0 && _carouselScrollController.hasClients) {
          final double sectionWidth = _screenWidth / numberOfReferences;
          final double listRelativeX = currentX;
          final double scrolledX = listRelativeX + _carouselScrollController.offset;
          final int potentialIndex = (scrolledX / sectionWidth).floor();
          final int sectionIndex = potentialIndex % numberOfReferences;
          newHighlightIndex = sectionIndex;
        }
      }
    }

    if (newHighlightIndex != _highlightedReferenceIndex) {
      if (mounted) {
        setState(() {
          _highlightedReferenceIndex = newHighlightIndex;
        });
      }
    }
  }

  void _resetHighlightedSection() {
    if (_highlightedReferenceIndex != null) {
      if (mounted) {
        setState(() {
          _highlightedReferenceIndex = null;
        });
      }
    }
  }

  // --- Callbacks desde el Controller ---

  void _showEndLevelDialog(String title, String message, bool levelWon) {
    if (!mounted || _screenWidth <= 0) return; // Añadido check _screenWidth > 0
    _stopCarouselAnimation(); // Detiene carrusel al mostrar diálogo

    final maxLevel = GameConstants.MAX_LEVEL;
    final bool isLastLevel = (GameConstants.NIVEL >= maxLevel);

    final int newsize = 10;
    // --- Tamaños de fuente responsivos para el diálogo ---
    final double dialogTitleSize = max(16.0, _screenWidth / (20 + newsize));
    final double dialogMessageSize = max(13.0, _screenWidth / (25 + newsize));
    final double dialogButtonSize = max(13.0, _screenWidth / (25 + newsize));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title, style: TextStyle(fontSize: dialogTitleSize)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: TextStyle(fontSize: dialogMessageSize)),
              if (levelWon && !isLastLevel) ...[
                const SizedBox(height: 15),
                Text("¿Continuar con el siguiente nivel?", style: TextStyle(fontSize: dialogMessageSize)),
              ] else if (levelWon && isLastLevel) ...[
                const SizedBox(height: 15),
                Text("¡Has completado todos los niveles!", style: TextStyle(fontSize: dialogMessageSize)),
              ] else if (!levelWon) ...[
                // Incluye derrota por tiempo aquí
                const SizedBox(height: 15),
                Text("¿Quieres intentarlo de nuevo?", style: TextStyle(fontSize: dialogMessageSize)),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                !levelWon ? "Reintentar Nivel" : (isLastLevel ? "Reiniciar Juego" : "Reintentar Nivel"),
                style: TextStyle(fontSize: dialogButtonSize),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _gameController.resetGame(); // Reinicia el juego/nivel
                _startCarouselAnimation(); // Reinicia la animación del carrusel
                // La animación y el timer se reiniciarán en _initializeDimensionsAndGame/_startTimer
              },
            ),
            if (levelWon && !isLastLevel)
              TextButton(
                child: Text("Siguiente Nivel", style: TextStyle(fontSize: dialogButtonSize)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _gameController.nextLevel(); // Pasa al siguiente nivel
                  _startCarouselAnimation(); // Reinicia la animación del carrusel
                  // La animación y el timer se reiniciarán
                },
              ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, bool isSuccess, double x, double y) {
    if (!mounted || _screenHeight <= 0 || _screenWidth <= 0) return;

    final snackBarHeightEstimate = 50.0;
    final snackBarWidthEstimate = 180.0;
    final screenPadding = 10.0;

    double bottomMargin = _screenHeight - y - (snackBarHeightEstimate / 2);
    bottomMargin = bottomMargin.clamp(screenPadding, _screenHeight - snackBarHeightEstimate - screenPadding);

    double horizontalMargin = (_screenWidth - snackBarWidthEstimate) / 2;
    double leftTarget = x - (snackBarWidthEstimate / 2);
    double rightTarget = _screenWidth - x - (snackBarWidthEstimate / 2);

    double finalLeftMargin = leftTarget.clamp(screenPadding, _screenWidth - snackBarWidthEstimate - screenPadding);
    double finalRightMargin = rightTarget.clamp(screenPadding, _screenWidth - snackBarWidthEstimate - screenPadding);

    // Centra si los márgenes calculados no caben
    if (finalLeftMargin + finalRightMargin + snackBarWidthEstimate > _screenWidth) {
      finalLeftMargin = horizontalMargin;
      finalRightMargin = horizontalMargin;
    }

    // --- Tamaño de fuente responsivo para SnackBar ---
    final double snackBarFontSize = max(12.0, _screenWidth / 60);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: snackBarFontSize)),
        duration: const Duration(milliseconds: 800),
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: bottomMargin, left: finalLeftMargin, right: finalRightMargin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        elevation: 6.0,
      ),
    );
  }

  // --- Construcción de la UI ---
  @override
  Widget build(BuildContext context) {
    _initializeDimensionsAndGame(); // Revisa dimensiones en cada build

    final int newsize = 10;
    // --- Tamaños de fuente responsivos para AppBar ---
    final double appBarTitleSize = max(10.0, _screenWidth / (22 + newsize));
    final double appBarScoreSize = max(9.0, _screenWidth / (25 + newsize));
    // final double appBarCounterSize = max(6.0, _screenWidth / (18 + newsize));
    final double appBarActionSize = max(6.0, _screenWidth / (25 + newsize));

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: _gameController.qualifiedIllustrationsCountNotifier, // Escucha cambios para actualizar nivel
          builder: (context, _, __) {
            return Text("LSM Game - Nivel ${GameConstants.NIVEL}", style: TextStyle(fontSize: appBarTitleSize));
          },
        ),
        actions: [
          // *** NUEVO: Muestra el Tiempo Restante ***
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Center(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _gameController.remainingTimeNotifier,
                builder: (context, remainingTime, _) {
                  // Formatea MM:SS
                  String formattedTime = _timeFormatter.format(
                    DateTime(0).add(remainingTime), // Crea un DateTime base para formatear
                  );
                  return Text(
                    "Tiempo: $formattedTime",
                    style: TextStyle(
                      fontSize: appBarActionSize,
                      // Cambia color si queda poco tiempo (ej. menos de 10s)
                      color: remainingTime.inSeconds <= 10 ? Colors.redAccent : Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
          // Muestra la Puntuación Actual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.scoreNotifier,
                builder: (context, score, _) => Text("Puntos: $score", style: TextStyle(fontSize: appBarScoreSize)),
              ),
            ),
          ),
          // Muestra el Contador de Progreso
          /* 
         Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.qualifiedIllustrationsCountNotifier,
                builder: (context, count, _) {
                  final total = _gameController._illustrationsDataForLevel.length;
                  // Evita mostrar 0/0 si aún no se cargan los datos
                  final totalText = total > 0 ? total : '-';
                  return Text(
                    "$count/$totalText",
                    style: TextStyle(
                      fontSize: appBarCounterSize,
                      color: Colors.white.withAlpha((0.7 * 255).toInt()), // Opacidad 0.7
                    ),
                  );
                },
              ),
            ),
          ),
          */
          // Botón Pausa/Reanudar
          ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  return IconButton(
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                    tooltip: isPaused ? "Reanudar" : "Pausar",
                    onPressed:
                        levelEnded
                            ? null // Deshabilitado si el nivel terminó
                            : () {
                              if (isPaused) {
                                _gameController.resumeGame(); // Reanuda juego y timer
                                _startCarouselAnimation(); // Reanuda animación visual
                              } else {
                                _gameController.pauseGame(); // Pausa juego y timer
                                _stopCarouselAnimation(); // Pausa animación visual
                              }
                            },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<MovingIllustration>>(
        valueListenable: _gameController.availableIllustrationsNotifier,
        builder: (context, availableIllustrations, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  // Muestra indicador de carga mientras las dimensiones no están listas
                  if (_screenWidth <= 0 || _screenHeight <= 0) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Construye el Stack principal del juego
                  return Stack(
                    children: [
                      _buildDropZonesAndBackground(), // Dibuja las zonas y fondo
                      // Dibuja las ilustraciones arrastrables
                      ..._buildDraggableIllustrations(availableIllustrations),
                      // Muestra overlay de pausa si está pausado y no terminado
                      if (isPaused && !levelEnded) _buildPauseOverlay(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- Widgets de Construcción Auxiliares ---

  Widget _buildDropZonesAndBackground() {
    if (_screenWidth <= 0 || _screenHeight <= 0) return const SizedBox.shrink();

    final double zoneHeight = _screenHeight / 2;
    final references = _gameController.currentReferences;
    final numberOfReferences = references.length;

    return Positioned.fill(
      child: Column(
        children: [
          // Zona Superior (Drop + Referencias) - ListView
          SizedBox(
            height: zoneHeight,
            width: double.infinity,
            child:
                numberOfReferences > 0
                    ? ListView.builder(
                      controller: _carouselScrollController,
                      scrollDirection: Axis.horizontal,
                      // Deshabilitar scroll manual si se desea
                      // physics: NeverScrollableScrollPhysics(),
                      itemCount: 10000 * numberOfReferences, // Simula loop infinito
                      itemBuilder: (context, index) {
                        final actualIndex = index % numberOfReferences;
                        final reference = references[actualIndex];
                        // Calcula el ancho de cada sección de referencia
                        final double sectionWidth = _screenWidth / numberOfReferences;
                        return _buildReferenceSection(
                          reference: reference,
                          index: actualIndex,
                          height: zoneHeight,
                          width: sectionWidth,
                          isHighlighted: _highlightedReferenceIndex == actualIndex,
                        );
                      },
                    )
                    : Container(
                      // Placeholder si no hay referencias
                      height: zoneHeight,
                      width: double.infinity,
                      color: Colors.blueGrey.withAlpha((0.12 * 255).toInt()), // Opacidad 0.12
                      alignment: Alignment.center,
                      child: _buildPlaceholderReference(60.0 * 1.5, "Cargando..."),
                    ),
          ),
          // Zona Inferior (Origen de ilustraciones - solo fondo)
          Container(
            width: double.infinity,
            height: zoneHeight,
            decoration: BoxDecoration(
              color: Colors.blueGrey.withAlpha((0.05 * 255).toInt()), // Opacidad 0.05
              border: Border(
                top: BorderSide(color: Colors.grey.withAlpha((0.15 * 255).toInt()), width: 1), // Opacidad 0.15
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceSection({
    required Illustration reference,
    required int index,
    required double height,
    required double width,
    required bool isHighlighted,
  }) {
    // Calcula tamaño de la imagen de referencia basado en el espacio disponible
    final double referenceImageSize = min(width * 0.5, height * 0.4);

    return ValueListenableBuilder<bool>(
      valueListenable: _gameController.levelEndedNotifier, // Escucha si el nivel terminó
      builder: (context, levelEnded, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            // Cambia color si está resaltada y el nivel no ha terminado
            color:
                isHighlighted && !levelEnded
                    ? Colors.amber.withAlpha((0.3 * 255).toInt()) // Resaltado Opacidad 0.3
                    : Colors.blueGrey.withAlpha((0.12 * 255).toInt()), // Normal Opacidad 0.12
            border: Border(
              // Borde derecho para separar secciones
              right: BorderSide(color: Colors.grey.withAlpha((0.2 * 255).toInt()), width: 1), // Opacidad 0.2
            ),
          ),
          alignment: Alignment.center,
          child: _buildReferenceWidget(reference, referenceImageSize), // Dibuja la imagen de referencia
        );
      },
    );
  }

  Widget _buildReferenceWidget(Illustration reference, double size) {
    return Padding(
      padding: const EdgeInsets.all(4.0), // Pequeño padding alrededor
      child: Opacity(
        // Aplica opacidad a la imagen
        opacity: 0.9,
        child: Image.asset(
          reference.path,
          width: size,
          height: size,
          fit: BoxFit.contain, // Asegura que la imagen quepa sin distorsión
          // Widget a mostrar si la imagen no carga
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              color: Colors.pink.shade100, // Fondo rosa claro
              child: Icon(Icons.error_outline, size: size * 0.6, color: Colors.pink.shade700), // Icono de error
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderReference(double size, String text) {
    // --- Tamaño de fuente responsivo para Placeholder ---
    // El tamaño del placeholder ya es relativo, ajustamos el multiplicador si es necesario
    final double placeholderFontSize = max(8.0, size / 6.6); // Asegura un mínimo

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300.withAlpha((0.5 * 255).toInt()), // Opacidad 0.5
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400.withAlpha((0.7 * 255).toInt())), // Opacidad 0.7
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700, fontSize: placeholderFontSize),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<Widget> _buildDraggableIllustrations(List<MovingIllustration> illustrations) {
    return illustrations.map((illustration) {
      final double currentIllustrationSize = illustration.size;
      // Usa Positioned para colocar cada ilustración en sus coordenadas x, y
      return Positioned(
        key: ValueKey(illustration.illustration.name), // Clave única para cada ilustración
        left: illustration.x,
        top: illustration.y,
        width: currentIllustrationSize,
        height: currentIllustrationSize,
        child: GestureDetector(
          // Detecta gestos de arrastre
          onPanStart: (_) => _onPanStart(illustration),
          onPanUpdate: (details) => _onPanUpdate(details, illustration),
          onPanEnd: (details) => _onPanEnd(details, illustration),
          // El widget que muestra la ilustración visualmente
          child: MovingIllustrationWidget(illustration: illustration),
        ),
      );
    }).toList(); // Convierte el iterable a una lista de Widgets
  }

  Widget _buildPauseOverlay() {
    if (_screenWidth <= 0) return const SizedBox.shrink(); // Check screenWidth

    // --- Tamaños de fuente responsivos para Overlay de Pausa ---
    final double pauseTitleSize = max(22.0, _screenWidth / 25);
    final double pauseButtonTextSize = max(16.0, _screenWidth / 20);
    final double pauseButtonIconSize = max(24.0, _screenWidth / 18);

    return Container(
      // Fondo semitransparente oscuro
      color: Colors.black.withAlpha((0.75 * 255).toInt()), // Opacidad 0.75
      alignment: Alignment.center, // Centra el contenido
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ajusta el tamaño al contenido
        children: [
          Text(
            "JUEGO PAUSADO",
            style: TextStyle(
              color: Colors.white,

              fontSize: pauseTitleSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              // Sombra para mejorar legibilidad
              shadows: [Shadow(blurRadius: 10.0, color: Colors.black54, offset: Offset(2.0, 2.0))],
            ),
          ),
          const SizedBox(height: 40), // Espacio vertical
          ElevatedButton.icon(
            // Botón para continuar
            icon: Icon(Icons.play_arrow, size: pauseButtonIconSize), // --- iconSize Responsivo ---
            label: const Text("Continuar"),
            style: ElevatedButton.styleFrom(
              // Estilo del botón
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              // --- textStyle con fontSize Responsivo ---
              textStyle: TextStyle(fontSize: pauseButtonTextSize, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Bordes redondeados
            ),
            onPressed: () {
              // Reanuda juego, timer y animación visual
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
