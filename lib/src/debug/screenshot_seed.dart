import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../data/unittrace_store.dart';
import '../domain/entities.dart';
import '../domain/room_templates.dart';
import '../l10n/app_strings.dart';
import '../services/app_directories.dart';
import '../services/hash_service.dart';
import '../services/pro_entitlement.dart';
import '../services/report_exporter.dart';

class ScreenshotSeed {
  const ScreenshotSeed._();

  static const empty = 'empty';
  static const dashboard = 'dashboard';
  static const inspection = 'inspection';
  static const inspectionFinal = 'inspection_final';
  static const reports = 'reports';
  static const more = 'more';

  static bool shouldSeed(String scenario) => scenario.trim().isNotEmpty;

  static LocaleConfig localeFor(String localeCode) {
    final normalized = localeCode.toLowerCase();
    if (normalized.startsWith('zh')) {
      return const LocaleConfig(languageCode: 'zh_Hans', localeTag: 'zh-Hans');
    }
    return const LocaleConfig(languageCode: 'en', localeTag: 'en');
  }

  static Future<ProEntitlementController> proController() async {
    final controller = ProEntitlementController(
      store: MemoryProEntitlementStore(),
      purchaseClient: const _ScreenshotPurchaseClient(),
    );
    await controller.unlockLifetime();
    return controller;
  }

  static Future<void> populate({
    required UnitTraceStore store,
    required String scenario,
    required String languageCode,
  }) async {
    await _resetScreenshotDocuments();
    if (scenario == empty) return;
    final now = DateTime.utc(2026, 5, 24, 17, 20);
    final property = PropertyRecord(
      id: 'screenshot-property',
      name: languageCode == 'zh_Hans' ? '滨河公寓 12A' : 'Oak Street Apartment 12A',
      address: languageCode == 'zh_Hans'
          ? '加州圣何塞 Market Street 1200号'
          : '1200 Market Street, San Jose, CA',
      createdAt: now.subtract(const Duration(days: 2)),
    );
    await store.saveProperty(property);

    final inspection = InspectionRecord(
      id: 'screenshot-move-in',
      propertyId: property.id,
      type: InspectionType.moveIn,
      languageCode: languageCode,
      createdAt: now.subtract(const Duration(hours: 2)),
    );
    await store.saveInspection(inspection);

    final rooms = RoomTemplates.forLanguageCode(languageCode).indexed
        .map(
          (entry) => RoomRecord(
            id: 'room-${entry.$1}',
            inspectionId: inspection.id,
            name: entry.$2,
            sortOrder: entry.$1,
          ),
        )
        .toList();
    for (final room in rooms) {
      await store.saveRoom(room);
    }

    final photoSpecs = [
      _SeedPhotoSpec(
        assetPath: 'assets/screenshots/sample_entry.jpg',
        roomIndex: 0,
        zhDescription: '玄关门下合页附近有轻微擦痕。',
        enDescription: 'Entry door has a small scuff near the lower hinge.',
        severity: EvidenceSeverity.issue,
      ),
      _SeedPhotoSpec(
        assetPath: 'assets/screenshots/sample_living.jpg',
        roomIndex: 1,
        zhDescription: '客厅木地板有一处细小划痕。',
        enDescription: 'Living room floor has a small visible scratch.',
        severity: EvidenceSeverity.issue,
      ),
      _SeedPhotoSpec(
        assetPath: 'assets/screenshots/sample_kitchen.jpg',
        roomIndex: 2,
        zhDescription: '厨房水槽下方柜门边缘有小磕碰。',
        enDescription: 'Kitchen cabinet edge has a small chip near the sink.',
        severity: EvidenceSeverity.note,
      ),
      _SeedPhotoSpec(
        assetPath: 'assets/screenshots/sample_bathroom.jpg',
        roomIndex: 4,
        zhDescription: '浴室台面有一圈浅色水渍痕迹。',
        enDescription: 'Bathroom counter has a light circular water mark.',
        severity: EvidenceSeverity.note,
      ),
    ];
    for (final spec in photoSpecs) {
      final room = rooms[spec.roomIndex.clamp(0, rooms.length - 1)];
      final storedPath = await _copyAssetToEvidence(spec.assetPath);
      final file = File(
        p.join((await AppDirectories.documents()).path, storedPath),
      );
      final hash = await HashService.sha256ForFile(file);
      await store.saveEvidence(
        EvidenceItemRecord(
          id: 'evidence-${spec.roomIndex}',
          inspectionId: inspection.id,
          roomId: room.id,
          description: languageCode == 'zh_Hans'
              ? spec.zhDescription
              : spec.enDescription,
          severity: spec.severity,
          capturedAt: now.subtract(Duration(minutes: 30 - spec.roomIndex * 4)),
          photoPath: storedPath,
          photoHash: hash,
          latitude: 37.3349,
          longitude: -121.8890,
          exifSummary:
              'Screenshot sample; asset: ${p.basename(spec.assetPath)}',
        ),
      );
    }

    await store.saveEvidence(
      EvidenceItemRecord(
        id: 'evidence-note',
        inspectionId: inspection.id,
        roomId: rooms.first.id,
        description: languageCode == 'zh_Hans'
            ? '钥匙交接时门锁可正常开合。'
            : 'Door lock works normally during key handoff.',
        severity: EvidenceSeverity.good,
        capturedAt: now.subtract(const Duration(minutes: 8)),
        latitude: 37.3349,
        longitude: -121.8890,
        exifSummary: 'Text-only evidence note',
      ),
    );

    await store.saveSignature(
      SignatureRecord(
        id: 'signature-tenant',
        inspectionId: inspection.id,
        signerRole: 'tenant',
        signerName: languageCode == 'zh_Hans' ? '张伟' : 'Alex Tenant',
        signedAt: now.subtract(const Duration(minutes: 5)),
        signatureHash:
            '8f4a2b7c91d4e6f0a1122334455667788990aabbccddeeff0011223344556677',
      ),
    );
    await store.saveSignature(
      SignatureRecord(
        id: 'signature-landlord',
        inspectionId: inspection.id,
        signerRole: 'landlord',
        signerName: languageCode == 'zh_Hans' ? '李安娜' : 'Laura Landlord',
        signedAt: now.subtract(const Duration(minutes: 3)),
        signatureHash:
            '91c4e6f08f4a2b7caabbccddeeff0011223344556677889901122334455667788',
      ),
    );

    final followUp = InspectionRecord(
      id: 'screenshot-move-out',
      propertyId: property.id,
      type: InspectionType.moveOut,
      languageCode: languageCode,
      createdAt: now.subtract(const Duration(days: 1)),
    );
    await store.saveInspection(followUp);

    if (scenario == reports || scenario == dashboard) {
      await ReportExporter().export(
        property: property,
        inspection: inspection,
        rooms: rooms,
        evidenceItems: await store.loadEvidence(inspection.id),
        signatures: await store.loadSignatures(inspection.id),
        strings: AppStrings.forLanguageCode(languageCode),
        watermarked: false,
      );
    }
  }

