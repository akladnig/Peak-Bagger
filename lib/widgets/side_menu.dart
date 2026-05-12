import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

import 'package:peak_bagger/router.dart';

class SideMenu extends StatelessWidget {
  final List<ShellDestination> destinations;
  final int selectedBranchIndex;
  final ValueChanged<ShellDestination> onDestinationSelected;

  const SideMenu({
    super.key,
    required this.destinations,
    required this.selectedBranchIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsetsDirectional.all(0),
      margin: EdgeInsetsDirectional.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      width: UiConstants.sideMenuColumnWidth,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            for (final destination in destinations) ...[
              _buildDestination(
                destination: destination,
                isSelected: selectedBranchIndex == destination.branchIndex,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestination({
    required ShellDestination destination,
    required bool isSelected,
  }) {
    final child = _WideMenuItemNew(
      key: Key(destination.keyName),
      icon: destination.icon,
      label: destination.label,
      isSelected: isSelected,
      onTap: () => onDestinationSelected(destination),
    );

    if (destination.legacyKeyName == null) {
      return child;
    }

    return Container(
      // color: Colors.cyan,
      // margin: EdgeInsetsGeometry.symmetric(vertical: 0, horizontal: 0),
      // padding: EdgeInsetsGeometry.symmetric(vertical: 0, horizontal: 0),
      key: Key(destination.legacyKeyName!),
      child: child,
    );
  }
}

class _WideMenuItemNew extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WideMenuItemNew({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        // color: isSelected
        // ? (isDark ? const Color(0xFF45475A) : const Color(0xFFBCC0CC))
        // ? (isDark ? const Color(0xFF6347EA) : const Color(0xFFBCC0CC))
        // : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(icon),
                    style: IconButton.styleFrom(
                      backgroundColor: isSelected
                          ? theme.iconTheme.color
                          : theme.colorScheme.primaryContainer,
                      foregroundColor: isSelected
                          ? theme.colorScheme.primaryContainer
                          : theme.iconTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    isSelected: isSelected,
                    onPressed: onTap,
                    mouseCursor: SystemMouseCursors.click,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
