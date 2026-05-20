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
  late final TextEditingController _routeNameController;
  late final MapNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(mapProvider.notifier);
    _routeNameController = TextEditingController();
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
    _routeNameController.dispose();
    _routeNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      mapProvider.select((state) => state.routeDraftName),
      (previous, next) {
        if (_routeNameController.text != next) {
          _routeNameController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    final (
      :routeDraftName,
      :routeDraftNameError,
      :routeDraftMode,
      :routeDraftCommittedPoints,
      :routeDraftStage,
      :routeDraftDistanceMeters,
      :routeDraftError,
      :routeDraftColour,
      :isSavingRoute,
    ) = ref.watch(
      mapProvider.select(
        (state) => (
          routeDraftName: state.routeDraftName,
          routeDraftNameError: state.routeDraftNameError,
          routeDraftMode: state.routeDraftMode,
          routeDraftCommittedPoints: state.routeDraftCommittedPoints,
          routeDraftStage: state.routeDraftStage,
          routeDraftDistanceMeters: state.routeDraftDistanceMeters,
          routeDraftError: state.routeDraftError,
          routeDraftColour: state.routeDraftColour,
          isSavingRoute: state.isSavingRoute,
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
                      Expanded(
                        child: _DistanceElevationGroup(
                          routeDraftStage: routeDraftStage,
                          routeDraftDistanceMeters: routeDraftDistanceMeters,
                          routeDraftError: routeDraftError,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: _RouteEditingGroup(
                            routeDraftName: routeDraftName,
                            routeDraftNameError: routeDraftNameError,
                            routeDraftMode: routeMode,
                            routeDraftColour: routeDraftColour,
                            routeNameController: _routeNameController,
                            routeNameFocusNode: _routeNameFocusNode,
                            onNameChanged: notifier.setRouteDraftName,
                            onModeSelected: notifier.setRouteDraftMode,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                        _RouteActionsGroup(
                          onCancel: notifier.endRouteDraft,
                          onSave: notifier.saveRouteDraft,
                          canSave:
                            routeDraftCommittedPoints.length >= 2 &&
                            routeDraftName.trim().isNotEmpty &&
                            routeDraftStage != RouteDraftStage.routingSegment &&
                            !isSavingRoute,
                          isSaving: isSavingRoute,
                        ),
                    ],
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
  const _DistanceElevationGroup({
    required this.routeDraftStage,
    required this.routeDraftDistanceMeters,
    required this.routeDraftError,
  });

  final RouteDraftStage routeDraftStage;
  final double routeDraftDistanceMeters;
  final String? routeDraftError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceKilometers = (routeDraftDistanceMeters / 1000)
        .toStringAsFixed(1);

    return Column(
      key: const Key('route-distance-elevation-group'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (routeDraftStage == RouteDraftStage.routingSegment)
          Text(
            'Routing...',
            key: const Key('route-loading-text'),
            style: theme.textTheme.bodyMedium,
          )
        else if (routeDraftError != null)
          Text(
            routeDraftError!,
            key: const Key('route-error-text'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (routeDraftDistanceMeters > 0)
          Text(
            '$distanceKilometers km',
            key: const Key('route-distance-text'),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(
            'Tap two points to route',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _RouteEditingGroup extends StatelessWidget {
  const _RouteEditingGroup({
    required this.routeDraftName,
    required this.routeDraftNameError,
    required this.routeDraftMode,
    required this.routeDraftColour,
    required this.routeNameController,
    required this.routeNameFocusNode,
    required this.onNameChanged,
    required this.onModeSelected,
  });

  final String routeDraftName;
  final String? routeDraftNameError;
  final RouteMode routeDraftMode;
  final int routeDraftColour;
  final TextEditingController routeNameController;
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
                selectedColor: Color(routeDraftColour),
                onPressed: () => onModeSelected(RouteMode.snapToTrail),
              ),
              const SizedBox(width: 8),
              _RouteModeButton(
                key: const Key('route-mode-straight-line'),
                label: 'Straight Line',
                selected: routeDraftMode == RouteMode.straightLine,
                selectedColor: Color(routeDraftColour),
                onPressed: null,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 244,
                child: TextFormField(
                  key: const Key('route-name-field'),
                  controller: routeNameController,
                  focusNode: routeNameFocusNode,
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
        if (routeDraftNameError != null) ...[
          const SizedBox(height: 8),
          Text(
            routeDraftNameError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _RouteModeButton extends StatelessWidget {
  const _RouteModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
  const _RouteActionsGroup({
    required this.onCancel,
    required this.onSave,
    required this.canSave,
    required this.isSaving,
  });

  final VoidCallback onCancel;
  final Future<void> Function() onSave;
  final bool canSave;
  final bool isSaving;

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
              onPressed: canSave ? () => onSave() : null,
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
