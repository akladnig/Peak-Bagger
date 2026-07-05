import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeColorPalette = ref.watch(themeColorPaletteProvider);
    final themeSchemeVariant = ref.watch(themeSchemeVariantProvider);
    final themeContrastLevel = ref.watch(themeContrastLevelProvider);
    ref.watch(routeGraphBootstrapProvider);

    final themeConfig = ThemeConfig(
      useSeedGeneratedColorScheme: themeColorPalette == ThemeColorPalette.seeded,
      seedColor: const Color(0xFF7E47EB),
      dynamicSchemeVariant: themeSchemeVariant,
      contrastLevel: themeContrastLevel,
    );

    return MaterialApp.router(
      title: 'Peak Bagger',
      theme: CatppuccinColors.lightWith(themeConfig),
      darkTheme: CatppuccinColors.darkWith(themeConfig),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
