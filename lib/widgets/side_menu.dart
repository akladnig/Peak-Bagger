import 'package:flutter/material.dart';

import 'package:peak_bagger/router.dart';

class SideMenu extends StatelessWidget {
  final List<ShellDestination> destinations;
  final int selectedBranchIndex;
  final ValueChanged<ShellDestination> onDestinationSelected;
  final bool compact;

  const SideMenu({
    super.key,
    required this.destinations,
    required this.selectedBranchIndex,
    required this.onDestinationSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: compact ? null : 132,
      color: theme.appBarTheme.backgroundColor,
      child: compact
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (final destination in destinations)
                  _buildDestination(
                    destination: destination,
                    isSelected: selectedBranchIndex == destination.branchIndex,
                    compact: true,
                  ),
              ],
            )
          : Column(
              children: [
                const SizedBox(height: 12),
                for (final destination in destinations) ...[
                  _buildDestination(
                    destination: destination,
                    isSelected: selectedBranchIndex == destination.branchIndex,
                    compact: false,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Widget _buildDestination({
    required ShellDestination destination,
    required bool isSelected,
    required bool compact,
  }) {
    final child = compact
        ? _CompactMenuItem(
            key: Key(destination.keyName),
            icon: destination.icon,
            label: destination.label,
            isSelected: isSelected,
            onTap: () => onDestinationSelected(destination),
          )
        : _WideMenuItem(
            key: Key(destination.keyName),
            icon: destination.icon,
            label: destination.label,
            isSelected: isSelected,
            onTap: () => onDestinationSelected(destination),
          );

    if (destination.legacyKeyName == null) {
      return child;
    }

    return Container(key: Key(destination.legacyKeyName!), child: child);
  }
}

class _WideMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WideMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: isSelected
            ? (isDark ? const Color(0xFF45475A) : const Color(0xFFBCC0CC))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.iconTheme.color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _CompactMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : theme.iconTheme.color,
      ),
      title: Text(label),
      selected: isSelected,
      selectedTileColor: isDark
          ? const Color(0xFF45475A)
          : const Color(0xFFBCC0CC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}
