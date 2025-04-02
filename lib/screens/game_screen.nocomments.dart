import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../constants/game_constants.dart';
import '../models/illustration.dart';
import '../models/moving_illustration.dart';
import '../models/illustration_container.dart';
import '../data/illustration_data.dart' as data;
import '../widgets/moving_illustration_widget.dart';

class GameController {
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> levelEndedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> qualifiedIllustrationsCountNotifier = ValueNotifier<int>(0);

  final ValueNotifier<List<MovingIllustration>> movingIllustrationsNotifier = ValueNotifier<List<MovingIllustration>>([]);

  final VoidCallback requestSetState;
  final Function(String title, String message, bool levelWon) showEndLevelDialog;
  final Function(String message, bool isSuccess, double x, double y) showSnackBar;
  final BuildContext context;

  final IllustrationContainer _leftContainer = IllustrationContainer();
  final IllustrationContainer _rightContainer = IllustrationContainer();
  final Random _random = Random();
  List<Illustration> _availableIllustrationsForLevel = [];
  List<Illustration> _availableReferenceForLevel = [];

  Timer? _gameTimer;
  Timer? _spawnTimer;

  double screenWidth = 0;
  double screenHeight = 0;

  GameController({
    required this.requestSetState,
    required this.showEndLevelDialog,
    required this.showSnackBar,
    required this.context,
  });

