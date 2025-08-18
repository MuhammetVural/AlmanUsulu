
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/providers.dart';
import '../../data/repo/auth_repo.dart';
import '../../services/group_invite_link_service.dart';

class GroupDetailPage extends ConsumerWidget {
  final int groupId;
  final String groupName;
  const GroupDetailPage({super.key, required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider(groupId));
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final balancesAsync = ref.watch(balancesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: Text(groupName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membersProvider(groupId));
          ref.invalidate(expensesProvider(groupId));
          ref.invalidate(balancesProvider(groupId));
        },
        child: ListView(
          children: [
            const ListTile(title: Text('Bakiye Özeti')),
            balancesAsync.when(
              data: (bals) {
                if (bals.isEmpty) {
                  return const ListTile(title: Text('Üye yok'));
                }
                return Column(
                  children: bals.entries.map((e) {
                    final member = (membersAsync.asData?.value ?? []).firstWhere(
                          (m) => m['id'] == e.key,
                      orElse: () => {'name': 'Üye #${e.key}'},
                    );
                    final amount = e.value;
                    final sign = amount >= 0 ? '+' : '';
                    final currentUid = Supabase.instance.client.auth.currentUser?.id;
                    final isSelf = (member['user_id'] == currentUid);
                    return ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          Text(member['name'] as String),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Adı düzenle',
                            onPressed: (member['id'] == null) ? null : () async {
                              final currentName = (member['name'] as String?) ?? '';
                              final ctrl = TextEditingController(text: currentName);
                              ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
                              final newName = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Üye adını düzenle'),
                                  content: TextField(
                                    controller: ctrl,
                                    autofocus: true,
                                    onTap: (){
                                      ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
                                    },
                                    textInputAction: TextInputAction.done,
                                  ),

                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Kaydet')),
                                  ],
                                ),
                              );
                              if (newName == null || newName.isEmpty || newName == currentName) return;

                              await ref.read(memberRepoProvider).updateMemberName(member['id'] as int, newName);
                              ref.invalidate(membersProvider(groupId)); // isimler tazelensin
                            },
                          ),
                          if(!isSelf)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Silinsin mi?'),
                                    content: const Text('Bu üyeyi silmek istediğinize emin misiniz?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Vazgeç'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          final currentUid = Supabase.instance.client.auth.currentUser?.id;
                                          final memberId = member['id'] as int?;
                                          final memberUserId = member['user_id'] as String?; // select(*) içinde döndüğümüz alan
                                          if (memberUserId != null && memberUserId == currentUid) {
                                            Navigator.pop(ctx, false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Kendinizi silemezsiniz.')),);
                                            return; }
                                          Navigator.pop(ctx, true);
                                        },

                                        child: const Text('Sil'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed != true) return;

                                // Soft delete + katılımcı kayıtlarını sil
                                final memberId = member['id'];
                                await ref.read(memberRepoProvider).softDeleteMember( groupId, memberId);

                                // Listeyi yenile
                                ref.invalidate(membersProvider(groupId));
                                ref.invalidate(expensesProvider(groupId));
                                ref.invalidate(balancesProvider(groupId));

                                // Geri al için snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Üye silindi'),
                                    action: SnackBarAction(
                                      label: 'GERİ AL',
                                      onPressed: () async {
                                        await ref.read(memberRepoProvider).undoDeleteMember(memberId, groupId);
                                        await ref.read(memberRepoProvider)
                                            .undoDeleteMember(memberId, groupId);
                                        ref.invalidate(membersProvider(groupId));
                                        ref.invalidate(balancesProvider(groupId));
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      trailing: Text('$sign${amount.toStringAsFixed(2)}'),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => ListTile(title: Text('Bakiye hatası: $e')),
            ),
            const Divider(),
            const ListTile(title: Text('Harcamalar')),

            expensesAsync.when(
              data: (rows) => rows.isEmpty
                  ? const ListTile(title: Text('Henüz harcama yok'))
                  : Column(
                children: rows.map((e) {
                  final members = membersAsync.asData?.value ?? [];
                  final ts = DateTime.fromMillisecondsSinceEpoch((e['created_at'] as int) * 1000).toLocal();
                  final formattedDate = DateFormat('dd-MM-yyyy | HH:mm').format(ts);
                  final amountText = (e['amount'] as num).toStringAsFixed(2);
                  final payerId = e['payer_id'] as int;
                  final payerName = (members.firstWhere(
                        (m) => m['id'] == payerId,
                    orElse: () => {'name': 'Üye #$payerId'},
                  )['name'] as String);
                  return ListTile(
                    title: Row(
                      children: [
                        Text(e['title']?.toString() ?? '(Başlıksız)'),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Başlığı düzenle',
                            onPressed: () async {
                              final titleCtrl = TextEditingController(text: e['title']?.toString() ?? '');
                              final amountCtrl = TextEditingController(text: (e['amount'] as num).toStringAsFixed(2));
                              titleCtrl.selection = TextSelection(baseOffset: 0, extentOffset: titleCtrl.text.length);

                              final result = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Harcama Düzenle'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: titleCtrl,
                                        decoration: const InputDecoration(labelText: 'Başlık'),
                                        onTap: (){
                                          titleCtrl.selection = TextSelection(baseOffset: 0, extentOffset: titleCtrl.text.length);
                                        },

                                        textInputAction: TextInputAction.done,
                                      ),
                                      TextField(
                                        controller: amountCtrl,
                                        decoration: const InputDecoration(labelText: 'Tutar'),
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        onSubmitted: (_) => Navigator.pop(ctx, titleCtrl.text.trim()), // klavyeden Enter ile onaylama işlemi
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                                    FilledButton(
                                      onPressed: () {
                                        final newTitle = titleCtrl.text.trim();
                                        final newAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                                        if (newTitle.isNotEmpty && newAmount != null) {
                                          Navigator.pop(ctx, {
                                            'title': newTitle,
                                            'amount': newAmount,
                                          });
                                        }
                                      },
                                      child: const Text('Kaydet'),
                                    ),
                                  ],
                                ),
                              );

                              if (result != null) {
                                await ref.read(expenseRepoProvider).updateExpense(
                                  e['id'] as int,
                                  title: result['title'],
                                  amount: result['amount'],
                                );
                                ref.invalidate(expensesProvider(groupId));
                                ref.invalidate(balancesProvider(groupId));
                              }
                            }
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Silinsin mi?'),
                                content: const Text('Bu harcama silinecek, emin misiniz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Vazgeç'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sil'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await ref.read(expenseRepoProvider).softDeleteExpense(e['id'] as int);
                              ref.invalidate(expensesProvider(groupId));

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: const Text('Harcama silindi'),
                                    action: SnackBarAction(
                                      label: 'Geri Al',
                                      onPressed: () async{
                                        await ref.read(expenseRepoProvider).undoDeleteExpense(e['id'] as int);
                                        ref.invalidate(expensesProvider(groupId));
                                        ref.invalidate(balancesProvider(groupId));
                                      }

                                  ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    subtitle: Text('$payerName ödedi • $formattedDate'),
                    trailing: Text(amountText),
                  );
                }).toList(),
              ),
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => ListTile(title: Text('Harcama hatası: $e')),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: _Fab(groupId: groupId),
    );
  }
}

class _Fab extends ConsumerWidget {
  final int groupId;
  const _Fab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return PopupMenuButton<String>(

      onSelected: (key) async {
        // ⬇️ GİRİŞ YOKSA AUTH SAYFASINA GÖTÜR
        final ok = await ensureSignedIn(context);
        if (!ok) return;
        if (key == 'member') {
          final name = await _askText(context, 'Üye adı');
          if (name == null || name.trim().isEmpty) return;

          // 1) Üyeyi ekle ve yeni üyenin id'sini al
          final newMemberId = await ref.read(memberRepoProvider).addMember(groupId, name.trim());

          // 2) Üye listesini hemen tazele
          ref.invalidate(membersProvider(groupId));

          // 3) Bu grupta aktif harcama var mı? Yoksa sorma
          final hasExpenses = await ref.read(expenseRepoProvider).hasActiveExpenses(groupId);
          if (!hasExpenses) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Üye eklendi')),
              );
            }
            return;
          }

          // 4) Varsa kullanıcıya sor
          final includePast = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Bütçeye dahil edilsin mi?'),
              content: const Text('Bu kişiyi geçmiş harcamalara katılımcı olarak ekleyelim mi?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
              ],
            ),
          );

          // 5) Evet ise geçmişe dahil et ve listeleri tazele
          if (includePast == true) {
            await ref.read(memberRepoProvider).includeMemberInPastExpensesFast(groupId, newMemberId);
            ref.invalidate(expensesProvider(groupId));
            ref.invalidate(balancesProvider(groupId));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Üye geçmiş harcamalara dahil edildi')),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Üye eklendi')),
              );
            }
          }
        } else if (key == 'expense') {
          await _addExpenseFlow(context, ref, groupId);
        }
        else if (key == 'invite') {
          // 1) Davet linki üret
          final url = await GroupInviteLinkService.createInviteLink(groupId);

          // 2) Alt seçenekleri göster: Kopyala / Paylaş
          if (context.mounted) {
            await showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (ctx) {
                return SafeArea(
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
                );
              },
            );
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'member', child: Text('Üye ekle')),
        PopupMenuItem(value: 'expense', child: Text('Harcama ekle')),
        PopupMenuItem(value: 'invite', child: Text('Davet linki')),
      ],
      child: const FloatingActionButton(child: Icon(Icons.add), onPressed: null),
    );
  }

  Future<void> _addExpenseFlow(BuildContext context, WidgetRef ref, int groupId) async {
    final members = await ref.read(memberRepoProvider).listMembers(groupId);
    if (members.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce en az bir üye ekleyin.')));
      }
      return;
    }
    final title = await _askText(context, 'Harcama Ekle');
    if (title == null) return;

    final amountStr = await _askText(context, 'Tutar (ör. 120.50)');
    if (amountStr == null) return;
    final amount = double.tryParse(amountStr.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz tutar.')));
      }
      return;
    }

    // Payer seçimi
    final payerId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ödeyen'),
        children: members
            .map((m) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, m['id'] as int),
          child: Text(m['name'] as String),
        ))
            .toList(),
      ),
    );
    if (payerId == null) return;

    // Katılımcılar (hepsi eşit bölüşüm, v1)
    final participantIds = members.map<int>((m) => m['id'] as int).toList();

    await ref.read(expenseRepoProvider).addExpense(
      groupId: groupId,
      title: title,
      amount: amount,
      payerId: payerId,
      participantIds: participantIds,
    );
    ref.invalidate(expensesProvider(groupId));
    ref.invalidate(balancesProvider(groupId));
  }

  Future<String?> _askText(BuildContext context, String title) async {
    final ctrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Tamam')),
        ],
      ),
    );
  }
}