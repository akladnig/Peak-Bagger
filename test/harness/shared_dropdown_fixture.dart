import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';

const dropdownChoices = [
  SharedDropdownChoice<String?>(
    value: null,
    label: 'Any',
    key: Key('choice-any'),
    icon: Icons.all_inclusive,
  ),
  SharedDropdownChoice<String?>(
    value: 'a',
    label: 'Alpha',
    key: Key('choice-a'),
    icon: Icons.show_chart,
  ),
  SharedDropdownChoice<String?>(
    value: 'b',
    label: 'Beta unavailable',
    enabled: false,
    key: Key('choice-b'),
    icon: Icons.block,
  ),
  SharedDropdownChoice<String?>(
    value: 'c',
    label: 'Complete longer choice',
    key: Key('choice-c'),
    icon: Icons.bar_chart,
  ),
];

/// Isolated widget/native fixture: no production startup, data or services.
class SharedDropdownFixture extends StatefulWidget {
  const SharedDropdownFixture({super.key});
  @override
  State<SharedDropdownFixture> createState() => SharedDropdownFixtureState();
}

class SharedDropdownFixtureState extends State<SharedDropdownFixture> {
  ThemeData theme = MyTheme.dark;
  double scale = 1;
  Size size = const Size(1280, 960);
  double fieldWidth = 600;
  Alignment alignment = Alignment.topLeft;
  SharedDropdownTrigger trigger = SharedDropdownTrigger.labelledField;
  SharedDropdownRows rows = SharedDropdownRows.labelOnly;
  List<SharedDropdownChoice<String?>> choices = dropdownChoices;
  String? selected = 'a';
  String label = 'Selection';
  String? hint;
  String? error;
  bool enabled = true;
  bool allowed = true;
  bool show = true;
  int selections = 0;
  int outsideActions = 0;
  int backgroundKeys = 0;
  final closeReasons = <SharedDropdownCloseReason>[];
  final menu = MenuController();
  final focus = FocusNode();
  final draft = TextEditingController(text: 'Unsaved draft');

  void update(VoidCallback change) => setState(change);

  @override
  void dispose() {
    focus.dispose();
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent) backgroundKeys++;
            return KeyEventResult.ignored;
          },
          child: SizedBox(
            key: const Key('dropdown-fixture-content'),
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                Align(
                  alignment: alignment,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: fieldWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (show)
                            SharedDropdown<String?>(
                              key: const Key('fixture-dropdown'),
                              controller: menu,
                              focusNode: focus,
                              label: label,
                              hint: hint,
                              value: selected,
                              choices: choices,
                              enabled: enabled,
                              isInteractionAllowed: () => allowed,
                              errorText: error,
                              trigger: trigger,
                              rows: rows,
                              icon: Icons.show_chart,
                              onClosed: closeReasons.add,
                              onSelected: (value) => setState(() {
                                selected = value;
                                selections++;
                              }),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: draft,
                            decoration: const InputDecoration(
                              labelText: 'Retained draft',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: FilledButton(
                    key: const Key('outside-action'),
                    onPressed: () => outsideActions++,
                    child: const Text('Outside action'),
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
