import '../domain/entities.dart';
import 'unittrace_store.dart';

class InMemoryUnitTraceStore implements UnitTraceStore {
  final _properties = <PropertyRecord>[];
  final _inspections = <InspectionRecord>[];
  final _rooms = <RoomRecord>[];
  final _evidence = <EvidenceItemRecord>[];
  final _signatures = <SignatureRecord>[];

  @override
  Future<void> close() async {}

  @override
  Future<List<PropertyRecord>> loadProperties() async => [..._properties];

  @override
  Future<List<InspectionRecord>> loadInspections() async => [..._inspections];

  @override
  Future<List<RoomRecord>> loadRooms(String inspectionId) async {
    return _rooms.where((room) => room.inspectionId == inspectionId).toList();
  }

  @override
  Future<List<EvidenceItemRecord>> loadEvidence(String inspectionId) async {
    return _evidence
        .where((item) => item.inspectionId == inspectionId)
        .toList();
  }

  @override
  Future<List<SignatureRecord>> loadSignatures(String inspectionId) async {
    return _signatures
        .where((signature) => signature.inspectionId == inspectionId)
        .toList();
  }

  @override
  Future<void> saveProperty(PropertyRecord property) async {
    _properties.removeWhere((item) => item.id == property.id);
    _properties.add(property);
  }

  @override
  Future<void> saveInspection(InspectionRecord inspection) async {
    _inspections.removeWhere((item) => item.id == inspection.id);
    _inspections.add(inspection);
  }

  @override
  Future<void> saveRoom(RoomRecord room) async {
    _rooms.removeWhere((item) => item.id == room.id);
    _rooms.add(room);
  }

  @override
  Future<void> saveEvidence(EvidenceItemRecord evidence) async {
    _evidence.removeWhere((item) => item.id == evidence.id);
    _evidence.add(evidence);
  }

  @override
  Future<void> saveSignature(SignatureRecord signature) async {
    _signatures.removeWhere((item) => item.id == signature.id);
    _signatures.add(signature);
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    final inspectionIds = _inspections
        .where((item) => item.propertyId == propertyId)
        .map((item) => item.id)
        .toSet();
    _properties.removeWhere((item) => item.id == propertyId);
    _inspections.removeWhere((item) => inspectionIds.contains(item.id));
    _rooms.removeWhere((item) => inspectionIds.contains(item.inspectionId));
    _evidence.removeWhere((item) => inspectionIds.contains(item.inspectionId));
    _signatures.removeWhere(
      (item) => inspectionIds.contains(item.inspectionId),
    );
  }

  @override
  Future<void> deleteInspection(String inspectionId) async {
    _inspections.removeWhere((item) => item.id == inspectionId);
    _rooms.removeWhere((item) => item.inspectionId == inspectionId);
    _evidence.removeWhere((item) => item.inspectionId == inspectionId);
    _signatures.removeWhere((item) => item.inspectionId == inspectionId);
  }

  @override
  Future<void> deleteEvidence(String evidenceId) async {
    _evidence.removeWhere((item) => item.id == evidenceId);
  }

  @override
  Future<void> deleteSignature(String signatureId) async {
    _signatures.removeWhere((item) => item.id == signatureId);
  }
}
