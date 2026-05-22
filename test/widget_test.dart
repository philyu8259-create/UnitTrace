import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/main.dart';
import 'package:unittrace/src/data/in_memory_unittrace_store.dart';

void main() {
  testWidgets('creates a property from the empty dashboard', (tester) async {
    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UnitTrace'), findsWidgets);
    expect(find.text('Create property'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Create property').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.enterText(
      find.byKey(const Key('property-address-field')),
      '12 Oak Street',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    expect(find.text('Oak Street Apt'), findsOneWidget);
    expect(find.text('Start inspection'), findsOneWidget);
  });

  testWidgets('runs inspection note and signature flow', (tester) async {
    final store = InMemoryUnitTraceStore();
    await tester.pumpWidget(
      UnitTraceApp(
        store: store,
        initialLocale: const Locale('en'),
        captureLocation: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create property').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.enterText(
      find.byKey(const Key('property-address-field')),
      '12 Oak Street',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Move-in'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && (await store.loadInspections()).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Generate PDF report'), findsOneWidget);
    expect(find.text('Entry'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.note_add_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('evidence-description-field')),
      'Scratch near the entry door',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save note'));
    await tester.pumpAndSettle();
    final inspections = await store.loadInspections();
    final evidence = await store.loadEvidence(inspections.single.id);
    expect(evidence.single.description, 'Scratch near the entry door');
    expect(find.text('Scratch near the entry door'), findsOneWidget);

    await tester.ensureVisible(find.text('Add signature'));
    await tester.tap(find.text('Add signature'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Alex Tenant');
    await tester.tap(find.text('Save signature'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Tenant'), findsOneWidget);
  });

  testWidgets('free plan blocks a second property', (tester) async {
    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create property').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create property').first);
    await tester.pumpAndSettle();
    expect(find.text('Free property limit reached'), findsOneWidget);
  });
}
