import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_alman_usulu/features/home/widgets/group_list_item.dart';
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
                final soft = assignedColors[i];
                return GroupListItem(g: g, softColor: soft);

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
