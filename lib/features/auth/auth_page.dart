import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 👈 eklendi
import 'package:local_alman_usulu/widgets/ui_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/ui/notifications.dart';
import '../../data/repo/auth_repo.dart';

class AuthPage extends ConsumerStatefulWidget { // 👈 ConsumerStatefulWidget
  final VoidCallback? onSignedIn; // başarıdan sonra çağır
  const AuthPage({super.key, this.onSignedIn});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState(); // 👈 ConsumerState
}

class _AuthPageState extends ConsumerState<AuthPage> {
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
        await ensureDisplayName(context, ref);
      } else {
        final res = await client.auth.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          emailRedirectTo: 'https://almanusulu-3838.web.app/auth/callback',
        );
        // Email confirm off ise res.user != null ve session oluşur
        // on ise kullanıcı mail onayı sonrası oturum açar
        if (Supabase.instance.client.auth.currentSession != null) {
          await ensureDisplayName(context, ref);
        }
      }
      if (!mounted) return;
      widget.onSignedIn?.call();
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      } else {
        // 👇 sizin imzaya göre
        showAppSnack(
          ref,
          title: 'common.success'.tr(),
          message: _isLogin
              ? 'auth.snack_login_success'.tr()
              : 'auth.snack_signup_sent'.tr(),
          type: AppNotice.success,
        );
      } // önceki ekrana dön
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnack(
        ref,
        title: 'common.failed'.tr(),
        message: e.message,
        type: AppNotice.error,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        ref,
        title: 'common.failed'.tr(),
        message: 'common.error'.tr(args: [e.toString()]),
        type: AppNotice.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                    isLogin ? 'auth.title_login'.tr() : 'auth.title_signup'.tr(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLogin
                        ? 'auth.subtitle_login'.tr()
                        : 'auth.subtitle_signup'.tr(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),

                  // Fields
                  AUTextField(controller: _email, hint: 'auth.field_email'.tr()),
                  const SizedBox(height: 18),
                  AUTextField(controller: _pass, hint: 'auth.field_password'.tr()),

                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: isLogin
                        ? 'auth.btn_login'.tr()
                        : 'auth.btn_signup'.tr(),
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
                            showAppSnack(
                              ref,
                              title: 'common.failed'.tr(),
                              message: 'auth.resend_need_email'.tr(),
                              type: AppNotice.error,
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
                            showAppSnack(
                              ref,
                              title: 'common.success'.tr(),
                              message: 'auth.resend_sent'.tr(),
                              type: AppNotice.success,
                            );
                          } on AuthException catch (e) {
                            if (!mounted) return;
                            showAppSnack(
                              ref,
                              title: 'common.failed'.tr(),
                              message: e.message,
                              type: AppNotice.error,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            showAppSnack(
                              ref,
                              title: 'common.failed'.tr(),
                              message: 'common.error'.tr(args: [e.toString()]),
                              type: AppNotice.error,
                            );
                          }
                        },
                        child: Text('auth.resend_title'.tr()),
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
                            ? 'auth.switch_to_signup'.tr()
                            : 'auth.switch_to_login'.tr(),
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
            child: _Blob(color: bottomLeftColor.withValues(alpha: .85), size: 260),
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