// ABOUTME: Platform detection helpers for consistent desktop/mobile checks.
// ABOUTME: Centralizes platform logic to avoid scattered inline checks.

import 'package:flutter/foundation.dart';
import 'dart:io';

/// Whether the current platform is a desktop OS (macOS, Windows, or Linux).
///
/// Returns `false` on web regardless of the underlying OS.
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
