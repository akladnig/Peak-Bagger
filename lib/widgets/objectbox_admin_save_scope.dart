import 'package:flutter/widgets.dart';

/// Shares the screen-owned Save gate with replacement panes, including a newly
/// created record shown while its success feedback is still pending.
class ObjectBoxAdminSaveScope extends InheritedWidget {
  const ObjectBoxAdminSaveScope({
    required this.pending,
    required this.isPending,
    required super.child,
    super.key,
  });

  final bool pending;
  final bool Function() isPending;

  static bool read(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<ObjectBoxAdminSaveScope>()
          ?.isPending() ??
      false;

  @override
  bool updateShouldNotify(ObjectBoxAdminSaveScope oldWidget) =>
      pending != oldWidget.pending;
}
