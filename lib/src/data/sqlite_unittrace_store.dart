import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/entities.dart';
import 'unittrace_store.dart';

class SqliteUnitTraceStore implements UnitTraceStore {
  SqliteUnitTraceStore._(this._db);

  final Database _db;

  static Future<SqliteUnitTraceStore> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      p.join(directory.path, 'unittrace.sqlite'),
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE properties (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE inspections (
            id TEXT PRIMARY KEY,
            propertyId TEXT NOT NULL,
            type TEXT NOT NULL,
            languageCode TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE rooms (
            id TEXT PRIMARY KEY,
            inspectionId TEXT NOT NULL,
            name TEXT NOT NULL,
            sortOrder INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE evidence (
            id TEXT PRIMARY KEY,
            inspectionId TEXT NOT NULL,
            roomId TEXT NOT NULL,
            description TEXT NOT NULL,
            severity TEXT NOT NULL,
            capturedAt TEXT NOT NULL,
            photoPath TEXT,
            photoHash TEXT,
            latitude REAL,
            longitude REAL,
            exifSummary TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE signatures (
            id TEXT PRIMARY KEY,
            inspectionId TEXT NOT NULL,
            signerRole TEXT NOT NULL,
            signerName TEXT NOT NULL,
            signedAt TEXT NOT NULL,
            signaturePath TEXT,
            signatureHash TEXT
          )
        ''');
      },
    );
    return SqliteUnitTraceStore._(db);
  }

  @override
  Future<void> close() => _db.close();

  @override
  Future<List<PropertyRecord>> loadProperties() async {
    final rows = await _db.query('properties', orderBy: 'createdAt DESC');
    return rows.map(PropertyRecord.fromJson).toList();
  }

  @override
  Future<List<InspectionRecord>> loadInspections() async {
    final rows = await _db.query('inspections', orderBy: 'createdAt DESC');
    return rows.map(InspectionRecord.fromJson).toList();
  }

  @override
  Future<List<RoomRecord>> loadRooms(String inspectionId) async {
    final rows = await _db.query(
      'rooms',
      where: 'inspectionId = ?',
      whereArgs: [inspectionId],
      orderBy: 'sortOrder ASC',
    );
    return rows.map(RoomRecord.fromJson).toList();
  }

  @override
  Future<List<EvidenceItemRecord>> loadEvidence(String inspectionId) async {
    final rows = await _db.query(
      'evidence',
      where: 'inspectionId = ?',
      whereArgs: [inspectionId],
      orderBy: 'capturedAt DESC',
    );
    return rows.map(EvidenceItemRecord.fromJson).toList();
  }

  @override
  Future<List<SignatureRecord>> loadSignatures(String inspectionId) async {
    final rows = await _db.query(
      'signatures',
      where: 'inspectionId = ?',
      whereArgs: [inspectionId],
      orderBy: 'signedAt ASC',
    );
    return rows.map(SignatureRecord.fromJson).toList();
  }

  @override
  Future<void> saveProperty(PropertyRecord property) {
    return _db.insert(
      'properties',
      property.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveInspection(InspectionRecord inspection) {
    return _db.insert(
      'inspections',
      inspection.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveRoom(RoomRecord room) {
    return _db.insert(
      'rooms',
      room.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveEvidence(EvidenceItemRecord evidence) {
    return _db.insert(
      'evidence',
      evidence.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveSignature(SignatureRecord signature) {
    return _db.insert(
      'signatures',
      signature.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
