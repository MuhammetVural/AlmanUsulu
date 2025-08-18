import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef InviteTokenHandler = Future<void> Function(String token);

class GroupInviteLinkService {
  static AppLinks? _links;

  /// Neden: Uygulama hem soğuk başlarken, hem açıkken gelen linkleri yakalamak için
  static Future<void> init({required InviteTokenHandler onToken}) async {
    _links ??= AppLinks();

    // soğuk başlangıç (uygulama link ile açılır)
    final initial = await _links!.getInitialLink();
    if (initial != null) {
      final token = initial.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        await onToken(token); // UI’dan bağımsız, üst katman karar versin
      }
    }

    // app açıkken (arka planda link gelirse)
    _links!.uriLinkStream.listen((uri) async {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        await onToken(token);
      }
    });
  }

  /// Neden: Owner/Admin bir davet linki üretip paylaşabilsin
  static Future<String> createInviteLink(int groupId) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;

    final row = await client
        .from('invites')
        .insert({
      'group_id': groupId,
      'inviter_id': uid,
    })
        .select('token')
        .single();

    final token = row['token'] as String;

    // Neden HTTPS link: App yoksa web açılır → oradan app link’e yönlendiririz
    return 'https://almanusulu-3838.web.app/invite?token=$token';
  }

  /// Neden: Token’ı RPC ile doğrulayıp üyeliği DB tarafında eklemek
  // lib/services/group_invite_link_service.dart
  static Future<int?> acceptInvite(String token) async {
    final client = Supabase.instance.client;
    final res = await client.rpc('accept_invite', params: {'p_token': token});
    // res -> {"out_group_id": 123, "out_role":"member"} veya null
    if (res is Map && res['out_group_id'] != null) {
      return (res['out_group_id'] as num).toInt();
    }
    return null;
  }

}