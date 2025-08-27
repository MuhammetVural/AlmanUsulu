// lib/features/auth/welcome_onboarding_page.dart
import 'package:flutter/material.dart';
import 'auth_page.dart';

class WelcomeOnboardingPage extends StatelessWidget {
  const WelcomeOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: _SoftBubbles(), // sol üst açık mavi büyük bubble
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // üstte avatar kolajı
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 140,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: 36,
                          top: 0,
                          child: _CircleAvatar(path: 'assets/onboarding/avatar2.png', size: 64),
                        ),
                        Positioned(
                          left: 24,
                          top: 32,
                          child: _CircleAvatar(path: 'assets/onboarding/avatar1.png', size: 96),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Let’s Get\nStarted",
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Grow Together",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AuthPage()),
                        );
                      },
                      child: const Text("JOIN NOW"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  final String path;
  final double size;
  const _CircleAvatar({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 20, offset: const Offset(0, 10))],
      ),
    );
  }
}

class _SoftBubbles extends StatelessWidget {
  const _SoftBubbles();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(right: -60, top: -60, child: _Bubble(color: Color(0xffdfe9f8), size: 280)),
        Positioned(left: -80, top: 200, child: _Bubble(color: Color(0xffe9f2ff), size: 320)),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final Color color;
  final double size;
  const _Bubble({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
