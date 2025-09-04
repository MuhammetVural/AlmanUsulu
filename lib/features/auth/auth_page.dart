import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 👈 eklendi
import 'package:local_alman_usulu/widgets/ui_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/ui/notifications.dart';
import '../../data/repo/auth_repo.dart';
import '../groups/home_page.dart';

class AuthPage extends ConsumerStatefulWidget {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color topColor;
    final Color bottomColor;

    if (isLogin) {
      // Login = yeşil tonları
      topColor    = isDark ? const Color(0xFF2E4635) : const Color(0xFFD9F6DB);
      bottomColor = isDark ? const Color(0xFF3B5C46) : const Color(0xFFC9F0CF);
    } else {
      // Signup = pembe tonları
      topColor    = isDark ? const Color(0xFF4B2F3B) : const Color(0xFFFFD6E0);
      bottomColor = isDark ? const Color(0xFF5E3C4C) : const Color(0xFFFFC2D0);
    }

    // build(...) içinde, mevcut Scaffold bloğunu bununla değiştirin:
    final double topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // status bar şeffaf
          statusBarIconBrightness:
          Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark, // Android ikon rengi
          statusBarBrightness:
          Theme.of(context).brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light, // iOS metin rengi
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true, // SafeArea top'u biz yöneteceğiz
          child: Stack(
            children: [
              _BlobsBackground(
                topRightColor: topColor,
                bottomLeftColor: bottomColor,
              ),
              Padding(
                // butonlar status bar'ın HEMEN ALTINA gelsin
                padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top actions: back (left) + language/theme (right)
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const Spacer(),
                        const LanguageToggleIcon(),
                        const SizedBox(width: 4),
                        const ThemeToggleIcon(),
                      ],
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        // Colors.black54 yerine tema uyumlu renk
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.72),
                      ),
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
                                message: 'common.error'
                                    .tr(args: [e.toString()]),
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