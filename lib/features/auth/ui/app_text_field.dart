// lib/features/auth/ui/app_text_field.dart
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        border: const UnderlineInputBorder(),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
