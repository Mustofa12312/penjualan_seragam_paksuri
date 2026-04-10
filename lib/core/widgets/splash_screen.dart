import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigasi cepat setelah delay singkat
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16), // Adjusted padding for image
                  decoration: BoxDecoration(
                    color: Colors.white, // White background for the JPEG icon
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.asset(
                      'assets/icons/iconapp.jpeg',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                      duration: 800.ms,
                      curve: Curves.easeInOutBack,
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.1, 1.1),
                    )
                    .shimmer(
                      duration: 1200.ms,
                      color: Colors.white.withOpacity(0.3),
                    ),
                const SizedBox(height: 20),
                // Loading indicator sederhana tapi premium
                SizedBox(
                  width: 40,
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ).animate().fadeIn(delay: 400.ms).scaleX(begin: 0, end: 1, duration: 1000.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
