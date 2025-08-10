import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import 'group_detail_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gruplar')),
      body: groupsAsync.when(
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
              return ListTile(
                title: Text(g['name'] as String),
                subtitle: Text(formattedDate.toString()), // istersen intl ile biçimlendirebiliriz
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  // HomePage ListTile.trailing (çöp kutusu ikonunun onPressed'i)
// — Soft delete + Snackbar'da GERİ AL

                  onPressed: () async {
                    final id = g['id'] as int;

                    // 1) Onay diyaloğu
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Silinsin mi?'),
                        content: Text('“${g['name']}” adlı grubu silmek üzeresiniz.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                        ],
                      ),
                    );

                    if (confirmed != true) return; // vazgeçildiyse çık

                    // 2) Soft delete (HATIRLATMA: GroupRepo.softDeleteGroup var olmalı ve _db kullanmalı)
                    await ref.read(groupRepoProvider).softDeleteGroup(id);

                    // 3) Listeyi tazele (ÖNEMLİ: listGroups() -> where: 'deleted_at IS NULL' olmalı)
                    ref.invalidate(groupsProvider);

                    // 4) Snackbar + UNDO
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Grup silindi'),
                          action: SnackBarAction(
                            label: 'GERİ AL',
                            onPressed: () async {
                              await ref.read(groupRepoProvider).undoDeleteGroup(id);
                              ref.invalidate(groupsProvider);
                            },
                          ),
                        ),
                      );
                    }
                  },
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