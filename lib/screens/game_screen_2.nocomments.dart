import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/game_constants.dart';
import '../models/illustration.dart';
import '../models/moving_illustration.dart';
import '../data/illustration_data.dart' as data;
import '../widgets/moving_illustration_widget_2.dart';

class GameController {
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

  final Random _random = Random();
  List<Illustration> _illustrationsDataForLevel = [];
  List<Illustration> _availableReferenceForLevel = [];

  Timer? _levelTimer;
  Duration _levelDuration = Duration.zero;
  bool _timedOut = false;

  double screenWidth = 0;
  double screenHeight = 0;

  final double padding = 10.0;

  GameController({
    required this.requestSetState,
    required this.showEndLevelDialog,
    required this.showSnackBar,
    required this.context,
  });

  void initializeGame(double width, double height) {
    bool dimensionsChanged = screenWidth != width || screenHeight != height;
    screenWidth = width;
    screenHeight = height;

    if (width > 0 && height > 0) {
      _precacheImages();
      if (dimensionsChanged || _illustrationsDataForLevel.isEmpty) {
        _initializeLevelData();
        _populateStaticIllustrations();

        if (!isPausedNotifier.value) {
          _startTimer();
        }
      } else {
        _populateStaticIllustrations();
        if (!isPausedNotifier.value && _levelTimer == null && !levelEndedNotifier.value) {
          _startTimer();
        }
      }
    } else {}
  }

