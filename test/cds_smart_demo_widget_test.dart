import 'package:cds_smart_mobile/cds_smart/demo_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'tracking navigates, searches, pages, and shows separate histories',
    (tester) async {
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(home: CdsDemoHome()));

      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();
      expect(find.text('Submission Tracking'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2400));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      final nextPage = find.byTooltip('Next page');
      await tester.tap(nextPage);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Sample conservation submission 9'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, 2400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Outgoing'));
      await tester.pumpAndSettle();
      expect(find.text('Biodiversity monitoring submission'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'History'));
      await tester.pumpAndSettle();
      expect(find.text('Technical assessment report'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Incoming'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DEMO-2026-001');
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Protected area conservation report'), findsOneWidget);

      await tester.tap(find.text('Protected area conservation report'));
      await tester.pumpAndSettle();
      expect(find.text('Current custody: PENRO Sample'), findsOneWidget);
      expect(find.text('Routing history'), findsOneWidget);
      expect(
        find.text('CENRO Sample → PENRO Sample\n2026-10-10T00:00:00.000Z'),
        findsOneWidget,
      );
      expect(find.text('Review history'), findsOneWidget);
      expect(find.text('needs correction'), findsOneWidget);
      expect(
        find.text(
          'A review verdict does not move custody. Only a routing event changes the recorded office.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('notifications change their in-memory read state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: CdsDemoHome()));

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('Unread'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(TextButton, 'Mark read').first);
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
  });

  testWidgets('small screen shows an explicit empty search state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: CdsDemoHome()));

    await tester.tap(find.text('Tracking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NO-SUCH-SAMPLE-REFERENCE');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('No matching sample documents.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
