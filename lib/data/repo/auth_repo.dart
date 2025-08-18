import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepo {
  final SupabaseClient _client = Supabase.instance.client;

  bool get isSignedIn => _client.auth.currentSession != null;
  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Email confirmations ON ise, `emailRedirectTo` AYARINI UNUTMA!
  Future<void> signUp(String email, String password, {String emailRedirectTo = 'https://almanusulu-3838.web.app/auth/callback'}) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailRedirectTo,
    );
  }

  /// Kayıt onay e-postasını tekrar gönder.
  Future<void> resendSignupEmail(String email, {String emailRedirectTo = 'https://almanusulu-3838.web.app/auth/callback'}) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Supabase’in mail onayı / magic link dönüşünü session’a çevirir.
  /// Supabase’in mail onayı / magic link / PKCE dönüşünü session’a çevirir.
  Future<void> handleAuthDeepLink(Uri uri) async {
    // Sadece bizim linkleri işle
    final isCustom = (uri.scheme == 'almanusulu' && uri.host == 'auth');
    final isHttps  = (uri.scheme == 'https' && uri.host == 'almanusulu-3838.web.app');
    if (!(isCustom || isHttps)) return;

    debugPrint('🔗 Incoming URI: $uri');

    // Eğer tokenlar query'de geldiyse (access_token / refresh_token),
    // Supabase fragment (#) beklediği için query'yi fragment'e çevir.
    Uri uriForSupabase = uri;
    final qp = uri.queryParameters;
    final hasQueryTokens = qp.containsKey('access_token') || qp.containsKey('refresh_token');
    if (hasQueryTokens && uri.fragment.isEmpty) {
      final frag = Uri(queryParameters: qp).query; // "a=1&b=2"
      uriForSupabase = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
        fragment: frag, // #a=1&b=2
      );
      debugPrint('↪️ Rewritten for Supabase: $uriForSupabase');
    }

    try {
      // 🔴 Artık exchangeCodeForSession KULLANMIYORUZ.
      final res = await Supabase.instance.client.auth.getSessionFromUrl(uriForSupabase);
      if (res.session != null) {
        debugPrint('✅ Session oluşturuldu: ${res.session!.user.id}');
      } else {
        debugPrint('⚠️ getSessionFromUrl session=null döndü');
      }
    } on AuthException catch (e) {
      debugPrint('❌ getSessionFromUrl AuthException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ getSessionFromUrl hata: $e');
      rethrow;
    }
  }
}

/// ---- Helper: Giriş yoksa mini dialog aç ----
/// Repo saf kalsın ama pratiklik için burada tutuyoruz.
Future<bool> ensureSignedIn(BuildContext context, {AuthRepo? repo}) async {
  final r = repo ?? AuthRepo();
  if (r.isSignedIn) return true;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLogin = true;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-posta')),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Şifre'), obscureText: true),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? 'Hesabın yok mu? Kayıt ol' : 'Zaten hesabın var mı? Giriş yap'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              try {
                if (isLogin) {
                  await r.signIn(emailCtrl.text.trim(), passCtrl.text);
                } else {
                  await r.signUp(emailCtrl.text.trim(), passCtrl.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-posta onayı gönderildi. Maildeki linke tıklayın.')),
                    );
                  }
                }
                Navigator.pop(ctx, r.isSignedIn);
              } on AuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
            child: Text(isLogin ? 'Giriş' : 'Kayıt'),
          ),
        ],
      ),
    ),
  );

  return ok == true || r.isSignedIn;
}

Future<void> ensureDisplayName(BuildContext context) async {
  final u = Supabase.instance.client.auth.currentUser;
  if (u == null) return;

  final current = (u.userMetadata?['name'] as String?)?.trim();
  if (current != null && current.isNotEmpty) return;

  final ctrl = TextEditingController(text: (u.email ?? '').split('@').first);
  ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Adını belirle'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Örn: Ali Vural'),
        onTap: (){
          ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
        },
        onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()), // klavyeden Enter ile onaylama işlemi
        textInputAction: TextInputAction.done,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Kaydet')),
      ],
    ),
  );

  if (name == null || name.isEmpty) return;

  try {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'name': name}),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsmin kaydedildi.')),
      );
    }
  } on AuthException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}