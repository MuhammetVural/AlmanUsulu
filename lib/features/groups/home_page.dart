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
import 'group_detail_page.dart';

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
      appBar: AppBar(title: const Text('Gruplar')),
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
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final g = rows[i];

                // created_at veritabanında UNIX saniyesi, DateTime ms bekliyor → ×1000
                final createdAtSec = g['created_at'] as int;
                final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000).toLocal();
                final formattedDate = DateFormat('dd-MM-yyyy | HH:mm').format(createdAt);
                final myRoleAsync = ref.watch(myRoleForGroupProvider(g['id'] as int));
                final role = myRoleAsync.asData?.value;
                final Color dotColor = myRoleAsync.when(
                  data: (role) => (role == 'owner') ? Colors.green : Colors.amber,
                  loading: () => Colors.grey, // yüklenirken nötr renk
                  error: (_, __) => Colors.red,
                );
                return ListTile(
                  title: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g['name'] as String)),
                    ],
                  ),
                  subtitle: Text(formattedDate), // istersen intl ile biçimlendirebiliriz
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✏️ Ad düzenle
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
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
                                onTap: () {
                                  // kutuya yeniden dokunursa yine hepsini seç
                                  ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
                                },
                                onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()), // klavyeden Enter ile onaylama işlemi
                                textInputAction: TextInputAction.done,
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                  child: const Text('Kaydet'),
                                ),
                              ],
                            ),
                          );

                          // İptal/boşsa yapma
                          if (newName == null || newName.isEmpty || newName == currentName) return;

                          // DB güncelle
                          await ref.read(groupRepoProvider).updateGroupName(id, newName);

                          // Listeyi yenile
                          ref.invalidate(groupsProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Grup adı güncellendi')),
                            );
                          }
                        },
                      ),
                      // gruptan ayrıl (sadece kendini listeden kaldır)
                      IconButton(
                        icon: const Icon(Icons.logout),

                        tooltip: 'Gruptan ayrıl',
                        onPressed: () async {
                          final id = g['id'] as int;

                          // 1) Onay diyaloğu
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Gruptan ayrıl?'),
                              content: Text('“${g['name']}” grubundan ayrıldığınızda bu grup sizin listenizden kalkacak ve hesaplamalara dahil edilmeyeceksiniz.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ayrıl')),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          // 2) Sadece kendini gruptan çıkar
                          await ref.read(memberRepoProvider).leaveGroup(id);

                          // 3) Listeyi yenile
                          ref.invalidate(groupsProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gruptan ayrıldınız')),
                            );
                          }
                        },
                      ),
                      // Yalnızca owner/admin ise grubu tamamen silebilme (global)
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
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Grubu sil (tüm üyeler için)',
                            onPressed: () async {
                              final id = g['id'] as int;

                              // Onay diyaloğu
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Grup silinsin mi?'),
                                  content: Text('“${g['name']}” grubunu silerseniz TÜM ÜYELER için kaldırılacaktır. Devam edilsin mi?'),
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
                        icon: const Icon(Icons.share),
                        tooltip: 'Davet linki',
                        onPressed: () async {
                          // 1) Giriş kontrolü (login yoksa mini dialog açılır)
                          final ok = await ensureSignedIn(context);
                          if (!ok) return;

                          // 2) Davet linki üret
                          final groupId = g['id'] as int;
                          final url = await GroupInviteLinkService.createInviteLink(groupId);
                          if (!context.mounted) return;

                          // 3) Alt sheet: Kopyala / Paylaş
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