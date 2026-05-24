import '../services/hash_service.dart';
import 'entities.dart';

class ReportManifest {
  const ReportManifest({
    required this.reportId,
    required this.property,
    required this.inspection,
    required this.rooms,
    required this.evidenceItems,
    required this.signatures,
    required this.generatedAt,
    required this.appVersion,
    required this.deviceLabel,
    required this.manifestHash,
  });

  final String reportId;
  final PropertyRecord property;
  final InspectionRecord inspection;
  final List<RoomRecord> rooms;
  final List<EvidenceItemRecord> evidenceItems;
  final List<SignatureRecord> signatures;
  final DateTime generatedAt;
  final String appVersion;
  final String deviceLabel;
  final String manifestHash;

  int get photoCount =>
      evidenceItems.where((item) => item.photoPath != null).length;

  int get evidenceCount => evidenceItems.length;

  List<String> get evidenceHashes {
    return evidenceItems
        .map((item) => item.photoHash)
        .whereType<String>()
        .toList();
  }

  Map<String, Object?> toJson({bool includeHash = true}) {
    final json = <String, Object?>{
      'reportId': reportId,
      'inspectionType': inspection.type.storageKey,
      'reportTitle':
          '${property.name} ${_manifestInspectionTitle(inspection.type, inspection.languageCode)}',
      'property': property.toJson(),
      'inspection': inspection.toJson(),
      'rooms': rooms.map((room) => room.toJson()).toList(),
      'evidenceItems': evidenceItems.map((item) => item.toJson()).toList(),
      'signatures': signatures.map((signature) => signature.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'appVersion': appVersion,
      'deviceLabel': deviceLabel,
      'evidenceCount': evidenceCount,
      'photoCount': photoCount,
      'evidenceHashes': evidenceHashes,
    };
    if (includeHash) {
      json['manifestHash'] = manifestHash;
    }
    return json;
  }
}

String _manifestInspectionTitle(InspectionType type, String languageCode) {
  final isChinese = languageCode.toLowerCase().startsWith('zh');
  return switch (type) {
    InspectionType.moveIn => isChinese ? '入住检查' : 'Move-in Inspection',
    InspectionType.moveOut => isChinese ? '退租检查' : 'Move-out Inspection',
    InspectionType.general => isChinese ? '普通检查' : 'General Inspection',
  };
}

class ReportManifestBuilder {
  ReportManifest build({
    required PropertyRecord property,
    required InspectionRecord inspection,
    required List<RoomRecord> rooms,
    required List<EvidenceItemRecord> evidenceItems,
    required List<SignatureRecord> signatures,
    required DateTime generatedAt,
    required String appVersion,
    required String deviceLabel,
  }) {
    final reportId = 'UT-${inspection.id}';
    final sortedRooms = [...rooms]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final sortedEvidence = [...evidenceItems]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final sortedSignatures = [...signatures]
      ..sort((a, b) => a.signedAt.compareTo(b.signedAt));
    final hashInput = <String, Object?>{
      'reportId': reportId,
      'property': property.toJson(),
      'inspection': inspection.toJson(),
      'rooms': sortedRooms.map((room) => room.toJson()).toList(),
      'evidenceItems': sortedEvidence.map((item) => item.toJson()).toList(),
      'signatures': sortedSignatures
          .map((signature) => signature.toJson())
          .toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'appVersion': appVersion,
      'deviceLabel': deviceLabel,
    };

    return ReportManifest(
      reportId: reportId,
      property: property,
      inspection: inspection,
      rooms: sortedRooms,
      evidenceItems: sortedEvidence,
      signatures: sortedSignatures,
      generatedAt: generatedAt,
      appVersion: appVersion,
      deviceLabel: deviceLabel,
      manifestHash: HashService.sha256ForJson(hashInput),
    );
  }
}
