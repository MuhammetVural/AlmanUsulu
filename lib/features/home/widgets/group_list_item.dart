import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/providers.dart';
import '../../../core/ui/notifications.dart';
import '../../../data/repo/auth_repo.dart';
import '../../../services/group_invite_link_service.dart';
import '../../groups/pages/group_detail_page.dart';
import '../utils/soft_palette.dart';
import 'inline_avatars.dart';
import 'role_pill.dart';

class GroupListItem extends ConsumerWidget {
  const GroupListItem({
    super.key,
    required this.g,
    required this.softColor,
  });

  final Map<String, dynamic> g;
  final Color softColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAtSec = g['created_at'] as int;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000).toLocal();

    final myRoleAsync = ref.watch(myRoleForGroupProvider(g['id'] as int));
    final membersAsync = ref.watch(membersProvider(g['id'] as int));

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailPage(
              groupId: g['id'] as int,
              groupName: g['name'] as String,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: adaptSoftForTheme(softColor, context),
            image: DecorationImage(
              image: const AssetImage('assets/patterns/doodle3.png'),
              fit: BoxFit.cover,
              opacity: 0.02,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol kolon (metinler ve butonlar)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Başlık + rol etiketi
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g['name'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        myRoleAsync.when(
                          data: (role) {
                            final key = (role == 'owner')
                                ? 'owner'
                                : (role == 'admin')
                                ? 'admin'
                                : 'member';
                            final color = (role == 'owner' || role == 'admin')
                                ? Colors.green
                                : Colors.amber;
                            return RolePill(labelKey: key, color: color);
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Oluşturulma tarihi
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'group.created_at'.tr(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM.yyyy').format(createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Alt satır: avatarlar + üye sayısı | aksiyon butonları
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        membersAsync.when(
                          data: (members) => Row(
                            children: [
                              InlineAvatars(members: members),
                              const SizedBox(width: 8),
                              Text(
                                'group.member_count'.tr(args: ['${members.length}']),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          loading: () => const SizedBox(height: 18),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                        // Aksiyonlar
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'group.edit_name'.tr(),
                              onPressed: () async {
                                final id = g['id'] as int;
                                final currentName = (g['name'] as String?) ?? '';
                                final ctrl = TextEditingController(text: currentName);
                                ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);

                                final newName = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('group.name_dialog_title'.tr()),
                                    content: TextField(
                                      controller: ctrl,
                                      autofocus: true,
                                      decoration: InputDecoration(hintText: 'group.name_hint'.tr()),
                                      onTap: () => ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
                                      onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
                                      textInputAction: TextInputAction.done,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text('common.save'.tr())),
                                    ],
                                  ),
                                );

                                if (newName == null || newName.isEmpty || newName == currentName) return;
                                await ref.read(groupRepoProvider).updateGroupName(id, newName);
                                ref.invalidate(groupsProvider);
                                if (context.mounted) {
                                  showAppSnack(
                                    ref,
                                    title: 'common.success'.tr(),
                                    message: 'group.name_update'.tr(),
                                    type: AppNotice.success,
                                  );
                                }
                              },
                            ),

                            IconButton(
                              icon: const Icon(Icons.logout, size: 20),
                              tooltip: 'group.leave'.tr(),
                              onPressed: () async {
                                final id = g['id'] as int;
                                final uid = Supabase.instance.client.auth.currentUser?.id;
                                if (uid == null) return;

                                final rows = await Supabase.instance.client
                                    .from('members')
                                    .select('role')
                                    .eq('group_id', id)
                                    .eq('user_id', uid)
                                    .isFilter('deleted_at', null)
                                    .limit(1);

                                if (rows.isNotEmpty) {
                                  final role = rows.first['role'] as String?;
                                  if (role == 'owner' || role == 'admin') {
                                    if (context.mounted) {
                                      showAppSnack(
                                        ref,
                                        title: 'common.failed'.tr(),
                                        message: 'group.cannot_leave_admin'.tr(),
                                        type: AppNotice.error,
                                      );
                                    }
                                    return;
                                  }
                                }

                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Gruptan ayrıl?'),
                                    content: Text('group.leave_message'.tr(args: [g['name'] as String])),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('group.leave_confirm'.tr())),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;

                                await ref.read(memberRepoProvider).leaveGroup(id);
                                ref.invalidate(groupsProvider);
                                if (context.mounted) {
                                  showAppSnack(
                                    ref,
                                    title: 'common.info'.tr(),
                                    message: 'group.you_left'.tr(),
                                    type: AppNotice.info,
                                  );
                                }
                              },
                            ),

                            FutureBuilder<String?>(
                              future: (() async {
                                final uid = Supabase.instance.client.auth.currentUser?.id;
                                if (uid == null) return null;
                                final rows = await Supabase.instance.client
                                    .from('members')
                                    .select('role')
                                    .eq('group_id', g['id'] as int)
                                    .eq('user_id', uid)
                                    .isFilter('deleted_at', null)
                                    .limit(1);
                                if (rows.isNotEmpty) {
                                  final r = rows.first['role'];
                                  return (r is String) ? r : null;
                                }
                                return null;
                              })(),
                              builder: (ctx, snap) {
                                final role = snap.data;
                                final canDelete = role == 'owner' || role == 'admin';
                                if (!canDelete) return const SizedBox.shrink();

                                return IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: 'group.delete_tooltip'.tr(),
                                  onPressed: () async {
                                    final id = g['id'] as int;
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('group.delete_title'.tr()),
                                        content: Text('group.delete_message'.tr(args: [g['name'] as String])),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.delete'.tr())),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;

                                    await ref.read(groupRepoProvider).softDeleteGroup(id);
                                    ref.invalidate(groupsProvider);
                                    if (context.mounted) {
                                      showAppSnack(
                                        ref,
                                        title: 'common.success'.tr(),
                                        message: 'group.deleted'.tr(),
                                        type: AppNotice.success,
                                      );
                                    }
                                  },
                                );
                              },
                            ),

                            IconButton(
                              icon: const Icon(Icons.share, size: 20),
                              tooltip: 'group.invite_link'.tr(),
                              onPressed: () async {
                                final ok = await ensureSignedIn(context, ref);
                                if (!ok) return;

                                final groupId = g['id'] as int;
                                final url = await GroupInviteLinkService.createInviteLink(groupId);
                                if (!context.mounted) return;

                                await showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (ctx) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.link),
                                          title: Text('group.invite_copy'.tr()),
                                          onTap: () async {
                                            await Clipboard.setData(ClipboardData(text: url));
                                            Navigator.pop(ctx);
                                            showAppSnack(
                                              ref,
                                              title: 'common.info'.tr(),
                                              message: 'group.invite_copied'.tr(),
                                              type: AppNotice.info,
                                            );
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.share),
                                          title: Text('group.invite_share'.tr()),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            await Share.share(url, subject: 'group.create_invite'.tr());
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
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