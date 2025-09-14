import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_file.dart';
import 'package:intl/intl.dart';
import 'package:local_alman_usulu/env/env.dart';
import 'package:local_alman_usulu/firebase_options.dart';
import 'package:local_alman_usulu/l10n/localization_manager.dart';
import 'package:local_alman_usulu/services/email_invite_link_service.dart';
import 'package:local_alman_usulu/services/group_invite_link_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/my_app.dart';
import 'app/splash_gate.dart';
import 'features/groups/home_page.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr';
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,

  );


  runApp(LocalizationManager(child: const ProviderScope(child: MyApp(home: SplashGate()))));
}
