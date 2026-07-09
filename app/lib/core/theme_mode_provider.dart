import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen theme mode (system / light / dark), persisted locally.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
