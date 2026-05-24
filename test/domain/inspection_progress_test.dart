import 'package:flutter_test/flutter_test.dart';

import 'package:unittrace/src/domain/entities.dart';
import 'package:unittrace/src/domain/inspection_progress.dart';

void main() {
  group('InspectionProgressSummary', () {
    final inspection = InspectionRecord(
      id: 'inspection-1',
      propertyId: 'property-1',
      type: InspectionType.moveIn,
      languageCode: 'en',
      createdAt: DateTime.utc(2026, 5, 1),
    );
    final room = RoomRecord(
      id: 'room-1',
      inspectionId: inspection.id,
      name: 'Living Room',
      sortOrder: 1,
    );

    test('empty inspection asks for addEvidence next step', () {
      final summary = InspectionProgressSummary.build(
        inspection: inspection,
        rooms: [room],
        evidenceItems: const [],
        signatures: const [],
      );

      expect(summary.nextStepKind, InspectionNextStep.addEvidence);
      expect(summary.canExport, isFalse);
      expect(summary.completionRatio, 0);
    });

    test('evidence present but no signature asks for addSignature', () {
      final summary = InspectionProgressSummary.build(
        inspection: inspection,
        rooms: [room],
        evidenceItems: [
          EvidenceItemRecord(
            id: 'e1',
            inspectionId: inspection.id,
            roomId: room.id,
            description: 'Water stain',
            severity: EvidenceSeverity.issue,
            capturedAt: DateTime.utc(2026, 5, 2, 10),
            photoPath: '/tmp/stain.jpg',
            photoHash: 'abc',
          ),
        ],
        signatures: const [],
      );

      expect(summary.nextStepKind, InspectionNextStep.addSignature);
      expect(summary.canExport, isFalse);
    });

    test('evidence and signature asks for exportReport', () {
      final summary = InspectionProgressSummary.build(
        inspection: inspection,
        rooms: [room],
        evidenceItems: [
          EvidenceItemRecord(
            id: 'e1',
            inspectionId: inspection.id,
            roomId: room.id,
            description: 'Water stain',
            severity: EvidenceSeverity.issue,
            capturedAt: DateTime.utc(2026, 5, 2, 10),
            photoPath: '/tmp/stain.jpg',
            photoHash: 'abc',
            latitude: 40.1,
            longitude: 74.2,
          ),
        ],
        signatures: [
          SignatureRecord(
            id: 's1',
            inspectionId: inspection.id,
            signerRole: 'tenant',
            signerName: 'Alex',
            signedAt: DateTime.utc(2026, 5, 2, 11),
            signaturePath: '/tmp/signature.png',
            signatureHash: 'sig-hash',
          ),
        ],
      );

      expect(summary.nextStepKind, InspectionNextStep.exportReport);
      expect(summary.canExport, isTrue);
      expect(summary.signatureCount, 1);
    });
  });

  group('RoomChecklistStatus', () {
    test('aggregates room checklist status correctly', () {
      final inspection = InspectionRecord(
        id: 'inspection-2',
        propertyId: 'property-1',
        type: InspectionType.general,
        languageCode: 'en',
        createdAt: DateTime.utc(2026, 5, 3),
      );
      final rooms = [
        RoomRecord(
          id: 'room-1',
          inspectionId: inspection.id,
          name: 'Kitchen',
          sortOrder: 1,
        ),
        RoomRecord(
          id: 'room-2',
          inspectionId: inspection.id,
          name: 'Bedroom',
          sortOrder: 2,
        ),
      ];

      final evidenceItems = [
        EvidenceItemRecord(
          id: 'e1',
          inspectionId: inspection.id,
          roomId: rooms[0].id,
          description: 'crack',
          severity: EvidenceSeverity.note,
          capturedAt: DateTime.utc(2026, 5, 3, 10),
          photoPath: '/tmp/kitchen1.jpg',
          photoHash: 'hash-1',
          latitude: 1.1,
          longitude: 2.2,
        ),
        EvidenceItemRecord(
          id: 'e2',
          inspectionId: inspection.id,
          roomId: rooms[0].id,
          description: 'note',
          severity: EvidenceSeverity.good,
          capturedAt: DateTime.utc(2026, 5, 3, 11),
          photoPath: '/tmp/kitchen2.jpg',
          photoHash: 'hash-2',
          latitude: 1.3,
          longitude: 2.4,
        ),
        EvidenceItemRecord(
          id: 'e3',
          inspectionId: inspection.id,
          roomId: rooms[1].id,
          description: 'none',
          severity: EvidenceSeverity.issue,
          capturedAt: DateTime.utc(2026, 5, 3, 12),
        ),
      ];

      final summary = InspectionProgressSummary.build(
        inspection: inspection,
        rooms: rooms,
        evidenceItems: evidenceItems,
        signatures: const [],
      );
      expect(summary.roomsWithEvidence, 2);
      expect(summary.completionRatio, 1.0);
      expect(summary.issueCount, 2);

      final statuses = RoomChecklistStatus.build(
        rooms: rooms,
        evidenceItems: evidenceItems,
      );
      final kitchen = statuses.firstWhere(
        (status) => status.room.id == rooms[0].id,
      );
      expect(kitchen.evidenceCount, 2);
      expect(kitchen.issueCount, 1);
      expect(kitchen.photoCount, 2);
      expect(kitchen.hashReady, isTrue);
      expect(kitchen.locationReady, isTrue);
      expect(kitchen.isComplete, isTrue);

      final bedroom = statuses.firstWhere(
        (status) => status.room.id == rooms[1].id,
      );
      expect(bedroom.evidenceCount, 1);
      expect(bedroom.issueCount, 1);
      expect(bedroom.photoCount, 0);
      expect(bedroom.hashReady, isFalse);
      expect(bedroom.locationReady, isFalse);
      expect(bedroom.isComplete, isFalse);
    });
  });

  group('ReportArchiveFilter', () {
    test('matches by inspection type key', () {
      expect(ReportArchiveFilter.all.matches('move_in'), isTrue);
      expect(ReportArchiveFilter.all.matches('move_out'), isTrue);
      expect(ReportArchiveFilter.all.matches('general'), isTrue);
      expect(ReportArchiveFilter.all.matches('other'), isTrue);

      expect(ReportArchiveFilter.moveIn.matches('move_in'), isTrue);
      expect(ReportArchiveFilter.moveIn.matches('move_out'), isFalse);

      expect(ReportArchiveFilter.moveOut.matches('move_out'), isTrue);
      expect(ReportArchiveFilter.moveOut.matches('general'), isFalse);

      expect(ReportArchiveFilter.general.matches('general'), isTrue);
      expect(ReportArchiveFilter.general.matches('move_in'), isFalse);
    });
  });
}
