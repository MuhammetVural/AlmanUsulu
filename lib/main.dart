import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/my_app.dart';
import 'features/groups/home_page.dart';

void main() {
  runApp(ProviderScope(child: MyApp(home: const HomePage())));
}

