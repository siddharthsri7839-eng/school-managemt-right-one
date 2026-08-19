import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:school_erp_staff_app/core/branding/brand_logo.dart';
import 'package:school_erp_staff_app/core/config/app_colors.dart';
import 'package:school_erp_staff_app/core/config/app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  late final AnimationController _textController;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Immersive status bar for splash
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Logo animation: scale up + fade in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Text animation: fade + slide up (starts after logo)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Shimmer for the loading bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Kick off sequence
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primaryLight,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles (matches dashboard hero)
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(15),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(8),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Animated Logo
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const BrandLogo(
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Animated text
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            const Text(
                              AppConfig.splashTitle,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'MULTI SCHOOL ERP',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withAlpha(160),
                                letterSpacing: 3.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Shimmer loading indicator
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Container(
                          width: 160,
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.white.withAlpha(30),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment(
                              (_shimmerController.value * 3) - 1,
                              0,
                            ),
                            widthFactor: 0.4,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withAlpha(0),
                                    Colors.white.withAlpha(120),
                                    Colors.white.withAlpha(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Initializing...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(100),
                        letterSpacing: 1.0,
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Footer
                    Text(
                      AppConfig.poweredBy,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(80),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}