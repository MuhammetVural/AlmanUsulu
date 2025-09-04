// DO NOT EDIT. This is code generated via package:easy_localization/generate.dart

// ignore_for_file: prefer_single_quotes, avoid_renaming_method_parameters, constant_identifier_names

import 'dart:ui';

import 'package:easy_localization/easy_localization.dart' show AssetLoader;

class CodegenLoader extends AssetLoader{
  const CodegenLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) {
    return Future.value(mapLocales[locale.toString()]);
  }

  static const Map<String,dynamic> _tr = {
  "common": {
    "filter": "Filtrele",
    "ok": "Tamam",
    "cancel": "Vazgeç",
    "save": "Kaydet",
    "add": "Ekle",
    "yes": "Evet",
    "no": "Hayır",
    "delete": "Sil",
    "error": "Hata: {0}"
  },
  "group": {
    "title": "Gruplar",
    "empty": "Henüz grup yok. + ile ekleyin.",
    "created_at": "Oluşturulma Tarihi:",
    "edit_name": "Adı düzenle",
    "name_dialog_title": "Grup adını düzenle",
    "name_hint": "Yeni grup adı",
    "name_update": "Grup adı güncellendi",
    "leave": "Gruptan ayrıl",
    "cannot_leave_admin": "⚠️ Admin/Owner gruptan ayrılamaz. (Geliştiriliyor)",
    "leave_message": "“{0}” grubu listenizden kaldırılacak.",
    "leave_confirm": "Ayrıl",
    "you_left": "Gruptan ayrıldınız",
    "delete_tooltip": "Grubu sil (tüm üyeler için)",
    "delete_title": "Grup silinsin mi?",
    "delete_message": "“{0}” tüm üyeler için kaldırılacak.",
    "deleted": "Grup silindi",
    "invite_link": "Davet linki",
    "invite_copy": "Bağlantıyı kopyala",
    "invite_copied": "Davet linki kopyalandı",
    "invite_share": "Paylaş (WhatsApp / Instagram / …)",
    "create_invite": "Davetiye Oluştur",
    "added": "Grup eklendi",
    "name_title": "Grup adı",
    "name_hint2": "ör. Ev Arkadaşları"
  },
  "groupDetail": {
    "balance_summary": "Bakiye Özeti",
    "expenses": "Harcamalar",
    "members": "Üyeler",
    "filter": "Filtrele",
    "filter_active_edit": "Filtre aktif — değiştir",
    "no_members": "Üye yok",
    "no_expenses": "Henüz harcama yok",
    "no_group_members": "Gruba üye eklenmemiş",
    "error_members": "Üye hatası: {0}",
    "error_expenses": "Harcama hatası: {0}",
    "error_balances": "Bakiye hatası: {0}",
    "add_member": "Üye ekle",
    "add_expense": "Harcama ekle",
    "invite": "Davet linki"
  },
  "dialogs": {
    "no_see_member": "Bu grupta üye olarak görünmüyorsunuz",
    "add_member_name": "Üye adı",
    "include_in_budget_title": "Bütçeye dahil edilsin mi?",
    "include_in_budget_message": "Bu kişiyi geçmiş harcamalara katılımcı olarak ekleyelim mi?",
    "added_member": "Üye eklendi",
    "included_past": "Üye geçmiş harcamalara dahil edildi",
    "add_expense_title": "Harcama Ekle",
    "amount_prompt": "Tutar (ör. 120.50)",
    "invalid_amount": "Geçersiz tutar.",
    "no_members_yet": "Önce en az bir üye ekleyin.",
    "no_session": "Oturum bulunamadı.",
    "payer": "Ödeyen"
  },
  "theme": {
    "dark": "Karanlık tema",
    "light": "Aydınlık tema",
    "toggle_suffix": "(değiştir)"
  },
  "snack": {
    "made_admin": "Admin yapıldı",
    "removed_admin": "Adminlik kaldırıldı"
  }
};
static const Map<String,dynamic> _en = {
  "common": {
    "filter": "Filter",
    "ok": "OK",
    "cancel": "Cancel",
    "save": "Save",
    "add": "Add",
    "yes": "Yes",
    "no": "No",
    "delete": "Delete",
    "error": "Error: {0}"
  },
  "group": {
    "title": "Groups",
    "empty": "No groups yet. Add with +.",
    "created_at": "Created At:",
    "edit_name": "Edit name",
    "name_dialog_title": "Edit group name",
    "name_hint": "New group name",
    "name_update": "Group name updated",
    "leave": "Leave group",
    "cannot_leave_admin": "⚠️ Admin/Owner cannot leave the group. (In development)",
    "leave_title": "Leave the group?",
    "leave_message": "“{0}” will be removed from your list.",
    "leave_confirm": "Leave",
    "you_left": "You left the group",
    "delete_tooltip": "Delete group (for all members)",
    "delete_title": "Delete group?",
    "delete_message": "“{0}” will be removed for all members.",
    "deleted": "Group deleted",
    "invite_link": "Invite link",
    "invite_copy": "Copy link",
    "invite_copied": "Invite link copied",
    "invite_share": "Share (WhatsApp / Instagram / …)",
    "create_invite": "Create Invite",
    "added": "Group added",
    "name_title": "Group name",
    "name_hint2": "e.g., Flatmates"
  },
  "groupDetail": {
    "balance_summary": "Balance Summary",
    "expenses": "Expenses",
    "members": "Members",
    "filter": "Filter",
    "filter_active_edit": "Filter active — edit",
    "no_members": "No members",
    "no_expenses": "No expenses yet",
    "no_group_members": "No members added to the group",
    "error_members": "Member error: {0}",
    "error_expenses": "Expense error: {0}",
    "error_balances": "Balance error: {0}",
    "add_member": "Add member",
    "add_expense": "Add expense",
    "invite": "Invite link"
  },
  "dialogs": {
    "no_see_member": "You do not appear to be a member of this group.",
    "add_member_name": "Member name",
    "include_in_budget_title": "Include in budget?",
    "include_in_budget_message": "Shall we add this person as a participant to past expenses?",
    "added_member": "Member added",
    "included_past": "Member included in past expenses",
    "add_expense_title": "Add Expense",
    "amount_prompt": "Amount (e.g., 120.50)",
    "invalid_amount": "Invalid amount.",
    "no_members_yet": "Please add at least one member first.",
    "no_session": "No session found.",
    "payer": "Payer"
  },
  "theme": {
    "dark": "Dark theme",
    "light": "Light theme",
    "toggle_suffix": "(switch)"
  },
  "snack": {
    "made_admin": "Made admin",
    "removed_admin": "Admin removed"
  }
};
static const Map<String, Map<String,dynamic>> mapLocales = {"tr": _tr, "en": _en};
}
