import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';

enum _RouteModeVisualState { inactive, active, selected }

_RouteModeVisualState _routeModeVisualState({
  required RouteMode mode,
  required RouteMode selectedMode,
  required RouteDraftStage stage,
  required bool hasPeakTarget,
}) {
  final isSelected = selectedMode == mode;
  final isRouting = stage == RouteDraftStage.routingSegment;
  final isAvailable = switch (mode) {
    RouteMode.routeToPeak => hasPeakTarget,
    RouteMode.snapToTrail || RouteMode.straightLine => true,
  };

  if (!isAvailable) {
    return _RouteModeVisualState.inactive;
  }
  if (isSelected) {
    return _RouteModeVisualState.selected;
  }
  if (isRouting || isAvailable) {
    return _RouteModeVisualState.active;
  }
  return _RouteModeVisualState.inactive;
}

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
    ref.listen<String>(mapProvider.select((state) => state.routeDraftName), (
      previous,
      next,
    ) {
      if (_routeNameController.text != next) {
        _routeNameController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final (
      :routeDraftName,
      :routeDraftNameError,
      :routeDraftMode,
      :routeDraftPeakTarget,
      :routeDraftMarkers,
      :routeDraftCommittedPoints,
      :routeDraftStage,
      :routeDraftDistanceMeters,
      :routeDraftError,
      :routeDraftElevationSummary,
      :routeDraftElevationLoading,
      :routeDraftElevationError,
      :routeDraftColour,
      :isSavingRoute,
    ) = ref.watch(
      mapProvider.select(
        (state) => (
          routeDraftName: state.routeDraftName,
          routeDraftNameError: state.routeDraftNameError,
          routeDraftMode: state.routeDraftMode,
          routeDraftPeakTarget: state.routeDraftPeakTarget,
          routeDraftMarkers: state.routeDraftMarkers,
          routeDraftCommittedPoints: state.routeDraftCommittedPoints,
          routeDraftStage: state.routeDraftStage,
          routeDraftDistanceMeters: state.routeDraftDistanceMeters,
          routeDraftError: state.routeDraftError,
          routeDraftElevationSummary: state.routeDraftElevationSummary,
          routeDraftElevationLoading: state.routeDraftElevationLoading,
          routeDraftElevationError: state.routeDraftElevationError,
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
                          routeDraftElevationSummary:
                              routeDraftElevationSummary,
                          routeDraftElevationLoading:
                              routeDraftElevationLoading,
                          routeDraftElevationError: routeDraftElevationError,
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
                            routeDraftStage: routeDraftStage,
                            routeDraftPeak: routeDraftPeakTarget,
                            routeDraftColour: routeDraftColour,
                            routeDraftMarkers: routeDraftMarkers,
                            routeDraftCommittedPoints:
                                routeDraftCommittedPoints,
                            isSavingRoute: isSavingRoute,
                            routeNameController: _routeNameController,
                            routeNameFocusNode: _routeNameFocusNode,
                            onNameChanged: notifier.setRouteDraftName,
                            onModeSelected: notifier.setRouteDraftMode,
                            onOutAndBack: notifier.applyRouteDraftOutAndBack,
                            onCloseLoop: notifier.applyRouteDraftCloseLoop,
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
    required this.routeDraftElevationSummary,
    required this.routeDraftElevationLoading,
    required this.routeDraftElevationError,
  });

  final RouteDraftStage routeDraftStage;
  final double routeDraftDistanceMeters;
  final String? routeDraftError;
  final RouteElevationSummary? routeDraftElevationSummary;
  final bool routeDraftElevationLoading;
  final String? routeDraftElevationError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceText = formatDistance(
      routeDraftDistanceMeters,
      decimalPlaces: 1,
    );
    final elevationSummary = routeDraftElevationSummary;

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
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                distanceText,
                key: const Key('route-distance-text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (routeDraftElevationLoading)
                Text(
                  'Sampling elevation...',
                  key: const Key('route-elevation-loading-text'),
                  style: theme.textTheme.bodySmall,
                )
              else if (routeDraftElevationError != null)
                Text(
                  routeDraftElevationError!,
                  key: const Key('route-elevation-error-text'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (elevationSummary != null) ...[
                _ElevationMetric(
                  icon: Icons.arrow_upward,
                  label: 'Ascent',
                  value: elevationSummary.ascent.round(),
                  valueKey: const Key('route-ascent-text'),
                ),
                _ElevationMetric(
                  icon: Icons.arrow_downward,
                  label: 'Descent',
                  value: elevationSummary.descent.round(),
                  valueKey: const Key('route-descent-text'),
                ),
              ],
            ],
          )
        else
          Text(
            'Tap a point to start routing',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _ElevationMetric extends StatelessWidget {
  const _ElevationMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final IconData icon;
  final String label;
  final int value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(width: 4),
        Text(
          '${formatElevationMetres(value)} m',
          key: valueKey,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
    required this.routeDraftStage,
    required this.routeDraftPeak,
    required this.routeDraftColour,
    required this.routeDraftMarkers,
    required this.routeDraftCommittedPoints,
    required this.isSavingRoute,
    required this.routeNameController,
    required this.routeNameFocusNode,
    required this.onNameChanged,
    required this.onModeSelected,
    required this.onOutAndBack,
    required this.onCloseLoop,
  });

  final String routeDraftName;
  final String? routeDraftNameError;
  final RouteMode routeDraftMode;
  final RouteDraftStage routeDraftStage;
  final Peak? routeDraftPeak;
  final int routeDraftColour;
  final List<LatLng> routeDraftMarkers;
  final List<LatLng> routeDraftCommittedPoints;
  final bool isSavingRoute;
  final TextEditingController routeNameController;
  final FocusNode routeNameFocusNode;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<RouteMode> onModeSelected;
  final VoidCallback onOutAndBack;
  final VoidCallback onCloseLoop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPeakTarget = routeDraftPeak != null;
    final routeModeSelectedColor = Colors.green;
    final routeModeActiveColor = Colors.purple;
    final isRouting = routeDraftStage == RouteDraftStage.routingSegment;
    final isClosedLoop =
        routeDraftCommittedPoints.length >= 2 &&
        routeDraftCommittedPoints.first == routeDraftCommittedPoints.last;
    final routeToPeakAvailable =
        hasPeakTarget && routeDraftMarkers.isNotEmpty && !isClosedLoop;

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
                key: const Key('route-mode-route-to-peak'),
                label: 'Route to Peak',
                visualState: _routeModeVisualState(
                  mode: RouteMode.routeToPeak,
                  selectedMode: routeDraftMode,
                  stage: routeDraftStage,
                  hasPeakTarget: routeToPeakAvailable,
                ),
                activeColor: routeModeActiveColor,
                selectedColor: routeModeSelectedColor,
                onPressed: routeDraftPeak == null ||
                        routeDraftMarkers.isEmpty ||
                        isClosedLoop ||
                        isRouting
                    ? null
                    : () => onModeSelected(RouteMode.routeToPeak),
              ),
              const SizedBox(width: 8),
              _RouteModeButton(
                key: const Key('route-mode-snap-to-trail'),
                label: 'Snap to Trail',
                visualState: _routeModeVisualState(
                  mode: RouteMode.snapToTrail,
                  selectedMode: routeDraftMode,
                  stage: routeDraftStage,
                  hasPeakTarget: hasPeakTarget,
                ),
                activeColor: routeModeActiveColor,
                selectedColor: routeModeSelectedColor,
                onPressed: isRouting
                    ? null
                    : () => onModeSelected(RouteMode.snapToTrail),
              ),
              const SizedBox(width: 8),
              _RouteModeButton(
                key: const Key('route-mode-straight-line'),
                label: 'Straight Line',
                visualState: _routeModeVisualState(
                  mode: RouteMode.straightLine,
                  selectedMode: routeDraftMode,
                  stage: routeDraftStage,
                  hasPeakTarget: hasPeakTarget,
                ),
                activeColor: routeModeActiveColor,
                selectedColor: routeModeSelectedColor,
                onPressed: isRouting
                    ? null
                    : () => onModeSelected(RouteMode.straightLine),
              ),
              const SizedBox(width: 8),
              _RouteActionButton(
                buttonKey: const Key('route-mode-out-and-back'),
                label: 'Out and Back',
                icon: Icons.sync_alt,
                enabled:
                    routeDraftCommittedPoints.length >= 2 &&
                    routeDraftCommittedPoints.first !=
                        routeDraftCommittedPoints.last &&
                    !isSavingRoute &&
                    routeDraftStage != RouteDraftStage.routingSegment &&
                    routeDraftStage != RouteDraftStage.segmentFailure,
                onPressed: onOutAndBack,
              ),
              const SizedBox(width: 8),
              _RouteActionButton(
                buttonKey: const Key('route-mode-close-loop'),
                label: 'Close Loop',
                icon: Icons.refresh,
                enabled:
                    routeDraftCommittedPoints.length >= 2 &&
                    !isClosedLoop &&
                    !isSavingRoute &&
                    routeDraftStage != RouteDraftStage.routingSegment &&
                    routeDraftStage != RouteDraftStage.segmentFailure,
                onPressed: onCloseLoop,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 244,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
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
    required this.visualState,
    required this.activeColor,
    required this.selectedColor,
    required this.onPressed,
  });

  final String label;
  final _RouteModeVisualState visualState;
  final Color activeColor;
  final Color selectedColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: switch (visualState) {
          _RouteModeVisualState.selected => selectedColor,
          _RouteModeVisualState.active => activeColor,
          _RouteModeVisualState.inactive => theme.colorScheme.surfaceContainer,
        },
        foregroundColor: visualState != _RouteModeVisualState.inactive
            ? Colors.white
            : theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _RouteActionButton extends StatelessWidget {
  const _RouteActionButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: Tooltip(
        message: label,
        child: FloatingActionButton.small(
          key: buttonKey,
          heroTag: label,
          shape: const CircleBorder(),
          backgroundColor: enabled
              ? Colors.purple
              : theme.colorScheme.surfaceContainer,
          foregroundColor: enabled ? Colors.white : theme.colorScheme.onSurface,
          onPressed: enabled ? onPressed : null,
          child: ExcludeSemantics(child: Icon(icon, size: 18)),
        ),
      ),
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
