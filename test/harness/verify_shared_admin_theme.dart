// Isolated native smoke check; never starts production services or opens a Store.
// flutter run -d macos -t test/harness/verify_shared_admin_theme.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:peak_bagger/models/route.dart' as model;
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_controls.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final key = GlobalKey<_SmokeState>();
  runApp(_Smoke(key: key));
  await _settle();
  String? originalFrame;
  Future<ProcessResult> windowScript(
    String script,
  ) => Process.run('/usr/bin/osascript', [
    '-e',
    'tell application "System Events" to tell (first application process whose unix id is $pid)\n$script\nend tell',
  ]);
  Future<void> restoreWindow() async {
    final frame = originalFrame
        ?.split(',')
        .map((value) => int.parse(value.trim()))
        .toList();
    if (frame != null && frame.length == 4) {
      await windowScript(
        'set position of window 1 to {${frame[0]}, ${frame[1]}}\nset size of window 1 to {${frame[2]}, ${frame[3]}}',
      );
    }
  }

  try {
    // Resize only this fixture process's window, then restore its frame on exit.
    // This needs macOS Accessibility access for osascript, not production data.
    final original = await windowScript(
      'get {position of window 1, size of window 1}',
    );
    _check(
      original.exitCode == 0,
      'Cannot inspect smoke window: ${original.stderr}',
    );
    originalFrame = original.stdout.toString().trim();
    final resize = await windowScript(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1050}',
    );
    _check(
      resize.exitCode == 0,
      'Cannot resize smoke window: ${resize.stderr}',
    );
    await _settle();
    final edit = _element('objectbox-admin-route-edit').widget as IconButton;
    edit.onPressed!();
    await _settle();
    final controller =
        (_element('objectbox-admin-route-name').widget as TextFormField)
            .controller!;
    controller.text = 'Unsaved native draft';
    const config = ThemeConfig(
      seedColor: Colors.teal,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .5,
    );
    for (final size in [
      const Size(1280, 960),
      const Size(1600, 1000),
      const Size(1280, 960),
    ]) {
      for (final theme in [
        MyTheme.light,
        MyTheme.dark,
        MyTheme.lightWith(config),
        MyTheme.darkWith(config),
      ]) {
        for (final scale in [1.0, 2.0]) {
          key.currentState!.configure(size, scale, theme);
          await _settle();
          final scene =
              _element('smoke-content').findRenderObject()! as RenderBox;
          _check(
            scene.size == size,
            'Native content was constrained below $size: ${scene.size}',
          );
          _check(
            controller.text == 'Unsaved native draft',
            'Draft changed during theme/resize',
          );
          for (final name in [
            'objectbox-admin-route-name',
            'objectbox-admin-route-save',
            'objectbox-admin-entity-dropdown',
          ]) {
            final box = _element(name).findRenderObject()! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            final bounds = scene.localToGlobal(Offset.zero) & scene.size;
            _check(
              bounds.contains(rect.topLeft) &&
                  bounds.contains(rect.bottomRight - const Offset(.1, .1)),
              '$name outside content: $rect',
            );
          }
          _check(errors.isEmpty, '${errors.length} framework errors');
          stdout.writeln(
            'PASS native Admin ${size.width}x${size.height}, scale=$scale, ${theme.brightness.name}, seed=${theme.seedColor.toARGB32()}',
          );
        }
      }
    }
    runApp(const SizedBox.shrink());
    await _settle();
    stdout.writeln(
      'PASS shared Admin native smoke (24 configurations; no writes)',
    );
    await restoreWindow();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    await restoreWindow();
    exit(1);
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 400));

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Element _element(String key) {
  Element? match;
  void visit(Element element) {
    if (element.widget.key == ValueKey(key)) match = element;
    element.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return match ?? (throw StateError('Missing $key'));
}

class _Smoke extends StatefulWidget {
  const _Smoke({super.key});
  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  Size size = const Size(1280, 960);
  double scale = 1;
  ThemeData theme = MyTheme.light;
  final search = TextEditingController();
  final header = ScrollController();
  final rowScroll = ScrollController();
  final vertical = ScrollController();
  final route = model.Route(
    id: 1,
    name: 'Native fixture',
    desc: 'Editable description',
  );

  void configure(Size nextSize, double nextScale, ThemeData nextTheme) =>
      setState(() {
        size = nextSize;
        scale = nextScale;
        theme = nextTheme;
      });

  @override
  void dispose() {
    search.dispose();
    header.dispose();
    rowScroll.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: const Key('smoke-content'),
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ObjectBoxAdminControls(
                    state: const ObjectBoxAdminState(
                      entities: [_entity],
                      selectedEntity: _entity,
                      mode: ObjectBoxAdminViewMode.data,
                      searchQuery: '',
                      sortAscending: true,
                      isLoading: false,
                      rows: [_row],
                      visibleRowCount: 1,
                    ),
                    searchController: search,
                    onEntityChanged: (_) {},
                    onModeChanged: (_) {},
                    onSearchChanged: (_) {},
                    onSearchSubmitted: () {},
                    onAddPeakPressed: () {},
                    onAddContactPressed: () {},
                    onSortPressed: () {},
                    onExportPressed: null,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: ObjectBoxAdminDataGrid(
                            entity: _entity,
                            rows: const [_row],
                            sortAscending: true,
                            selectedRow: _row,
                            headerHorizontalController: header,
                            rowHorizontalControllerFor: (_) => rowScroll,
                            verticalController: vertical,
                            canLoadMore: false,
                            onSortPressed: () {},
                            onRowTap: (_) {},
                            onDeletePressed: (_) {},
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 320,
                          child: ObjectBoxAdminDetailsPane(
                            row: _row,
                            entity: _entity,
                            peakList: null,
                            route: route,
                            naturalFeature: null,
                            isCreatingPeak: false,
                            isNaturalFeatureMutationLocked: false,
                            onClose: () {},
                            createOsmId: 0,
                            onViewPeakOnMap: (_) {},
                            onViewNaturalFeatureOnMap: (_) {},
                            onViewGpxTrackOnMap: null,
                            onViewRouteOnMap: null,
                            onPeakSubmit: (_) async => null,
                            onPeakListSubmit: (_) async => null,
                            onRouteSubmit: (_) async => null,
                            onNaturalFeatureSubmit: (_) async => null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

const _entity = ObjectBoxAdminEntityDescriptor(
  name: 'Route',
  displayName: 'Route',
  primaryKeyField: 'id',
  primaryNameField: 'name',
  fields: [
    ObjectBoxAdminFieldDescriptor(
      name: 'id',
      typeLabel: 'int',
      nullable: false,
      isPrimaryKey: true,
      isPrimaryName: false,
    ),
    ObjectBoxAdminFieldDescriptor(
      name: 'name',
      typeLabel: 'String',
      nullable: false,
      isPrimaryKey: false,
      isPrimaryName: true,
    ),
    ObjectBoxAdminFieldDescriptor(
      name: 'desc',
      typeLabel: 'String',
      nullable: false,
      isPrimaryKey: false,
      isPrimaryName: false,
    ),
  ],
);
const _row = ObjectBoxAdminRow(
  primaryKeyValue: 1,
  values: {'id': 1, 'name': 'Native fixture', 'desc': 'Editable description'},
);
