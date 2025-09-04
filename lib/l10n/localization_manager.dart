import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../constants/enums/locals.dart';
import 'generated/codegen_loader.g.dart';

@immutable
final class LocalizationManager extends EasyLocalization {
  LocalizationManager({
    required super.child,
    super.key,
  }) : super(
    supportedLocales: const [Locale('tr'), Locale('en')],
    path: _translationPath,
    useOnlyLangCode: true,
    startLocale: Locales.tr.locale,
    fallbackLocale: Locales.en.locale,
    assetLoader: const CodegenLoader(), // ⬅️ .g loader
  );

  static const String _translationPath = 'assets/language';

  static Future<void> updateLanguage({
    required BuildContext context,
    required Locales value,
  }) =>
      context.setLocale(value.locale);
}