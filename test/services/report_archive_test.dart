import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:unittrace/src/services/report_archive.dart';

void main() {
  test('scans exported report manifests newest first', () async {
    final temp = await Directory.systemTemp.createTemp('unittrace_reports_');
    addTearDown(() => temp.delete(recursive: true));

    await _writeReportPair(
      temp,
      baseName: 'older',
      reportId: 'UT-older',
      propertyName: 'Older Apt',
      inspectionTypeKey: 'move_in',
      generatedAt: DateTime.utc(2026, 5, 1),
      manifestHash: 'a' * 64,
    );
    await _writeReportPair(
      temp,
      baseName: 'newer',
      reportId: 'UT-newer',
      propertyName: 'Newer Apt',
      inspectionTypeKey: 'move_out',
      generatedAt: DateTime.utc(2026, 5, 2),
      manifestHash: 'b' * 64,
    );
    await File(p.join(temp.path, 'orphan.pdf')).writeAsBytes([37, 80, 68, 70]);

    final reports = await ReportArchive().scanDirectory(temp);

    expect(reports.map((report) => report.reportId), ['UT-newer', 'UT-older']);
    expect(reports.first.propertyName, 'Newer Apt');
    expect(reports.first.pdfFile.path, endsWith('newer.pdf'));
    expect(reports.first.inspectionTypeKey, 'move_out');
    expect(reports.first.manifestHash, 'b' * 64);
    expect(reports.first.evidenceCount, 3);
    expect(reports.first.photoCount, 2);
  });
}

Future<void> _writeReportPair(
  Directory directory, {
  required String baseName,
  required String reportId,
  required String propertyName,
  required String inspectionTypeKey,
  required DateTime generatedAt,
  required String manifestHash,
}) async {
  await File(
    p.join(directory.path, '$baseName.pdf'),
  ).writeAsBytes([37, 80, 68, 70]);
  await File(p.join(directory.path, '$baseName.json')).writeAsString(
    jsonEncode({
      'reportId': reportId,
      'inspectionType': inspectionTypeKey,
      'property': {'name': propertyName},
      'inspection': {'type': inspectionTypeKey},
      'generatedAt': generatedAt.toIso8601String(),
      'manifestHash': manifestHash,
      'evidenceCount': 3,
      'photoCount': 2,
    }),
  );
}
