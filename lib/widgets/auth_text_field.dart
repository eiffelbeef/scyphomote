import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData icon;
  final TextInputType keyboardType;
  final Iterable<String> autofillHints;
  final String emptyErrorMsg;
  final bool obscureText;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    required this.icon,
    required this.keyboardType,
    required this.autofillHints,
    required this.emptyErrorMsg,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      validator: (value) {
        if (!obscureText && (value == null || value.isEmpty)) {
          return emptyErrorMsg;
        }
        return null;
      },
    );
  }
}
