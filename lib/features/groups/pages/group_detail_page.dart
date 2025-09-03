
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_alman_usulu/widgets/loading_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/providers.dart';
import '../../../data/repo/auth_repo.dart';
import '../../../services/group_invite_link_service.dart';
import '../home_page.dart';
import '../presentation/sheets/expense_filter_sheet.dart';
import '../presentation/widgets/balance_tile.dart';
import '../presentation/widgets/expense_tile.dart';
import '../presentation/widgets/member_tile.dart';
import '../presentation/widgets/section_card.dart';

class GroupDetailPage extends ConsumerWidget {
  final int groupId;
  final String groupName;
  const GroupDetailPage({super.key, required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👇 Benim bu gruptaki rolüm
    final myRoleAsync = ref.watch(myRoleForGroupProvider(groupId));
    final String? myRole = myRoleAsync.asData?.value; // 'owner' | 'admin' | 'member' | null
    final hasFilter = ref.watch(currentExpenseFilterProvider(groupId)) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: const [Padding(
          padding: EdgeInsets.only(right: 12),
          child: ThemeToggleIcon(),
        )],),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membersProvider(groupId));
          ref.invalidate(expensesProvider(groupId));
          ref.invalidate(balancesProvider(groupId));
        },
        child: Consumer(
          builder: (context, ref, _) {
            final membersAsync = ref.watch(membersProvider(groupId));
            final expensesAsync = ref.watch(visibleExpensesProvider(groupId));
            final balancesAsync = ref.watch(balancesProvider(groupId));

            // Hepsi aynı anda gelsin istiyorsak:
            if (membersAsync.isLoading || expensesAsync.isLoading || balancesAsync.isLoading) {
              return const ListTile(title: LoadingList());
            }
            if (membersAsync.hasError) {
              return ListTile(title: Text('Üye hatası: ${membersAsync.error}'));
            }
            if (expensesAsync.hasError) {
              return ListTile(title: Text('Harcama hatası: ${expensesAsync.error}'));
            }
            if (balancesAsync.hasError) {
              return ListTile(title: Text('Bakiye hatası: ${balancesAsync.error}'));
            }

            final members = membersAsync.value ?? [];
            final expenses = expensesAsync.value ?? [];
            final balances = balancesAsync.value ?? {};


// --- 3 Ayrı Kart: Bakiye Özeti, Harcamalar, Üyeler ---

// 1) Bakiye Özeti kartı item'ları
            final List<Widget> balanceItems = [];
            if (balances.isEmpty) {
              balanceItems.add(
                const ListTile(dense: true, title: Text('Üye yok')),
              );
            } else {
              for (final entry in balances.entries) {
                final member = members.firstWhere(
                      (m) => m['id'] == entry.key,
                  orElse: () => {'name': 'Üye #${entry.key}', 'user_id': null, 'id': entry.key},
                );
                balanceItems.add(
                  BalanceTile(
                    member: member,
                    amount: entry.value,
                    members: members,
                    groupId: groupId,
                    ref: ref,
                  ),
                );
              }
            }

// 2) Harcamalar kartı item'ları
            final List<Widget> expenseItems = [];
            if (expenses.isEmpty) {
              expenseItems.add(
                const ListTile(dense: true, title: Text('Henüz harcama yok')),
              );
            } else {
              for (final e in expenses) {
                expenseItems.add(
                  ExpenseTile(
                    expense: e,
                    members: members,
                    groupId: groupId,
                    ref: ref,
                    canManage: (myRole == 'owner' || myRole == 'admin'),
                  ),
                );
              }
            }

// 3) Üyeler kartı item'ları
            final List<Widget> memberItems = [];
            if (members.isEmpty) {
              memberItems.add(
                const ListTile(dense: true, title: Text('Gruba üye eklenmemiş')),
              );
            } else {
              for (final m in members) {
                memberItems.add(
                  MemberTile(member: m, groupId: groupId,),
                );
              }
            }

// 3 ayrı kartı tek bir scroll içinde göster
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96, top: 8, left: 12, right: 12),
              children: [
                SectionCard(title: 'Bakiye Özeti', children: balanceItems),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Harcamalar',
                  header: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Harcamalar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      IconButton(
                        tooltip: hasFilter ? 'Filtre aktif — değiştir' : 'Filtrele',
                        icon: Icon(Icons.filter_list, color: hasFilter ? Theme.of(context).colorScheme.primary : null),
                        onPressed: () => openExpenseFilterSheet(context, ref, groupId, members),
                      ),
                    ],
                  ),
                  children: expenseItems,
                ),
                const SizedBox(height: 12),
                SectionCard(title: 'Üyeler', children: memberItems),
              ],
            );








          },
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
            ref.invalidate(filteredExpensesProvider);
            ref.invalidate(visibleExpensesProvider(groupId));
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
// Payer seçimi:
// - member ise: otomatik kendisi
// - owner/admin ise: istediği kişiyi seçebilir
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oturum bulunamadı.')),
        );
      }
      return;
    }

// Bu gruptaki mevcut kullanıcının member kaydını bul
    final me = members.firstWhere(
          (m) => m['user_id'] == uid,
      orElse: () => throw Exception('Bu grupta üye olarak görünmüyorsunuz'),
    );
    final myRole = (me['role'] as String?) ?? 'member';

    int? payerId;
    if (myRole == 'owner' || myRole == 'admin') {
      // owner/admin: payeri seçebilir
      payerId = await showDialog<int>(
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
    } else {
      // normal üye: her zaman kendisi
      payerId = (me['id'] as num).toInt();
    }

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
    ref.invalidate(filteredExpensesProvider);
    ref.invalidate(visibleExpensesProvider(groupId));
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


