import 'package:flutter/material.dart';
import 'package:local_alman_usulu/widgets/ui_components.dart';
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
          SnackBar(
            content: Text(
              _isLogin
                  ? 'Giriş başarılı'
                  : 'E-posta onayı gönderildi. Lütfen mailden onaylayın.',
            ),
          ),
        );
      } // önceki ekrana dön
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bir şeyler ters gitti: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // This is a preview-only copy of the updated build() for your AuthPage,
  // plus two tiny helper widgets used purely for the visuals.
  // Your auth logic is untouched; only UI structure & styling changed.

  @override
  Widget build(BuildContext context) {
    final isLogin = _isLogin;
    final topColor = isLogin
        ? const Color(0xFFD9F6DB)
        : const Color(0xFFFFD6E0); // login=green, signup=pink
    final bottomColor = isLogin
        ? const Color(0xFFC9F0CF)
        : const Color(0xFFFFC2D0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _BlobsBackground(
              topRightColor: topColor,
              bottomLeftColor: bottomColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button (keeps AppBar-free look)
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(height: 8),

                  // Headline + subtitle
                  Text(
                    isLogin ? 'Tekrar Hoşgeldiniz!' : 'Hesap Oluştur :)',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),

                    const SizedBox(height: 6),
                    Text( isLogin ?
                      'Mail ve şifre ile giriş yapabilirsiniz' : 'Mail ve şifre ile kaydolabilirsiniz' ,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  const SizedBox(height: 28),

                  // Fields (labels kept same -> no logic change)
                  AUTextField(controller: _email, hint: 'E-posta'),
                  const SizedBox(height: 18),
                  AUTextField(controller: _pass, hint: 'Şifre'),

                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: isLogin ? 'LOGIN' : 'Sign Up',
                    onPressed: _loading ? null : _submit,
                  ),

                  const SizedBox(height: 12),
                  if (!isLogin) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                final email = _email.text.trim();
                                if (email.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Önce e-posta adresini yaz.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await AuthRepo().resendSignupEmail(
                                    email,
                                    emailRedirectTo:
                                        'https://almanusulu-3838.web.app/auth/callback',
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Doğrulama e-postası tekrar gönderildi.',
                                      ),
                                    ),
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
                        child: const Text(
                          'Doğrulama e-postasını yeniden gönder',
                        ),
                      ),
                    ),
                  ],

                  // Switch login/signup (same behavior as before)
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        isLogin
                            ? 'Hesabın yok mu? Kayıt ol'
                            : 'Zaten hesabın var mı? Giriş yap',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- tiny helper widgets (visual-only) ----------
class _BlobsBackground extends StatelessWidget {
  const _BlobsBackground({
    required this.topRightColor,
    required this.bottomLeftColor,
  });
  final Color topRightColor;
  final Color bottomLeftColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -40,
            child: _Blob(color: topRightColor, size: 280),
          ),
          Positioned(
            left: -60,
            top: 180,
            child: _Blob(color: bottomLeftColor.withValues(alpha:  .85), size: 260),
          ),
          Positioned(
            right: -120,
            bottom: -60,
            child: _Blob(color: bottomLeftColor, size: 360),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}
