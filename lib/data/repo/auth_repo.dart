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

  /// App geneli deep link karşılayıcı:
  /// - Auth linklerini mevcut handleAuthDeepLink ile işler.
  /// - Davet linklerinde kullanıcıdan onay ister ve onaylarsa gruba ekler.
  Future<void> handleAppDeepLink(BuildContext context, Uri uri) async {
    // 1) Önce auth linklerini karşılayalım (oturum oluşturma vs.)
    try {
      await handleAuthDeepLink(uri);
    } catch (_) {
      // auth olmayan linklerde sorun değil; davet akışına geçeceğiz.
    }

    // 2) Davet linki mi? (ör: .../invite?group_id=123 veya ?gid=123)
    final isInvitePath = uri.path.contains('invite');
    final qp = uri.queryParameters;
    final groupIdStr = qp['group_id'] ?? qp['gid'];
    if (!isInvitePath && groupIdStr == null) {
      return; // Davet değil; işimiz yok.
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devam etmek için önce giriş yapın.')),
        );
      }
      return;
    }

    // 3) Grup bilgisi (adı) al
    int? groupId = int.tryParse(groupIdStr ?? '');
    if (groupId == null) {
      // Bazı davet linkleri path segmentinde id taşıyabilir: /invite/123
      final seg = uri.pathSegments;
      final idx = seg.indexWhere((s) => s == 'invite');
      if (idx != -1 && idx + 1 < seg.length) {
        groupId = int.tryParse(seg[idx + 1]);
      }
    }
    if (groupId == null) return;

    Map<String, dynamic>? groupRow;
    try {
      final res = await client
          .from('groups')
          .select('id, name')
          .eq('id', groupId)
          .maybeSingle();
      if (res != null) {
        groupRow = Map<String, dynamic>.from(res);
      }
    } catch (_) {
      // Gruplar okunamadıysa yine de soruyu sorarız.
    }
    final groupName = (groupRow?['name'] as String?) ?? 'bu grup';

    // 4) Kullanıcıdan onay iste
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Davet'),
        content: Text('“$groupName” adlı gruba katılma davetini kabul ediyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kabul Et')),
        ],
      ),
    );
    if (accepted != true) return;

    // 5) Üye olarak ekle (mevcutsa çakışmada güncelle; yoksa oluştur)
    final displayName = (user.userMetadata?['name'] as String?)?.trim().isNotEmpty == true
        ? user.userMetadata!['name'] as String
        : (user.email ?? '').split('@').first;

    try {
      await client
          .from('members')
          .upsert({
            'group_id': groupId,
            'user_id': user.id,
            'name': displayName,
            'is_active': 1,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          }, onConflict: 'group_id,user_id')
          .select()
          .maybeSingle();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“$groupName” grubuna katıldınız.')),
        );
      }
    } on PostgrestException catch (e) {
      // 23505 unique violation vs. durumlarında kullanıcıya yalın mesaj ver
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gruba katılım sırasında hata: ${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gruba katılamadınız: $e')),
        );
      }
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