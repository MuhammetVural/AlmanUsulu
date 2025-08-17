import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import '../data/repo/auth_repo.dart';        // handleAuthDeepLink için
import '../features/auth/auth_page.dart';    // giriş/kayıt sayfan
// import '../features/groups/group_list_page.dart'; // senin grup listesi sayfan

class AuthGate extends StatefulWidget {
  final Widget child; // oturum varken göstereceğimiz asıl ekran (ör. GroupListPage)
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SupabaseClient _client;
  late final AppLinks _links;
  AuthRepo get _authRepo => AuthRepo();

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;

    // 1) Deep link: soğuk başlangıç + app açıkken
    _links = AppLinks();
    _initDeepLinks();

    // 2) Auth state değiştiğinde yeniden çiz (login/logout)
    _client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initDeepLinks() async {
    // soğuk başlangıç
    final initial = await _links.getInitialLink();
    if (initial != null) {
      await _authRepo.handleAuthDeepLink(initial);
      if (mounted) setState(() {});
    }
    // app açıkken
    _links.uriLinkStream.listen((uri) async {
      await _authRepo.handleAuthDeepLink(uri);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _client.auth.currentSession != null;

    // OTURUM YOKSA → AuthPage
    if (!hasSession) {
      return const AuthPage();
    }

    // OTURUM VARSA → Asıl uygulama (grup listesi vs.)
    return widget.child;
  }
}