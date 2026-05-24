import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/main.dart';
import 'package:unittrace/src/data/in_memory_unittrace_store.dart';
import 'package:unittrace/src/domain/entities.dart';

void main() {
  for (final scenario in _scenarios) {
    testWidgets('responsive smoke: ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
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

      expect(find.text('Local Evidence Vault'), findsOneWidget);
      expect(find.text('Oak Street Apt'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });
  }
}

const _scenarios = [
  _ResponsiveScenario('iPhone SE', Size(320, 568)),
  _ResponsiveScenario('standard iPhone', Size(390, 844)),
  _ResponsiveScenario('iPhone Pro Max', Size(440, 956)),
  _ResponsiveScenario('iPad portrait', Size(768, 1024)),
  _ResponsiveScenario('Android small', Size(360, 740)),
];

class _ResponsiveScenario {
  const _ResponsiveScenario(this.name, this.size);

  final String name;
  final Size size;
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
  final room = RoomRecord(
    id: 'room-entry',
    inspectionId: inspection.id,
    name: 'Entry',
    sortOrder: 0,
  );
  await store.saveProperty(property);
  await store.saveInspection(inspection);
  await store.saveRoom(room);
  await store.saveEvidence(
    EvidenceItemRecord(
      id: 'evidence-1',
      inspectionId: inspection.id,
      roomId: room.id,
      description: 'Scratch near the entry door',
      severity: EvidenceSeverity.issue,
      capturedAt: DateTime.utc(2026, 5, 21, 16, 30),
      photoHash: '1234567890abcdef',
    ),
  );
  return store;
}
