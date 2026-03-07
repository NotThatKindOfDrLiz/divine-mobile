// ABOUTME: Shared utilities for support dialogs (bug reports, feature requests)
// ABOUTME: Contains common input decoration styling for consistency

import 'package:flutter/material.dart';
import 'package:divine_ui/divine_ui.dart';

/// Build consistent input decoration for support dialog text fields
InputDecoration buildSupportInputDecoration({
  required String label,
  required String hint,
  String? helper,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: VineTheme.onSurfaceVariant),
    hintText: hint,
    hintStyle: const TextStyle(color: VineTheme.onSurfaceDisabled),
    helperText: helper,
    helperStyle: const TextStyle(color: VineTheme.onSurfaceDisabled),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: VineTheme.onSurfaceMuted),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: VineTheme.outlineVariant),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: VineTheme.vineGreen),
    ),
  );
}
