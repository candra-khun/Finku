import 'package:flutter/material.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  String get storageValue => name;

  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => AppThemeMode.system,
    );
  }
}
