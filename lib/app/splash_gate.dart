import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/auth_page.dart';
import '../features/groups/home_page.dart';

enum SplashTarget { onboarding, home, auth }

/// Riverpod ile hedef belirleyici (initState yok)
final splashTargetProvider = FutureProvider<SplashTarget>((ref) async {
  // animasyon gözüksün diye küçük bir gecikme
  await Future.delayed(const Duration(milliseconds: 1200));
  final session = Supabase.instance.client.auth.currentSession;

  if (session != null) {
    // TODO: onboarding flag'i eklemek istersen burada kontrol et
    return SplashTarget.home;
  } else {
    return SplashTarget.auth;
  }
});

class SplashGate extends ConsumerWidget {
  const SplashGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hedef resolve olunca bir kez yönlendir
    ref.listen(splashTargetProvider, (prev, next) {
      next.whenOrNull(data: (target) {
        switch (target) {
          case SplashTarget.home:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
            break;
          case SplashTarget.auth:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AuthPage(
                  onSignedIn: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                  ),
                ),
              ),
            );
            break;
          case SplashTarget.onboarding:
          // ileride onboarding sayfası eklersek buraya yönlendiririz
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
            break;
        }
      });
    });

    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final gradient = isDark
        ? const [Color(0xFF061F19), Color(0xFF0B2E25)]
        : const [Color(0xFFEFFAF6), Color(0xFFD9F2E8)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            // initState yerine TweenAnimationBuilder ile fade/scale
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                final scale = 0.92 + (0.08 * t);
                return Opacity(
                  opacity: t,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: const _LogoAndDots(),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoAndDots extends StatelessWidget {
  const _LogoAndDots();

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _Logo(),
        SizedBox(height: 24),
        _ProgressDots(),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0E2B23) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                blurRadius: 28,
                offset: const Offset(0, 12),
                color: Colors.black.withValues(alpha:  isDark ? .25 : .12),
              ),
            ],
            border: Border.all(color: const Color(0xFF0E9F6E).withValues(alpha:  .18), width: 1),
          ),
          child: const Center(
            child: Icon(Icons.groups_2_rounded, size: 56, color: Color(0xFF0E9F6E)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'app_name'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'app_title'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: (isDark ? Colors.white : Colors.black87).withValues(alpha: .75),
          ),
        ),
      ],
    );
  }
}

class _ProgressDots extends StatefulWidget {
  const _ProgressDots();
  @override
  State<_ProgressDots> createState() => _ProgressDotsState();
}

class _ProgressDotsState extends State<_ProgressDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final t = _a.value; // 0..1
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final v = (t + i * 0.25) % 1.0;
            final s = 6.0 + (v < 0.5 ? v : 1 - v) * 10;
            final o = .4 + (v < .5 ? v : 1 - v) * .6;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: s, height: s,
              decoration: BoxDecoration(
                color: const Color(0xFF0E9F6E).withValues(alpha:  o),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}