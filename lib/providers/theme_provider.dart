import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme_mode';
const _themeColorPaletteKey = 'theme_color_palette';
const _themeSeedColorKey = 'theme_seed_color';
const _themeSchemeVariantKey = 'theme_scheme_variant';
const _themeContrastLevelKey = 'theme_contrast_level';

final bootstrappedThemePreferencesProvider = Provider<SharedPreferences?>(
  (ref) => null,
);

final themePreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

enum ThemeColorPalette { catppuccin, seeded }

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final themeSeedColorProvider =
    NotifierProvider<ThemeSeedColorNotifier, ThemeSeedSwatch>(
      ThemeSeedColorNotifier.new,
    );

final themeColorPaletteProvider =
    NotifierProvider<ThemeColorPaletteNotifier, ThemeColorPalette>(
      ThemeColorPaletteNotifier.new,
    );

final themeSchemeVariantProvider =
    NotifierProvider<ThemeSchemeVariantNotifier, DynamicSchemeVariant>(
      ThemeSchemeVariantNotifier.new,
    );

final themeContrastLevelProvider =
    NotifierProvider<ThemeContrastLevelNotifier, double>(
      ThemeContrastLevelNotifier.new,
    );

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _hasUserOverride = false;

  @override
  ThemeMode build() {
    final bootstrappedPreferences = ref.watch(
      bootstrappedThemePreferencesProvider,
    );
    if (bootstrappedPreferences != null) {
      return _parseThemeMode(bootstrappedPreferences.getString(_themeKey));
    }

    unawaited(_loadTheme());
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      state = _parseThemeMode(prefs.getString(_themeKey));
    } catch (e) {
      state = ThemeMode.system;
    }
  }

  ThemeMode _parseThemeMode(String? value) {
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

class ThemeSeedColorNotifier extends Notifier<ThemeSeedSwatch> {
  bool _hasUserOverride = false;

  @override
  ThemeSeedSwatch build() {
    final bootstrappedPreferences = ref.watch(
      bootstrappedThemePreferencesProvider,
    );
    if (bootstrappedPreferences != null) {
      _clearLegacyThemeColorPalette(bootstrappedPreferences);
      return _parseThemeSeedSwatch(
        bootstrappedPreferences.getString(_themeSeedColorKey),
      );
    }

    unawaited(_loadThemeSeedColor());
    return defaultThemeSeedSwatch;
  }

  Future<void> _loadThemeSeedColor() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      _clearLegacyThemeColorPalette(prefs);
      if (_hasUserOverride) {
        return;
      }

      state = _parseThemeSeedSwatch(prefs.getString(_themeSeedColorKey));
    } catch (_) {
      if (!_hasUserOverride) {
        state = defaultThemeSeedSwatch;
      }
    }
  }

  ThemeSeedSwatch _parseThemeSeedSwatch(String? value) {
    return themeSeedSwatchById(value) ?? defaultThemeSeedSwatch;
  }

  Future<void> setThemeSeedColor(ThemeSeedSwatch swatch) async {
    _hasUserOverride = true;
    state = swatch;
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      _clearLegacyThemeColorPalette(prefs);
      await prefs.setString(_themeSeedColorKey, swatch.id);
    } catch (_) {
      // Continue with in-memory change
    }
  }

  void _clearLegacyThemeColorPalette(SharedPreferences prefs) {
    if (prefs.containsKey(_themeColorPaletteKey)) {
      unawaited(prefs.remove(_themeColorPaletteKey));
    }
  }
}

class ThemeColorPaletteNotifier extends Notifier<ThemeColorPalette> {
  @override
  ThemeColorPalette build() {
    final bootstrappedPreferences = ref.watch(
      bootstrappedThemePreferencesProvider,
    );
    if (bootstrappedPreferences != null &&
        bootstrappedPreferences.containsKey(_themeColorPaletteKey)) {
      unawaited(bootstrappedPreferences.remove(_themeColorPaletteKey));
    } else {
      unawaited(_removeLegacyThemeColorPalette());
    }

    return ThemeColorPalette.seeded;
  }

  Future<void> _removeLegacyThemeColorPalette() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      if (prefs.containsKey(_themeColorPaletteKey)) {
        await prefs.remove(_themeColorPaletteKey);
      }
    } catch (_) {
      state = ThemeColorPalette.seeded;
    }
  }

  Future<void> setThemeColorPalette(ThemeColorPalette palette) async {
    state = ThemeColorPalette.seeded;
    await _removeLegacyThemeColorPalette();
  }
}

class ThemeSchemeVariantNotifier extends Notifier<DynamicSchemeVariant> {
  bool _hasUserOverride = false;

  @override
  DynamicSchemeVariant build() {
    final bootstrappedPreferences = ref.watch(
      bootstrappedThemePreferencesProvider,
    );
    if (bootstrappedPreferences != null) {
      return _parseThemeSchemeVariant(
        bootstrappedPreferences.getString(_themeSchemeVariantKey),
      );
    }

    unawaited(_loadThemeSchemeVariant());
    return DynamicSchemeVariant.vibrant;
  }

  Future<void> _loadThemeSchemeVariant() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      state = _parseThemeSchemeVariant(prefs.getString(_themeSchemeVariantKey));
    } catch (_) {
      state = DynamicSchemeVariant.vibrant;
    }
  }

  DynamicSchemeVariant _parseThemeSchemeVariant(String? value) {
    return DynamicSchemeVariant.values.firstWhere(
      (variant) => variant.name == value,
      orElse: () => DynamicSchemeVariant.vibrant,
    );
  }

  Future<void> setThemeSchemeVariant(DynamicSchemeVariant variant) async {
    _hasUserOverride = true;
    state = variant;
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      await prefs.setString(_themeSchemeVariantKey, variant.name);
    } catch (_) {
      // Continue with in-memory change
    }
  }
}

class ThemeContrastLevelNotifier extends Notifier<double> {
  bool _hasUserOverride = false;

  @override
  double build() {
    final bootstrappedPreferences = ref.watch(
      bootstrappedThemePreferencesProvider,
    );
    if (bootstrappedPreferences != null) {
      return _clampContrastLevel(
        bootstrappedPreferences.getDouble(_themeContrastLevelKey) ?? 0.0,
      );
    }

    unawaited(_loadThemeContrastLevel());
    return 0.0;
  }

  Future<void> _loadThemeContrastLevel() async {
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      if (_hasUserOverride) {
        return;
      }

      state = _clampContrastLevel(
        prefs.getDouble(_themeContrastLevelKey) ?? 0.0,
      );
    } catch (_) {
      state = 0.0;
    }
  }

  Future<void> setThemeContrastLevel(double contrastLevel) async {
    final next = _clampContrastLevel(contrastLevel);
    _hasUserOverride = true;
    state = next;
    try {
      final prefs = await ref.read(themePreferencesLoaderProvider)();
      await prefs.setDouble(_themeContrastLevelKey, next);
    } catch (_) {
      // Continue with in-memory change
    }
  }

  double _clampContrastLevel(double value) {
    return value.clamp(-1.0, 1.0);
  }
}
