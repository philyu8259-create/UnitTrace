enum InspectionType {
  moveIn('move_in'),
  moveOut('move_out'),
  general('general');

  const InspectionType(this.storageKey);

  final String storageKey;

  static InspectionType fromStorageKey(String key) {
    return InspectionType.values.firstWhere(
      (type) => type.storageKey == key,
      orElse: () => InspectionType.general,
    );
  }
}

enum EvidenceSeverity {
  good('good'),
  note('note'),
  issue('issue'),
  urgent('urgent');

  const EvidenceSeverity(this.storageKey);

  final String storageKey;

  static EvidenceSeverity fromStorageKey(String key) {
    return EvidenceSeverity.values.firstWhere(
      (severity) => severity.storageKey == key,
      orElse: () => EvidenceSeverity.note,
    );
  }
}

class PropertyRecord {
  const PropertyRecord({
    required this.id,
    required this.name,
    required this.address,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'createdAt': createdAt.toIso8601String(),
  };

  static PropertyRecord fromJson(Map<String, Object?> json) => PropertyRecord(
    id: json['id']! as String,
    name: json['name']! as String,
    address: json['address']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}

class InspectionRecord {
  const InspectionRecord({
    required this.id,
    required this.propertyId,
    required this.type,
    required this.languageCode,
    required this.createdAt,
  });

  final String id;
  final String propertyId;
  final InspectionType type;
  final String languageCode;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'propertyId': propertyId,
    'type': type.storageKey,
    'languageCode': languageCode,
    'createdAt': createdAt.toIso8601String(),
  };

  static InspectionRecord fromJson(Map<String, Object?> json) =>
      InspectionRecord(
        id: json['id']! as String,
        propertyId: json['propertyId']! as String,
        type: InspectionType.fromStorageKey(json['type']! as String),
        languageCode: json['languageCode']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
      );
}

class RoomRecord {
  const RoomRecord({
    required this.id,
    required this.inspectionId,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String inspectionId;
  final String name;
  final int sortOrder;

  Map<String, Object?> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'name': name,
    'sortOrder': sortOrder,
  };

  static RoomRecord fromJson(Map<String, Object?> json) => RoomRecord(
    id: json['id']! as String,
    inspectionId: json['inspectionId']! as String,
    name: json['name']! as String,
    sortOrder: json['sortOrder']! as int,
  );
}

class EvidenceItemRecord {
  const EvidenceItemRecord({
    required this.id,
    required this.inspectionId,
    required this.roomId,
    required this.description,
    required this.severity,
    required this.capturedAt,
    this.photoPath,
    this.photoHash,
    this.latitude,
    this.longitude,
    this.exifSummary,
  });

  final String id;
  final String inspectionId;
  final String roomId;
  final String description;
  final EvidenceSeverity severity;
  final DateTime capturedAt;
  final String? photoPath;
  final String? photoHash;
  final double? latitude;
  final double? longitude;
  final String? exifSummary;

  Map<String, Object?> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'roomId': roomId,
    'description': description,
    'severity': severity.storageKey,
    'capturedAt': capturedAt.toIso8601String(),
    'photoPath': photoPath,
    'photoHash': photoHash,
    'latitude': latitude,
    'longitude': longitude,
    'exifSummary': exifSummary,
  };

  static EvidenceItemRecord fromJson(Map<String, Object?> json) =>
      EvidenceItemRecord(
        id: json['id']! as String,
        inspectionId: json['inspectionId']! as String,
        roomId: json['roomId']! as String,
        description: json['description']! as String,
        severity: EvidenceSeverity.fromStorageKey(json['severity']! as String),
        capturedAt: DateTime.parse(json['capturedAt']! as String),
        photoPath: json['photoPath'] as String?,
        photoHash: json['photoHash'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        exifSummary: json['exifSummary'] as String?,
      );
}

class SignatureRecord {
  const SignatureRecord({
    required this.id,
    required this.inspectionId,
    required this.signerRole,
    required this.signerName,
    required this.signedAt,
    this.signaturePath,
    this.signatureHash,
  });

  final String id;
  final String inspectionId;
  final String signerRole;
  final String signerName;
  final DateTime signedAt;
  final String? signaturePath;
  final String? signatureHash;

  Map<String, Object?> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'signerRole': signerRole,
    'signerName': signerName,
    'signedAt': signedAt.toIso8601String(),
    'signaturePath': signaturePath,
    'signatureHash': signatureHash,
  };

  static SignatureRecord fromJson(Map<String, Object?> json) => SignatureRecord(
    id: json['id']! as String,
    inspectionId: json['inspectionId']! as String,
    signerRole: json['signerRole']! as String,
    signerName: json['signerName']! as String,
    signedAt: DateTime.parse(json['signedAt']! as String),
    signaturePath: json['signaturePath'] as String?,
    signatureHash: json['signatureHash'] as String?,
  );
}
