
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/auth_gate.dart';
import '../../app/providers.dart';
import '../../core/ui/notifications.dart';
import '../groups/home_page.dart';

/// FutureProvider to fetch the current user's member row from Supabase.
final currentMemberProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final sb = Supabase.instance.client;
  final u = sb.auth.currentUser;
  if (u == null) return null;

  final rows = await sb
      .from('members')
      .select('id, name, user_id, updated_at, created_at')
      .eq('user_id', u.id)
      .isFilter('deleted_at', null)
      .order('updated_at', ascending: false)
      .limit(1); // ← tek satır getir

  return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
});

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb = Supabase.instance.client;
    final u = sb.auth.currentUser;
    final memberAsync = ref.watch(currentMemberProvider);
    // Auth metadata değişikliklerini (updateUser) yakalamak için authState'i izle
    ref.watch(authStateProvider);
    // Önce auth.metadata.name, yoksa members.name
    final metaName = (u?.userMetadata?['name'] as String?)?.trim();
    final name = (metaName != null && metaName.isNotEmpty)
        ? metaName
        : ((memberAsync.valueOrNull?['name'] as String?)?.trim() ?? '');


    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        UserAccountsDrawerHeader(
          accountName: Text(name),                         // ← hep isim
          accountEmail: Text(u?.email ?? ''),              // ← hep email
          currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
          decoration: const BoxDecoration(color: Colors.teal),
        ),
        ListTile(
          leading: const Icon(Icons.edit, size: 18),
          title:  Text('appDrawer.name_edit'.tr()),
          onTap: () async {
            if (u == null) return;
            final ctrl = TextEditingController(text: name);
            final newName = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title:  Text('appDrawer.name_edit'.tr()),
                content: TextField(controller: ctrl, autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child:  Text('common.cancel'.tr())),
                  FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child:  Text('common.save'.tr()),)
                ],
              ),
            );
            if (newName == null) return;
            final trimmed = newName.trim();
            if (trimmed.isEmpty || trimmed == name) return;

            // Tüm gruplardaki ismi senkronla
            await sb
                .from('members')
                .update({'name': trimmed})
                .eq('user_id', u.id)
                .isFilter('deleted_at', null);

            // Auth metadata.name de güncellensin ki Drawer anında yenilensin
            await sb.auth.updateUser(UserAttributes(data: {'name': trimmed}));


            ref.invalidate(currentMemberProvider);// authStateProvider zaten watch ediliyor; userUpdated ile rebuild olur
            if (context.mounted) {
              showAppSnack(
                ref,
                title: 'common.success'.tr(),
                message: 'appDrawer.name_update'.tr(),
                type: AppNotice.success,
              );
            }
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title:  Text('appDrawer.exit'.tr()),
          onTap: () async {
            await sb.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pop();
              // Tüm stack'i temizle ve köke `AuthGate` ile dön
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate(child: HomePage())),
                    (route) => false,
              );
              showAppSnack(
                ref,
                title: 'common.info'.tr(),
                message: 'appDrawer.exit_login'.tr(),
                type: AppNotice.info,
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Verilerimi Sil'),
          subtitle: const Text('Tüm kişisel verileriniz ve ilişkileriniz kaldırılır.'),
          onTap: () async {
            final sure = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Veriler silinsin mi?'),
                content: const Text('Bu işlem geri alınamaz. Harcama kayıtlarındaki kişisel ilişkileriniz kaldırılacak.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet, sil')),
                ],
              ),
            );
            if (sure != true) return;

            try {
              final res = await Supabase.instance.client.rpc('erase_my_data').select();
              // success snack
              if (context.mounted) {
                showAppSnack(ref, title: 'Tamam', message: 'Verileriniz silindi.', type: AppNotice.success);
              }
            } catch (e) {
              if (context.mounted) {
                showAppSnack(ref, title: 'Hata', message: '$e', type: AppNotice.error);
              }
            }
          },
        ),

        ListTile(
          leading: const Icon(Icons.person_off_outlined),
          title: const Text('Hesabı Sil'),
          subtitle: const Text('Hesabınız ve verileriniz kaldırılır, oturum kapanır.'),
          onTap: () async {
            final sure = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Hesap silinsin mi?'),
                content: const Text('Bu işlem geri alınamaz. Owner olduğunuz gruplar varsa önce devretmeniz gerekebilir.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet, sil')),
                ],
              ),
            );
            if (sure != true) return;

            try {
              final supa = Supabase.instance.client;
              final step = await supa.rpc('request_account_deletion').select().single();

              if (step['ok'] == true) {
                final fn = await supa.functions.invoke('delete-auth-user');
                // Local sign-out
                await supa.auth.signOut();
                if (context.mounted) {
                  showAppSnack(ref, title: 'Tamam', message: 'Hesabınız silindi.', type: AppNotice.success);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              } else if (step['reason'] == 'TRANSFER_OWNERSHIP_REQUIRED') {
                if (context.mounted) {
                  showAppSnack(ref,
                    title: 'İşlem Durduruldu',
                    message: 'Owner olduğunuz ve başka üyeleri olan gruplar var. Önce sahipliği devredin.',
                    type: AppNotice.error,
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                showAppSnack(ref, title: 'Hata', message: '$e', type: AppNotice.error);
              }
            }
          },
        ),
      ]),
    );
  }
}