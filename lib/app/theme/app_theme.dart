import 'package:flutter/material.dart';
import 'design_tokens.dart';

ThemeData lightTheme() {
  final seed = const Color(0xFF2BB673);
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

  const Color _bg       = Color(0xFFF2F1F6); // sayfa
  const Color _card     = Colors.white;      // kart/input
  const Color _primary  = Color(0xFF2BB673); // buton/aktif
  const Color _outline  = Color(0xFFE2E4EA);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,

    scaffoldBackgroundColor: _bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: _bg,
      foregroundColor: Colors.black,
      centerTitle: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
    ),
    // Bölücüler
    dividerTheme: const DividerThemeData(
      color: _outline, thickness: .5, space: 0,
    ),
    // Kartlar
    cardTheme: CardThemeData(
      color: _card,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .06),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    // Arama/Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _card,
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: .4)),
      prefixIconColor: scheme.onSurfaceVariant.withValues(alpha: .7),
      suffixIconColor: scheme.onSurfaceVariant.withValues(alpha: .7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    extensions: const [
      AppTokens(
        radiusL: 28.0,
        fieldPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    ],
    listTileTheme: ListTileThemeData(
      minLeadingWidth: 44,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      subtitleTextStyle: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .64)),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        minimumSize: const Size(28, 28),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary, foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: const StadiumBorder(),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary, foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: const StadiumBorder(side: BorderSide.none),
      ),
    ),
    // Chip (filter etiketleri)
    chipTheme: ChipThemeData(
      backgroundColor: _bg,
      selectedColor: _primary,
      disabledColor: _bg,
      side: const BorderSide(color: _outline),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      showCheckmark: false,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    // Slider (Budget)
    sliderTheme: SliderThemeData(
      activeTrackColor: _primary,
      inactiveTrackColor: _outline,
      thumbColor: _primary,
      overlayColor: _primary.withValues(alpha: .12),
      trackHeight: 4,
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
    ),
    textTheme: ThemeData.light().textTheme.copyWith(
      headlineMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: scheme.onSurface.withValues(alpha: .9)),
      bodySmall: TextStyle(color: scheme.onSurface.withValues(alpha: .7)),
      labelSmall: TextStyle(color: scheme.onSurface.withValues(alpha: .7)),
    ),
  );
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2BB673), brightness: Brightness.dark);
  final Color _bg = scheme.surface;
  final Color _card = scheme.surfaceContainerLow;
  const Color _primary = Color(0xFF2BB673);
  final Color _outline = scheme.outlineVariant.withValues(alpha: .35);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    extensions: const [
      AppTokens(
        radiusL: 28.0,
        fieldPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    ],
    cardTheme: CardThemeData(
      color: _card, elevation: 2, shadowColor: Colors.black.withValues(alpha: .24),
      surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: _card,
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: .4)),
      prefixIconColor: scheme.onSurfaceVariant.withValues(alpha: .7),
      suffixIconColor: scheme.onSurfaceVariant.withValues(alpha: .7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _outline, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _outline, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    ),

    dividerTheme: DividerThemeData(color: _outline, thickness: .5, space: 0),

    listTileTheme: ListTileThemeData(
      minLeadingWidth: 44,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      subtitleTextStyle: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .72)),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(padding: EdgeInsets.zero, visualDensity: const VisualDensity(horizontal: -4, vertical: -4), minimumSize: const Size(28, 28)),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.w700), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18), shape: const StadiumBorder()),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, textStyle: const TextStyle(fontWeight: FontWeight.w700), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18), shape: const StadiumBorder()),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _bg, selectedColor: _primary, disabledColor: _bg,
      side: BorderSide(color: _outline), shape: const StadiumBorder(),
      labelStyle: TextStyle(color: scheme.onSurface), secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), showCheckmark: false,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: _primary, inactiveTrackColor: _outline, thumbColor: _primary, overlayColor: _primary.withValues(alpha: .12), trackHeight: 4,
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(), rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
    ),

    textTheme: ThemeData.dark().textTheme.copyWith(
      headlineMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: scheme.onSurface.withValues(alpha: .92)),
      bodySmall: TextStyle(color: scheme.onSurface.withValues(alpha: .75)),
      labelSmall: TextStyle(color: scheme.onSurface.withValues(alpha: .75)),
    ),
  );
}