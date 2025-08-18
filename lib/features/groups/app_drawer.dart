// lib/widgets/drawer.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('Alman Usulü'),
            accountEmail: Text(user?.email ?? '—'),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            decoration: const BoxDecoration(color: Colors.teal),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Gruplar'),
            onTap: () {
              // Drawer’ı kapat; ana ekrandaysan kal, başka ekrandaysan geri dönmek istersen buraya yönlendirme koyabiliriz.
              Navigator.of(context).pop();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış yap'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pop(); // drawer kapansın
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Çıkış yapıldı')),
                );
              }
              // AuthGate zaten login ekranına döndürecek.
            },
          ),
        ],
      ),
    );
  }
}