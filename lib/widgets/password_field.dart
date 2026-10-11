import 'package:flutter/material.dart';

/// Champ de saisie de mot de passe réutilisable avec bouton
/// pour afficher/masquer la valeur saisie.
class PasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? hintText;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final Key? fieldKey;

  const PasswordField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText = 'Mot de passe',
    this.hintText,
    this.textInputAction = TextInputAction.done,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints = const [AutofillHints.password],
    this.fieldKey,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscureText ? 'Afficher' : 'Masquer',
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