  void initializeGame(double width, double height) {
    screenWidth = width;
    screenHeight = height;
    _precacheImages();
    _initializeLevelData();

    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      _startGameTimers();
    }
  }

  void _precacheImages() {
    for (var illustration in data.availableReference) {
      precacheImage(AssetImage(illustration.path), context);
    }

    for (var illustration in data.availableIllustrations) {
      precacheImage(AssetImage(illustration.path), context);
    }
  }

  void _initializeLevelData() {
    _availableIllustrationsForLevel = data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL).toList();
    _availableIllustrationsForLevel.shuffle(_random);

    _availableReferenceForLevel = data.availableReference.where((il) => il.nivel == GameConstants.NIVEL).toList();
    _availableReferenceForLevel.shuffle(_random);
  }

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
      isPausedNotifier.value = true;
      _gameTimer?.cancel();
      _spawnTimer?.cancel();
    }
  }

  void resumeGame() {
    if (isPausedNotifier.value && !levelEndedNotifier.value) {
      isPausedNotifier.value = false;
      _startGameTimers();
    }
  }

  void resetGame() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    scoreNotifier.value = 0;
    movingIllustrationsNotifier.value = [];
    _leftContainer.correctIllustrations.clear();
    _rightContainer.correctIllustrations.clear();
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    GameConstants.SEEMATCH = false;

    _initializeLevelData();

    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      _startGameTimers();
    }
  }

  void nextLevel() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    GameConstants.NIVEL++;

    scoreNotifier.value = 0;
    movingIllustrationsNotifier.value = [];
    _leftContainer.correctIllustrations.clear();
    _rightContainer.correctIllustrations.clear();
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    GameConstants.SEEMATCH = false;

    _initializeLevelData();

    if (!isPausedNotifier.value && !levelEndedNotifier.value) {
      _startGameTimers();
    }
  }

  void _updateGame() {
    if (isPausedNotifier.value || levelEndedNotifier.value || screenHeight <= 0) return;

    final double deltaTimeSeconds = GameConstants.GAME_TICK.inMilliseconds / 1000.0;

    final fallDuration = GameConstants.TARGET_FALL_DURATION_SECONDS[GameConstants.NIVEL];

    final double requiredSpeedPerSecond = screenHeight / (fallDuration ?? 4.0);

    final double distancePerTick = requiredSpeedPerSecond * deltaTimeSeconds;

    List<MovingIllustration> nextFrameIllustrations = [];
    bool illustrationsRemoved = false;

    for (final illustration in movingIllustrationsNotifier.value) {
      illustration.timeLeft -= deltaTimeSeconds;

      if (!illustration.isBeingDragged) {
        illustration.y += distancePerTick;
      }

      if (illustration.y <= screenHeight && illustration.timeLeft > 0) {
        nextFrameIllustrations.add(illustration);
      } else {
        illustrationsRemoved = true;
        qualifiedIllustrationsCountNotifier.value++;
      }
    }

    if (illustrationsRemoved || nextFrameIllustrations.isNotEmpty) {
      movingIllustrationsNotifier.value = List.from(nextFrameIllustrations);
    }

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

    final size = 60.0;

    final x = (screenWidth / 2) - (size / 2);
    final y = -size;

    final newFallingIllustration = MovingIllustration(illustration: illustrationToSpawn, x: x, y: y, size: size);

    movingIllustrationsNotifier.value = List.from(movingIllustrationsNotifier.value)..add(newFallingIllustration);
  }

  void handleDrop(MovingIllustration illustration, double dropX, double dropY) {
    if (levelEndedNotifier.value) return;

    final double dropZoneWidth = screenWidth / 3;
    final bool droppedOnLeft = dropX < dropZoneWidth;
    final bool droppedOnRight = dropX > screenWidth - dropZoneWidth;

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

    if (correctMatch || incorrectMatchInDestinationZone) {
      if (correctMatch) {
        scoreNotifier.value++;
        targetContainer?.correctIllustrations.add(illustration);
        showSnackBar('¡Correcto!', true, dropX, dropY);
      } else {
        showSnackBar('¡Incorrecto!', false, dropX, dropY);
      }

      movingIllustrationsNotifier.value = movingIllustrationsNotifier.value.where((item) => item != illustration).toList();

      qualifiedIllustrationsCountNotifier.value++;

      if (GameConstants.SEEMATCH) {
        requestSetState();
      }

      _checkLevelEndConditions();
    }
  }

  void _checkLevelEndConditions() {
    final illustrationsPerLevel = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL];

    if (qualifiedIllustrationsCountNotifier.value >= (illustrationsPerLevel ?? 0) && !levelEndedNotifier.value) {
      levelEndedNotifier.value = true;
      _endLevel();
    }
  }

  void _endLevel() {
    pauseGame();

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

  void _showEndLevelDialogInternal(String title, String message, bool levelWon) {
    Future.delayed(const Duration(milliseconds: 100), () {
      showEndLevelDialog(title, message, levelWon);
    });
  }

  List<Illustration> get currentReferences => List.unmodifiable(_availableReferenceForLevel);
  List<MovingIllustration> get correctLeftIllustrations => List.unmodifiable(_leftContainer.correctIllustrations);
  List<MovingIllustration> get correctRightIllustrations => List.unmodifiable(_rightContainer.correctIllustrations);

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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameController _gameController;

  bool _isLeftTopHighlighted = false;
  bool _isLeftBottomHighlighted = false;
  bool _isRightTopHighlighted = false;
  bool _isRightBottomHighlighted = false;

  double _screenWidth = 0;
  double _screenHeight = 0;

  MovingIllustration? _draggedIllustration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _gameController = GameController(
      context: context,
      requestSetState: () {
        if (mounted) {
          setState(() {});
        }
      },
      showEndLevelDialog: _showEndLevelDialog,
      showSnackBar: _showSnackBar,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaQuery = MediaQuery.of(context);
      final initialScreenWidth = mediaQuery.size.width;
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
    _gameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _gameController.pauseGame();
    } else if (state == AppLifecycleState.resumed) {
      if (_gameController.isPausedNotifier.value && !_gameController.levelEndedNotifier.value) {
        _gameController.resumeGame();
      }
    }
  }

  void _onPanStart(MovingIllustration illustration) {
    if (_gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value) return;

    setState(() {
      _draggedIllustration = illustration;
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
      illustration.x += details.delta.dx;
      illustration.y += details.delta.dy;

      illustration.x = illustration.x.clamp(0.0, _screenWidth - illustration.size);
      illustration.y = illustration.y.clamp(0.0, _screenHeight - illustration.size);

      _updateHighlightedAreas(illustration.x + illustration.size / 2, illustration.y + illustration.size / 2);
    });
  }

  void _onPanEnd(DragEndDetails details, MovingIllustration illustration) {
    if (_draggedIllustration != illustration) return;

    final bool wasPausedOrEnded = _gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value;

    final dropX = illustration.x + illustration.size / 2;
    final dropY = illustration.y + illustration.size / 2;

    setState(() {
      illustration.isBeingDragged = false;
      _draggedIllustration = null;
      _resetHighlightedAreas();
    });

    if (wasPausedOrEnded) return;

    _gameController.handleDrop(illustration, dropX, dropY);
  }

  void _updateHighlightedAreas(double currentX, double currentY) {
    if (_gameController.levelEndedNotifier.value) return;

    bool needsUpdate = false;
    final double dropZoneWidth = _screenWidth / 3;

    final bool isOnLeftSide = currentX < dropZoneWidth;
    final bool isOnRightSide = currentX > _screenWidth - dropZoneWidth;

    final bool newLeftHighlight = isOnLeftSide && !_gameController.levelEndedNotifier.value;
    if (newLeftHighlight != _isLeftTopHighlighted) {
      _isLeftTopHighlighted = newLeftHighlight;
      _isLeftBottomHighlighted = newLeftHighlight;
      needsUpdate = true;
    }

    final bool newRightHighlight = isOnRightSide && !_gameController.levelEndedNotifier.value;
    if (newRightHighlight != _isRightTopHighlighted) {
      _isRightTopHighlighted = newRightHighlight;
      _isRightBottomHighlighted = newRightHighlight;
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  void _resetHighlightedAreas() {
    if (_isLeftTopHighlighted || _isLeftBottomHighlighted || _isRightTopHighlighted || _isRightBottomHighlighted) {
      setState(() {
        _isLeftTopHighlighted = false;
        _isLeftBottomHighlighted = false;
        _isRightTopHighlighted = false;
        _isRightBottomHighlighted = false;
      });
    }
  }

  void _showEndLevelDialog(String title, String message, bool levelWon) {
    if (!mounted || _screenWidth <= 0) return;

    final maxLevel = GameConstants.MAX_LEVEL;
    final bool isLastLevel = (GameConstants.NIVEL >= maxLevel);

    final int newsize = 10;
    final double dialogTitleSize = max(16.0, _screenWidth / (20 + newsize));
    final double dialogMessageSize = max(13.0, _screenWidth / (25 + newsize));
    final double dialogButtonSize = max(13.0, _screenWidth / (25 + newsize));

    showDialog(
      context: context,
      barrierDismissible: false,
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
                Navigator.of(context).pop();
                _gameController.resetGame();
              },
            ),

            if (levelWon && !isLastLevel)
              TextButton(
                child: Text("Continuar", style: TextStyle(fontSize: dialogButtonSize)),
                onPressed: () {
                  Navigator.of(context).pop();
                  _gameController.nextLevel();
                },
              ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, bool isSuccess, double x, double y) {
    if (!mounted || _screenHeight <= 0 || _screenWidth <= 0) return;

    final bottomMargin = max(20.0, _screenHeight - y - 30).clamp(20.0, _screenHeight - 60.0);

    final leftMargin = max(10.0, x - 80).clamp(10.0, _screenWidth - 170.0);

    final rightMargin = max(10.0, _screenWidth - x - 80).clamp(10.0, _screenWidth - 170.0);

    final double snackBarFontSize = max(12.0, _screenWidth / 60);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: snackBarFontSize)),
        duration: const Duration(milliseconds: 800),
        backgroundColor: isSuccess ? Colors.green : const Color.fromARGB(255, 175, 76, 76),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: bottomMargin, left: leftMargin, right: rightMargin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentScreenWidth = mediaQuery.size.width;
    final double appBarHeight = AppBar().preferredSize.height;
    final double topPadding = mediaQuery.padding.top;
    final currentScreenHeight = mediaQuery.size.height - topPadding - appBarHeight;

    if (currentScreenWidth > 0 &&
        currentScreenHeight > 0 &&
        (currentScreenWidth != _screenWidth || currentScreenHeight != _screenHeight)) {
      _screenWidth = currentScreenWidth;
      _screenHeight = currentScreenHeight;

      if (_gameController.screenWidth > 0) {
        _gameController.screenWidth = _screenWidth;
        _gameController.screenHeight = _screenHeight;
      }
    }

    final int newsize = 10;
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

          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.qualifiedIllustrationsCountNotifier,
                builder: (context, count, _) {
                  final total = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL] ?? 0;
                  return Text("$count/$total", style: TextStyle(fontSize: appBarCounterSize, color: Colors.white70));
                },
              ),
            ),
          ),

          IconButton(
            icon: Icon(GameConstants.SEEMATCH ? Icons.visibility_off : Icons.visibility),
            tooltip: GameConstants.SEEMATCH ? "Ocultar Coincidencias" : "Mostrar Coincidencias",
            onPressed: () {
              setState(() {
                GameConstants.SEEMATCH = !GameConstants.SEEMATCH;
              });

              _gameController.requestSetState();
            },
          ),

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

      body: ValueListenableBuilder<List<MovingIllustration>>(
        valueListenable: _gameController.movingIllustrationsNotifier,
        builder: (context, movingIllustrations, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: _gameController.isPausedNotifier,
            builder: (context, isPaused, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: _gameController.levelEndedNotifier,
                builder: (context, levelEnded, _) {
                  if (_screenWidth <= 0 || _screenHeight <= 0) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Stack(
                    children: [
                      _buildBackgroundAndDropZones(),

                      ..._buildFallingIllustrations(movingIllustrations),

                      ..._buildPlacedIllustrations(_gameController.correctLeftIllustrations, true),
                      ..._buildPlacedIllustrations(_gameController.correctRightIllustrations, false),

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

  Widget _buildBackgroundAndDropZones() {
    if (_screenWidth <= 0 || _screenHeight <= 0) return const SizedBox.shrink();

    final double zoneWidth = _screenWidth / 3;

    final references = _gameController.currentReferences;

    final double referenceImageSize = min(zoneWidth * 0.6, (_screenHeight / 2) * 0.4);

    final bool hasEnoughReferences = references.length >= 2;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildDropZoneArea(
                isHighlighted: _isLeftTopHighlighted,
                child:
                    hasEnoughReferences
                        ? _buildReferenceWidget(references[0], referenceImageSize)
                        : _buildPlaceholderReference(referenceImageSize, "Cargando..."),
              ),

              Container(width: zoneWidth, color: Colors.transparent),

              _buildDropZoneArea(
                isHighlighted: _isRightTopHighlighted,
                child:
                    hasEnoughReferences
                        ? _buildReferenceWidget(references[1], referenceImageSize)
                        : _buildPlaceholderReference(referenceImageSize, "Cargando..."),
              ),
            ],
          ),
        ),

        Expanded(
          child: Row(
            children: [
              _buildDropZoneArea(isHighlighted: _isLeftBottomHighlighted),

              Container(width: zoneWidth, color: Colors.transparent),

              _buildDropZoneArea(isHighlighted: _isRightBottomHighlighted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropZoneArea({required bool isHighlighted, Widget? child}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _gameController.levelEndedNotifier,
      builder: (context, levelEnded, _) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color:
                  isHighlighted ? Colors.amber.withAlpha((0.3 * 255).toInt()) : Colors.blueGrey.withAlpha((0.08 * 255).toInt()),
              border: Border.all(color: Colors.grey.withAlpha((0.2 * 255).toInt()), width: 1),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildReferenceWidget(Illustration reference, double size) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.asset(
        reference.path,
        width: size,
        height: size,
        fit: BoxFit.contain,

        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: Colors.red.shade100,
            child: Icon(Icons.broken_image, size: size * 0.6, color: Colors.red.shade700),
          );
        },
      ),
    );
  }

  List<Widget> _buildFallingIllustrations(List<MovingIllustration> illustrations) {
    if (_gameController.levelEndedNotifier.value) return [];

    return illustrations.map((illustration) {
      return Positioned(
        key: ValueKey(illustration.illustration.name),
        left: illustration.x,
        top: illustration.y,

        child: GestureDetector(
          onPanStart: (_) => _onPanStart(illustration),
          onPanUpdate: (details) => _onPanUpdate(details, illustration),
          onPanEnd: (details) => _onPanEnd(details, illustration),

          child: MovingIllustrationWidget(illustration: illustration),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPlacedIllustrations(List<MovingIllustration> placedList, bool isLeft) {
    if (!GameConstants.SEEMATCH || _screenWidth <= 0) {
      return [];
    }

    const double placedSize = 30.0;
    const double spacing = 4.0;
    const double bottomMargin = 8.0;
    const double sideMargin = 6.0;
    final double containerWidth = _screenWidth / 3;

    int maxItemsPerRow = ((containerWidth - 2 * sideMargin + spacing) / (placedSize + spacing)).floor();
    maxItemsPerRow = max(1, maxItemsPerRow);

    List<Widget> positionedWidgets = [];

    for (int i = 0; i < placedList.length; i++) {
      int rowIndex = i ~/ maxItemsPerRow;
      int colIndex = i % maxItemsPerRow;

      double horizontalPosition = sideMargin + colIndex * (placedSize + spacing);

      double verticalPosition = bottomMargin + rowIndex * (placedSize + spacing);

      positionedWidgets.add(
        Positioned(
          left: isLeft ? horizontalPosition : null,
          right: !isLeft ? horizontalPosition : null,
          bottom: verticalPosition,
          child: Image.asset(
            placedList[i].illustration.path,
            key: ValueKey("placed_${placedList[i].illustration.name}"),
            width: placedSize,
            height: placedSize,
            fit: BoxFit.contain,

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
    return positionedWidgets;
  }

  Widget _buildPauseOverlay() {
    if (_screenWidth <= 0) return const SizedBox.shrink();

    final double pauseTitleSize = max(22.0, _screenWidth / 25);
    final double pauseButtonTextSize = max(16.0, _screenWidth / 20);
    final double pauseButtonIconSize = max(24.0, _screenWidth / 18);

    return Container(
      color: Colors.black.withAlpha((0.7 * 255).toInt()),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "JUEGO PAUSADO",
            style: TextStyle(color: Colors.white, fontSize: pauseTitleSize, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 40),

          ElevatedButton.icon(
            icon: Icon(Icons.play_arrow, size: pauseButtonIconSize),
            label: const Text("Continuar"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: TextStyle(fontSize: pauseButtonTextSize),
            ),

            onPressed: _gameController.resumeGame,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderReference(double size, String text) {
    final double placeholderFontSize = max(8.0, size / 6.6);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
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
