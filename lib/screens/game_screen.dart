// lib/widgets/game_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Los imports originales se mantienen, asumiendo que son correctos en tu proyecto.
import '../constants/game_constants.dart';
import '../models/illustration.dart';
import '../models/moving_illustration.dart';
import '../models/illustration_container.dart';
import '../data/illustration_data.dart' as data;
import '../widgets/moving_illustration_widget.dart';

//****************************************************************************
// Clase Controller para la Lógica del Juego
//****************************************************************************
class GameController {
  // --- Notificadores y Callbacks para comunicar con la UI ---
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> levelEndedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> qualifiedIllustrationsCountNotifier = ValueNotifier<int>(0);
  // Inicializa con una lista vacía inmutable para seguridad
  final ValueNotifier<List<MovingIllustration>> movingIllustrationsNotifier = ValueNotifier<List<MovingIllustration>>(
    [],
  );
  final VoidCallback requestSetState; // Para solicitar a la UI que se redibuje
  final Function(String title, String message, bool levelWon) showEndLevelDialog;
  final Function(String message, bool isSuccess, double x, double y) showSnackBar;
  final BuildContext context; // Necesario para precacheImage

  // --- Estado Interno del Juego ---
  final IllustrationContainer _leftContainer = IllustrationContainer();
  final IllustrationContainer _rightContainer = IllustrationContainer();
  final Random _random = Random();
  List<Illustration> _availableIllustrationsForLevel = [];
  List<Illustration> _availableReferenceForLevel = [];

  // --- Temporizadores ---
  Timer? _gameTimer;
  Timer? _spawnTimer;

  // --- Dimensiones (proporcionadas por la UI) ---
  double screenWidth = 0;
  double screenHeight = 0;

  // --- Constructor ---
  GameController({
    required this.requestSetState,
    required this.showEndLevelDialog,
    required this.showSnackBar,
    required this.context, // Recibe el context
  });

