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
    ref.watch(routeGraphBootstrapProvider);

    return MaterialApp.router(
      title: 'Peak Bagger',
      theme: CatppuccinColors.light,
      darkTheme: CatppuccinColors.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
