// Native, isolated model-backed Schema smoke; no Store or production startup.
// flutter run -d macos -t test/harness/verify_admin_schema.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_controls.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_states.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final key = GlobalKey<_SchemaSmokeState>();
  runApp(_SchemaSmoke(key: key));
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
    await _settle();
    final original = await windowScript(
      'set frontmost to true\n'
      'repeat 40 times\n'
      'if exists window 1 then exit repeat\n'
      'delay 0.1\n'
      'end repeat\n'
      'get {position of window 1, size of window 1}',
    );
    _check(
      original.exitCode == 0,
      'Cannot inspect native fixture window: ${original.stderr}',
    );
    originalFrame = original.stdout.toString().trim();
    final resize = await windowScript(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1050}',
    );
    _check(
      resize.exitCode == 0,
      'Cannot resize native fixture window: ${resize.stderr}',
    );
    await _settle();
    const custom = ThemeConfig(
      seedColor: Colors.teal,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .5,
    );
    var configurations = 0;
    for (final size in [
      const Size(1280, 960),
      const Size(1600, 1000),
      const Size(1600, 960),
      const Size(1280, 960),
    ]) {
      for (final theme in [
        MyTheme.light,
        MyTheme.dark,
        MyTheme.lightWith(custom),
        MyTheme.darkWith(custom),
      ]) {
        for (final scale in [1.0, 2.0]) {
          final state = key.currentState!;
          state.configure(size, theme, scale);
          await _settle();
          final scene =
              _element('schema-smoke-content').findRenderObject()! as RenderBox;
          _check(
            scene.size == size,
            'Native viewport constrained: ${scene.size}, wanted $size',
          );
          for (final name in [
            'objectbox-admin-entity-dropdown',
            'objectbox-admin-schema-data-toggle',
            'objectbox-admin-schema-table',
          ]) {
            final box = _element(name).findRenderObject()! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            final bounds = scene.localToGlobal(Offset.zero) & scene.size;
            _check(
              bounds.contains(rect.topLeft) &&
                  bounds.contains(rect.bottomRight - const Offset(.1, .1)),
              '$name outside supported content: $rect',
            );
          }
          _check(errors.isEmpty, '${errors.length} framework errors');
          configurations++;
          stdout.writeln(
            'PASS native Schema $size ${theme.brightness.name} scale=$scale',
          );
        }
      }
    }
    // Exercise every actual discovered entity, including empty maintenance types,
    // and scroll long schemas to their final persisted member at enlarged scale.
    for (final entity in key.currentState!.entities) {
      key.currentState!.select(entity);
      await _settle();
      final list = _element('objectbox-admin-schema-table');
      ScrollableState? scroll;
      void visit(Element element) {
        if (element is StatefulElement && element.state is ScrollableState) {
          scroll ??= element.state as ScrollableState;
        }
        element.visitChildren(visit);
      }

      visit(list);
      scroll!.position.jumpTo(scroll!.position.maxScrollExtent);
      await _settle();
      final last = _element(
        'objectbox-admin-schema-${entity.name}-${entity.fields.last.name}',
      );
      _check(
        last.mounted,
        'Last persisted field inaccessible for ${entity.name}',
      );
      _check(errors.isEmpty, 'Schema errors for ${entity.name}');
    }
    // Use Flutter's real native focus traversal, without intercepting copy/edit keys.
    final table = _element('objectbox-admin-schema-table');
    FocusScope.of(table).nextFocus();
    await _settle();
    _check(
      FocusManager.instance.primaryFocus?.context != null,
      'Keyboard focus unavailable',
    );
    stdout.writeln(
      'PASS native Schema: $configurations supported size/theme/scale configurations; 18 model-backed entities; scrolling/focus; no writes',
    );
    runApp(const SizedBox.shrink());
    await _settle();
    await restoreWindow();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    await restoreWindow();
    exit(1);
  }
}

Future<void> _settle() async {
  // A fixture may be occluded by the terminal; force its scheduled layout rather
  // than waiting forever for a throttled native vsync/frame notification.
  WidgetsBinding.instance.scheduleWarmUpFrame();
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 5));
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

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

class _SchemaSmoke extends StatefulWidget {
  const _SchemaSmoke({super.key});
  @override
  State<_SchemaSmoke> createState() => _SchemaSmokeState();
}

class _SchemaSmokeState extends State<_SchemaSmoke> {
  final entities = ObjectBoxAdminRepositoryImpl().getEntities();
  final search = TextEditingController();
  late ObjectBoxAdminEntityDescriptor entity = entities.singleWhere(
    (e) => e.name == 'PeakListItemEntity',
  );
  Size size = const Size(1280, 960);
  ThemeData theme = MyTheme.light;
  double scale = 1;

  void configure(Size nextSize, ThemeData nextTheme, double nextScale) =>
      setState(() {
        size = nextSize;
        theme = nextTheme;
        scale = nextScale;
      });

  void select(ObjectBoxAdminEntityDescriptor next) =>
      setState(() => entity = next);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    themeAnimationDuration: Duration.zero,
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: const Key('schema-smoke-content'),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ObjectBoxAdminControls(
                    state: ObjectBoxAdminState(
                      entities: entities,
                      selectedEntity: entity,
                      mode: ObjectBoxAdminViewMode.schema,
                      searchQuery: '',
                      sortAscending: true,
                      isLoading: false,
                      rows: const [],
                      visibleRowCount: 0,
                    ),
                    searchController: search,
                    onEntityChanged: (next) {
                      if (next != null) select(next);
                    },
                    onModeChanged: (_) {},
                    onSearchChanged: (_) {},
                    onSearchSubmitted: () {},
                    onSearchPressed: () {},
                    onAddPeakPressed: () {},
                    onAddContactPressed: () {},
                    onSortPressed: () {},
                    onExportPressed: null,
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: ObjectBoxAdminSchemaView(entity: entity)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
