import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme_mode';
const _themeColorPaletteKey = 'theme_color_palette';

final themePreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

enum ThemeColorPalette { catppuccin, seeded }

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final themeColorPaletteProvider =
    NotifierProvider<ThemeColorPaletteNotifier, ThemeColorPalette>(
      ThemeColorPaletteNotifier.new,
    );

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _hasUserOverride = false;

  @override
  ThemeMode build() {
    unawaited(_loadTheme());
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getString(_themeKey);
      if (stored != null) {
        state = _parseThemeMode(stored);
      }
    } catch (e) {
      state = ThemeMode.system;
    }
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _hasUserOverride = true;
    state = mode;
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      final value = switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_themeKey, value);
    } catch (e) {
      // Continue with in-memory change
    }
  }

  void toggleTheme() {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }
}

class ThemeColorPaletteNotifier extends Notifier<ThemeColorPalette> {
  bool _hasUserOverride = false;

  @override
  ThemeColorPalette build() {
    unawaited(_loadThemeColorPalette());
    return ThemeColorPalette.catppuccin;
  }

  Future<void> _loadThemeColorPalette() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      final stored = prefs.getString(_themeColorPaletteKey);
      if (stored != null) {
        state = _parseThemeColorPalette(stored);
      }
    } catch (_) {
      state = ThemeColorPalette.catppuccin;
    }
  }

  ThemeColorPalette _parseThemeColorPalette(String value) {
    switch (value) {
      case 'seeded':
        return ThemeColorPalette.seeded;
      case 'catppuccin':
      default:
        return ThemeColorPalette.catppuccin;
    }
  }

  Future<void> setThemeColorPalette(ThemeColorPalette palette) async {
    _hasUserOverride = true;
    state = palette;
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      await prefs.setString(_themeColorPaletteKey, palette.name);
    } catch (_) {
      // Continue with in-memory change
    }
  }
}
