import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/providers.dart';
import 'data/repo/group_repo.dart';
import 'features/groups/group_detail.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alman Usulü',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gruplar')),
      body: groups.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Henüz grup yok. + ile ekle.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final g = rows[i];
              return ListTile(
                title: Text(g['name'] as String),
                subtitle: Text(DateTime.fromMillisecondsSinceEpoch(g['created_at'] as int).toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref.read(groupRepoProvider).deleteGroup(g['id'] as int);
                    ref.invalidate(groupsProvider);
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
          await ref.read(groupRepoProvider).createGroup(name);
          ref.invalidate(groupsProvider);
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
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'ör. Ev Arkadaşları')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Ekle')),
        ],
      ),
    );
  }
}