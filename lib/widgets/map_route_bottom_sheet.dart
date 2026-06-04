import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

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

class RouteDraftGraphOverlay extends ConsumerWidget {
  const RouteDraftGraphOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      :routeDraftStage,
      :routeDraftDistanceMeters,
      :routeDraftError,
      :routeDraftFailureKind,
      :routeDraftElevationSummary,
      :routeDraftElevationLoading,
      :routeDraftElevationError,
      :routeDraftCommittedPoints,
      :routeDraftPointElevations,
    ) = ref.watch(
      mapProvider.select(
        (state) => (
          routeDraftStage: state.routeDraftStage,
          routeDraftDistanceMeters: state.routeDraftDistanceMeters,
          routeDraftError: state.routeDraftError,
          routeDraftFailureKind: state.routeDraftFailureKind,
          routeDraftElevationSummary: state.routeDraftElevationSummary,
          routeDraftElevationLoading: state.routeDraftElevationLoading,
          routeDraftElevationError: state.routeDraftElevationError,
          routeDraftCommittedPoints: state.routeDraftCommittedPoints,
          routeDraftPointElevations: state.routeDraftPointElevations,
        ),
      ),
    );

    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          320.0,
          math.min(420.0, constraints.maxWidth * 0.35),
        ).toDouble();

        return Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: width,
            height: RouteConstants.sheetHeight,
            child: Material(
              elevation: 10,
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _DistanceElevationGroup(
                    routeDraftStage: routeDraftStage,
                    routeDraftDistanceMeters: routeDraftDistanceMeters,
                    routeDraftError: routeDraftError,
                    routeDraftFailureKind: routeDraftFailureKind,
                    routeDraftElevationSummary: routeDraftElevationSummary,
                    routeDraftElevationLoading: routeDraftElevationLoading,
                    routeDraftElevationError: routeDraftElevationError,
                    routeDraftCommittedPoints: routeDraftCommittedPoints,
                    routeDraftPointElevations: routeDraftPointElevations,
                    onRetry:
                        ref.read(mapProvider.notifier).retryRouteDraftSegment,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RouteDraftControlsOverlay extends ConsumerStatefulWidget {
  const RouteDraftControlsOverlay({super.key});

  @override
  ConsumerState<RouteDraftControlsOverlay> createState() =>
      _RouteDraftControlsOverlayState();
}

class _RouteDraftControlsOverlayState
    extends ConsumerState<RouteDraftControlsOverlay> {
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
      :routeDraftColour,
      :isSavingRoute,
      :routeDraftCanUndo,
      :routeDraftCanRedo,
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
          routeDraftColour: state.routeDraftColour,
          isSavingRoute: state.isSavingRoute,
          routeDraftCanUndo: state.routeDraftCanUndo,
          routeDraftCanRedo: state.routeDraftCanRedo,
        ),
      ),
    );

    final notifier = ref.read(mapProvider.notifier);
    final theme = Theme.of(context);
    final routeMode = routeDraftMode;

    return Material(
      elevation: 10,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteEditingGroup(
                  routeDraftName: routeDraftName,
                  routeDraftNameError: routeDraftNameError,
                  routeDraftMode: routeMode,
                  routeDraftStage: routeDraftStage,
                  routeDraftPeak: routeDraftPeakTarget,
                  routeDraftColour: routeDraftColour,
                  routeDraftMarkers: routeDraftMarkers,
                  routeDraftCommittedPoints: routeDraftCommittedPoints,
                  isSavingRoute: isSavingRoute,
                  routeNameController: _routeNameController,
                  routeNameFocusNode: _routeNameFocusNode,
                  onNameChanged: notifier.setRouteDraftName,
                  onModeSelected: notifier.setRouteDraftMode,
                  onOutAndBack: notifier.applyRouteDraftOutAndBack,
                  onCloseLoop: notifier.applyRouteDraftCloseLoop,
                  onUndo: notifier.undoRouteDraftEdit,
                  onRedo: notifier.redoRouteDraftEdit,
                  canUndo: routeDraftCanUndo,
                  canRedo: routeDraftCanRedo,
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
    required this.routeDraftFailureKind,
    required this.routeDraftElevationSummary,
    required this.routeDraftElevationLoading,
    required this.routeDraftElevationError,
    required this.routeDraftCommittedPoints,
    required this.routeDraftPointElevations,
    required this.onRetry,
  });

  final RouteDraftStage routeDraftStage;
  final double routeDraftDistanceMeters;
  final String? routeDraftError;
  final RoutePlanningFailureKind routeDraftFailureKind;
  final RouteElevationSummary? routeDraftElevationSummary;
  final bool routeDraftElevationLoading;
  final String? routeDraftElevationError;
  final List<LatLng> routeDraftCommittedPoints;
  final List<double?> routeDraftPointElevations;
  final VoidCallback onRetry;

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routeDraftError!,
                key: const Key('route-error-text'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              if (routeDraftStage == RouteDraftStage.segmentFailure &&
                  routeDraftFailureKind ==
                      RoutePlanningFailureKind.routeGraphLoad) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: const Key('route-retry-button'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
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
          ),
        if (routeDraftDistanceMeters > 0) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevationProfileChart(
              series: ElevationProfileSeriesBuilder.fromRoutePoints(
                points: routeDraftCommittedPoints,
                elevations: routeDraftPointElevations,
              ),
              isLoading:
                  routeDraftElevationLoading && routeDraftPointElevations.isEmpty,
              errorText: routeDraftElevationError,
            ),
          ),
        ]
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
          formatElevation(value),
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
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
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
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;

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

    return Row(
      key: const Key('route-editing-group'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
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
            _RouteActionButton(
              buttonKey: const Key('route-undo-button'),
              label: 'Undo (⌘ Z)',
              icon: Icons.undo,
              enabled: canUndo && !isRouting && !isSavingRoute,
              onPressed: onUndo,
            ),
            _RouteActionButton(
              buttonKey: const Key('route-redo-button'),
              label: 'Redo (⌘ ⇧ Z)',
              icon: Icons.redo,
              enabled: canRedo && !isRouting && !isSavingRoute,
              onPressed: onRedo,
            ),
          ],
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
        child: FilledButton(
          key: buttonKey,
          style: FilledButton.styleFrom(
            minimumSize: const Size.square(40),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: enabled
                ? Colors.purple
                : theme.colorScheme.surfaceContainer,
            foregroundColor: enabled
                ? Colors.white
                : theme.colorScheme.onSurface,
          ),
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
