import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_alman_usulu/env/env.dart';
import 'package:local_alman_usulu/firebase_options.dart';
import 'package:local_alman_usulu/services/email_invite_link_service.dart';
import 'package:local_alman_usulu/services/group_invite_link_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/my_app.dart';
import 'features/groups/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.implicit, // 🔴 PKCE değil, IMPLICIT
  ),
  );
  await GroupInviteLinkService.init(onToken: (token) async {
    final client = Supabase.instance.client;
    // Neden: login yoksa önce kullanıcıyı girişe yönlendirmek
    if (client.auth.currentSession == null) return;
    await GroupInviteLinkService.acceptInvite(token);
    // Neden: kabul sonrası listeleri tazelemek (UI tarafında invalidate ediyorsun)
    // Örn: home sayfasına dön, SnackBar göster vs.
  });
  await EmailInviteLinkService.init(onToken: (token) async {
    // 1) kullanıcı login değilse: token’ı sakla, login ekranına yönlendir
    // 2) kullanıcı login ise: acceptInvite(token) → Supabase tarafında üyelik ekle/bağla
  });
  runApp(const ProviderScope(child: MyApp(home: HomePage())));
}

