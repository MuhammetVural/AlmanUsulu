import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repo/auth_repo.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback? onSignedIn; // başarıdan sonra çağır
  const AuthPage({super.key, this.onSignedIn});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    final client = Supabase.instance.client;

    try {
      if (_isLogin) {
        await client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
        // Ensure display name before group creation
        await ensureDisplayName(context);
      } else {
        final res = await client.auth.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          emailRedirectTo: 'https://almanusulu-3838.web.app/auth/callback',
        );
        // Email confirm off ise res.user != null ve session oluşur
        // on ise kullanıcı mail onayı sonrası oturum açar
        if (Supabase.instance.client.auth.currentSession != null) {
          await ensureDisplayName(context); // ← EKLE
        }
      }
      if (!mounted) return;
      widget.onSignedIn?.call();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      } else {
        // AuthGate state değişimini yakalayacak; burada ekranda kal.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLogin ? 'Giriş başarılı' : 'E-posta onayı gönderildi. Lütfen mailden onaylayın.')),
        );
      }// önceki ekrana dön
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir şeyler ters gitti: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-posta')),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Şifre'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(), // Enter ile formu gönder
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_isLogin ? 'Giriş' : 'Kayıt'),
              ),
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final email = _email.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Önce e-posta adresini yaz.')),
                            );
                            return;
                          }
                          try {
                            await AuthRepo().resendSignupEmail(
                              email,
                              emailRedirectTo: 'https://almanusulu-3838.web.app/auth/callback',
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Doğrulama e-postası tekrar gönderildi.')),
                            );
                          } on AuthException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata: $e')),
                            );
                          }
                        },
                  child: const Text('Doğrulama e-postasını yeniden gönder'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(_isLogin ? 'Hesabın yok mu? Kayıt ol' : 'Zaten hesabın var mı? Giriş yap'),
            ),
          ],
        ),
      ),
    );
  }
}