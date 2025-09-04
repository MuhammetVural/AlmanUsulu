
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

enum AppNotice { success, info, warning, error }
void showAppSnack(
    WidgetRef ref, {
      required String title,
      required String message,
      AppNotice type = AppNotice.success,
    }) {
  final key = ref.read(scaffoldMessengerKeyProvider);
  final ctx = key.currentContext;
  if (ctx == null) return;

  // ---- Palette (pastel üst -> orta -> alt) ----
  // base: ikon ve vurgu rengi (daha doygun)
  // top/mid: kartın üst kısımdaki yumuşak tonlar
  final isDark = Theme.of(ctx).brightness == Brightness.dark;
  final bottom = isDark ? const Color(0xFF101214) : Colors.white; // alt zemin

  late final Color base;
  late Color topTint;
  late Color midTint;

  switch (type) {
    case AppNotice.error:
      base    = const Color(0xFFFF5A5F);
      topTint = const Color(0xFFFFE3E0);
      midTint = const Color(0xFFFFD3CC);
      break;
    case AppNotice.warning:
      base    = const Color(0xFFFFB020);
      topTint = const Color(0xFFFFF1DC);
      midTint = const Color(0xFFFFE7C2);
      break;
    case AppNotice.success:
      base    = const Color(0xFF2ECC71);
      topTint = const Color(0xFFE8F8F1);
      midTint = const Color(0xFFD9F3E7);
      break;
    case AppNotice.info:
      base    = const Color(0xFF3B82F6);
      topTint = const Color(0xFFE7F0FF);
      midTint = const Color(0xFFD9E8FF);
      break;
  }

  // Dark mode override: use neutral dark tints for the top band so it isn’t too bright
  if (isDark) {
    topTint = const Color(0xFF272A2E); // darker top
    midTint = const Color(0xFF1B1E22); // mid step
  }

  // ---- Boyut / margin (şeffaf alanı küçült) ----
  final screenW = MediaQuery.of(ctx).size.width;
  const maxW = 520.0;
  const side = 12.0;
  final double? snackWidth = (screenW > maxW + side * 2) ? maxW : null;
  final EdgeInsetsGeometry snackMargin =
  const EdgeInsets.symmetric(horizontal: side, vertical: 10);

  final snack = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    width: snackWidth,
    margin: snackMargin,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    content: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ?  Colors.white : Color(0xFF2A2E30), width: 0.2),
        // Üst yumuşak → alt zemin: lineer ve çok soft
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topTint, midTint, bottom],
          stops: const [0.0, 0.60, 1.0],
        ),
        // Hafif derinlik
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF0B0D0F) : const Color(0xFFE6E6E6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge (opak, gölge sabit ton)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1113) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0xFF0B0D0F) : const Color(0xFFE6E6E6),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                switch (type) {
                  AppNotice.success => Icons.check_circle,
                  AppNotice.info    => Icons.info,
                  AppNotice.warning => Icons.warning_amber_rounded,
                  AppNotice.error   => Icons.error,
                },
                color: base,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    height: 1.3,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  key.currentState?..clearSnackBars();
  key.currentState?..showSnackBar(snack);
}