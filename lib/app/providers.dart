import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/db/database_provider.dart';
import '../data/repo/group_repo.dart';
import '../data/repo/member_repo.dart';
import '../data/repo/expense_repo.dart';
import '../services/group_invite_link_service.dart';

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
      (_) => GlobalKey<NavigatorState>(),
);

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final databaseProvider = FutureProvider<Database>((ref) async {
  return AppDatabase.instance.db;
});

/// Supabase auth state değişince event yayınlar (sign-in, sign-out, token refresh)
final authStateProvider = StreamProvider((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Bu provider sadece auth değişimini dinletmek için.
// Bunu watch eden herkes auth değişince rebuild olur.
final authUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider); // <<— tetikleyici
  return Supabase.instance.client.auth.currentUser?.id;
});

final inviteLinksInitProvider = Provider<void>((ref) {
  // Init sadece bir kez kurulur (service içi idempotent). Hata olursa UI'yi bozmasın.
  GroupInviteLinkService.init(
    onToken: (token) async {
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentSession == null) {
          debugPrint('🔒 Invite token alındı ama kullanıcı login değil.');
          return; // login yoksa bırak
        }
        final gid = await GroupInviteLinkService.acceptInvite(token);
        debugPrint('✅ Invite kabul edildi. group_id=$gid');
        // UI'ye haber ver (Snackbar vb.)
        ref.read(lastAcceptedGroupIdProvider.notifier).state = gid;
        // 🔄 Grupları yenile
        ref.invalidate(groupsProvider);
        // İsteğe bağlı: gid != null ise members/expenses invalidate edilebilir
      } catch (e) {
        debugPrint('❌ Invite kabul hatası: $e');
      }

      // İsteğe bağlı: başka provider’ları da yenileyebilirsin.
      // Örn: ref.invalidate(membersProvider(groupId));
    },
  );
});
// Son kabul edilen davetin group_id'sini UI'ye iletmek için
final lastAcceptedGroupIdProvider = StateProvider<int?>((ref) => null);

final groupRepoProvider = Provider<GroupRepo>((ref) => GroupRepo());
final memberRepoProvider = Provider<MemberRepo>((ref) => MemberRepo());
final expenseRepoProvider = Provider<ExpenseRepo>((ref) => ExpenseRepo());

final groupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final _ = ref.watch(authUserIdProvider);
  final repo = ref.read(groupRepoProvider);
  return repo.listGroups();
});

final membersProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((
  ref,
  groupId,
) async {

  // AUTH DEĞİŞİMİNİ DİNLET
  final _ = ref.watch(authUserIdProvider);

  final sb = Supabase.instance.client;
  final rows = await sb
      .from('members')
      .select('*')
      .eq('group_id', groupId)
      .isFilter('deleted_at', null)
      .order('id', ascending: false);

  return List<Map<String, dynamic>>.from(rows);
});

final expensesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, groupId) async {

    final _ = ref.watch(authUserIdProvider); // auth değişince yeniden fetch
    final client = ref.read(supabaseClientProvider);
    final res = await client
        .from('expenses')
        .select()
        .eq('group_id', groupId)
        .isFilter('deleted_at', null);

    return (res as List).cast<Map<String, dynamic>>();
  },
);

/// -----------------------------------------------
/// EXPENSE FILTERING (payer/date range)
/// -----------------------------------------------
/// Immutable key for filtering expenses in a group.
class ExpenseFilter {
  final int groupId;
  final int? payerId; // only expenses paid by this member
  final int? fromSec; // created_at >= fromSec (Unix seconds)
  final int? toSec;   // created_at <= toSec   (Unix seconds)

  const ExpenseFilter({
    required this.groupId,
    this.payerId,
    this.fromSec,
    this.toSec,
  });

  @override
  bool operator ==(Object other) {
    return other is ExpenseFilter &&
        other.groupId == groupId &&
        other.payerId == payerId &&
        other.fromSec == fromSec &&
        other.toSec == toSec;
  }