  void _precacheImages() {
    for (var illustration in data.availableReference.where((il) => il.nivel == GameConstants.NIVEL)) {
      precacheImage(AssetImage(illustration.path), context);
    }
    for (var illustration in data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL)) {
      precacheImage(AssetImage(illustration.path), context);
    }
  }

  void _initializeLevelData() {
    List<Illustration> allIllustrationsForLevel =
        data.availableIllustrations.where((il) => il.nivel == GameConstants.NIVEL).toList();
    allIllustrationsForLevel.shuffle(_random);

    int limit = GameConstants.ILLUSTRATIONS_PER_LEVEL[GameConstants.NIVEL] ?? allIllustrationsForLevel.length;
    _illustrationsDataForLevel = allIllustrationsForLevel.take(limit).toList();

    _availableReferenceForLevel = data.availableReference.where((il) => il.nivel == GameConstants.NIVEL).toList();

    _levelDuration = GameConstants.LEVEL_DURATION[GameConstants.NIVEL] ?? const Duration(seconds: 60);

    remainingTimeNotifier.value = _levelDuration;
    _timedOut = false;
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
    _cancelTimer();
    scoreNotifier.value = 0;
    availableIllustrationsNotifier.value = [];
    qualifiedIllustrationsCountNotifier.value = 0;
    isPausedNotifier.value = false;
    levelEndedNotifier.value = false;
    _timedOut = false;

    if (screenWidth > 0 && screenHeight > 0) {
      _initializeLevelData();
      _populateStaticIllustrations();
      _startTimer();
    } else {}
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
    _timedOut = false;

    if (screenWidth > 0 && screenHeight > 0) {
      _precacheImages();
      _initializeLevelData();
      _populateStaticIllustrations();
      _startTimer();
    }
  }

  void handleDrop(MovingIllustration illustration, double dropX, double dropY, int targetIndex) {
    if (levelEndedNotifier.value) {
      return;
    }

    if (_availableReferenceForLevel.isEmpty || targetIndex < 0 || targetIndex >= _availableReferenceForLevel.length) {
      showSnackBar('Error: Referencia no válida', false, dropX, dropY);
      _removeIllustration(illustration);
      _checkLevelEndConditions();
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
    _checkLevelEndConditions();
  }

  void _removeIllustration(MovingIllustration illustrationToRemove) {
    final currentList = List<MovingIllustration>.from(availableIllustrationsNotifier.value);
    bool removed = currentList.remove(illustrationToRemove);
    if (removed) {
      availableIllustrationsNotifier.value = currentList;
      qualifiedIllustrationsCountNotifier.value++;
    }
  }

  void _checkLevelEndConditions() {
    final totalIllustrationsForLevel = _illustrationsDataForLevel.length;

    if (totalIllustrationsForLevel > 0 &&
        qualifiedIllustrationsCountNotifier.value >= totalIllustrationsForLevel &&
        !levelEndedNotifier.value) {
      _cancelTimer();
      levelEndedNotifier.value = true;
      _endLevel();
    } else if (totalIllustrationsForLevel == 0 && !levelEndedNotifier.value) {
      _cancelTimer();
      levelEndedNotifier.value = true;
      _endLevel();
    }
  }

  void _startTimer() {
    _cancelTimer();

    if (_levelDuration <= Duration.zero || isPausedNotifier.value || levelEndedNotifier.value) {
      return;
    }

    if (remainingTimeNotifier.value <= Duration.zero || remainingTimeNotifier.value > _levelDuration) {
      remainingTimeNotifier.value = _levelDuration;
    }

    _levelTimer = Timer.periodic(const Duration(seconds: 1), _timerTick);
  }

  void _timerTick(Timer timer) {
    if (isPausedNotifier.value || levelEndedNotifier.value) {
      _cancelTimer();
      return;
    }

    final newTime = remainingTimeNotifier.value - const Duration(seconds: 1);

    if (newTime <= Duration.zero) {
      remainingTimeNotifier.value = Duration.zero;
      timer.cancel();
      _triggerTimeOutEnd();
    } else {
      remainingTimeNotifier.value = newTime;
    }
  }

  void _cancelTimer() {
    if (_levelTimer?.isActive ?? false) {
      _levelTimer!.cancel();
      _levelTimer = null;
    }
  }

  void _triggerTimeOutEnd() {
    if (!levelEndedNotifier.value) {
      _timedOut = true;
      levelEndedNotifier.value = true;
      pauseGame();
      _endLevel();
    }
  }

  void _endLevel() {
    _cancelTimer();
    pauseGame();

    final winningScore =
        GameConstants.WINNING_SCORE_THRESHOLD[GameConstants.NIVEL] ?? _illustrationsDataForLevel.length;
    final score = scoreNotifier.value;

    final bool levelWon = score >= winningScore && !_timedOut;

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
      } else {}
    });
  }

  List<Illustration> get currentReferences => List.unmodifiable(_availableReferenceForLevel);

  void dispose() {
    _cancelTimer();
    scoreNotifier.dispose();
    isPausedNotifier.dispose();
    levelEndedNotifier.dispose();
    qualifiedIllustrationsCountNotifier.dispose();
    availableIllustrationsNotifier.dispose();
    remainingTimeNotifier.dispose();
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late final GameController _gameController;
  DateTime? _lastScrollUpdateTime;

  int? _highlightedReferenceIndex;
  double _screenWidth = 0;
  double _screenHeight = 0;
  MovingIllustration? _draggedIllustration;
  Offset? _originalPosition;

  late AnimationController _carouselAnimationController;
  late ScrollController _carouselScrollController;

  double _totalReferenceWidth = 0;

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
    _carouselAnimationController = AnimationController(duration: const Duration(seconds: 10), vsync: this)
      ..addListener(_scrollListener);

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

  double _calculateCarouselSpeedPixelsPerSecond(double rpm) {
    if (_totalReferenceWidth <= 0 || rpm <= 0) {
      return 0.0;
    }

    double speed = (rpm / 60.0) * _totalReferenceWidth;
    return speed;
  }

  void _scrollListener() {
    if (!_carouselScrollController.hasClients ||
        _totalReferenceWidth <= 0 ||
        !_carouselAnimationController.isAnimating) {
      _lastScrollUpdateTime = null;
      return;
    }

    final DateTime now = DateTime.now();
    double deltaSeconds = 0;

    if (_lastScrollUpdateTime != null) {
      deltaSeconds = now.difference(_lastScrollUpdateTime!).inMilliseconds / 1000.0;
    }

    _lastScrollUpdateTime = now;

    const double maxDeltaThreshold = 0.1;
    const double fallbackDelta = 1.0 / 60.0;
    if (deltaSeconds <= 0 || deltaSeconds > maxDeltaThreshold) {
      deltaSeconds = fallbackDelta;
    }

    double speedPixelsPerSecond = _calculateCarouselSpeedPixelsPerSecond(
      GameConstants.CAROUSEL_RPM[GameConstants.NIVEL] ?? 0.0,
    );

    double moveAmount = speedPixelsPerSecond * deltaSeconds;

    if (moveAmount == 0) return;

    double currentOffset = _carouselScrollController.offset;
    double largeRange = _totalReferenceWidth * 5000;
    double newOffset = (currentOffset + moveAmount) % largeRange;

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
        _lastScrollUpdateTime = null;
        _carouselAnimationController.repeat();
      }
    }
  }

  void _stopCarouselAnimation() {
    if (_carouselAnimationController.isAnimating) {
      _carouselAnimationController.stop();
    }
    _lastScrollUpdateTime = null;
  }

  void _calculateTotalReferenceWidth() {
    final references = _gameController.currentReferences;
    final numberOfReferences = references.length;
    if (numberOfReferences > 0 && _screenWidth > 0) {
      final double sectionWidth = _screenWidth / numberOfReferences;
      _totalReferenceWidth = sectionWidth * numberOfReferences;
    } else {
      _totalReferenceWidth = 0;
    }
  }

  void _initializeDimensionsAndGame() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.of(context);

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
        if (mounted && dimensionsChanged) setState(() {});
      } else {
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
      _gameController.pauseGame();
      _stopCarouselAnimation();
    } else if (state == AppLifecycleState.resumed) {
      if (!_gameController.levelEndedNotifier.value) {
        if (!_gameController.isPausedNotifier.value) {
          _gameController.resumeGame();
          _startCarouselAnimation();
        }
      }
    }
  }

  void _onPanStart(MovingIllustration illustration) {
    if (_gameController.isPausedNotifier.value || _gameController.levelEndedNotifier.value) {
      return;
    }

    setState(() {
      _draggedIllustration = illustration;
      illustration.isBeingDragged = true;
      _originalPosition = Offset(illustration.x, illustration.y);

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

        final double scrolledX = listRelativeX + _carouselScrollController.offset;
        final int potentialIndex = (scrolledX / sectionWidth).floor();

        targetIndex = potentialIndex % numberOfReferences;
      }
      _gameController.handleDrop(endedIllustration, dropX, dropY, targetIndex);
    } else {
      if (originalPos != null) {
        _snapIllustrationBack(endedIllustration, originalPos);
      }
    }
  }

  void _snapIllustrationBack(MovingIllustration illustration, Offset originalPosition) {
    illustration.x = originalPosition.dx;
    illustration.y = originalPosition.dy;

    final currentList = List<MovingIllustration>.from(_gameController.availableIllustrationsNotifier.value);
    int index = currentList.indexWhere((item) => item == illustration);
    if (index != -1) {
      _gameController.availableIllustrationsNotifier.value = List.from(currentList);
    }

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

  void _showEndLevelDialog(String title, String message, bool levelWon) {
    if (!mounted || _screenWidth <= 0) return;
    _stopCarouselAnimation();

    final maxLevel = GameConstants.MAX_LEVEL;
    final bool isLastLevel = (GameConstants.NIVEL >= maxLevel);

    final int newsize = 10;

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
                _gameController.resetGame();
                _startCarouselAnimation();
              },
            ),
            if (levelWon && !isLastLevel)
              TextButton(
                child: Text("Siguiente Nivel", style: TextStyle(fontSize: dialogButtonSize)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _gameController.nextLevel();
                  _startCarouselAnimation();
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

    if (finalLeftMargin + finalRightMargin + snackBarWidthEstimate > _screenWidth) {
      finalLeftMargin = horizontalMargin;
      finalRightMargin = horizontalMargin;
    }

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

  @override
  Widget build(BuildContext context) {
    _initializeDimensionsAndGame();

    final int newsize = 10;

    final double appBarTitleSize = max(10.0, _screenWidth / (22 + newsize));
    final double appBarScoreSize = max(9.0, _screenWidth / (25 + newsize));

    final double appBarActionSize = max(6.0, _screenWidth / (25 + newsize));

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: _gameController.qualifiedIllustrationsCountNotifier,
          builder: (context, _, __) {
            return Text("LSM Game - Nivel ${GameConstants.NIVEL}", style: TextStyle(fontSize: appBarTitleSize));
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Center(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _gameController.remainingTimeNotifier,
                builder: (context, remainingTime, _) {
                  String formattedTime = _timeFormatter.format(DateTime(0).add(remainingTime));
                  return Text(
                    "Tiempo: $formattedTime",
                    style: TextStyle(
                      fontSize: appBarActionSize,

                      color: remainingTime.inSeconds <= 10 ? Colors.redAccent : Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _gameController.scoreNotifier,
                builder: (context, score, _) => Text("Puntos: $score", style: TextStyle(fontSize: appBarScoreSize)),
              ),
            ),
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
      body: ValueListenableBuilder<List<MovingIllustration>>(
        valueListenable: _gameController.availableIllustrationsNotifier,
        builder: (context, availableIllustrations, _) {
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
                      _buildDropZonesAndBackground(),

                      ..._buildDraggableIllustrations(availableIllustrations),

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

  Widget _buildDropZonesAndBackground() {
    if (_screenWidth <= 0 || _screenHeight <= 0) return const SizedBox.shrink();

    final double zoneHeight = _screenHeight / 2;
    final references = _gameController.currentReferences;
    final numberOfReferences = references.length;

    return Positioned.fill(
      child: Column(
        children: [
          SizedBox(
            height: zoneHeight,
            width: double.infinity,
            child:
                numberOfReferences > 0
                    ? ListView.builder(
                      controller: _carouselScrollController,
                      scrollDirection: Axis.horizontal,

                      itemCount: 10000 * numberOfReferences,
                      itemBuilder: (context, index) {
                        final actualIndex = index % numberOfReferences;
                        final reference = references[actualIndex];

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
                      height: zoneHeight,
                      width: double.infinity,
                      color: Colors.blueGrey.withAlpha((0.12 * 255).toInt()),
                      alignment: Alignment.center,
                      child: _buildPlaceholderReference(60.0 * 1.5, "Cargando..."),
                    ),
          ),

          Container(
            width: double.infinity,
            height: zoneHeight,
            decoration: BoxDecoration(
              color: Colors.blueGrey.withAlpha((0.05 * 255).toInt()),
              border: Border(top: BorderSide(color: Colors.grey.withAlpha((0.15 * 255).toInt()), width: 1)),
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
    final double referenceImageSize = min(width * 0.5, height * 0.4);

    return ValueListenableBuilder<bool>(
      valueListenable: _gameController.levelEndedNotifier,
      builder: (context, levelEnded, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color:
                isHighlighted && !levelEnded
                    ? Colors.amber.withAlpha((0.3 * 255).toInt())
                    : Colors.blueGrey.withAlpha((0.12 * 255).toInt()),
            border: Border(right: BorderSide(color: Colors.grey.withAlpha((0.2 * 255).toInt()), width: 1)),
          ),
          alignment: Alignment.center,
          child: _buildReferenceWidget(reference, referenceImageSize),
        );
      },
    );
  }

  Widget _buildReferenceWidget(Illustration reference, double size) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Opacity(
        opacity: 0.9,
        child: Image.asset(
          reference.path,
          width: size,
          height: size,
          fit: BoxFit.contain,

          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              color: Colors.pink.shade100,
              child: Icon(Icons.error_outline, size: size * 0.6, color: Colors.pink.shade700),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderReference(double size, String text) {
    final double placeholderFontSize = max(8.0, size / 6.6);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300.withAlpha((0.5 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400.withAlpha((0.7 * 255).toInt())),
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

      return Positioned(
        key: ValueKey(illustration.illustration.name),
        left: illustration.x,
        top: illustration.y,
        width: currentIllustrationSize,
        height: currentIllustrationSize,
        child: GestureDetector(
          onPanStart: (_) => _onPanStart(illustration),
          onPanUpdate: (details) => _onPanUpdate(details, illustration),
          onPanEnd: (details) => _onPanEnd(details, illustration),

          child: MovingIllustrationWidget(illustration: illustration),
        ),
      );
    }).toList();
  }

  Widget _buildPauseOverlay() {
    if (_screenWidth <= 0) return const SizedBox.shrink();

    final double pauseTitleSize = max(22.0, _screenWidth / 25);
    final double pauseButtonTextSize = max(16.0, _screenWidth / 20);
    final double pauseButtonIconSize = max(24.0, _screenWidth / 18);

    return Container(
      color: Colors.black.withAlpha((0.75 * 255).toInt()),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "JUEGO PAUSADO",
            style: TextStyle(
              color: Colors.white,

              fontSize: pauseTitleSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,

              shadows: [Shadow(blurRadius: 10.0, color: Colors.black54, offset: Offset(2.0, 2.0))],
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: Icon(Icons.play_arrow, size: pauseButtonIconSize),
            label: const Text("Continuar"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),

              textStyle: TextStyle(fontSize: pauseButtonTextSize, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () {
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
