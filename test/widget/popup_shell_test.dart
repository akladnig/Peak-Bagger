import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/widgets/popup_shell.dart';

void main() {
  group('PopupShell', () {
    testWidgets('renders shared header and body padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupShell(
              title: const Text('Popup Title'),
              body: const Text('Popup Body'),
              onClose: () {},
            ),
          ),
        ),
      );

      final headerPadding = tester.widget<Padding>(
        find.byKey(const Key('popup-shell-header-padding')),
      );
      expect(
        headerPadding.padding,
        EdgeInsets.all(PopupUIConstants.surfacePadding),
      );

      final bodyPadding = tester.widget<Padding>(
        find.byKey(const Key('popup-shell-body-padding')),
      );
      expect(
        bodyPadding.padding,
        const EdgeInsets.fromLTRB(
          PopupUIConstants.surfacePadding,
          0,
          PopupUIConstants.surfacePadding,
          PopupUIConstants.surfacePadding,
        ),
      );

      final closeButton = tester.widget<IconButton>(
        find.byKey(const Key('popup-shell-close')),
      );
      expect(closeButton.tooltip, 'Close');
    });

    testWidgets('dismisses on escape and ctrl+c', (tester) async {
      final open = ValueNotifier(true);
      addTearDown(open.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (context, isOpen, child) {
                if (!isOpen) {
                  return const SizedBox.shrink();
                }
                return PopupShell(
                  title: const Text('Popup Title'),
                  body: const Text('Popup Body'),
                  onClose: () {
                    open.value = false;
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Popup Title'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Popup Title'), findsNothing);

      open.value = true;
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(find.text('Popup Title'), findsNothing);
    });

    testWidgets('header action icons stay grouped on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PopupShell(
                  title: const Text('Popup Title'),
                  body: const Text('Popup Body'),
                  headerActions: [
                    IconButton(
                      key: const Key('popup-shell-extra-action'),
                      onPressed: () {},
                      icon: const Icon(Icons.edit),
                    ),
                  ],
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final titleRight = tester.getTopRight(find.text('Popup Title')).dx;
      final extraActionLeft = tester
          .getTopLeft(find.byKey(const Key('popup-shell-extra-action')))
          .dx;
      final closeLeft = tester
          .getTopLeft(find.byKey(const Key('popup-shell-close')))
          .dx;

      expect(extraActionLeft, greaterThan(titleRight));
      expect(closeLeft, greaterThan(extraActionLeft));
    });
  });
}
