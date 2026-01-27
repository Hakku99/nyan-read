import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/mascot_manager.dart';
import '../bookshelf/home_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MascotManager().render(MascotScene.splash, size: 150)
                .animate()
                .fade(duration: 800.ms)
                .scale(duration: 800.ms),
            const SizedBox(height: 20),
            const Text(
              "Nyan Read",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 500.ms),
            const Text(
              "v1.0.0",
              style: TextStyle(color: Colors.white70),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
