
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/providers.dart';
import '../../data/repo/auth_repo.dart';
import '../../services/group_invite_link_service.dart';
import '../widgets/app_drawer.dart';

class GroupDetailPage extends ConsumerWidget {
  final int groupId;
  final String groupName;
  const GroupDetailPage({super.key, required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider(groupId));
    final expensesAsync = ref.watch(expensesProvider(groupId));
    final balancesAsync = ref.watch(balancesProvider(groupId));
    // 👇 Benim bu gruptaki rolüm
    final myRoleAsync = ref.watch(myRoleForGroupProvider(groupId));
    final String? myRole = myRoleAsync.asData?.value; // 'owner' | 'admin' | 'member' | null

    return Scaffold(
      appBar: AppBar(title: Text(groupName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(membersProvider(groupId));
          ref.invalidate(expensesProvider(groupId));
          ref.invalidate(balancesProvider(groupId));
        },
        child: Consumer(
          builder: (context, ref, _) {
            final membersAsync = ref.watch(membersProvider(groupId));
            final expensesAsync = ref.watch(expensesProvider(groupId));
            final balancesAsync = ref.watch(balancesProvider(groupId));

            // Hepsi aynı anda gelsin istiyorsak:
            if (membersAsync.isLoading || expensesAsync.isLoading || balancesAsync.isLoading) {
              return const ListTile(title: LinearProgressIndicator());
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
                  _BalanceTile(
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
                  _ExpenseTile(
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
                  _MemberTile(member: m, groupId: groupId, ref: ref),
                );
              }
            }

// 3 ayrı kartı tek bir scroll içinde göster
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96, top: 8, left: 12, right: 12),
              children: [
                _SectionCard(title: 'Bakiye Özeti', children: balanceItems),
                const SizedBox(height: 12),
                _SectionCard(title: 'Harcamalar', children: expenseItems),
                const SizedBox(height: 12),
                _SectionCard(title: 'Üyeler', children: memberItems),
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

enum _RowType { header, note, balance, expense, member }

class _Row {
  final _RowType type;
  final String? title;
  final Map<String, dynamic>? member;
  final double? amount;
  final Map<String, dynamic>? expense;
  final List<Map<String, dynamic>>? members;
  final String? myRole; // owner/admin/member

  const _Row._({
    required this.type,
    this.title,
    this.member,
    this.amount,
    this.expense,
    this.members,
    this.myRole,
  });

  const _Row.header(this.title)
      : type = _RowType.header,
        member = null,
        amount = null,
        expense = null,
        members = null,
        myRole = null;

  const _Row.note(this.title)
      : type = _RowType.note,
        member = null,
        amount = null,
        expense = null,
        members = null,
        myRole = null;

  factory _Row.balance({required Map<String, dynamic> member, required double amount}) =>
      _Row._(type: _RowType.balance, member: member, amount: amount);

  factory _Row.expense({
    required Map<String, dynamic> expense,
    required List<Map<String, dynamic>> members,
    String? myRole,
  }) =>
      _Row._(type: _RowType.expense, expense: expense, members: members, myRole: myRole);

  factory _Row.member({required Map<String, dynamic> member}) =>
      _Row._(type: _RowType.member, member: member);
}

class FadedDivider extends StatelessWidget {
  const FadedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thickness = (1.0 / dpr).clamp(0.4, 1.0); // hairline ~ süper ince

    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Theme.of(context).colorScheme.outlineVariant.withOpacity(.35),
              Theme.of(context).colorScheme.outlineVariant.withOpacity(.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.15, 0.85, 1.0], // kenarlarda silikleşme
          ),
        ),
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final double amount;
  final List<Map<String, dynamic>> members;
  final int groupId;
  final WidgetRef ref;
  const _BalanceTile({required this.member, required this.amount, required this.members, required this.groupId, required this.ref, super.key});

  @override
  Widget build(BuildContext context) {
    final sign = amount >= 0 ? '+' : '';
    final isSelf = (member['user_id'] == Supabase.instance.client.auth.currentUser?.id);
    return ListTile(
      dense: true,
      title: Text(member['name'] as String),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: _colorFromString(member['id'].toString() + (member['name'] as String? ?? '')),
        child: Text(
          (member['name'] as String).isNotEmpty
              ? (member['name'] as String)[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      trailing: Text(
        (amount >= 0)
            ? '+${amount.abs().toStringAsFixed(2)}₺'
            : '-${amount.abs().toStringAsFixed(2)}₺',
        style: TextStyle(
          color: amount >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
      // İstersen burada popup menu vs. ekleyebilirsin
      subtitle: isSelf ? const Text('Sen', style: TextStyle(fontSize: 12)) : null,
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final List<Map<String, dynamic>> members;
  final int groupId;
  final WidgetRef ref;
  final bool canManage;
  const _ExpenseTile({required this.expense, required this.members, required this.groupId, required this.ref, this.canManage = false, super.key});

  @override
  Widget build(BuildContext context) {
    final ts = DateTime.fromMillisecondsSinceEpoch((expense['created_at'] as int) * 1000).toLocal();
    final dateStr = DateFormat('dd-MM-yyyy | HH:mm').format(ts);
    final amountText = (expense['amount'] as num).toStringAsFixed(2);
    final payerId = expense['payer_id'] as int;
    final payerName = (members.firstWhere(
          (m) => m['id'] == payerId,
      orElse: () => {'name': 'Üye #$payerId'},
    )['name'] as String);

    return ListTile(
      title: Text(expense['title']?.toString() ?? '(Başlıksız)'),
      subtitle: Text('$payerName • $dateStr'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$amountText₺',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canManage) // 👈 sadece owner/admin görür
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Silinsin mi?'),
                    content: const Text('Bu harcama silinecek, emin misiniz?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(expenseRepoProvider).softDeleteExpense(expense['id'] as int);
                  ref.invalidate(expensesProvider(groupId));
                  ref.invalidate(balancesProvider(groupId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Harcama silindi')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final int groupId;
  final WidgetRef ref;
  const _MemberTile({required this.member, required this.groupId, required this.ref, super.key});

  @override
  Widget build(BuildContext context) {
    final isSelf = (member['user_id'] == Supabase.instance.client.auth.currentUser?.id);
    final role = member['role'] as String?;
    final bool isAdmin = role == 'owner' || role == 'admin';
    final String? roleLabel = (role == null)
        ? null
        : (role == 'member' ? 'ÜYE' : role.toString().toUpperCase());
    final Color roleColor = isAdmin ? Colors.green : Colors.amber;
    return ListTile(
      title: Text(member['name'] as String),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: _colorFromString(member['id'].toString() + (member['name'] as String? ?? '')),
        child: Text(
          (member['name'] as String).isNotEmpty
              ? (member['name'] as String)[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      subtitle: isSelf ? const Text('Sen', style: TextStyle(fontSize: 12)) : null,
      trailing: (roleLabel == null) ? null : _RolePill(label: roleLabel, color: roleColor),
      // TODO: burada da düzenle/sil aksiyonlarını ekleyebilirsin
    );
  }
}

// Helper function for generating a random color from a string (member id + name)
Color _colorFromString(String input) {
  final hash = input.hashCode;
  final r = (hash & 0xFF0000) >> 16;
  final g = (hash & 0x00FF00) >> 8;
  final b = (hash & 0x0000FF);
  return Color.fromARGB(255, r, g, b).withOpacity(0.8);
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final bg = color.withOpacity(.12);
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 0.5, height: 0.5),
            const SizedBox(height: 2),
            ..._intersperseWithFadedDividers(children),
          ],
        ),
      ),
    );
  }
}

List<Widget> _intersperseWithFadedDividers(List<Widget> items) {
  if (items.isEmpty) return items;
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    out.add(items[i]);
    if (i != items.length - 1) {
      out.add(const FadedDivider()); // yanları silik, çok ince çizgi
    }
  }
  return out;
}