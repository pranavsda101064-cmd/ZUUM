import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Text input with Zuum decoration, optional obscure toggle, error line.
class ZTextField extends StatefulWidget {
  const ZTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;

  @override
  State<ZTextField> createState() => _ZTextFieldState();
}

class _ZTextFieldState extends State<ZTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: !widget.obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      onTap: widget.onTap,
      style: ZTypography.body,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 2,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20, color: ZColors.textTertiary),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: ZColors.textTertiary,
                ),
              )
            : widget.suffix,
      ),
    );
  }
}
