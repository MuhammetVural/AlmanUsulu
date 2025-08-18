import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequireAuth extends StatelessWidget {
  final Widget child;
  final VoidCallback? onNeedAuth;
  const RequireAuth({super.key, required this.child, this.onNeedAuth});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // oturum yok → auth sayfasına yönlendir
      onNeedAuth?.call();
      return const SizedBox.shrink();
    }
    return child;
  }
}