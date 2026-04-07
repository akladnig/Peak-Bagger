import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class SideMenu extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const SideMenu({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 64,
      color: theme.appBarTheme.backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: FaIcon(
              FontAwesomeIcons.mountain,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
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
            icon: Icons.landscape,
            isSelected: navigationShell.currentIndex == 2,
            onTap: () => navigationShell.goBranch(2),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.settings,
            isSelected: navigationShell.currentIndex == 3,
            onTap: () => navigationShell.goBranch(3),
          ),
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
