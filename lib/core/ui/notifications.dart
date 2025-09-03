import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

enum AppNotice { success, info, warning, error }

void showAppSnack(
    WidgetRef ref, {
      required String title,
      required String message,
      AppNotice type = AppNotice.success,
    }) {
  final key = ref.read(scaffoldMessengerKeyProvider);

  final Color base = switch (type) {
    AppNotice.success => Colors.green,
    AppNotice.info    => Colors.blue,
    AppNotice.warning => Colors.amber,
    AppNotice.error   => Colors.red,
  };

  final snack = SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    content: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: base.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            switch (type) {
              AppNotice.success => Icons.check_circle,
              AppNotice.info    => Icons.info,
              AppNotice.warning => Icons.warning_amber_rounded,
              AppNotice.error   => Icons.error,
            },
            color: base,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: base,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                      color: Colors.black87,
                    )),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  key.currentState?..clearSnackBars();
  key.currentState?..showSnackBar(snack);
}