import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/notifications.dart';
import 'role_pill.dart';

class MemberTile extends ConsumerWidget {
  const MemberTile({super.key, required this.member, required this.groupId});

  final Map<String, dynamic> member;
  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRoleAsync = ref.watch(myRoleForGroupProvider(groupId));
    final myRole = myRoleAsync.asData?.value; // 'owner' | 'admin' | 'member' | null

    final role = (member['role'] as String?) ?? 'member';
    final isOwnerTarget = role == 'owner';

    // Kullanıcı kendisi mi?
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = uid != null && member['user_id'] == uid;

    // Görsel rol etiketi
    final String roleLabel = role == 'member' ? 'ÜYE' : role.toUpperCase();
    final Color roleColor =
    (role == 'owner' || role == 'admin') ? Colors.green : Colors.amber;

    return ListTile(
      dense: true,
      title: Row(
        children: [
          Text(
            member['name']?.toString() ?? 'Üye',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(width: 10,),
          RolePill(
            label: role == 'member' ? 'ÜYE' : role.toUpperCase(),
            color: (role == 'owner' || role == 'admin') ? Colors.green : Colors.amber,
          ),
        ],
      ),
      trailing: (myRole == 'owner' && !isOwnerTarget)
          ? PopupMenuButton<String>(
        tooltip: 'Yetki',
        onSelected: (key) async {
          if (key == 'make_admin') {
            await ref.read(memberRepoProvider).updateMemberRole(
              groupId: groupId,
              memberId: (member['id'] as num).toInt(),
              role: 'admin',
            );
          } else if (key == 'remove_admin') {
            await ref.read(memberRepoProvider).updateMemberRole(
              groupId: groupId,
              memberId: (member['id'] as num).toInt(),
              role: 'member',
            );
          }
          ref.invalidate(membersProvider(groupId));

          if (context.mounted) {
            showAppSnack(
              ref,
              title: 'common.success'.tr(),
              message: key == 'make_admin' ? 'snack.made_admin'.tr() : 'snack.removed_admin'.tr(),
              type: AppNotice.success,
            );
          }
        },
        itemBuilder: (ctx) => [
          if (role == 'member')
            const PopupMenuItem(
              value: 'make_admin',
              child: Text('Admin yap'),
            ),
          if (role == 'admin')
            const PopupMenuItem(
              value: 'remove_admin',
              child: Text('Adminliği kaldır'),
            ),
        ],
        icon: const Icon(Icons.more_vert),
      )
          : null,
      subtitle: isSelf ? const Text('Sen', style: TextStyle(fontSize: 12)) : null,

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}