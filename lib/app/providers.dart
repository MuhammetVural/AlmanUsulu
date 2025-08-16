import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/db/database_provider.dart';
import '../data/repo/group_repo.dart';
import '../data/repo/member_repo.dart';
import '../data/repo/expense_repo.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final databaseProvider = FutureProvider<Database>((ref) async {
  return AppDatabase.instance.db;
});

final groupRepoProvider = Provider<GroupRepo>((ref) => GroupRepo());
final memberRepoProvider = Provider<MemberRepo>((ref) => MemberRepo());
final expenseRepoProvider = Provider<ExpenseRepo>((ref) => ExpenseRepo());

final groupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(groupRepoProvider);
  return repo.listGroups();
});

final membersProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, groupId) async {
  final client = ref.read(supabaseClientProvider);
  final res = await client
      .from('members')
      .select()
      .eq('group_id', groupId)
      .isFilter('deleted_at', null);

  return (res as List).cast<Map<String, dynamic>>();
});

final expensesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, groupId) async {
  final client = ref.read(supabaseClientProvider);
  final res = await client
      .from('expenses')
      .select()
      .eq('group_id', groupId)
      .isFilter('deleted_at', null);

  return (res as List).cast<Map<String, dynamic>>();
});

/// Basit bakiye hesaplayıcı (eşit bölüşme)
final balancesProvider = FutureProvider.family<Map<int, double>, int>((ref, groupId) async {

  final repo = ref.watch(expenseRepoProvider);

  final members = await ref.watch(membersProvider(groupId).future);
  final expenses = await ref.watch(expensesProvider(groupId).future);
  final expenseRepo = ref.read(expenseRepoProvider);

  // başlangıç bakiyeleri (id -> 0.0)
  final balances = {for (final m in members) m['id'] as int: 0.0};

  for (final e in expenses) {
    final expenseId = e['id'] as int;
    final amount = (e['amount'] as num).toDouble();
    final payerId = e['payer_id'] as int;
    final parts = await expenseRepo.listParticipants(expenseId);
    if (parts.isEmpty) continue;
    final share = amount / parts.length;

    // payer alacaklandır
    balances[payerId] = (balances[payerId] ?? 0) + amount;

    // her katılımcı borçlandır
    for (final p in parts) {
      final mid = p['member_id'] as int;
      balances[mid] = (balances[mid] ?? 0) - share;
    }
  }
  return balances;
});