import '../domain/entities.dart';

abstract class UnitTraceStore {
  Future<void> close();
  Future<List<PropertyRecord>> loadProperties();
  Future<List<InspectionRecord>> loadInspections();
  Future<List<RoomRecord>> loadRooms(String inspectionId);
  Future<List<EvidenceItemRecord>> loadEvidence(String inspectionId);
  Future<List<SignatureRecord>> loadSignatures(String inspectionId);
  Future<void> saveProperty(PropertyRecord property);
  Future<void> saveInspection(InspectionRecord inspection);
  Future<void> saveRoom(RoomRecord room);
  Future<void> saveEvidence(EvidenceItemRecord evidence);
  Future<void> saveSignature(SignatureRecord signature);
}
