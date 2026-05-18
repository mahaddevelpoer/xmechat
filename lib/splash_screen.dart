import 'package:flutter/material.dart';
import 'dart:async';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController c;
  late Animation<double> fade;

  @override
  void initState() {
    super.initState();

    c = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    fade = Tween(begin: 0.0, end: 1.0).animate(c);
    c.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/icon.png", width: 120),
              const SizedBox(height: 20),
              const Text("M4 Chat", style: TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}
