import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities.dart';
import '../domain/report_manifest.dart';
import '../l10n/app_strings.dart';

class ReportExportResult {
  const ReportExportResult({
    required this.pdfFile,
    required this.manifestFile,
    required this.manifest,
  });

  final File pdfFile;
  final File manifestFile;
  final ReportManifest manifest;
}

class ReportExporter {
  Future<ReportExportResult> export({
    required PropertyRecord property,
    required InspectionRecord inspection,
    required List<RoomRecord> rooms,
    required List<EvidenceItemRecord> evidenceItems,
    required List<SignatureRecord> signatures,
    required AppStrings strings,
    required bool watermarked,
  }) async {
    final generatedAt = DateTime.now().toUtc();
    final manifest = ReportManifestBuilder().build(
      property: property,
      inspection: inspection,
      rooms: rooms,
      evidenceItems: evidenceItems,
      signatures: signatures,
      generatedAt: generatedAt,
      appVersion: '1.0.0',
      deviceLabel: Platform.operatingSystem,
    );
    final bytes = await buildPdfBytes(
      manifest: manifest,
      strings: strings,
      watermarked: watermarked,
    );
    final reportDirectory = await reportsDirectory();
    await reportDirectory.create(recursive: true);
    final baseName =
        '${manifest.reportId}-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
    final pdfFile = File(p.join(reportDirectory.path, '$baseName.pdf'));
    final manifestFile = File(p.join(reportDirectory.path, '$baseName.json'));
    await pdfFile.writeAsBytes(bytes, flush: true);
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
      flush: true,
    );
    return ReportExportResult(
      pdfFile: pdfFile,
      manifestFile: manifestFile,
      manifest: manifest,
    );
  }

  static Future<Directory> reportsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory(p.join(directory.path, 'reports'));
  }

  Future<Uint8List> buildPdfBytes({
    required ReportManifest manifest,
    required AppStrings strings,
    required bool watermarked,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final coverData = await rootBundle.load('assets/images/report_cover.png');
    final cover = pw.MemoryImage(coverData.buffer.asUint8List());
    final baseFontData = await rootBundle.load(
      'assets/fonts/NotoSansSC-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSansSC-Bold.ttf',
    );
    final baseFont = pw.Font.ttf(baseFontData);
    final boldFont = pw.Font.ttf(boldFontData);
    final pdfTheme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final labels = _ReportPdfLabels(strings);
    final generatedAt = dateFormat.format(manifest.generatedAt.toLocal());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(32),
          theme: pdfTheme,
        ),
        footer: (context) => pw.Text(
          '${strings.appTitle} | ${manifest.reportId} | ${labels.pageLabel(context.pageNumber, context.pagesCount)} | ${manifest.manifestHash.substring(0, 12)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        build: (context) => [
          _coverHeader(
            cover: cover,
            title: labels.reportTitle,
            subtitle: strings.trustedOffline,
            property: manifest.property,
            generatedAt: generatedAt,
            labels: labels,
          ),
          pw.SizedBox(height: 14),
          _summaryGrid(
            labels: labels,
            evidenceCount: manifest.evidenceCount,
            photoCount: manifest.photoCount,
            signatureCount: manifest.signatures.length,
          ),
          pw.SizedBox(height: 16),
          _sectionTitle(labels.reportDetails),
          pw.SizedBox(height: 6),
          _infoTable([
            [labels.reportId, manifest.reportId],
            [
              labels.inspectionType,
              labels.inspectionTypeName(manifest.inspection.type),
            ],
            [labels.generatedAt, generatedAt],
            [labels.propertyName, manifest.property.name],
            [labels.address, manifest.property.address],
            [labels.device, manifest.deviceLabel],
            [labels.appVersion, manifest.appVersion],
            [labels.manifestHash, manifest.manifestHash],
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle(strings.evidence),
          pw.SizedBox(height: 8),
          if (manifest.evidenceItems.isEmpty)
            _emptyBlock(labels.noEvidence)
          else
            ...manifest.rooms.map((room) {
              final items = manifest.evidenceItems
                  .where((item) => item.roomId == room.id)
                  .toList();
              if (items.isEmpty) {
                return pw.SizedBox.shrink();
              }
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE7F0EC),
                    ),
                    child: pw.Text(
                      '${room.name} - ${items.length} ${labels.items}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...items.map(
                    (item) => _evidenceBlock(item, dateFormat, labels),
                  ),
                  pw.SizedBox(height: 12),
                ],
              );
            }),
          pw.SizedBox(height: 8),
          _sectionTitle(strings.signatures),
          pw.SizedBox(height: 8),
          if (manifest.signatures.isEmpty)
            _emptyBlock(labels.noSignatures)
          else
            ...manifest.signatures.map(
              (signature) => _signatureBlock(signature, dateFormat, labels),
            ),
          pw.SizedBox(height: 14),
          _sectionTitle(labels.disclaimerTitle),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Text(
              strings.disclaimer,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          if (watermarked)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 18),
              child: pw.Text(
                labels.freeWatermark,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey500,
                ),
              ),
            ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _coverHeader({
    required pw.ImageProvider cover,
    required String title,
    required String subtitle,
    required PropertyRecord property,
    required String generatedAt,
    required _ReportPdfLabels labels,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFBF7EF),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  property.name,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  property.address,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '${labels.generatedAt}: $generatedAt',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Image(cover, width: 118),
        ],
      ),
    );
  }

  pw.Widget _summaryGrid({
    required _ReportPdfLabels labels,
    required int evidenceCount,
    required int photoCount,
    required int signatureCount,
  }) {
    return pw.Row(
      children: [
        _summaryCell(labels.evidenceCount, evidenceCount.toString()),
        pw.SizedBox(width: 8),
        _summaryCell(labels.photoCount, photoCount.toString()),
        pw.SizedBox(width: 8),
        _summaryCell(labels.signatureCount, signatureCount.toString()),
      ],
    );
  }

  pw.Widget _summaryCell(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _emptyBlock(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _signatureBlock(
    SignatureRecord signature,
    DateFormat dateFormat,
    _ReportPdfLabels labels,
  ) {
    pw.Widget? signatureImage;
    if (signature.signaturePath != null) {
      final signatureFile = File(signature.signaturePath!);
      if (signatureFile.existsSync()) {
        try {
          final bytes = signatureFile.readAsBytesSync();
          if (bytes.isNotEmpty) {
            signatureImage = pw.Container(
              height: 54,
              alignment: pw.Alignment.centerLeft,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Image(
                pw.MemoryImage(bytes),
                height: 50,
                fit: pw.BoxFit.contain,
              ),
            );
          }
        } on Object {
          signatureImage = null;
        }
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${labels.signatureRole(signature.signerRole)}: ${signature.signerName} | ${labels.signedAt}: ${dateFormat.format(signature.signedAt.toLocal())}',
          ),
          ?signatureImage,
          if (signature.signatureHash != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                'Signature SHA-256: ${signature.signatureHash}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _evidenceBlock(
    EvidenceItemRecord item,
    DateFormat dateFormat,
    _ReportPdfLabels labels,
  ) {
    pw.Widget? image;
    final photoMissing =
        item.photoPath != null && !File(item.photoPath!).existsSync();
    if (item.photoPath != null && !photoMissing) {
      final bytes = File(item.photoPath!).readAsBytesSync();
      image = pw.Image(
        pw.MemoryImage(bytes),
        width: 120,
        height: 90,
        fit: pw.BoxFit.cover,
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (image != null) ...[image, pw.SizedBox(width: 10)],
          if (image == null && item.photoPath != null) ...[
            pw.Container(
              width: 120,
              height: 90,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                labels.photoFileMissing,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.description.isEmpty ? labels.noNote : item.description,
                ),
                pw.Text(
                  '${labels.severity}: ${labels.severityName(item.severity)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  '${labels.capturedAt}: ${dateFormat.format(item.capturedAt.toLocal())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                if (item.latitude != null && item.longitude != null)
                  pw.Text(
                    '${labels.location}: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                if (item.photoHash != null)
                  pw.Text(
                    'SHA-256: ${item.photoHash}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                if (item.exifSummary != null)
                  pw.Text(
                    labels.exifSummary(item.exifSummary!),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _infoTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {0: pw.FixedColumnWidth(90), 1: pw.FlexColumnWidth()},
      children: rows
          .map(
            (row) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    row[1],
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _ReportPdfLabels {
  const _ReportPdfLabels(this.strings);

  final AppStrings strings;

  bool get isChinese => strings.isChinese;

  String get reportTitle => isChinese ? '房况证据报告' : 'Property Evidence Report';
  String get reportDetails => isChinese ? '报告详情' : 'Report details';
  String get reportId => isChinese ? '报告 ID' : 'Report ID';
  String get inspectionType => isChinese ? '检查类型' : 'Inspection type';
  String get generatedAt => isChinese ? '生成时间' : 'Generated at';
  String get propertyName => isChinese ? '房屋名称' : 'Property name';
  String get address => isChinese ? '地址' : 'Address';
  String get device => isChinese ? '设备' : 'Device';
  String get appVersion => isChinese ? 'App 版本' : 'App version';
  String get manifestHash => isChinese ? 'Manifest 哈希' : 'Manifest hash';
  String get evidenceCount => isChinese ? '证据数量' : 'Evidence items';
  String get photoCount => isChinese ? '照片数量' : 'Photos';
  String get signatureCount => isChinese ? '签名数量' : 'Signatures';
  String get items => isChinese ? '项' : 'items';
  String get noEvidence =>
      isChinese ? '本报告没有证据记录。' : 'No evidence items in this report.';
  String get noSignatures =>
      isChinese ? '本报告没有签名记录。' : 'No signatures in this report.';
  String get disclaimerTitle => isChinese ? '免责声明' : 'Disclaimer';
  String get freeWatermark =>
      isChinese ? '由 UnitTrace 内测版生成' : 'Generated with UnitTrace Beta';
  String get noNote => isChinese ? '无备注' : '(No note)';
  String get severity => isChinese ? '严重程度' : 'Severity';
  String get capturedAt => isChinese ? '采集时间' : 'Captured';
  String get signedAt => isChinese ? '签署时间' : 'Signed at';
  String get location => isChinese ? '位置' : 'Location';
  String get photoFileMissing => isChinese ? '照片文件缺失' : 'Photo file missing';

  String pageLabel(int pageNumber, int pageCount) {
    return isChinese
        ? '第 $pageNumber / $pageCount 页'
        : 'Page $pageNumber / $pageCount';
  }

  String exifSummary(String summary) {
    if (!isChinese) return summary;
    return summary.replaceAll('Source:', '来源：').replaceAll('File:', '文件：');
  }

  String inspectionTypeName(InspectionType type) {
    return switch (type) {
      InspectionType.moveIn => strings.moveIn,
      InspectionType.moveOut => strings.moveOut,
      InspectionType.general => strings.generalInspection,
    };
  }

  String severityName(EvidenceSeverity severity) {
    return switch (severity) {
      EvidenceSeverity.good => strings.good,
      EvidenceSeverity.note => strings.note,
      EvidenceSeverity.issue => strings.issue,
      EvidenceSeverity.urgent => strings.urgent,
    };
  }

  String signatureRole(String role) {
    if (role == 'Tenant') return strings.tenant;
    if (role == 'Landlord') return strings.landlord;
    return role;
  }
}
