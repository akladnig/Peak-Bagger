import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/providers/map_provider.dart';

class MapRouteBottomSheet extends ConsumerStatefulWidget {
  const MapRouteBottomSheet({super.key});

  @override
  ConsumerState<MapRouteBottomSheet> createState() =>
      _MapRouteBottomSheetState();
}

class _MapRouteBottomSheetState extends ConsumerState<MapRouteBottomSheet> {
  late final FocusNode _routeNameFocusNode;
  late final MapNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(mapProvider.notifier);
    _routeNameFocusNode = FocusNode()
      ..addListener(() {
        if (mounted) {
          _notifier.setRouteDraftNameFieldFocused(_routeNameFocusNode.hasFocus);
        }
      });
  }

  @override
  void dispose() {
    _notifier.setRouteDraftNameFieldFocused(false);
    _routeNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (:routeDraftName, :routeDraftMode) = ref.watch(
      mapProvider.select(
        (state) => (
          routeDraftName: state.routeDraftName,
          routeDraftMode: state.routeDraftMode,
        ),
      ),
    );

    final notifier = ref.read(mapProvider.notifier);
    final theme = Theme.of(context);
    final routeMode = routeDraftMode;

    return Material(
      key: const Key('route-bottom-sheet'),
      elevation: 10,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: RouteConstants.sheetHeight,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _DistanceElevationGroup()),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: _RouteEditingGroup(
                            routeDraftName: routeDraftName,
                            routeDraftMode: routeMode,
                            routeNameFocusNode: _routeNameFocusNode,
                            onNameChanged: notifier.setRouteDraftName,
                            onModeSelected: notifier.setRouteDraftMode,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RouteActionsGroup(
                        onCancel: notifier.endRouteDraft,
                        onSave: notifier.endRouteDraft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('route-elevation-placeholder'),
                    height: 92,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(12),
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

class _DistanceElevationGroup extends StatelessWidget {
  const _DistanceElevationGroup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const Key('route-distance-elevation-group'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '12.3 km',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: '  •  '),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.arrow_upward, size: 16),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '315 m',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: '  •  '),
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.arrow_downward, size: 16),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '234 m',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteEditingGroup extends StatelessWidget {
  const _RouteEditingGroup({
    required this.routeDraftName,
    required this.routeDraftMode,
    required this.routeNameFocusNode,
    required this.onNameChanged,
    required this.onModeSelected,
  });

  final String routeDraftName;
  final RouteMode routeDraftMode;
  final FocusNode routeNameFocusNode;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<RouteMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const Key('route-editing-group'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Routing Mode:', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              _RouteModeButton(
                key: const Key('route-mode-snap-to-trail'),
                label: 'Snap to Trail',
                selected: routeDraftMode == RouteMode.snapToTrail,
                onPressed: () => onModeSelected(RouteMode.snapToTrail),
              ),
              const SizedBox(width: 8),
              _RouteModeButton(
                key: const Key('route-mode-straight-line'),
                label: 'Straight Line',
                selected: routeDraftMode == RouteMode.straightLine,
                onPressed: () => onModeSelected(RouteMode.straightLine),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 244,
                child: TextFormField(
                  key: const Key('route-name-field'),
                  focusNode: routeNameFocusNode,
                  initialValue: routeDraftName,
                  onChanged: onNameChanged,
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    hintText: 'Route name',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteModeButton extends StatelessWidget {
  const _RouteModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = Colors.green.shade700;

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? selectedColor
            : theme.colorScheme.surfaceContainer,
        foregroundColor: selected ? Colors.white : theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _RouteActionsGroup extends StatelessWidget {
  const _RouteActionsGroup({required this.onCancel, required this.onSave});

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('route-actions-group'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const Key('route-cancel-button'),
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('route-save-button'),
              onPressed: onSave,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