  @override
  int get hashCode => Object.hash(groupId, payerId, fromSec, toSec);
}

/// Filtered expenses for a group. Supports payer and date range.
final filteredExpensesProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ExpenseFilter>((ref, filter) async {
  // Re-fetch on auth changes
  final _ = ref.watch(authUserIdProvider);
  final client = ref.read(supabaseClientProvider);

  var query = client
      .from('expenses')
      .select()
      .eq('group_id', filter.groupId)
      .isFilter('deleted_at', null);

  if (filter.payerId != null) {
    query = query.eq('payer_id', filter.payerId!);
  }
  if (filter.fromSec != null) {
    query = query.gte('created_at', filter.fromSec!);
  }
  if (filter.toSec != null) {
    query = query.lte('created_at', filter.toSec!);
  }

  // Newest first for convenience in UI lists
  final res = await query.order('id', ascending: false);
  return (res as List).cast<Map<String, dynamic>>();
});

/// snackbar tasarımı
final scaffoldMessengerKeyProvider =
Provider<GlobalKey<ScaffoldMessengerState>>((ref) {
  return GlobalKey<ScaffoldMessengerState>();
});

/// Optional: keep current filter in UI state per group (null = no filter)

final currentExpenseFilterProvider =
    StateProvider.family<ExpenseFilter?, int>((ref, groupId) => null);

/// -----------------------------------------------
/// VISIBLE EXPENSES (UI tarafı tek provider izler)
/// -----------------------------------------------
/// UI'de sadece bunu watch etmek yeterli. Eğer filtre varsa filtreli,
/// yoksa tüm giderleri döner.
final visibleExpensesProvider = FutureProvider.family<
    List<Map<String, dynamic>>, int>((ref, groupId) async {
  final filter = ref.watch(currentExpenseFilterProvider(groupId));
  if (filter == null) {
    return ref.watch(expensesProvider(groupId).future);
  } else {
    return ref.watch(filteredExpensesProvider(filter).future);
  }
});

/// Küçük yardımcılar: UI'den kolay set/clear
int? _toSec(DateTime? dt) => dt == null ? null : dt.millisecondsSinceEpoch ~/ 1000;

void setExpenseFilter(
  WidgetRef ref,
  int groupId, {
  int? payerId,
  DateTime? from,
  DateTime? to,
}) {
  ref.read(currentExpenseFilterProvider(groupId).notifier).state = ExpenseFilter(
    groupId: groupId,
    payerId: payerId,
    fromSec: _toSec(from),
    toSec: _toSec(to),
  );
}

void clearExpenseFilter(WidgetRef ref, int groupId) {
  ref.read(currentExpenseFilterProvider(groupId).notifier).state = null;
}







/// Basit bakiye hesaplayıcı (eşit bölüşme)
final balancesProvider = FutureProvider.family<Map<int, double>, int>((
  ref,
  groupId,
) async {
  final _ = ref.watch(authUserIdProvider); // auth değişince yeniden hesapla
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


/// Kullanıcının bir gruptaki rolünü döner (owner/admin/member). Yoksa null.
final myRoleForGroupProvider = FutureProvider.family<String?, int>((ref, groupId) async {
  final client = ref.read(supabaseClientProvider);
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final res = await client
      .from('members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', uid)
      .isFilter('deleted_at', null)
      .maybeSingle();

  if (res == null) return null;
  return res['role'] as String?;
});

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);
  static const _key = 'theme_mode';

  ThemeMode _decode(String v) {
    switch (v) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.system:
      default:               return 'system';
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) state = _decode(raw);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  Future<void> toggle() async {
    final next = switch (state) {
      ThemeMode.light  => ThemeMode.dark,
      ThemeMode.dark   => ThemeMode.light,
      ThemeMode.system => ThemeMode.dark,
    };
    await set(next);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  final ctrl = ThemeController();
  ctrl.load(); // async yükle (kalıcı tercih)
  return ctrl;
});
