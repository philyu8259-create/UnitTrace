import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ReportArchiveEntry {
  const ReportArchiveEntry({
    required this.reportId,
    required this.propertyName,
    required this.inspectionTypeKey,
    required this.generatedAt,
    required this.manifestHash,
    required this.evidenceCount,
    required this.photoCount,
    required this.pdfFile,
    required this.manifestFile,
  });

  final String reportId;
  final String propertyName;
  final String inspectionTypeKey;
  final DateTime generatedAt;
  final String manifestHash;
  final int evidenceCount;
  final int photoCount;
  final File pdfFile;
  final File manifestFile;
}

class ReportArchive {
  Future<List<ReportArchiveEntry>> scanDirectory(
    Directory reportDirectory,
  ) async {
    if (!await reportDirectory.exists()) {
      return const [];
    }
    final manifests = await reportDirectory
        .list()
        .where(
          (entity) => entity is File && p.extension(entity.path) == '.json',
        )
        .cast<File>()
        .toList();
    final entries = <ReportArchiveEntry>[];
    for (final manifestFile in manifests) {
      final baseName = p.basenameWithoutExtension(manifestFile.path);
      final pdfFile = File(p.join(reportDirectory.path, '$baseName.pdf'));
      if (!await pdfFile.exists()) {
        continue;
      }
      try {
        final json =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, Object?>;
        final propertyJson =
            json['property'] as Map<String, Object?>? ?? const {};
        final inspectionJson =
            json['inspection'] as Map<String, Object?>? ?? const {};
        entries.add(
          ReportArchiveEntry(
            reportId: json['reportId'] as String? ?? baseName,
            propertyName:
                propertyJson['name'] as String? ?? 'Untitled property',
            inspectionTypeKey:
                json['inspectionType'] as String? ??
                inspectionJson['type'] as String? ??
                'general',
            generatedAt:
                DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
                await manifestFile.lastModified(),
            manifestHash: json['manifestHash'] as String? ?? '',
            evidenceCount:
                (json['evidenceCount'] as num?)?.toInt() ??
                (json['evidenceItems'] as List<Object?>?)?.length ??
                (json['photoCount'] as num?)?.toInt() ??
                0,
            photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
            pdfFile: pdfFile,
            manifestFile: manifestFile,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    entries.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return entries;
  }
}
