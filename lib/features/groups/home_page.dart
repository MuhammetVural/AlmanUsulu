import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_alman_usulu/features/widgets/app_drawer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/providers.dart';
import '../../data/repo/auth_repo.dart';
import '../../services/group_invite_link_service.dart';
import 'pages/group_detail_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    // Davet linki dinleyicisini ayağa kaldır (idempotent)
    ref.watch(inviteLinksInitProvider);



    // Başka biri Login olunca sayfayı yeniler
    ref.listen(authStateProvider, (previous, next) {
      ref.invalidate(groupsProvider);
    });

    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        title: const Text('Gruplar'),
        actions: const [Padding(
          padding: EdgeInsets.only(right: 12),
          child: ThemeToggleIcon(),
        )],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Provider’ı invalid edip yeniden fetch etmesini bekle
          ref.invalidate(groupsProvider);
          await ref.read(groupsProvider.future);
        },
        child: groupsAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(child: Text('Henüz grup yok. + ile ekleyin.'));
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(),
              itemBuilder: (ctx, i) {
                final g = rows[i];

                // created_at veritabanında UNIX saniyesi, DateTime ms bekliyor → ×1000
                final createdAtSec = g['created_at'] as int;
                final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000).toLocal();
                final formattedDate = DateFormat('dd-MM-yyyy | HH:mm').format(createdAt);
                final myRoleAsync = ref.watch(myRoleForGroupProvider(g['id'] as int));
                // final role = myRoleAsync.asData?.value;
                final Color dotColor = myRoleAsync.when(
                  data: (role) => (role == 'owner') ? Colors.green : Colors.amber,
                  loading: () => Colors.grey, // yüklenirken nötr renk
                  error: (_, __) => Colors.red,
                );
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
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).cardTheme.color,
                    elevation: Theme.of(context).cardTheme.elevation ?? 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.6,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // başlık + küçük etiket
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g['name'] as String,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // rol etiketini küçük pil gibi göster
                                    myRoleAsync.when(
                                      data: (role) {
                                        final label = (role == 'owner')
                                            ? 'OWNER'
                                            : (role == 'admin')
                                            ? 'ADMIN'
                                            : 'MEMBER';
                                        final color = (role == 'owner' || role == 'admin')
                                            ? Colors.green
                                            : Colors.amber;
                                        return _Pill(label: label, color: color); // ✅ burada Pill dönüyoruz
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    ),

                                  ],
                                ),
                                const SizedBox(height: 6),

                                // tarih satırı (sağ uçta)

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start, // 🔹 sola hizalı
                                  children: [
                                    Text(
                                      "Oluşturulma Tarihi: ",
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

                                const SizedBox(height: 8),
                                // aksiyonlar (mevcut işlevler aynen)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Adı düzenle',
                                      onPressed: () async {
                                        final id = g['id'] as int;
                                        final currentName = (g['name'] as String?) ?? '';
                                        final ctrl = TextEditingController(text: currentName);
                                        ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);

                                        final newName = await showDialog<String>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Grup adını düzenle'),
                                            content: TextField(
                                              controller: ctrl,
                                              autofocus: true,
                                              decoration: const InputDecoration(hintText: 'Yeni grup adı'),
                                              onTap: () => ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length),
                                              onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
                                              textInputAction: TextInputAction.done,
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                                              FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Kaydet')),
                                            ],
                                          ),
                                        );

                                        if (newName == null || newName.isEmpty || newName == currentName) return;
                                        await ref.read(groupRepoProvider).updateGroupName(id, newName);
                                        ref.invalidate(groupsProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(content: Text('Grup adı güncellendi')));
                                        }
                                      },
                                    ),

                                    // gruptan ayrıl
                                    IconButton(
                                      icon: const Icon(Icons.logout, size: 20),
                                      tooltip: 'Gruptan ayrıl',
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
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('⚠️ Admin/Owner gruptan ayrılamaz. (Geliştiriliyor)')),
                                              );
                                            }
                                            return;
                                          }
                                        }

                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Gruptan ayrıl?'),
                                            content: Text('“${g['name']}” grubu listenizden kaldırılacak.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ayrıl')),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) return;

                                        await ref.read(memberRepoProvider).leaveGroup(id);
                                        ref.invalidate(groupsProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(content: Text('Gruptan ayrıldınız')));
                                        }
                                      },
                                    ),

                                    // (owner/admin ise) sil
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
                                          tooltip: 'Grubu sil (tüm üyeler için)',
                                          onPressed: () async {
                                            final id = g['id'] as int;
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Grup silinsin mi?'),
                                                content: Text('“${g['name']}” tüm üyeler için kaldırılacak.'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                                                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                                                ],
                                              ),
                                            );
                                            if (confirmed != true) return;

                                            await ref.read(groupRepoProvider).softDeleteGroup(id);
                                            ref.invalidate(groupsProvider);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Grup silindi')),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),

                                    IconButton(
                                      icon: const Icon(Icons.share, size: 20),
                                      tooltip: 'Davet linki',
                                      onPressed: () async {
                                        final ok = await ensureSignedIn(context);
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
                                                  title: const Text('Bağlantıyı kopyala'),
                                                  onTap: () async {
                                                    await Clipboard.setData(ClipboardData(text: url));
                                                    Navigator.pop(ctx);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Davet linki kopyalandı')),
                                                    );
                                                  },
                                                ),
                                                ListTile(
                                                  leading: const Icon(Icons.share),
                                                  title: const Text('Paylaş (WhatsApp / Instagram / …)'),
                                                  onTap: () async {
                                                    Navigator.pop(ctx);
                                                    await Share.share(url, subject: 'Gruba katıl daveti');
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
                          ),
                        ],
                      ),
                    ),
                  ),
                );

              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Hata: $e'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _askGroupName(context);
          if (name == null || name.trim().isEmpty) return;



          // Grup oluştur
          await ref.read(groupRepoProvider).createGroup(name.trim());

          // Listeyi yenile
          ref.invalidate(groupsProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Grup eklendi')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _askGroupName(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grup adı'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ör. Ev Arkadaşları',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final bg = color.withValues(alpha: .12);
    final fg = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class ThemeToggleIcon extends ConsumerWidget {
  const ThemeToggleIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final Brightness systemB = MediaQuery.of(context).platformBrightness;

    // Şu an koyu mu?
    final bool isDarkNow = switch (mode) {
      ThemeMode.dark   => true,
      ThemeMode.light  => false,
      ThemeMode.system => systemB == Brightness.dark,
    };

    final icon = isDarkNow ? Icons.dark_mode : Icons.light_mode;
    final tooltip = isDarkNow ? 'Karanlık tema' : 'Aydınlık tema';

    return IconButton(
      tooltip: '$tooltip (değiştir)',
      icon: Icon(icon),
      onPressed: () {
        // Her basışta sadece Light <-> Dark
        ref.read(themeModeProvider.notifier)
            .set(isDarkNow ? ThemeMode.light : ThemeMode.dark);
      },
    );
  }
}