  static Future<void> _resetScreenshotDocuments() async {
    final documents = await AppDirectories.documents();
    for (final child in ['evidence', 'reports']) {
      final directory = Directory(p.join(documents.path, child));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  static Future<String> _copyAssetToEvidence(String assetPath) async {
    final documents = await AppDirectories.documents();
    final evidenceDirectory = Directory(p.join(documents.path, 'evidence'));
    await evidenceDirectory.create(recursive: true);
    final fileName = p.basename(assetPath);
    final target = File(p.join(evidenceDirectory.path, fileName));
    final bytes = await rootBundle.load(assetPath);
    await target.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return p.join('evidence', fileName);
  }
}

class LocaleConfig {
  const LocaleConfig({required this.languageCode, required this.localeTag});

  final String languageCode;
  final String localeTag;
}

class _SeedPhotoSpec {
  const _SeedPhotoSpec({
    required this.assetPath,
    required this.roomIndex,
    required this.zhDescription,
    required this.enDescription,
    required this.severity,
  });

  final String assetPath;
  final int roomIndex;
  final String zhDescription;
  final String enDescription;
  final EvidenceSeverity severity;
}

class _ScreenshotPurchaseClient implements ProPurchaseClient {
  const _ScreenshotPurchaseClient();

  @override
  Future<ProPurchaseResult> buyLifetime() async => ProPurchaseResult.success;

  @override
  Future<ProPurchaseResult> restorePurchases() async =>
      ProPurchaseResult.restored;
}
