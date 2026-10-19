import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

import 'package:peak_bagger/router.dart';
import 'shell_destination_keyboard.dart';

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
        color: theme.colorScheme.onPrimaryFixed,
        borderRadius: BorderRadius.circular(12),
      ),
      width: UiConstants.sideMenuColumnWidth,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            for (final destination in destinations) ...[
              _buildDestination(
                context: context,
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
    required BuildContext context,
    required ShellDestination destination,
    required bool isSelected,
  }) {
    final keyboard = ShellDestinationKeyboard.maybeOf(context);
    final highlighted = keyboard?.highlightedIndex == destination.branchIndex;
    final item = _WideMenuItemNew(
      key: Key(destination.keyName),
      icon: destination.icon,
      label: destination.label,
      isSelected: isSelected,
      onTap: () => onDestinationSelected(destination),
    );
    final child = Focus(
      key: Key('shell-destination-${destination.branchIndex}-focus'),
      focusNode: keyboard?.nodes[destination.branchIndex],
      skipTraversal: true,
      descendantsAreTraversable:
          selectedBranchIndex != 0 && keyboard?.temporary != true,
      child: ExcludeFocus(
        excluding: keyboard?.temporary == true,
        child: Semantics(
          label: destination.label,
          selected: isSelected,
          focused: highlighted,
          child: DecoratedBox(
            key: Key('shell-destination-${destination.branchIndex}-highlight'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlighted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: item,
          ),
        ),
      ),
    );

    if (destination.legacyKeyName == null) {
      return child;
    }

    return Container(key: Key(destination.legacyKeyName!), child: child);
  }
}

class _WideMenuItemNew extends StatelessWidget {
  final Widget icon;
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
                    tooltip: label,
                    icon: icon,
                    style: IconButton.styleFrom(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primaryFixed
                          : theme.colorScheme.onPrimaryFixed,
                      foregroundColor: isSelected
                          ? theme.colorScheme.onPrimaryFixed
                          : theme.colorScheme.primaryFixed,
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
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primaryFixed,
                      ),
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
