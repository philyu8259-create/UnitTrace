import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
    final bytes = await _buildPdf(
      manifest: manifest,
      strings: strings,
      watermarked: watermarked,
    );
    final directory = await getApplicationDocumentsDirectory();
    final reportDirectory = Directory(p.join(directory.path, 'reports'));
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

  Future<Uint8List> _buildPdf({
    required ReportManifest manifest,
    required AppStrings strings,
    required bool watermarked,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final coverData = await rootBundle.load('assets/images/report_cover.png');
    final cover = pw.MemoryImage(coverData.buffer.asUint8List());
    final baseFont = await PdfGoogleFonts.notoSansSCRegular();
    final boldFont = await PdfGoogleFonts.notoSansSCBold();
    final pdfTheme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(32),
          theme: pdfTheme,
        ),
        footer: (context) => pw.Text(
          '${strings.appTitle} | ${manifest.reportId} | ${manifest.manifestHash.substring(0, 12)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      strings.trustedOffline,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      manifest.property.name,
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                    pw.Text(
                      manifest.property.address,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Image(cover, width: 130),
            ],
          ),
          pw.SizedBox(height: 20),
          _infoTable([
            ['Report ID', manifest.reportId],
            ['Inspection type', manifest.inspection.type.storageKey],
            ['Generated at', dateFormat.format(manifest.generatedAt.toLocal())],
            ['Photo count', manifest.photoCount.toString()],
            ['Manifest hash', manifest.manifestHash],
          ]),
          pw.SizedBox(height: 18),
          pw.Text(
            strings.evidence,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
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
                pw.Text(
                  room.name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                ...items.map((item) => _evidenceBlock(item, dateFormat)),
                pw.SizedBox(height: 12),
              ],
            );
          }),
          pw.SizedBox(height: 12),
          pw.Text(
            strings.signatures,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...manifest.signatures.map(
            (signature) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                '${signature.signerRole}: ${signature.signerName} | ${dateFormat.format(signature.signedAt.toLocal())}',
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            strings.disclaimer,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (watermarked)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Generated with UnitTrace Free',
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

  pw.Widget _evidenceBlock(EvidenceItemRecord item, DateFormat dateFormat) {
    pw.Widget? image;
    if (item.photoPath != null && File(item.photoPath!).existsSync()) {
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
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.description.isEmpty ? '(No note)' : item.description,
                ),
                pw.Text(
                  'Severity: ${item.severity.storageKey}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Captured: ${dateFormat.format(item.capturedAt.toLocal())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                if (item.latitude != null && item.longitude != null)
                  pw.Text(
                    'Location: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
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
                    item.exifSummary!,
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
