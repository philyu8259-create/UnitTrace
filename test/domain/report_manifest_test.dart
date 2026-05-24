import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/src/domain/entities.dart';
import 'package:unittrace/src/domain/report_manifest.dart';
import 'package:unittrace/src/services/hash_service.dart';

void main() {
  test('builds deterministic manifest with evidence hashes', () async {
    final property = PropertyRecord(
      id: 'property-1',
      name: 'Oak Street Apt',
      address: '12 Oak Street, Los Angeles, CA',
      createdAt: DateTime.utc(2026, 5, 1),
    );
    final inspection = InspectionRecord(
      id: 'inspection-1',
      propertyId: property.id,
      type: InspectionType.moveIn,
      languageCode: 'en',
      createdAt: DateTime.utc(2026, 5, 2),
    );
    final room = RoomRecord(
      id: 'room-1',
      inspectionId: inspection.id,
      name: 'Kitchen',
      sortOrder: 1,
    );
    final photoHash = HashService.sha256ForBytes(utf8.encode('photo-bytes'));
    final evidence = EvidenceItemRecord(
      id: 'evidence-1',
      inspectionId: inspection.id,
      roomId: room.id,
      description: 'Scratch near sink',
      severity: EvidenceSeverity.issue,
      capturedAt: DateTime.utc(2026, 5, 2, 18, 30),
      photoPath: '/tmp/kitchen.jpg',
      photoHash: photoHash,
      latitude: 34.0522,
      longitude: -118.2437,
      exifSummary: 'captured-by-test',
    );

    final manifest = ReportManifestBuilder().build(
      property: property,
      inspection: inspection,
      rooms: [room],
      evidenceItems: [evidence],
      signatures: const [],
      generatedAt: DateTime.utc(2026, 5, 2, 19),
      appVersion: '1.0.0',
      deviceLabel: 'UnitTrace Test Device',
    );

    expect(manifest.reportId, 'UT-inspection-1');
    expect(manifest.evidenceCount, 1);
    expect(manifest.photoCount, 1);
    expect(manifest.evidenceHashes, [photoHash]);
    expect(manifest.toJson()['inspectionType'], 'move_in');
    final propertyJson = manifest.toJson()['property']! as Map<String, Object?>;
    expect(propertyJson['address'], contains('Los Angeles'));
    expect(manifest.manifestHash.length, 64);
  });

  test('hash service produces stable SHA-256 hex strings', () {
    expect(
      HashService.sha256ForBytes(utf8.encode('UnitTrace')),
      '68b6c74b2b24d74745131a3659f5d1d2caba4132e5a226e758a0309ae40a5f99',
    );
  });
}
