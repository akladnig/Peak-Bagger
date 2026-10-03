import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/widgets/mapping_store_failure_dialog.dart';

void main() {
  testWidgets('shows the active Mapping failure with stable controls', (
    tester,
  ) async {
    final coordinator = MappingStoreOperationCoordinator();
    final failure = MappingStoreOperationFailure(
      key: MappingStoreOperationKey.polygonDisplay('Polygons/tasmania.poly'),
      paths: const ['Polygons/tasmania.poly'],
      retryAction: () async {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MappingStoreFailureDialog(
            failure: failure,
            coordinator: coordinator,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('mapping-store-failure-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-failure-operation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-failure-path-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-failure-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-failure-dismiss')),
      findsOneWidget,
    );
  });
}
