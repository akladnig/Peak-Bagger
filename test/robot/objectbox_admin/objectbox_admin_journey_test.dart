import 'package:flutter_test/flutter_test.dart';

import 'objectbox_admin_robot.dart';

void main() {
  testWidgets('admin shell opens from menu', (tester) async {
    final robot = ObjectBoxAdminRobot(tester);

    await robot.pumpApp();
    await robot.openAdminFromMenu();
    robot.expectAdminShellVisible();

    await tester.tap(robot.homeAction);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: robot.appBarTitle, matching: find.text('Dashboard')),
      findsOneWidget,
    );
  });
}
