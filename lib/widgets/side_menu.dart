import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/providers/theme_provider.dart';

class SideMenu extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const SideMenu({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      width: 64,
      color: theme.appBarTheme.backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _MenuItem(
            icon: Icons.dashboard,
            isSelected: navigationShell.currentIndex == 0,
            onTap: () => navigationShell.goBranch(0),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.map,
            isSelected: navigationShell.currentIndex == 1,
            onTap: () => navigationShell.goBranch(1),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.list_alt,
            isSelected: navigationShell.currentIndex == 2,
            onTap: () => navigationShell.goBranch(2),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.settings,
            isSelected: navigationShell.currentIndex == 3,
            onTap: () => navigationShell.goBranch(3),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF45475A) : const Color(0xFFBCC0CC))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : theme.iconTheme.color,
        ),
      ),
    );
  }
}
