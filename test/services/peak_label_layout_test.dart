import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_label_layout.dart';

void main() {
  testWidgets('lower-on-screen labels win collision resolution', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (widgetContext) {
            context = widgetContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final placements = layoutPeakLabels(
      context: context,
      candidates: [
        ProjectedPeakCandidate(
          peak: Peak(
            osmId: 6406,
            name: 'Southern Cone',
            elevation: 1018,
            latitude: -43.0,
            longitude: 147.0,
          ),
          screenPosition: Offset(100, 100),
          isTicked: false,
        ),
        ProjectedPeakCandidate(
          peak: Peak(
            osmId: 7000,
            name: 'Northern Cone',
            elevation: 1020,
            latitude: -42.99,
            longitude: 147.0,
          ),
          screenPosition: Offset(100, 92),
          isTicked: false,
        ),
      ],
    );

    expect(placements.map((placement) => placement.candidate.peak.osmId), [
      6406,
    ]);
  });
}
