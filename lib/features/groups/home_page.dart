import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_alman_usulu/features/widgets/app_drawer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/providers.dart';
import '../../app/theme/theme_utils.dart';
import '../../data/repo/auth_repo.dart';
import '../../services/group_invite_link_service.dart';
import 'pages/group_detail_page.dart';
import '../../core/ui/notifications.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final groupsAsync = ref.watch(groupsProvider);
    // Davet linki dinleyicisini ayağa kaldır (idempotent)
    ref.watch(inviteLinksInitProvider);

    // Helper: joined snackbar + reset
    void _showJoinedSnack(int gid) {
      Future.microtask(() async {
        try {
          await ref.read(groupsProvider.future);
        } catch (_) {}

        if (!context.mounted) return;

        String groupName = 'Grup';
        final groupsValue = ref.read(groupsProvider);
        groupsValue.whenData((rows) {
          final match = rows.cast<Map<String, dynamic>>().where((g) => g['id'] == gid);
          if (match.isNotEmpty) {
            groupName = (match.first['name'] as String?) ?? 'Grup';
          }
        });

        // Bazı senaryolarda HomePage mount/demount sırasında Snackbar yutulabiliyor.
        // Kök (root) Navigator'un context'i ile ve bir sonraki frame'de göstermek daha güvenli.
        final rootCtx = Navigator.of(context, rootNavigator: true).overlay?.context ?? context;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;

          showAppSnack(
            ref,
            title: 'common.success'.tr(),
            message: 'group.joined_group'.tr(args: [groupName]),
            type: AppNotice.success,
          );
        });

        ref.read(lastAcceptedGroupIdProvider.notifier).state = null;
      });
    }

    // Eğer değer bu build'ten önce set edildiyse hemen göster
    final _pendingGid = ref.watch(lastAcceptedGroupIdProvider);
    if (_pendingGid != null) {
      _showJoinedSnack(_pendingGid);
    }

    // Davet kabul edildiğinde sadece bilgilendirme göster
    ref.listen<int?>(lastAcceptedGroupIdProvider, (prev, next) {
      if (next == null) return;
      _showJoinedSnack(next);
    });

    // Fallback: Gruplar listesi arttıysa, yeni eklenen grup için snackbar göster.
    // Bu, join sinyalini kaçırdığımız senaryolarda (ör. timing) devreye girer.
    ref.listen(groupsProvider, (prev, next) {
      final prevRows = prev?.asData?.value ?? const <dynamic>[];
      final nextRows = next.asData?.value ?? const <dynamic>[];

      try {
        final prevIds = prevRows
            .map((g) => (g as Map<String, dynamic>)['id'] as int)
            .toSet();
        final nextIds = nextRows
            .map((g) => (g as Map<String, dynamic>)['id'] as int)
            .toSet();

        final added = nextIds.difference(prevIds);
        if (added.isNotEmpty) {
          final gid = added.first;
          _showJoinedSnack(gid);
        }
      } catch (_) {
        // types / null issues — sessiz geç
      }
    });



    // Başka biri Login olunca sayfayı yeniler
    ref.listen(authStateProvider, (previous, next) {
      ref.invalidate(groupsProvider);
    });

    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        title:  Text('group.title'.tr()),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: LanguageToggleIcon(),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ThemeToggleIcon(),
          ),
        ],
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
              return Center(child: Text('group.empty'.tr()));
            }
            // Pastel renkleri listeye dağıt (kullanılmayanı öncele, ardışık tekrar yok)
            final assignedColors = _assignSoftColors(
              rows.map<String>((r) => (r['name'] as String?) ?? '').toList(),
            );
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
                // Bu grubun üyeleri (avatarlar ve sayı için)
                final membersAsync = ref.watch(membersProvider(g['id'] as int));
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
                  // YENİ (Container + tek renk + desen)
                  child: Builder(
                    builder: (context) {
                      // grup adına göre stabil “random” pastel
                      // 1) Paletten gelen baz renk
                      final Color _softBase = assignedColors[i];
                      final Color _soft = adaptSoftForTheme(_softBase, context);

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(24), // desen taşmasın
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),

                            color: _soft, // tek açık arka plan rengi
                            image: const DecorationImage(
                              image: AssetImage('assets/patterns/doodle3.png'),
                              fit: BoxFit.cover,            // zoom yapma
                              opacity: 0.02,               // yumuşak görünüm
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                                        myRoleAsync.when(
                                          data: (role) {
                                            // role from backend: 'owner' | 'admin' | 'member' (or null/other)
                                            final key = (role == 'owner')
                                                ? 'owner'
                                                : (role == 'admin')
                                                ? 'admin'
                                                : 'member';
                                            final color = (role == 'owner' || role == 'admin')
                                                ? Colors.green
                                                : Colors.amber;
                                            return _Pill(label: key, color: color); // label is a localization key
                                          },
                                          loading: () => const SizedBox.shrink(),
                                          error: (_, __) => const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // tarih satırı
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

                                    // aksiyonlar (mevcut işlevler)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Üyeler: küçük avatarlar + "N members"
                                        membersAsync.when(
                                          data: (members) => Row(
                                            children: [
                                              _InlineAvatars(members: members),
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
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
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
                                            // gruptan ayrıl
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
                                                    title: Text('Gruptan ayrıl?'),
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
                                                  enableDrag: true,

                                                  builder: (ctx) => SafeArea(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                                            leading: const Icon(Icons.share_outlined),
                                                            title: Text('group.invite_share'.tr()),
                                                            onTap: () async {
                                                              Navigator.pop(ctx);
                                                              await Share.share(url, subject: 'group.create_invite'.tr());
                                                            },
                                                          ),
                                                        ],
                                                      ),
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
                      );
                    },
                  ),
                );

              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('common.error'.tr(args: [e.toString()])),
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
            showAppSnack(
              ref,
              title: 'common.success'.tr(),
              message: 'group.added'.tr(),
              type: AppNotice.success,
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  /// 10 parçalı pastel palet
  static const List<Color> kSoftPalette = [
    Color(0xFFEDEBFF), // lila
    Color(0xFFE7F3FF), // açık mavi
    Color(0xFFFFEEF2), // pembe
    Color(0xFFFFF3E5), // şeftali
    Color(0xFFEFFBF1), // mint
    Color(0xFFEAF7FF), // buz mavisi
    Color(0xFFFFF0F5), // lavanta pembe
    Color(0xFFEFF0FF), // perivinkle
    Color(0xFFEFFAF6), // mint cream
    Color(0xFFFFFAE5), // açık sarı
  ];

  /// Basit seed -> renk (gerekirse)
  Color _softColorFromSeed(String seed) {
    final h = seed.hashCode.abs();
    return kSoftPalette[h % kSoftPalette.length];
  }

  /// Listedeki her grup için renk atar:
  /// - Önce kullanılmamış renkleri tüketir
  /// - Palet bittiğinde, bir önceki ile aynı rengi vermez (ardışık tekrar yok)
  /// - Seed (grup adı) başlangıç ofsetini belirler; görünüm çoğunlukla stabil kalır
  List<Color> _assignSoftColors(List<String> names) {
    final int n = kSoftPalette.length;
    final used = <int>{};
    final colors = <Color>[];
    int? prevIdx;

    for (final seed in names) {
      final base = seed.hashCode.abs() % n;
      int pick = -1;

      // 1) Kullanılmayan renkleri öncele
      for (int step = 0; step < n; step++) {
        final idx = (base + step) % n;
        if (!used.contains(idx) && idx != prevIdx) {
          pick = idx;
          break;
        }
      }

      // 2) Hepsi kullanıldıysa: prev ile aynı olmayan ilk rengi seç
      if (pick == -1) {
        for (int step = 0; step < n; step++) {
          final idx = (base + step) % n;
          if (idx != prevIdx) {
            pick = idx;
            break;
          }
        }
      }

      used.add(pick);
      prevIdx = pick;
      colors.add(kSoftPalette[pick]);
    }

    return colors;
  }

  Future<String?> _askGroupName(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:  Text('group.name_title'.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:  InputDecoration(
            hintText: 'group.name_hint2'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:  Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child:  Text('common.add'.tr()),
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
        'group.role.$label'.tr(),
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
    final tooltip = isDarkNow ? 'theme.dark'.tr() : 'theme.light'.tr();

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
class LanguageToggleIcon extends StatelessWidget {
  const LanguageToggleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final String code = context.locale.languageCode.toUpperCase(); // TR / EN
    final String next = (code == 'TR') ? 'EN' : 'TR';
    final tooltip = next + ' ' + 'theme.toggle_suffix'.tr();

    return IconButton(
      tooltip: tooltip,
      onPressed: () async {
        final nextLocale = (code == 'TR') ? const Locale('en') : const Locale('tr');
        await context.setLocale(nextLocale);
      },
      icon: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .25),
          ),
        ),
        child: Text(
          code,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}




// --- Küçük inline avatarlar (grup listesi altında) ----------------------------
class _InlineAvatars extends StatelessWidget {
  const _InlineAvatars({required this.members});
  final List<Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) {

    final visible = members.take(3).toList();
    final width = (visible.length <= 1) ? 22.0 : (22.0 + (visible.length - 1) * 16.0);
    return SizedBox(
      width: width,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(visible.length, (i) {
          final m = visible[i];
          final name = (m['name'] as String?) ?? '';
          final initials = _initials(name);
          final bg = _avatarColorFor(name);
          return Positioned(
            left: i * 16.0,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.white.withValues(alpha: 0.5), // ince beyaz kenar efekti
              child: CircleAvatar(
                radius: 10,
                backgroundColor: bg,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
}

// Avatar arka plan rengi — 12 tonluk sabit paletten, isme göre
const List<Color> _kAvatarPalette = [
  Color(0xFF6C63FF), // mor
  Color(0xFF2F88FF), // mavi
  Color(0xFFFF6B6B), // kırmızı
  Color(0xFFFF9E47), // turuncu
  Color(0xFF00B894), // teal
  Color(0xFF10B981), // yeşil
  Color(0xFF6366F1), // indigo
  Color(0xFFEC4899), // pembe
  Color(0xFFF59E0B), // amber
  Color(0xFF3B82F6), // azure
  Color(0xFF14B8A6), // aqua
  Color(0xFF8B5CF6), // lavanta
];

Color _avatarColorFor(String seed) {
  final h = seed.hashCode.abs();
  return _kAvatarPalette[h % _kAvatarPalette.length];
}