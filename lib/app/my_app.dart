import 'package:flutter/material.dart';
import 'package:local_alman_usulu/app/auth_gate.dart';

/// Root app widget.
///
/// - [home] opsiyoneldir; verilmezse basit bir yer tutucu ekran gösterilir.
/// - Material 3 teması ve `colorSchemeSeed` ile kolayca özelleştirilebilir.
class MyApp extends StatelessWidget {
  final Widget? home;
  final Color? seedColor;

  const MyApp({
    super.key,
    this.home,
    this.seedColor,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alman Usulü',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor ?? Colors.teal,
      ),
      home: AuthGate(child: home ?? const _DefaultHome()),
    );
  }
}

/// Eğer `home` verilmezse kullanıcıya kısa bir uyarı gösteren basit bir sayfa.
class _DefaultHome extends StatelessWidget {
  const _DefaultHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alman Usulü')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'MyApp.home bağlanmadı.\n\n'
            'main.dart içinde runApp(MyApp(home: HomePage())) şeklinde kullanın.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
