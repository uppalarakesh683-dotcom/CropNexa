import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_screen.dart';

class AntigravityIntroScreen extends StatefulWidget {
  const AntigravityIntroScreen({super.key});

  @override
  State<AntigravityIntroScreen> createState() => _AntigravityIntroScreenState();
}

class _AntigravityIntroScreenState extends State<AntigravityIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _ambientController;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random(55);

  @override
  void initState() {
    super.initState();

    // 3.2 seconds total brand intro before smooth transition to Full-Screen Login
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _initLogoParticles();

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToLogin();
      }
    });

    _animController.forward();
  }

  void _initLogoParticles() {
    _particles.clear();
    const count = 36;
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final y = -40.0 + (t * 80.0);
      final widthFactor = math.sin(t * math.pi) * (1.0 - 0.22 * t);

      _particles.add(
        _Particle(
          targetX: -28.0 * widthFactor,
          targetY: y,
          initialX: (_random.nextDouble() - 0.5) * 200,
          initialY: (_random.nextDouble() - 0.5) * 200,
          isCyan: _random.nextBool(),
        ),
      );
      _particles.add(
        _Particle(
          targetX: 28.0 * widthFactor,
          targetY: y,
          initialX: (_random.nextDouble() - 0.5) * 200,
          initialY: (_random.nextDouble() - 0.5) * 200,
          isCyan: _random.nextBool(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF02120A),
      body: Stack(
        children: [
          // 1. DEEP GREEN CLEAN MOBILE AGRICULTURE BACKGROUND
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, child) {
              return CustomPaint(
                size: screenSize,
                painter: _DeepGreenBackgroundPainter(
                  ambientProgress: _ambientController.value,
                ),
              );
            },
          ),

          // 2. BRAND ANIMATION (LOGO -> CROP NEXA -> SMART FARMING INTELLIGENCE)
          AnimatedBuilder(
            animation: Listenable.merge([_animController, _ambientController]),
            builder: (context, child) {
              final t = _animController.value;

              // 0.0 - 0.35: Particles coalesce into leaf logo + bloom
              final convergence = Curves.easeInOutCubic.transform(
                (t / 0.35).clamp(0.0, 1.0),
              );
              final leafOpacity = Curves.easeIn.transform(
                ((t - 0.20) / (0.38 - 0.20)).clamp(0.0, 1.0),
              );

              // 0.35 - 0.65: CROP NEXA text appears with light sweep
              final textProgress = ((t - 0.35) / (0.65 - 0.35)).clamp(0.0, 1.0);
              final textOpacity = Curves.easeOut.transform(textProgress);
              final textScale = Tween<double>(begin: 0.94, end: 1.0).transform(
                Curves.easeOutCubic.transform(textProgress),
              );
              final lightSweepProgress = ((t - 0.40) / (0.75 - 0.40)).clamp(0.0, 1.0);

              // 0.65 - 0.85: Smart Farming Intelligence appears
              final taglineProgress = ((t - 0.65) / (0.85 - 0.65)).clamp(0.0, 1.0);
              final taglineOpacity = Curves.easeOut.transform(taglineProgress);

              final breathingGlow = (math.sin(_ambientController.value * math.pi * 2) + 1.0) * 0.5;

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Leaf Logo Emblem
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (leafOpacity > 0.05)
                            Opacity(
                              opacity: (leafOpacity * 0.85).clamp(0.0, 1.0),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00E676).withValues(
                                      alpha: 0.30 + (breathingGlow * 0.25),
                                    ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E676).withValues(
                                        alpha: 0.20 + (breathingGlow * 0.20),
                                      ),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Particle Canvas
                          CustomPaint(
                            size: const Size(120, 120),
                            painter: _IntroParticlePainter(
                              particles: _particles,
                              convergence: convergence,
                              ambient: _ambientController.value,
                            ),
                          ),

                          // Solid crisp leaf icon
                          if (leafOpacity > 0.1)
                            Opacity(
                              opacity: leafOpacity,
                              child: const Icon(
                                Icons.eco_rounded,
                                size: 52,
                                color: Color(0xFF7CFF9B),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // CROP NEXA title
                    if (textOpacity > 0.01)
                      Opacity(
                        opacity: textOpacity,
                        child: Transform.scale(
                          scale: textScale,
                          child: _buildCropNexaText(lightSweepProgress, breathingGlow),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Smart Farming Intelligence
                    if (taglineOpacity > 0.01)
                      Opacity(
                        opacity: taglineOpacity,
                        child: Column(
                          children: [
                            Container(
                              width: 58,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E676), Color(0xFF00E5FF)],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Smart Farming Intelligence',
                              style: TextStyle(
                                fontSize: 13.5,
                                letterSpacing: 2.2,
                                color: Color(0xFFC8E6C9),
                                fontWeight: FontWeight.w300,
                                shadows: [
                                  Shadow(color: Color(0xFF00E676), blurRadius: 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // 3. Skip Button (Top Right)
          Positioned(
            top: 48,
            right: 20,
            child: InkWell(
              onTap: _navigateToLogin,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SKIP',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.fast_forward_rounded,
                      size: 13,
                      color: Color(0xFF00E676),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropNexaText(double lightSweepProgress, double breathingGlow) {
    const textStyle = TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w900,
      letterSpacing: 6.0,
      color: Colors.white,
    );

    final baseText = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('CROP ', style: textStyle),
        Text(
          'NEXA',
          style: textStyle.copyWith(
            color: const Color(0xFF69F0AE),
            shadows: [
              Shadow(
                color: const Color(0xFF00E676).withValues(
                  alpha: 0.45 + (breathingGlow * 0.35),
                ),
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );

    if (lightSweepProgress > 0.0 && lightSweepProgress < 1.0) {
      return ShaderMask(
        shaderCallback: (bounds) {
          final sweepPos = (lightSweepProgress * 1.6) - 0.3;
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (sweepPos - 0.25).clamp(0.0, 1.0),
              sweepPos.clamp(0.0, 1.0),
              (sweepPos + 0.25).clamp(0.0, 1.0),
            ],
            colors: const [Colors.white, Color(0xFFE0F7FA), Colors.white],
          ).createShader(bounds);
        },
        child: baseText,
      );
    }

    return baseText;
  }
}

// Particle model
class _Particle {
  final double initialX;
  final double initialY;
  final double targetX;
  final double targetY;
  final bool isCyan;

  _Particle({
    required this.initialX,
    required this.initialY,
    required this.targetX,
    required this.targetY,
    required this.isCyan,
  });
}

class _IntroParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double convergence;
  final double ambient;

  _IntroParticlePainter({
    required this.particles,
    required this.convergence,
    required this.ambient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.5;
    final centerY = size.height * 0.5;

    for (final p in particles) {
      final curX = centerX + (p.initialX * (1.0 - convergence) + (p.targetX * convergence));
      final curY = centerY + (p.initialY * (1.0 - convergence) + (p.targetY * convergence));

      final alpha = (0.4 + (convergence * 0.6)).clamp(0.0, 1.0);
      final color = p.isCyan
          ? const Color(0xFF00E5FF).withValues(alpha: alpha)
          : const Color(0xFF00E676).withValues(alpha: alpha);

      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

      canvas.drawCircle(Offset(curX, curY), 1.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroParticlePainter oldDelegate) {
    return true;
  }
}

class _DeepGreenBackgroundPainter extends CustomPainter {
  final double ambientProgress;

  _DeepGreenBackgroundPainter({required this.ambientProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF02120A),
          Color(0xFF062215),
          Color(0xFF082C1B),
          Color(0xFF03160C),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Subtle edge foliage blurs
    _drawFoliageBlur(canvas, Offset(w * -0.15, h * 0.15), 140, const Color(0xFF00E676).withValues(alpha: 0.08));
    _drawFoliageBlur(canvas, Offset(w * 1.15, h * 0.35), 170, const Color(0xFF00B0FF).withValues(alpha: 0.06));
    _drawFoliageBlur(canvas, Offset(w * -0.10, h * 0.80), 160, const Color(0xFF00E676).withValues(alpha: 0.07));
    _drawFoliageBlur(canvas, Offset(w * 1.10, h * 0.90), 150, const Color(0xFF00E676).withValues(alpha: 0.08));

    // Subtle floating leaves and particles
    for (int i = 0; i < 14; i++) {
      final pProgress = (ambientProgress + (i * 0.071)) % 1.0;
      final px = (w * 0.08) + ((i * 49) % (w * 0.84));
      final py = (h * 0.95) - (pProgress * (h * 0.90));
      final alpha = (math.sin(pProgress * math.pi) * 0.35).clamp(0.0, 1.0);

      if (i % 2 == 0) {
        final leafPaint = Paint()..color = const Color(0xFF00E676).withValues(alpha: alpha);
        final leaf = Path();
        const leafSize = 3.5;
        leaf.moveTo(px, py - leafSize);
        leaf.quadraticBezierTo(px + leafSize, py, px, py + leafSize);
        leaf.quadraticBezierTo(px - leafSize, py, px, py - leafSize);
        leaf.close();
        canvas.drawPath(leaf, leafPaint);
      } else {
        final motePaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawCircle(Offset(px, py), 1.5, motePaint);
      }
    }
  }

  void _drawFoliageBlur(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.6);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _DeepGreenBackgroundPainter oldDelegate) {
    return true;
  }
}
