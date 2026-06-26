import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pocket_tutor/app/theme/app_colors.dart';
import 'package:pocket_tutor/core/constants/app_strings.dart';
import 'package:pocket_tutor/core/navigation/app_routes.dart';
import 'package:pocket_tutor/core/network/connectivity_service.dart';
import 'package:pocket_tutor/core/services/offline_sync_service.dart';
import 'package:pocket_tutor/core/services/notification_service.dart';
import 'package:pocket_tutor/core/storage/hive_service.dart';
import 'package:pocket_tutor/features/auth/data/auth_repository.dart';
import 'package:pocket_tutor/features/chat/data/chat_repository.dart';
import 'package:pocket_tutor/firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  StreamSubscription? _authSub;
  var _navigated = false;

  // Logo float
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  // Glow pulse
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  // Tagline fade-in
  late final AnimationController _tagCtrl;
  late final Animation<double> _tagFade;
  late final Animation<Offset> _tagSlide;

  // Button fade-in
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnFade;

  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();

    // Float
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Glow
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Tagline
    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);
    _tagSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _tagCtrl.forward();
    });

    // Button
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _btnCtrl.forward();
    });

    // Start App Initialization
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() {
      _initError = null;
      _initialized = false;
    });

    try {
      // 1. Initialize core services
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await HiveService.instance.init();

      // 2. Initialize remaining services in parallel
      await Future.wait([
        ConnectivityService.instance.init(),
        NotificationService.instance.init(),
        OfflineSyncService.instance.init(),
      ]);

      // 3. Set up repository listeners
      ChatRepository.instance.init();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      // 4. Start auth state listener now that services are ready
      _startAuthListener();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  void _startAuthListener() {
    _authSub = AuthRepository.instance.authStateChanges.listen((user) {
      if (!mounted || _navigated) return;

      if (user != null) {
        _navigated = true;
        AppRoutes.goToHome(context);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    _tagCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated mesh background
          Positioned.fill(child: _MeshBackground()),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Floating logo with glow ring
                  AnimatedBuilder(
                    animation: Listenable.merge([_floatAnim, _glowAnim]),
                    builder: (_, child) {
                      return Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(
                                      alpha: _glowAnim.value * 0.4,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // Inner card
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                gradient: AppColors.heroGradient,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: _glowAnim.value * 0.6,
                                    ),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                "assets/images/logo.png",
                                fit: BoxFit.fill
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // App name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.heroGradient.createShader(bounds),
                    child: const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tagline with slide-fade
                  FadeTransition(
                    opacity: _tagFade,
                    child: SlideTransition(
                      position: _tagSlide,
                      child: const Text(
                        AppStrings.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // AI badge pill
                  FadeTransition(
                    opacity: _tagFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.4),
                        ),
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.online,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            AppStrings.aiBadge,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryAccent,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Get Started button
                  FadeTransition(
                    opacity: _btnFade,
                    child: _GetStartedButton(
                      isLoading: !_initialized && _initError == null,
                      isError: _initError != null,
                      onTap: () {
                        if (_initError != null) {
                          _initApp();
                        } else if (_initialized) {
                          AppRoutes.openLogin(context);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Mesh Background ──────────────────────────────────────────────────
class _MeshBackground extends StatefulWidget {
  @override
  State<_MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<_MeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return CustomPaint(painter: _MeshPainter(_ctrl.value));
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.background,
    );

    // Moving orbs
    final orbs = [
      (
        cx: size.width * 0.2 + 40 * math.sin(t * 2 * math.pi),
        cy: size.height * 0.25 + 30 * math.cos(t * 2 * math.pi),
        r: 180.0,
        color: AppColors.primary.withValues(alpha: 0.15),
      ),
      (
        cx: size.width * 0.8 + 50 * math.cos(t * 2 * math.pi),
        cy: size.height * 0.6 + 40 * math.sin(t * 2 * math.pi),
        r: 200.0,
        color: AppColors.secondary.withValues(alpha: 0.10),
      ),
      (
        cx: size.width * 0.5,
        cy: size.height * 0.15 + 20 * math.sin(t * math.pi),
        r: 120.0,
        color: AppColors.primaryLight.withValues(alpha: 0.08),
      ),
    ];

    for (final orb in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(colors: [orb.color, Colors.transparent])
            .createShader(
              Rect.fromCircle(center: Offset(orb.cx, orb.cy), radius: orb.r),
            );
      canvas.drawCircle(Offset(orb.cx, orb.cy), orb.r, paint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.t != t;
}

// ── Get Started Button ────────────────────────────────────────────────────────
class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({
    required this.onTap,
    this.isLoading = false,
    this.isError = false,
  });
  final VoidCallback onTap;
  final bool isLoading;
  final bool isError;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: disabled
                ? const LinearGradient(
                    colors: [AppColors.surfaceMuted, AppColors.surfaceMuted],
                  )
                : widget.isError
                    ? const LinearGradient(
                        colors: [AppColors.error, AppColors.error],
                      )
                    : AppColors.userBubbleGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: disabled || widget.isError
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _pressed ? 0.2 : 0.45,
                      ),
                      blurRadius: _pressed ? 10 : 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.isError
                ? const [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Initialization Failed. Tap to retry',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]
                : disabled
                    ? const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Setting up...',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onSurfaceMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]
                    : const [
                        Text(
                          AppStrings.getStarted,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                      ],
          ),
        ),
      ),
    );
  }
}
