import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/router.dart' as app_router;
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/mapping_store_failure_dialog.dart';

class App extends ConsumerWidget {
  const App({this.router, super.key});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeSeedColor = ref.watch(themeSeedColorProvider);
    final themeSchemeVariant = ref.watch(themeSchemeVariantProvider);
    final themeContrastLevel = ref.watch(themeContrastLevelProvider);
    ref.watch(routeGraphBootstrapProvider);
    ref.watch(mappingStoreBootstrapProvider);

    final themeConfig = ThemeConfig(
      seedColor: themeSeedColor.color,
      dynamicSchemeVariant: themeSchemeVariant,
      contrastLevel: themeContrastLevel,
    );

    return MaterialApp.router(
      title: 'Peak Bagger',
      theme: MyTheme.lightWith(themeConfig),
      darkTheme: MyTheme.darkWith(themeConfig),
      themeMode: themeMode,
      routerConfig: router ?? (app_router.router = app_router.createRouter()),
      builder: (context, child) => MappingStoreFailureDialogHost(
        child: child ?? const SizedBox.shrink(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
