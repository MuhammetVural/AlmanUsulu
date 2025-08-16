import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_alman_usulu/env/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/my_app.dart';
import 'features/groups/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey
  );
  runApp(const ProviderScope(child: MyApp(home: HomePage())));
}

