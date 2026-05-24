import 'entities.dart';

enum InspectionNextStep { addEvidence, addSignature, exportReport }

class InspectionProgressSummary {
  const InspectionProgressSummary({
    required this.totalRooms,
    required this.roomsWithEvidence,
    required this.evidenceCount,
    required this.issueCount,
    required this.photoCount,
    required this.hashCount,
    required this.locationCount,
    required this.signatureCount,
    required this.canExport,
    required this.completionRatio,
    required this.nextStepKind,
  });

  final int totalRooms;
  final int roomsWithEvidence;
  final int evidenceCount;
  final int issueCount;
  final int photoCount;
  final int hashCount;
  final int locationCount;
  final int signatureCount;
  final bool canExport;
  final double completionRatio;
  final InspectionNextStep nextStepKind;

  factory InspectionProgressSummary.build({
    required InspectionRecord inspection,
    required List<RoomRecord> rooms,
    required List<EvidenceItemRecord> evidenceItems,
    required List<SignatureRecord> signatures,
  }) {
    final scopedRooms = rooms
        .where((room) => room.inspectionId == inspection.id)
        .toList();
    final scopedEvidence = evidenceItems
        .where((item) => item.inspectionId == inspection.id)
        .toList();
    final scopedSignatures = signatures
        .where((signature) => signature.inspectionId == inspection.id)
        .toList();

    final evidenceCount = scopedEvidence.length;
    final issueCount = scopedEvidence
        .where((item) => item.severity != EvidenceSeverity.good)
        .length;
    final photoCount = scopedEvidence
        .where((item) => item.photoPath != null)
        .length;
    final hashCount = scopedEvidence
        .where((item) => item.photoHash != null && item.photoHash!.isNotEmpty)
        .length;
    final locationCount = scopedEvidence
        .where((item) => item.latitude != null && item.longitude != null)
        .length;
    final signatureCount = scopedSignatures.length;
    final totalRooms = scopedRooms.length;
    final roomIdsWithEvidence = scopedEvidence
        .map((item) => item.roomId)
        .toSet();
    final roomsWithEvidence = scopedRooms
        .where((room) => roomIdsWithEvidence.contains(room.id))
        .length;
    final completionRatio = totalRooms == 0
        ? 0.0
        : roomsWithEvidence / totalRooms;
    final canExport = evidenceCount > 0 && signatureCount > 0;
    final nextStepKind = switch (evidenceCount) {
      0 => InspectionNextStep.addEvidence,
      _ when !canExport => InspectionNextStep.addSignature,
      _ => InspectionNextStep.exportReport,
    };

    return InspectionProgressSummary(
      totalRooms: totalRooms,
      roomsWithEvidence: roomsWithEvidence,
      evidenceCount: evidenceCount,
      issueCount: issueCount,
      photoCount: photoCount,
      hashCount: hashCount,
      locationCount: locationCount,
      signatureCount: signatureCount,
      canExport: canExport,
      completionRatio: completionRatio,
      nextStepKind: nextStepKind,
    );
  }
}

class RoomChecklistStatus {
  const RoomChecklistStatus({
    required this.room,
    required this.evidenceCount,
    required this.issueCount,
    required this.photoCount,
    required this.hashReady,
    required this.locationReady,
    required this.isComplete,
  });

  final RoomRecord room;
  final int evidenceCount;
  final int issueCount;
  final int photoCount;
  final bool hashReady;
  final bool locationReady;
  final bool isComplete;

  static List<RoomChecklistStatus> build({
    required List<RoomRecord> rooms,
    required List<EvidenceItemRecord> evidenceItems,
  }) {
    final evidenceByRoom = <String, List<EvidenceItemRecord>>{};
    for (final item in evidenceItems) {
      evidenceByRoom
          .putIfAbsent(item.roomId, () => <EvidenceItemRecord>[])
          .add(item);
    }

    return rooms.map((room) {
      final items = evidenceByRoom[room.id] ?? const <EvidenceItemRecord>[];
      final issueCount = items
          .where((item) => item.severity != EvidenceSeverity.good)
          .length;
      final photoCount = items.where((item) => item.photoPath != null).length;
      final hashReady = items.any(
        (item) => item.photoHash != null && item.photoHash!.isNotEmpty,
      );
      final locationReady = items.any(
        (item) => item.latitude != null && item.longitude != null,
      );
      return RoomChecklistStatus(
        room: room,
        evidenceCount: items.length,
        issueCount: issueCount,
        photoCount: photoCount,
        hashReady: hashReady,
        locationReady: locationReady,
        isComplete: items.isNotEmpty && hashReady && locationReady,
      );
    }).toList();
  }
}

enum ReportArchiveFilter { all, moveIn, moveOut, general }

extension ReportArchiveFilterMatcher on ReportArchiveFilter {
  bool matches(String inspectionTypeKey) {
    return switch (this) {
      ReportArchiveFilter.all => true,
      ReportArchiveFilter.moveIn =>
        inspectionTypeKey == InspectionType.moveIn.storageKey,
      ReportArchiveFilter.moveOut =>
        inspectionTypeKey == InspectionType.moveOut.storageKey,
      ReportArchiveFilter.general =>
        inspectionTypeKey == InspectionType.general.storageKey,
    };
  }
}
