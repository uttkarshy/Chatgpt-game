import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kAppName = 'Tap Escape';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const TapEscapeApp());
}

class TapEscapeApp extends StatelessWidget {
  const TapEscapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        useMaterial3: true,
      ),
      home: const TapEscapeGame(),
    );
  }
}

class TapEscapeGame extends StatefulWidget {
  const TapEscapeGame({super.key});

  @override
  State<TapEscapeGame> createState() => _TapEscapeGameState();
}

class _TapEscapeGameState extends State<TapEscapeGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final math.Random _random = math.Random();
  final List<Obstacle> _obstacles = <Obstacle>[];

  Duration? _lastTick;
  bool _isGameOver = false;
  bool _soundEnabled = true;

  int _score = 0;
  double _ballX = 0;
  double _ballY = 0;
  double _ballRadius = 12;

  double _horizontalDirection = 1;
  double _horizontalSpeed = 120;
  double _verticalSpeed = 210;

  double _worldWidth = 0;
  double _worldHeight = 0;
  double _obstacleHeight = 22;
  double _spawnSpacing = 165;
  double _nextSpawnY = -80;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController.unbounded(vsync: this)
      ..addListener(_onTick)
      ..repeat(min: 0, max: 1, period: const Duration(milliseconds: 16));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    final Duration now = _ticker.lastElapsedDuration ?? Duration.zero;
    if (_lastTick == null) {
      _lastTick = now;
      return;
    }

    final double dt = (now - _lastTick!).inMicroseconds / 1e6;
    _lastTick = now;

    if (dt <= 0 || _worldWidth == 0 || _isGameOver) {
      return;
    }

    _updateWorld(dt.clamp(0.0, 0.04));
  }

  void _updateWorld(double dt) {
    _ballX += _horizontalDirection * _horizontalSpeed * dt;

    if (_ballX - _ballRadius <= 0) {
      _ballX = _ballRadius;
      _horizontalDirection = 1;
    } else if (_ballX + _ballRadius >= _worldWidth) {
      _ballX = _worldWidth - _ballRadius;
      _horizontalDirection = -1;
    }

    for (final Obstacle obstacle in _obstacles) {
      obstacle.y += _verticalSpeed * dt;

      final bool ballWithinBand = _ballY + _ballRadius >= obstacle.y &&
          _ballY - _ballRadius <= obstacle.y + obstacle.height;

      if (ballWithinBand) {
        final double gapLeft = obstacle.gapCenterX - obstacle.gapWidth / 2;
        final double gapRight = obstacle.gapCenterX + obstacle.gapWidth / 2;

        final bool hitsLeft = _ballX - _ballRadius < gapLeft;
        final bool hitsRight = _ballX + _ballRadius > gapRight;

        if (hitsLeft || hitsRight) {
          setState(() {
            _isGameOver = true;
          });
          return;
        }
      }

      if (!obstacle.scored && obstacle.y > _ballY + _ballRadius) {
        obstacle.scored = true;
        _score += 1;
      }
    }

    _obstacles.removeWhere((Obstacle o) => o.y > _worldHeight + o.height + 40);

    while (_nextSpawnY < 0) {
      _spawnObstacle(_nextSpawnY);
      _nextSpawnY -= _spawnSpacing;
    }

    _nextSpawnY += _verticalSpeed * dt;

    setState(() {});
  }

  void _spawnObstacle(double yPosition) {
    final double gapWidth = _worldWidth * 0.34;
    final double horizontalPadding = _worldWidth * 0.15;
    final double minCenter = horizontalPadding + gapWidth / 2;
    final double maxCenter = _worldWidth - horizontalPadding - gapWidth / 2;

    final double gapCenter = minCenter + _random.nextDouble() * (maxCenter - minCenter);

    _obstacles.add(
      Obstacle(
        y: yPosition,
        height: _obstacleHeight,
        gapCenterX: gapCenter,
        gapWidth: gapWidth,
      ),
    );
  }

  void _initializeWorld(Size size) {
    if (_worldWidth == size.width && _worldHeight == size.height) {
      return;
    }

    _worldWidth = size.width;
    _worldHeight = size.height;

    final double scale = size.shortestSide / 400;
    _ballRadius = 12 * scale;
    _horizontalSpeed = 130 * scale;
    _verticalSpeed = 230 * scale;
    _obstacleHeight = 22 * scale;
    _spawnSpacing = 170 * scale;

    _resetGameState();
  }

  void _resetGameState() {
    _isGameOver = false;
    _score = 0;
    _horizontalDirection = 1;
    _ballX = _worldWidth / 2;
    _ballY = _worldHeight * 0.72;
    _nextSpawnY = -80;
    _obstacles.clear();

    for (int i = 0; i < 7; i++) {
      _spawnObstacle(_nextSpawnY);
      _nextSpawnY -= _spawnSpacing;
    }
  }

  void _onTap() {
    if (_worldWidth == 0) return;

    setState(() {
      if (_isGameOver) {
        _resetGameState();
      } else {
        _horizontalDirection *= -1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = Size(constraints.maxWidth, constraints.maxHeight);
            _initializeWorld(size);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: Stack(
                children: <Widget>[
                  CustomPaint(
                    size: size,
                    painter: GamePainter(
                      ballX: _ballX,
                      ballY: _ballY,
                      ballRadius: _ballRadius,
                      obstacles: _obstacles,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        '$_score',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE0F8FF),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Sound toggle (placeholder)',
                      onPressed: () {
                        setState(() {
                          _soundEnabled = !_soundEnabled;
                        });
                      },
                      icon: Icon(
                        _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: const Color(0xFF7EF9FF),
                      ),
                    ),
                  ),
                  if (_isGameOver)
                    Container(
                      color: Colors.black.withValues(alpha: 0.28),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Game Over',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF5FA2),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Tap to Restart',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE0F8FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class Obstacle {
  Obstacle({
    required this.y,
    required this.height,
    required this.gapCenterX,
    required this.gapWidth,
  });

  double y;
  final double height;
  final double gapCenterX;
  final double gapWidth;
  bool scored = false;
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.ballX,
    required this.ballY,
    required this.ballRadius,
    required this.obstacles,
  });

  final double ballX;
  final double ballY;
  final double ballRadius;
  final List<Obstacle> obstacles;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0xFF0F0F1A);
    canvas.drawRect(Offset.zero & size, background);

    final Paint glowPaint = Paint()
      ..color = const Color(0xFF27E1FF).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    final Paint ballPaint = Paint()
      ..color = const Color(0xFF7EF9FF)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(ballX, ballY), ballRadius * 2.0, glowPaint);
    canvas.drawCircle(Offset(ballX, ballY), ballRadius, ballPaint);

    final Paint obstacleGlow = Paint()
      ..color = const Color(0xFF5A64FF).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final Paint obstaclePaint = Paint()..color = const Color(0xFF7C84FF);

    for (final Obstacle obstacle in obstacles) {
      final double gapLeft = obstacle.gapCenterX - obstacle.gapWidth / 2;
      final double gapRight = obstacle.gapCenterX + obstacle.gapWidth / 2;

      final Rect left = Rect.fromLTWH(0, obstacle.y, gapLeft, obstacle.height);
      final Rect right =
          Rect.fromLTWH(gapRight, obstacle.y, size.width - gapRight, obstacle.height);

      canvas.drawRect(left.inflate(2), obstacleGlow);
      canvas.drawRect(right.inflate(2), obstacleGlow);
      canvas.drawRect(left, obstaclePaint);
      canvas.drawRect(right, obstaclePaint);
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.ballX != ballX ||
        oldDelegate.ballY != ballY ||
        oldDelegate.obstacles != obstacles;
  }
}
