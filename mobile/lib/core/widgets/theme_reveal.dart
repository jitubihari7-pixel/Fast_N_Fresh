import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// Switches the app between Light and Dark.
///
/// The switch is instant: the old circular "reveal" animation snapshotted the
/// screen and looked odd over the redesigned screens, and an instant change
/// keeps MaterialApp's theme and the legacy [AppColors] palette in lockstep.
/// [originContext] is accepted for compatibility with existing callers.
Future<void> changeThemeWithReveal(
  BuildContext context,
  AppThemeMode targetMode, {
  BuildContext? originContext,
}) {
  return context.read<ThemeProvider>().setMode(targetMode);
}
