import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/main.dart';
import 'package:unittrace/src/data/in_memory_unittrace_store.dart';
import 'package:unittrace/src/domain/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp('unittrace-goldens');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return temp.path;
            }
            return temp.path;
          },
        );
  });

  testWidgets('golden home dashboard', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UnitTraceApp(
        store: await _seedStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(UnitTraceApp),
      matchesGoldenFile('goldens/home_dashboard.png'),
    );
  });

  testWidgets('golden room checklist workspace', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UnitTraceApp(
        store: await _seedStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue inspection'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Room checklist'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(UnitTraceApp),
      matchesGoldenFile('goldens/room_checklist.png'),
    );
  });

  testWidgets('golden report history', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UnitTraceApp(
        store: await _seedStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pump();
    await _pumpUntilReportHistoryReady(tester);

    await expectLater(
      find.byType(UnitTraceApp),
      matchesGoldenFile('goldens/report_history.png'),
    );
  });
}

Future<void> _pumpUntilReportHistoryReady(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final hasStableHistoryContent =
        find.text('Where reports come from').evaluate().isNotEmpty ||
        find.text('No exported reports yet').evaluate().isNotEmpty ||
        find.text('PDF REPORT · MANIFEST').evaluate().isNotEmpty;
    final isLoading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;
    if (!isLoading && hasStableHistoryContent) return;
  }
  throw Exception('Report history did not reach stable content');
}

Future<InMemoryUnitTraceStore> _seedStore() async {
  final store = InMemoryUnitTraceStore();
  final property = PropertyRecord(
    id: 'property-1',
    name: 'Oak Street Apt',
    address: '12 Oak Street',
    createdAt: DateTime.utc(2026, 5, 20),
  );
  final inspection = InspectionRecord(
    id: 'inspection-1',
    propertyId: property.id,
    type: InspectionType.moveIn,
    languageCode: 'en',
    createdAt: DateTime.utc(2026, 5, 21),
  );
  final entry = RoomRecord(
    id: 'room-entry',
    inspectionId: inspection.id,
    name: 'Entry',
    sortOrder: 0,
  );
  final kitchen = RoomRecord(
    id: 'room-kitchen',
    inspectionId: inspection.id,
    name: 'Kitchen',
    sortOrder: 1,
  );
  await store.saveProperty(property);
  await store.saveInspection(inspection);
  await store.saveRoom(entry);
  await store.saveRoom(kitchen);
  await store.saveEvidence(
    EvidenceItemRecord(
      id: 'evidence-1',
      inspectionId: inspection.id,
      roomId: entry.id,
      description: 'Scratch near the entry door',
      severity: EvidenceSeverity.issue,
      capturedAt: DateTime.utc(2026, 5, 21, 16, 30),
      photoPath: '/tmp/unittrace-entry.jpg',
      photoHash: '1234567890abcdef',
      latitude: 37.7749,
      longitude: -122.4194,
    ),
  );
  await store.saveSignature(
    SignatureRecord(
      id: 'signature-1',
      inspectionId: inspection.id,
      signerRole: 'Tenant',
      signerName: 'Alex Tenant',
      signedAt: DateTime.utc(2026, 5, 21, 17),
      signatureHash: 'signature-hash',
    ),
  );
  return store;
}