  // --- Inicialización ---
  void initializeGame(double width, double height) {
    screenWidth = width;
    screenHeight = height;
    _precacheImages(); // Precarga las imágenes
    _initializeLevelData();
    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      _startGameTimers();
    }
  }

  void _precacheImages() {
    // Precarga imágenes de referencia
    for (var illustration in data.availableReference) {
      precacheImage(AssetImage(illustration.path), context);
    }
    // Precarga imágenes que caen
    for (var illustration in data.availableIllustrations) {
      precacheImage(AssetImage(illustration.path), context);
    }
  }

  void _initializeLevelData() {
    // Inicializa ilustraciones disponibles para el nivel actual
    _availableIllustrationsForLevel =
        data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL).toList();
    _availableIllustrationsForLevel.shuffle(_random);

    // Inicializa referencias para el nivel actual
    _availableReferenceForLevel = data.availableReference.where((il) => il.nivel == GameConstants.NIVEL).toList();
    _availableReferenceForLevel.shuffle(_random);
  }

  // --- Control del Juego (Inicio, Pausa, Reanudación, Reseteo) ---
  void _startGameTimers() {
    if (isPausedNotifier.value || levelEndedNotifier.value || screenHeight <= 0) return;

    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    _gameTimer = Timer.periodic(GameConstants.GAME_TICK, (_) {
      _updateGame();
    });

    final spawnInterval = GameConstants.SPAWN_INTERVAL[GameConstants.NIVEL];
    if (spawnInterval != null) {
      _spawnTimer = Timer.periodic(spawnInterval, (_) {
        _spawnNewIllustration();
      });
    }
  }

  void pauseGame() {
    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = true; // Notifica a la UI
      _gameTimer?.cancel();
      _spawnTimer?.cancel();
    }
  }

  void resumeGame() {
    if (isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = false; // Notifica a la UI
      _startGameTimers();
    }
  }

  void resetGame() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    // Resetea el estado del juego
    scoreNotifier.value = 0;
    // Asigna una nueva lista vacía para notificar el cambio
    movingIllustrationsNotifier.value = [];
    _leftContainer.correctIllustrations.clear();
    _rightContainer.correctIllustrations.clear();
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    GameConstants.SEEMATCH = false;

    _initializeLevelData(); // Recarga datos para el nivel

    // Solicita a la UI que se redibuje para reflejar el estado reseteado
    // (ValueListenableBuilders se actualizarán automáticamente por los notifiers)
    // requestSetState(); // Puede no ser necesario si todo depende de ValueListenableBuilders

    // Reinicia los temporizadores si no está pausado/terminado
    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      _startGameTimers();
    }
  }

  void nextLevel() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    // Incrementa el nivel
    GameConstants.NIVEL++;

    // Resetea estado para el nuevo nivel
    scoreNotifier.value = 0; // O mantén la puntuación si el juego lo requiere
    // Asigna una nueva lista vacía para notificar el cambio
    movingIllustrationsNotifier.value = [];
    _leftContainer.correctIllustrations.clear();
    _rightContainer.correctIllustrations.clear();
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    GameConstants.SEEMATCH = false;

    _initializeLevelData(); // Carga datos para el nuevo nivel

    // Reinicia temporizadores
    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      _startGameTimers();
    }
  }

  // --- Lógica Principal del Juego ---
  void _updateGame() {
    if (isPausedNotifier.value || levelEndedNotifier.value || screenHeight <= 0) return;

    final double deltaTimeSeconds = GameConstants.GAME_TICK.inMilliseconds / 1000.0;
    final fallDuration = GameConstants.TARGET_FALL_DURATION_SECONDS[GameConstants.NIVEL];

    final double requiredSpeedPerSecond = screenHeight / (fallDuration ?? 4.0);
    final double distancePerTick = requiredSpeedPerSecond * deltaTimeSeconds;

    // Lista para guardar las ilustraciones que continúan en pantalla
    List<MovingIllustration> nextFrameIllustrations = [];
    bool illustrationsRemoved = false;

    for (final illustration in movingIllustrationsNotifier.value) {
      // Actualiza tiempo restante
      illustration.timeLeft -= deltaTimeSeconds;

      if (!illustration.isBeingDragged) {
        illustration.y += distancePerTick;
      }

      // Condición de permanencia: Dentro de pantalla y tiempo restante
      if (illustration.y <= screenHeight && illustration.timeLeft > 0) {
        nextFrameIllustrations.add(illustration); // Conserva la ilustración
      } else {
        // La ilustración sale de pantalla o se agota el tiempo
        illustrationsRemoved = true;
        qualifiedIllustrationsCountNotifier.value++; // Notifica cambio
      }
    }

    // Si alguna ilustración fue removida o movida, actualiza el notifier con la nueva lista
    if (illustrationsRemoved || nextFrameIllustrations.isNotEmpty) {
      movingIllustrationsNotifier.value = nextFrameIllustrations;
    }

    // Verifica si el nivel terminó después de actualizar
    if (illustrationsRemoved) {
      _checkLevelEndConditions();
    }
  }

  void _spawnNewIllustration() {
    final maxIllustrations = GameConstants.MAX_FALLING_ILLUSTRATIONS[GameConstants.NIVEL];

    if (isPausedNotifier.value ||
        levelEndedNotifier.value ||
        movingIllustrationsNotifier.value.length >= (maxIllustrations ?? 1) ||
        _availableIllustrationsForLevel.isEmpty) {
      return;
    }

    final int randomIndex = _random.nextInt(_availableIllustrationsForLevel.length);
    final Illustration illustrationToSpawn = _availableIllustrationsForLevel.removeAt(randomIndex);

    final size = 60.0; // Podría ser una constante
    final x = (screenWidth / 2) - (size / 2);
    final y = -size; // Empieza justo encima

    final newFallingIllustration = MovingIllustration(illustration: illustrationToSpawn, x: x, y: y, size: size);

    // Añade a la lista creando una nueva instancia y asignándola a .value
    movingIllustrationsNotifier.value = List.from(movingIllustrationsNotifier.value)..add(newFallingIllustration);
  }

  // --- Manejo de Interacción (Arrastre) ---
  void handleDrop(MovingIllustration illustration, double dropX, double dropY) {
    if (levelEndedNotifier.value) return;

    final double dropZoneWidth = screenWidth / 3;
    final bool droppedOnLeft = dropX < dropZoneWidth;
    final bool droppedOnRight = dropX > screenWidth - dropZoneWidth;

    // Simplificado: Izquierda o Derecha
    final bool droppedInLeftDestination = droppedOnLeft;
    final bool droppedInRightDestination = droppedOnRight;

    IllustrationContainer? targetContainer;
    bool correctMatch = false;
    bool incorrectMatchInDestinationZone = false;

    if (droppedInLeftDestination) {
      if (illustration.illustration.category == _availableReferenceForLevel[0].category) {
        targetContainer = _leftContainer;
        correctMatch = true;
      } else {
        incorrectMatchInDestinationZone = true;
      }
    } else if (droppedInRightDestination) {
      if (illustration.illustration.category == _availableReferenceForLevel[1].category) {
        targetContainer = _rightContainer;
        correctMatch = true;
      } else {
        incorrectMatchInDestinationZone = true;
      }
    }

    // Si cayó en una zona de destino (correcta o incorrecta)
    if (correctMatch || incorrectMatchInDestinationZone) {
      if (correctMatch) {
        scoreNotifier.value++; // Notifica
        targetContainer?.correctIllustrations.add(illustration); // Añade al contenedor correcto
        showSnackBar('¡Correcto!', true, dropX, dropY); // Llama al callback de la UI
      } else {
        showSnackBar('¡Incorrecto!', false, dropX, dropY); // Llama al callback de la UI
      }

      // Elimina la ilustración creando una nueva lista filtrada y asignándola a .value
      movingIllustrationsNotifier.value =
          movingIllustrationsNotifier.value.where((item) => item != illustration).toList();

      qualifiedIllustrationsCountNotifier.value++; // Notifica

      // Pide a la UI que se redibuje si es necesario (para mostrar las colocadas, si SEEMATCH es true)
      if (GameConstants.SEEMATCH) {
        requestSetState();
      }

      _checkLevelEndConditions();
    }
  }

  void _checkLevelEndConditions() {
    final illustrationsPerLevel = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL];

    if (qualifiedIllustrationsCountNotifier.value >= (illustrationsPerLevel ?? 0) && !levelEndedNotifier.value) {
      levelEndedNotifier.value = true; // Notifica
      _endLevel();
    }
  }

  void _endLevel() {
    pauseGame(); // Detiene timers y actualiza isPausedNotifier si es necesario

    // Asegúrate de que WINNING_SCORE_THRESHOLD tenga entrada para el nivel
    final winningScore = GameConstants.WINNING_SCORE_THRESHOLD[GameConstants.NIVEL];

    final score = scoreNotifier.value;
    final bool levelWon = score >= (winningScore ?? 0);
    String title = levelWon ? "¡Excelente!" : "Nivel Terminado";
    String message =
        levelWon
            ? "Ganaste este nivel con $score puntos."
            : "No alcanzaste la puntuación mínima ($winningScore).\nTu puntuación: $score puntos.";

    _showEndLevelDialogInternal(title, message, levelWon);
  }

  // Método interno para encapsular el retraso y la llamada al callback
  void _showEndLevelDialogInternal(String title, String message, bool levelWon) {
    // Usamos un pequeño retraso para asegurar que el estado se actualice visualmente
    Future.delayed(const Duration(milliseconds: 100), () {
      // Verifica si el controller todavía está "vivo" antes de llamar al callback
      showEndLevelDialog(title, message, levelWon);
    });
  }

  // --- Getters para la UI (para evitar exponer estado interno directamente) ---
  List<Illustration> get currentReferences => List.unmodifiable(_availableReferenceForLevel);
  List<MovingIllustration> get correctLeftIllustrations => List.unmodifiable(_leftContainer.correctIllustrations);
  List<MovingIllustration> get correctRightIllustrations => List.unmodifiable(_rightContainer.correctIllustrations);

  // --- Limpieza ---
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    scoreNotifier.dispose();
    isPausedNotifier.dispose();
    levelEndedNotifier.dispose();
    qualifiedIllustrationsCountNotifier.dispose();
    movingIllustrationsNotifier.dispose();
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

class GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  // --- Controller ---
  late final GameController _gameController;

  // --- Estado específico de la UI ---
  bool _isLeftTopHighlighted = false;
  bool _isLeftBottomHighlighted = false;
  bool _isRightTopHighlighted = false;
  bool _isRightBottomHighlighted = false;

  // --- Dimensiones (se obtienen en build) ---
  double _screenWidth = 0;
  double _screenHeight = 0;

  // --- Estado para manejar el drag localmente ---
  MovingIllustration? _draggedIllustration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Crea el GameController, pasando los callbacks necesarios
    _gameController = GameController(
      context: context, // Pasa el context
      requestSetState: () {
        if (mounted) {
          setState(() {}); // Llama a setState cuando el controller lo pida
        }
      },
      showEndLevelDialog: _showEndLevelDialog, // Pasa la función local
      showSnackBar: _showSnackBar, // Pasa la función local
    );

    // Inicializa el juego después de que el primer frame se haya renderizado
    // para asegurar que MediaQuery funcione correctamente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Obtiene las dimensiones iniciales aquí, dentro del postFrameCallback
      final mediaQuery = MediaQuery.of(context);
      final initialScreenWidth = mediaQuery.size.width;
      // Asegurarse de que kToolbarHeight sea accesible o usar un valor por defecto
      final double appBarHeight = AppBar().preferredSize.height;
      final double topPadding = mediaQuery.padding.top;
      final double initialScreenHeight = mediaQuery.size.height - topPadding - appBarHeight;

      if (mounted && initialScreenWidth > 0 && initialScreenHeight > 0) {
        _screenWidth = initialScreenWidth;
        _screenHeight = initialScreenHeight;
        _gameController.initializeGame(_screenWidth, _screenHeight);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameController.dispose(); // Llama al dispose del controller
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Delega el manejo del ciclo de vida al controller
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _gameController.pauseGame();
    } else if (state == AppLifecycleState.resumed) {
      // Solo reanuda si estaba pausado por el ciclo de vida, no si el nivel terminó
      if (_gameController.isPausedNotifier.value && !_gameController.levelEndedNotifier.value) {
        _gameController.resumeGame();
      }
    }
  }

  // --- Manejo de Interacción (Drag en la UI) ---

  void _onPanStart(MovingIllustration illustration) {
    // No permitir drag si el juego está pausado o terminado
    if (_gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value) return;

    setState(() {
      _draggedIllustration = illustration; // Marca cuál se está arrastrando
      illustration.isBeingDragged = true;

      final currentList = _gameController.movingIllustrationsNotifier.value;
      if (currentList.contains(illustration)) {
        _gameController.movingIllustrationsNotifier.value =
            currentList.where((i) => i != illustration).toList()..add(illustration);
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
      // Actualiza posición localmente para respuesta visual inmediata
      illustration.x += details.delta.dx;
      illustration.y += details.delta.dy;
      // Clamp para mantener dentro de la pantalla
      illustration.x = illustration.x.clamp(0.0, _screenWidth - illustration.size);
      illustration.y = illustration.y.clamp(0.0, _screenHeight - illustration.size);
      // Actualiza las áreas resaltadas basado en la posición actual
      _updateHighlightedAreas(illustration.x + illustration.size / 2, illustration.y + illustration.size / 2);
    });
  }

  void _onPanEnd(DragEndDetails details, MovingIllustration illustration) {
    if (_draggedIllustration != illustration) return; // Solo procesa si es la que se estaba arrastrando

    final bool wasPausedOrEnded = _gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value;

    // Guarda la posición final antes de resetear el estado de drag
    final dropX = illustration.x + illustration.size / 2;
    final dropY = illustration.y + illustration.size / 2;

    // Siempre resetea el estado de drag y las áreas resaltadas al soltar
    setState(() {
      illustration.isBeingDragged = false;
      _draggedIllustration = null;
      _resetHighlightedAreas();
    });

    // Si el juego estaba pausado o terminado cuando se soltó, no procesar el drop
    if (wasPausedOrEnded) return;

    // Delega la lógica de verificar el match al controller
    _gameController.handleDrop(illustration, dropX, dropY);
  }

  void _updateHighlightedAreas(double currentX, double currentY) {
    if (_gameController.levelEndedNotifier.value) return;

    bool needsUpdate = false;
    final double dropZoneWidth = _screenWidth / 3;

    // Simplificado: Solo resalta la columna izquierda o derecha completa
    final bool isOnLeftSide = currentX < dropZoneWidth;
    final bool isOnRightSide = currentX > _screenWidth - dropZoneWidth;

    // Actualiza resaltado izquierdo (ambas zonas, superior e inferior)
    final bool newLeftHighlight = isOnLeftSide && !_gameController.levelEndedNotifier.value;
    if (newLeftHighlight != _isLeftTopHighlighted) {
      // Compara con uno, aplica a ambos
      _isLeftTopHighlighted = newLeftHighlight;
      _isLeftBottomHighlighted = newLeftHighlight; // Mismo estado para ambas
      needsUpdate = true;
    }

    // Actualiza resaltado derecho (ambas zonas, superior e inferior)
    final bool newRightHighlight = isOnRightSide && !_gameController.levelEndedNotifier.value;
    if (newRightHighlight != _isRightTopHighlighted) {
      // Compara con uno, aplica a ambos
      _isRightTopHighlighted = newRightHighlight;
      _isRightBottomHighlighted = newRightHighlight; // Mismo estado para ambas
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  void _resetHighlightedAreas() {
    // Solo actualiza si alguna estaba resaltada
    if (_isLeftTopHighlighted || _isLeftBottomHighlighted || _isRightTopHighlighted || _isRightBottomHighlighted) {
      setState(() {
        _isLeftTopHighlighted = false;
        _isLeftBottomHighlighted = false;
        _isRightTopHighlighted = false;
        _isRightBottomHighlighted = false;
      });
    }
  }

  // --- Callbacks para el Controller ---

  void _showEndLevelDialog(String title, String message, bool levelWon) {
    // Asegurarse que el widget está montado antes de mostrar el diálogo
    if (!mounted || _screenWidth <= 0) return; // Añadido check _screenWidth

    // Verifica si MAX_LEVEL está definido y es válido
    final maxLevel = GameConstants.MAX_LEVEL; // Asume que MAX_LEVEL es const
    final bool isLastLevel = (GameConstants.NIVEL >= maxLevel);

    final int newsize = 10;
    // --- Tamaños de fuente responsivos para el diálogo ---
    final double dialogTitleSize = max(16.0, _screenWidth / (20 + newsize));
    final double dialogMessageSize = max(13.0, _screenWidth / (25 + newsize));
    final double dialogButtonSize = max(13.0, _screenWidth / (25 + newsize));

    showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando fuera
      builder: (BuildContext context) {
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
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Reiniciar Juego", style: TextStyle(fontSize: dialogButtonSize)),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
                _gameController.resetGame(); // Llama al reset del controller
              },
            ),
            // Muestra "Continuar" solo si ganó y no es el último nivel
            if (levelWon && !isLastLevel)
              TextButton(
                child: Text("Continuar", style: TextStyle(fontSize: dialogButtonSize)),
                onPressed: () {
                  Navigator.of(context).pop(); // Cierra el diálogo
                  _gameController.nextLevel(); // Llama a nextLevel del controller
                },
              ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, bool isSuccess, double x, double y) {
    if (!mounted || _screenHeight <= 0 || _screenWidth <= 0) return; // Verifica dimensiones

    final bottomMargin = max(
      20.0,
      _screenHeight - y - 30,
    ).clamp(20.0, _screenHeight - 60.0); // 60 = altura estimada SnackBar
    final leftMargin = max(
      10.0,
      x - 80,
    ).clamp(10.0, _screenWidth - 170.0); // 80 = mitad ancho estimado, 170 = ancho + margen
    final rightMargin = max(10.0, _screenWidth - x - 80).clamp(10.0, _screenWidth - 170.0);

    // --- Tamaño de fuente responsivo para SnackBar ---
    final double snackBarFontSize = max(12.0, _screenWidth / 60);

    // Asegúrate de remover SnackBars anteriores antes de mostrar uno nuevo
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: snackBarFontSize)),
        duration: const Duration(milliseconds: 800),
        backgroundColor: isSuccess ? Colors.green : const Color.fromARGB(255, 175, 76, 76),
        behavior: SnackBarBehavior.floating, // Necesario para usar márgenes
        margin: EdgeInsets.only(bottom: bottomMargin, left: leftMargin, right: rightMargin),
        // Redondea las esquinas para un mejor aspecto
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }

  // --- Construcción de la UI ---
  @override
  Widget build(BuildContext context) {
    // Obtiene dimensiones aquí para asegurar que estén disponibles
    final mediaQuery = MediaQuery.of(context);
    final currentScreenWidth = mediaQuery.size.width;
    // Asegurarse de que kToolbarHeight sea accesible o usar un valor por defecto
    final double appBarHeight = AppBar().preferredSize.height;
    final double topPadding = mediaQuery.padding.top;
    final currentScreenHeight = mediaQuery.size.height - topPadding - appBarHeight;

    // Si las dimensiones cambian (ej. rotación o redimensionamiento), informa al controller
    // Solo actualiza si las nuevas dimensiones son válidas y diferentes
    if (currentScreenWidth > 0 &&
        currentScreenHeight > 0 &&
        (currentScreenWidth != _screenWidth || currentScreenHeight != _screenHeight)) {
      _screenWidth = currentScreenWidth;
      _screenHeight = currentScreenHeight;
      // Actualiza las dimensiones en el controller si ya fue inicializado
      if (_gameController.screenWidth > 0) {
        _gameController.screenWidth = _screenWidth;
        _gameController.screenHeight = _screenHeight;
      }
      // No intentar inicializar desde build si ya se hizo en initState/postFrameCallback
    }

    final int newsize = 10;
    // --- Tamaños de fuente responsivos para AppBar ---
    final double appBarTitleSize = max(10.0, _screenWidth / (22 + newsize));
    final double appBarScoreSize = max(9.0, _screenWidth / (25 + newsize));
    final double appBarCounterSize = max(6.0, _screenWidth / (25 + newsize));

    return Scaffold(
      appBar: AppBar(
        title: Text("LSM Game - Nivel ${GameConstants.NIVEL}", style: TextStyle(fontSize: appBarTitleSize)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.scoreNotifier,
                builder: (context, score, _) {
                  return Text("Puntos: $score", style: TextStyle(fontSize: appBarScoreSize));
                },
              ),
            ),
          ),
          // Contador de ilustraciones calificadas
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.qualifiedIllustrationsCountNotifier,
                builder: (context, count, _) {
                  // Obtiene el total del nivel, maneja caso nulo
                  final total = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL] ?? 0;
                  return Text("$count/$total", style: TextStyle(fontSize: appBarCounterSize, color: Colors.white70));
                },
              ),
            ),
          ),
          // Botón Mostrar/Ocultar Coincidencias
          IconButton(
            icon: Icon(GameConstants.SEEMATCH ? Icons.visibility_off : Icons.visibility),
            tooltip: GameConstants.SEEMATCH ? "Ocultar Coincidencias" : "Mostrar Coincidencias",
            onPressed: () {
              // setState es necesario aquí para redibujar el icono del AppBar
              setState(() {
                GameConstants.SEEMATCH = !GameConstants.SEEMATCH;
              });
              _gameController.requestSetState(); // Llama a setState en GameScreen
            },
          ),
          // Botón Pausa/Reanudar (escucha a ambos notifiers)
          ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  return IconButton(
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                    tooltip: isPaused ? "Reanudar" : "Pausar",
                    // Deshabilitado si el nivel terminó
                    onPressed:
                        levelEnded
                            ? null
                            : () {
                              if (isPaused) {
                                _gameController.resumeGame();
                              } else {
                                _gameController.pauseGame();
                              }
                            },
                  );
                },
              );
            },
          ),
        ],
      ),
      // El cuerpo escucha los cambios en las ilustraciones que caen
      body: ValueListenableBuilder<List<MovingIllustration>>(
        valueListenable: _gameController.movingIllustrationsNotifier,
        builder: (context, movingIllustrations, _) {
          // Y también escucha el estado de pausa para el overlay
          return ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              // Y el estado de fin de nivel
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  // Asegúrate de que las dimensiones sean válidas antes de construir el Stack
                  if (_screenWidth <= 0 || _screenHeight <= 0) {
                    // Muestra un indicador de carga o un placeholder mientras se obtienen las dimensiones
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Stack(
                    children: [
                      _buildBackgroundAndDropZones(),
                      // Construye las ilustraciones que caen (obtenidas del notifier)
                      ..._buildFallingIllustrations(movingIllustrations),
                      // Construye las ilustraciones colocadas (obtenidas del controller)
                      ..._buildPlacedIllustrations(_gameController.correctLeftIllustrations, true),
                      ..._buildPlacedIllustrations(_gameController.correctRightIllustrations, false),
                      // Muestra overlay de pausa si está pausado Y el nivel NO ha terminado
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

  // --- Widgets de Construcción (Build Helpers) ---

  Widget _buildBackgroundAndDropZones() {
    // Asegura dimensiones válidas
    if (_screenWidth <= 0 || _screenHeight <= 0) return const SizedBox.shrink();

    final double zoneWidth = _screenWidth / 3;
    // Obtiene las referencias actuales del controller
    final references = _gameController.currentReferences;
    // Calcula tamaño basado en dimensiones actuales
    final double referenceImageSize = min(zoneWidth * 0.6, (_screenHeight / 2) * 0.4);
    // Verifica si hay suficientes referencias (el controller debería asegurar esto)
    final bool hasEnoughReferences = references.length >= 2;

    return Column(
      children: [
        // Fila Superior (Referencias)
        Expanded(
          child: Row(
            children: [
              // Zona Izquierda Superior (Referencia 1)
              _buildDropZoneArea(
                isHighlighted: _isLeftTopHighlighted,
                child:
                    hasEnoughReferences
                        ? _buildReferenceWidget(references[0], referenceImageSize)
                        : _buildPlaceholderReference(referenceImageSize, "Cargando..."), // Placeholder
              ),
              // Zona Central (Vacía)
              Container(width: zoneWidth, color: Colors.transparent),
              // Zona Derecha Superior (Referencia 2)
              _buildDropZoneArea(
                isHighlighted: _isRightTopHighlighted,
                child:
                    hasEnoughReferences
                        ? _buildReferenceWidget(references[1], referenceImageSize)
                        : _buildPlaceholderReference(referenceImageSize, "Cargando..."), // Placeholder
              ),
            ],
          ),
        ),
        // Fila Inferior (Zonas de Destino)
        Expanded(
          child: Row(
            children: [
              // Zona Izquierda Inferior (Destino 1)
              _buildDropZoneArea(isHighlighted: _isLeftBottomHighlighted),
              // Zona Central (Vacía)
              Container(width: zoneWidth, color: Colors.transparent),
              // Zona Derecha Inferior (Destino 2)
              _buildDropZoneArea(isHighlighted: _isRightBottomHighlighted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropZoneArea({required bool isHighlighted, Widget? child}) {
    // Escucha el notifier de fin de nivel para desactivar el resaltado
    return ValueListenableBuilder<bool>(
      valueListenable: _gameController.levelEndedNotifier,
      builder: (context, levelEnded, _) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              // No resaltar si el nivel terminó
              color:
                  isHighlighted // Ya consideramos levelEnded en _updateHighlightedAreas
                      ? Colors.amber.withAlpha((0.3 * 255).toInt()) // Resaltado activo
                      : Colors.blueGrey.withAlpha((0.08 * 255).toInt()), // Fondo normal
              border: Border.all(color: Colors.grey.withAlpha((0.2 * 255).toInt()), width: 1),
            ),
            alignment: Alignment.center,
            child: child, // Muestra la imagen de referencia si se proporciona
          ),
        );
      },
    );
  }

  Widget _buildReferenceWidget(Illustration reference, double size) {
    return Padding(
      padding: const EdgeInsets.all(8.0), // Espaciado interno
      child: Image.asset(
        reference.path,
        width: size,
        height: size,
        fit: BoxFit.contain, // Asegura que la imagen quepa sin distorsión
        // Manejo de error si la imagen no carga
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: Colors.red.shade100, // Fondo rojo claro para indicar error
            child: Icon(Icons.broken_image, size: size * 0.6, color: Colors.red.shade700),
          );
        },
      ),
    );
  }

  // Construye los widgets para las ilustraciones que están cayendo
  List<Widget> _buildFallingIllustrations(List<MovingIllustration> illustrations) {
    // No mostrar si el nivel terminó
    if (_gameController.levelEndedNotifier.value) return [];

    return illustrations.map((illustration) {
      // Usa Positioned para colocar cada ilustración según sus coordenadas x, y
      return Positioned(
        // Usa un ID único de la ilustración como Key
        key: ValueKey(illustration.illustration.name),
        left: illustration.x,
        top: illustration.y,
        child: GestureDetector(
          // Vincula los eventos de drag a los métodos _onPan... de esta clase (_GameScreenState)
          onPanStart: (_) => _onPanStart(illustration),
          onPanUpdate: (details) => _onPanUpdate(details, illustration),
          onPanEnd: (details) => _onPanEnd(details, illustration),
          child: MovingIllustrationWidget(illustration: illustration), // Usa tu widget personalizado
        ),
      );
    }).toList();
  }

  // Construye los widgets para las ilustraciones que ya fueron colocadas correctamente
  List<Widget> _buildPlacedIllustrations(List<MovingIllustration> placedList, bool isLeft) {
    // Solo muestra si la opción SEEMATCH está activa
    if (!GameConstants.SEEMATCH || _screenWidth <= 0) {
      // Verifica también dimensiones
      return []; // Retorna lista vacía si no se deben mostrar
    }

    // Constantes para el layout de las imágenes colocadas
    const double placedSize = 30.0; // Tamaño más pequeño para las colocadas
    const double spacing = 4.0; // Espacio entre imágenes
    const double bottomMargin = 8.0; // Margen desde el borde inferior
    const double sideMargin = 6.0; // Margen desde los bordes laterales de la zona
    final double containerWidth = _screenWidth / 3; // Ancho de la zona de colocación

    // Calcula cuántas imágenes caben por fila, asegurando al menos 1
    int maxItemsPerRow = ((containerWidth - 2 * sideMargin + spacing) / (placedSize + spacing)).floor();
    maxItemsPerRow = max(1, maxItemsPerRow); // Evita división por cero o valor 0

    List<Widget> positionedWidgets = []; // Lista para guardar los widgets Positioned
    for (int i = 0; i < placedList.length; i++) {
      int rowIndex = i ~/ maxItemsPerRow; // Calcula la fila
      int colIndex = i % maxItemsPerRow; // Calcula la columna

      // Calcula la posición horizontal dentro de la zona (izquierda o derecha)
      double horizontalPosition = sideMargin + colIndex * (placedSize + spacing);
      // Calcula la posición vertical desde abajo
      double verticalPosition = bottomMargin + rowIndex * (placedSize + spacing);

      positionedWidgets.add(
        Positioned(
          // Define 'left' si es la zona izquierda, 'right' si es la derecha
          left: isLeft ? horizontalPosition : null,
          right: !isLeft ? horizontalPosition : null,
          bottom: verticalPosition, // Posiciona desde abajo
          child: Image.asset(
            placedList[i].illustration.path, // Usa la ruta de la ilustración
            key: ValueKey("placed_${placedList[i].illustration.name}"), // Key única
            width: placedSize,
            height: placedSize,
            fit: BoxFit.contain,
            // Widget de error si la imagen no carga
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: placedSize,
                height: placedSize,
                color: Colors.grey.shade300,
                child: Icon(Icons.image_not_supported, size: placedSize * 0.7, color: Colors.grey.shade600),
              );
            },
          ),
        ),
      );
    }
    return positionedWidgets; // Devuelve la lista de widgets posicionados
  }

  // Construye el overlay que se muestra cuando el juego está pausado
  Widget _buildPauseOverlay() {
    if (_screenWidth <= 0) return const SizedBox.shrink(); // Check screenWidth

    // --- Tamaños de fuente responsivos para Overlay de Pausa ---
    final double pauseTitleSize = max(22.0, _screenWidth / 25);
    final double pauseButtonTextSize = max(16.0, _screenWidth / 20);
    final double pauseButtonIconSize = max(24.0, _screenWidth / 18);

    return Container(
      // Fondo semitransparente oscuro
      color: Colors.black.withAlpha((0.7 * 255).toInt()),
      alignment: Alignment.center, // Centra el contenido
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ajusta el tamaño al contenido
        children: [
          // Texto "JUEGO PAUSADO"
          Text(
            "JUEGO PAUSADO",
            style: TextStyle(
              color: Colors.white,
              fontSize: pauseTitleSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 40), // Espacio vertical
          // Botón para reanudar
          ElevatedButton.icon(
            icon: Icon(Icons.play_arrow, size: pauseButtonIconSize),
            label: const Text("Continuar"),
            style: ElevatedButton.styleFrom(
              // Estilo del botón
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: TextStyle(fontSize: pauseButtonTextSize),
            ),
            // Llama a resumeGame del controller al presionar
            onPressed: _gameController.resumeGame,
          ),
        ],
      ),
    );
  }

  // Widget placeholder para cuando las referencias no están listas
  Widget _buildPlaceholderReference(double size, String text) {
    // --- Tamaño de fuente responsivo para Placeholder ---
    final double placeholderFontSize = max(8.0, size / 6.6); // Asegura un mínimo

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200, // Fondo gris claro
        border: Border.all(color: Colors.grey.shade400), // Borde gris
        borderRadius: BorderRadius.circular(4), // Esquinas redondeadas
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade600, fontSize: placeholderFontSize),
        textAlign: TextAlign.center,
      ),
    );
  }
}
