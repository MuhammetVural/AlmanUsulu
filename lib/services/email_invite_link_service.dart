import 'dart:async';
import 'package:app_links/app_links.dart';

class EmailInviteLinkService {
  static AppLinks? _links;
  static StreamSubscription<Uri>? _sub;

  static Future<void> init({
    required void Function(String token) onToken,
  }) async {
    _links ??= AppLinks();

    // Uygulama soğuk başlarken gelen link
    final initial = await _links!.getInitialLink();
    if (initial != null &&
        initial.scheme == 'almanusulu' &&
        initial.host == 'invite') {
      final t = initial.queryParameters['token'];
      if (t != null && t.isNotEmpty) onToken(t);
    }

    // Uygulama açıkken gelen linkler
    await _sub?.cancel();
    _sub = _links!.uriLinkStream.listen((uri) {
      if (uri.scheme == 'almanusulu' && uri.host == 'invite') {
        final t = uri.queryParameters['token'];
        if (t != null && t.isNotEmpty) onToken(t);
      }
    });
  }

  static Future<void> dispose() async => _sub?.cancel();
}