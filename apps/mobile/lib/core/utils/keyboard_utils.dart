import 'package:flutter/widgets.dart';

/// Oculta el teclado y quita el foco del campo activo.
void hideKeyboard() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus != null && focus.hasFocus) {
    focus.unfocus();
  }
}
