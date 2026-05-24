import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/src/domain/entities.dart';
import 'package:unittrace/src/domain/report_manifest.dart';
import 'package:unittrace/src/l10n/app_strings.dart';
import 'package:unittrace/src/services/hash_service.dart';
import 'package:unittrace/src/services/report_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds PDF bytes with bundled Chinese-capable fonts', () async {
    final property = PropertyRecord(
      id: 'property-cn',
      name: '房况留证测试房屋',
      address: '12 Oak Street',
      createdAt: DateTime.utc(2026, 5, 1),
    );
    final inspection = InspectionRecord(
      id: 'inspection-cn',
      propertyId: property.id,
      type: InspectionType.moveOut,
      languageCode: 'zh_Hans',
      createdAt: DateTime.utc(2026, 5, 2),
    );
    final room = RoomRecord(
      id: 'room-cn',
      inspectionId: inspection.id,
      name: '厨房',
      sortOrder: 0,
    );
    final evidence = EvidenceItemRecord(
      id: 'evidence-cn',
      inspectionId: inspection.id,
      roomId: room.id,
      description: '水槽旁有划痕',
      severity: EvidenceSeverity.issue,
      capturedAt: DateTime.utc(2026, 5, 2, 12),
      photoHash: HashService.sha256ForBytes(utf8.encode('photo')),
    );
    final manifest = ReportManifestBuilder().build(
      property: property,
      inspection: inspection,
      rooms: [room],
      evidenceItems: [evidence],
      signatures: const [],
      generatedAt: DateTime.utc(2026, 5, 2, 13),
      appVersion: '1.0.0',
      deviceLabel: 'test-device',
    );

    final bytes = await ReportExporter().buildPdfBytes(
      manifest: manifest,
      strings: AppStrings.forLanguageCode('zh_Hans'),
      watermarked: true,
    );

    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(50000));
    expect(bytes.length, lessThan(2000000));
  });

  test('embeds signature image bytes when a saved signature exists', () async {
    final signatureFile = File('assets/images/report_cover.png');
    expect(signatureFile.existsSync(), isTrue);

    final property = PropertyRecord(
      id: 'property-signature',
      name: 'Oak Street Apt',
      address: '12 Oak Street',
      createdAt: DateTime.utc(2026, 5, 1),
    );
    final inspection = InspectionRecord(
      id: 'inspection-signature',
      propertyId: property.id,
      type: InspectionType.moveIn,
      languageCode: 'en',
      createdAt: DateTime.utc(2026, 5, 2),
    );
    final room = RoomRecord(
      id: 'room-signature',
      inspectionId: inspection.id,
      name: 'Entry',
      sortOrder: 0,
    );
    final signature = SignatureRecord(
      id: 'signature-tenant',
      inspectionId: inspection.id,
      signerRole: 'Tenant',
      signerName: 'Alex Tenant',
      signedAt: DateTime.utc(2026, 5, 2, 13),
      signaturePath: signatureFile.path,
      signatureHash: HashService.sha256ForBytes(
        await signatureFile.readAsBytes(),
      ),
    );
    final unsignedManifest = ReportManifestBuilder().build(
      property: property,
      inspection: inspection,
      rooms: [room],
      evidenceItems: const [],
      signatures: const [],
      generatedAt: DateTime.utc(2026, 5, 2, 13),
      appVersion: '1.0.0',
      deviceLabel: 'test-device',
    );
    final signedManifest = ReportManifestBuilder().build(
      property: property,
      inspection: inspection,
      rooms: [room],
      evidenceItems: const [],
      signatures: [signature],
      generatedAt: DateTime.utc(2026, 5, 2, 13),
      appVersion: '1.0.0',
      deviceLabel: 'test-device',
    );

    final exporter = ReportExporter();
    final unsignedBytes = await exporter.buildPdfBytes(
      manifest: unsignedManifest,
      strings: AppStrings.forLanguageCode('en'),
      watermarked: true,
    );
    final signedBytes = await exporter.buildPdfBytes(
      manifest: signedManifest,
      strings: AppStrings.forLanguageCode('en'),
      watermarked: true,
    );

    expect(ascii.decode(signedBytes.take(4).toList()), '%PDF');
    expect(signedBytes.length, greaterThan(unsignedBytes.length));
  });
}
