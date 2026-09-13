import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/local_topo_overlay_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';

import '../core/constants.dart';
import 'drawer_outline_button.dart';

class MapBasemapsDrawer extends ConsumerWidget {
  const MapBasemapsDrawer({
    super.key,
    required this.basemapKeys,
    required this.showOverlays,
  });

  final List<String> basemapKeys;
  final bool showOverlays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basemap = ref.watch(mapProvider.select((state) => state.basemap));
    final overlaySettings = ref.watch(localTopoOverlaySettingsProvider);
    final snapshot = localTopoRuntime.capabilitySnapshot;
    final regionBasemaps = basemapKeys
        .map(regionManifestCatalog.basemapByKey)
        .whereType<RegionManifestBasemapData>()
        .toList(growable: false);

    return Drawer(
      key: const Key('basemaps-drawer'),
      width: drawerWidthForLabels(context, [
        if (regionBasemaps.isEmpty) 'Basemaps',
        ...regionBasemaps.map((basemapData) => basemapData.name),
        if (showOverlays) 'Terrain relief shading',
      ]),
      child: ListView(
        padding: const EdgeInsets.all(UiConstants.drawerHorizontalPadding),
        children: [
          const Text(
            'Basemaps',
            style: TextStyle(
              fontSize: UiConstants.drawerTitleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (regionBasemaps.isEmpty)
            const Text(
              'Basemaps unavailable for this region.',
              key: Key('basemaps-drawer-empty-state'),
              style: TextStyle(fontSize: UiConstants.drawerSupportingFontSize),
            )
          else
            for (final basemapData in regionBasemaps) ...[
              DrawerOutlineButton(
                buttonKey: Key('basemap-option-${basemapData.key}'),
                icon: Icons.map_outlined,
                label: basemapData.name,
                isSelected:
                    basemap ==
                    regionManifestCatalog.basemapEnumByKey(basemapData.key),
                onPressed: () {
                  final selected = regionManifestCatalog.basemapEnumByKey(
                    basemapData.key,
                  );
                  if (selected != null) {
                    ref.read(mapProvider.notifier).setBasemap(selected);
                  }
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          if (showOverlays) ...[
            const SizedBox(height: 16),
            const Text(
              'Overlays',
              key: Key('overlays-section'),
              style: TextStyle(
                fontSize: UiConstants.drawerTitleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _OverlayControl(
              overlayKey: terrainReliefShadingOverlayKey,
              label: 'Terrain relief shading',
              enabled: overlaySettings.terrainReliefShadingEnabled,
              opacity: overlaySettings.terrainReliefShadingOpacity,
              availability: _overlayAvailability(
                snapshot,
                terrainReliefShadingOverlayKey,
                basemap,
              ),
            ),
            const SizedBox(height: 8),
            _OverlayControl(
              overlayKey: contourLinesOverlayKey,
              label: 'Contour lines',
              enabled: overlaySettings.contourLinesEnabled,
              opacity: overlaySettings.contourLinesOpacity,
              availability: _overlayAvailability(
                snapshot,
                contourLinesOverlayKey,
                basemap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _OverlayAvailability { available, unavailable, includedInLocalTopo }

_OverlayAvailability _overlayAvailability(
  LocalTopoCapabilitySnapshot? snapshot,
  String overlayKey,
  Basemap basemap,
) {
  if (basemap == Basemap.localTopo) {
    return _OverlayAvailability.includedInLocalTopo;
  }
  return snapshot?.resolvedOverlayTileUrlTemplate(
            key: overlayKey,
            regionKey: 'tasmania',
          ) !=
          null
      ? _OverlayAvailability.available
      : _OverlayAvailability.unavailable;
}

class _OverlayControl extends ConsumerStatefulWidget {
  const _OverlayControl({
    required this.overlayKey,
    required this.label,
    required this.enabled,
    required this.opacity,
    required this.availability,
  });

  final String overlayKey;
  final String label;
  final bool enabled;
  final int opacity;
  final _OverlayAvailability availability;

  @override
  ConsumerState<_OverlayControl> createState() => _OverlayControlState();
}

class _OverlayControlState extends ConsumerState<_OverlayControl> {
  late final TextEditingController _opacityController;
  late final FocusNode _opacityFocusNode;

  @override
  void initState() {
    super.initState();
    _opacityController = TextEditingController(text: '${widget.opacity}');
    _opacityFocusNode = FocusNode()..addListener(_commitOpacityOnFocusLoss);
  }

  @override
  void didUpdateWidget(covariant _OverlayControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_opacityFocusNode.hasFocus && oldWidget.opacity != widget.opacity) {
      _opacityController.text = '${widget.opacity}';
    }
  }

  @override
  void dispose() {
    _opacityFocusNode
      ..removeListener(_commitOpacityOnFocusLoss)
      ..dispose();
    _opacityController.dispose();
    super.dispose();
  }

  void _commitOpacityOnFocusLoss() {
    if (!_opacityFocusNode.hasFocus) {
      _commitOpacity();
    }
  }

  void _commitOpacity() {
    final opacity = int.tryParse(_opacityController.text);
    if (opacity == null || opacity < 0 || opacity > 100) {
      _opacityController.text = '${widget.opacity}';
      return;
    }
    ref
        .read(localTopoOverlaySettingsProvider.notifier)
        .setOpacity(widget.overlayKey, opacity);
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.availability == _OverlayAvailability.available;
    final included =
        widget.availability == _OverlayAvailability.includedInLocalTopo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: Key('overlay-switch-${widget.overlayKey}'),
          contentPadding: EdgeInsets.zero,
          title: Text(widget.label),
          subtitle: available
              ? null
              : Text(
                  included
                      ? 'Included in Local Topo'
                      : 'Unavailable from the local tile server',
                ),
          value: widget.enabled,
          onChanged: available
              ? (value) => ref
                    .read(localTopoOverlaySettingsProvider.notifier)
                    .setEnabled(widget.overlayKey, value)
              : null,
        ),
        if (available && widget.enabled)
          Row(
            key: Key('overlay-opacity-${widget.overlayKey}'),
            children: [
              const Text('Opacity'),
              Expanded(
                child: Slider(
                  value: widget.opacity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${widget.opacity}%',
                  onChanged: (value) => ref
                      .read(localTopoOverlaySettingsProvider.notifier)
                      .setOpacity(widget.overlayKey, value.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  key: Key('overlay-opacity-input-${widget.overlayKey}'),
                  controller: _opacityController,
                  focusNode: _opacityFocusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _commitOpacity(),
                  decoration: const InputDecoration(suffixText: '%'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
