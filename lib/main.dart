import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'src/data/sqlite_unittrace_store.dart';
import 'src/data/unittrace_store.dart';
import 'src/domain/entities.dart';
import 'src/domain/room_templates.dart';
import 'src/l10n/app_strings.dart';
import 'src/services/hash_service.dart';
import 'src/services/report_exporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SqliteUnitTraceStore.open();
  runApp(UnitTraceApp(store: store));
}

class UnitTraceApp extends StatelessWidget {
  const UnitTraceApp({super.key, required this.store, this.initialLocale});

  final UnitTraceStore store;
  final Locale? initialLocale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnitTrace',
      locale: initialLocale,
      supportedLocales: const [Locale('en'), Locale('zh', 'Hans')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F5C5C),
          primary: const Color(0xFF0F5C5C),
          secondary: const Color(0xFFD89A2B),
          surface: const Color(0xFFFFFCF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFCF7),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE4E0D8)),
          ),
        ),
      ),
      home: UnitTraceHome(store: store),
    );
  }
}

class UnitTraceHome extends StatefulWidget {
  const UnitTraceHome({super.key, required this.store});

  final UnitTraceStore store;

  @override
  State<UnitTraceHome> createState() => _UnitTraceHomeState();
}

class _UnitTraceHomeState extends State<UnitTraceHome> {
  final _uuid = const Uuid();
  List<PropertyRecord> _properties = [];
  List<InspectionRecord> _inspections = [];
  PropertyRecord? _selectedProperty;
  InspectionRecord? _selectedInspection;
  bool _loading = true;

  AppStrings get strings => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final properties = await widget.store.loadProperties();
    final inspections = await widget.store.loadInspections();
    if (!mounted) return;
    setState(() {
      _properties = properties;
      _inspections = inspections;
      _selectedProperty ??= properties.firstOrNull;
      _selectedInspection ??= inspections
          .where((inspection) => inspection.propertyId == _selectedProperty?.id)
          .firstOrNull;
      _loading = false;
    });
  }

  Future<void> _createProperty() async {
    final property = await showDialog<PropertyRecord>(
      context: context,
      builder: (context) => _PropertyDialog(strings: strings, uuid: _uuid),
    );
    if (property == null) return;
    await widget.store.saveProperty(property);
    setState(() {
      _selectedProperty = property;
      _selectedInspection = null;
    });
    await _reload();
  }

  Future<void> _startInspection(InspectionType type) async {
    final property = _selectedProperty;
    if (property == null) return;
    final inspection = InspectionRecord(
      id: _uuid.v4(),
      propertyId: property.id,
      type: type,
      languageCode: strings.languageCode,
      createdAt: DateTime.now().toUtc(),
    );
    await widget.store.saveInspection(inspection);
    for (final entry in RoomTemplates.defaultRooms.indexed) {
      await widget.store.saveRoom(
        RoomRecord(
          id: _uuid.v4(),
          inspectionId: inspection.id,
          name: entry.$2,
          sortOrder: entry.$1,
        ),
      );
    }
    setState(() => _selectedInspection = inspection);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.createProperty,
            onPressed: _createProperty,
            icon: const Icon(Icons.add_home_work_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final sidebar = _DashboardSidebar(
              strings: strings,
              properties: _properties,
              selectedProperty: _selectedProperty,
              inspections: _inspections,
              selectedInspection: _selectedInspection,
              onCreateProperty: _createProperty,
              onSelectProperty: (property) => setState(() {
                _selectedProperty = property;
                _selectedInspection = _inspections
                    .where((inspection) => inspection.propertyId == property.id)
                    .firstOrNull;
              }),
              onSelectInspection: (inspection) =>
                  setState(() => _selectedInspection = inspection),
              onStartInspection: _startInspection,
            );
            final content =
                _selectedProperty == null || _selectedInspection == null
                ? _EmptyDashboard(
                    strings: strings,
                    onCreateProperty: _createProperty,
                  )
                : InspectionWorkspace(
                    key: ValueKey(_selectedInspection!.id),
                    store: widget.store,
                    property: _selectedProperty!,
                    inspection: _selectedInspection!,
                    strings: strings,
                  );
            if (!wide) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [sidebar, const SizedBox(height: 16), content],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 330,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: sidebar,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: content,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.strings,
    required this.properties,
    required this.selectedProperty,
    required this.inspections,
    required this.selectedInspection,
    required this.onCreateProperty,
    required this.onSelectProperty,
    required this.onSelectInspection,
    required this.onStartInspection,
  });

  final AppStrings strings;
  final List<PropertyRecord> properties;
  final PropertyRecord? selectedProperty;
  final List<InspectionRecord> inspections;
  final InspectionRecord? selectedInspection;
  final VoidCallback onCreateProperty;
  final ValueChanged<PropertyRecord> onSelectProperty;
  final ValueChanged<InspectionRecord> onSelectInspection;
  final ValueChanged<InspectionType> onStartInspection;

  @override
  Widget build(BuildContext context) {
    final propertyInspections = inspections
        .where((item) => item.propertyId == selectedProperty?.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.appSubtitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(strings.freePlan, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onCreateProperty,
          icon: const Icon(Icons.add),
          label: Text(strings.createProperty),
        ),
        const SizedBox(height: 16),
        ...properties.map(
          (property) => Card(
            color: property.id == selectedProperty?.id
                ? const Color(0xFFE6F1EF)
                : null,
            child: ListTile(
              leading: const Icon(Icons.apartment),
              title: Text(property.name),
              subtitle: Text(property.address),
              onTap: () => onSelectProperty(property),
            ),
          ),
        ),
        if (selectedProperty != null) ...[
          const SizedBox(height: 16),
          Text(
            strings.startInspection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<InspectionType>(
            segments: [
              ButtonSegment(
                value: InspectionType.moveIn,
                label: Text(strings.moveIn),
                icon: const Icon(Icons.login),
              ),
              ButtonSegment(
                value: InspectionType.moveOut,
                label: Text(strings.moveOut),
                icon: const Icon(Icons.logout),
              ),
              ButtonSegment(
                value: InspectionType.general,
                label: Text(strings.generalInspection),
                icon: const Icon(Icons.fact_check_outlined),
              ),
            ],
            selected: const {},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onStartInspection(selection.first);
            },
          ),
          const SizedBox(height: 12),
          ...propertyInspections.map(
            (inspection) => ListTile(
              leading: const Icon(Icons.description_outlined),
              selected: inspection.id == selectedInspection?.id,
              title: Text(_typeLabel(strings, inspection.type)),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(inspection.createdAt.toLocal()),
              ),
              onTap: () => onSelectInspection(inspection),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({
    required this.strings,
    required this.onCreateProperty,
  });

  final AppStrings strings;
  final VoidCallback onCreateProperty;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/empty_dashboard.png',
                height: 230,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.trustedOffline,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(strings.noProperties, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateProperty,
              icon: const Icon(Icons.add_home_work_outlined),
              label: Text(strings.createProperty),
            ),
          ],
        ),
      ),
    );
  }
}

class InspectionWorkspace extends StatefulWidget {
  const InspectionWorkspace({
    super.key,
    required this.store,
    required this.property,
    required this.inspection,
    required this.strings,
  });

  final UnitTraceStore store;
  final PropertyRecord property;
  final InspectionRecord inspection;
  final AppStrings strings;

  @override
  State<InspectionWorkspace> createState() => _InspectionWorkspaceState();
}

class _InspectionWorkspaceState extends State<InspectionWorkspace> {
  final _uuid = const Uuid();
  final _picker = ImagePicker();
  List<RoomRecord> _rooms = [];
  List<EvidenceItemRecord> _evidence = [];
  List<SignatureRecord> _signatures = [];
  RoomRecord? _selectedRoom;
  ReportExportResult? _lastReport;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rooms = await widget.store.loadRooms(widget.inspection.id);
    final evidence = await widget.store.loadEvidence(widget.inspection.id);
    final signatures = await widget.store.loadSignatures(widget.inspection.id);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _evidence = evidence;
      _signatures = signatures;
      _selectedRoom ??= rooms.firstOrNull;
      _busy = false;
    });
  }

  Future<void> _addEvidence({required ImageSource? source}) async {
    final room = _selectedRoom;
    if (room == null) return;
    final result = await showModalBottomSheet<_EvidenceDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EvidenceSheet(strings: widget.strings),
    );
    if (result == null) return;

    String? photoPath;
    String? photoHash;
    String? exifSummary;
    if (source != null) {
      final image = await _picker.pickImage(source: source, imageQuality: 88);
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final evidenceDirectory = Directory(p.join(directory.path, 'evidence'));
        await evidenceDirectory.create(recursive: true);
        photoPath = p.join(
          evidenceDirectory.path,
          '${_uuid.v4()}${p.extension(image.path)}',
        );
        await File(image.path).copy(photoPath);
        photoHash = await HashService.sha256ForFile(File(photoPath));
        exifSummary = 'Source: ${source.name}; File: ${p.basename(photoPath)}';
      }
    }

    Position? position;
    try {
      position = await _currentPosition();
    } catch (_) {
      position = null;
    }

    final evidence = EvidenceItemRecord(
      id: _uuid.v4(),
      inspectionId: widget.inspection.id,
      roomId: room.id,
      description: result.description,
      severity: result.severity,
      capturedAt: DateTime.now().toUtc(),
      photoPath: photoPath,
      photoHash: photoHash,
      latitude: position?.latitude,
      longitude: position?.longitude,
      exifSummary: exifSummary,
    );
    await widget.store.saveEvidence(evidence);
    await _load();
  }

  Future<void> _addSignature() async {
    final signature = await showDialog<SignatureRecord>(
      context: context,
      builder: (context) => _SignatureDialog(
        strings: widget.strings,
        uuid: _uuid,
        inspectionId: widget.inspection.id,
      ),
    );
    if (signature == null) return;
    await widget.store.saveSignature(signature);
    await _load();
  }

  Future<void> _exportReport() async {
    setState(() => _busy = true);
    try {
      final result = await ReportExporter().export(
        property: widget.property,
        inspection: widget.inspection,
        rooms: _rooms,
        evidenceItems: _evidence,
        signatures: _signatures,
        strings: widget.strings,
        watermarked: true,
      );
      await Printing.sharePdf(
        bytes: await result.pdfFile.readAsBytes(),
        filename: p.basename(result.pdfFile.path),
      );
      if (!mounted) return;
      setState(() => _lastReport = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.strings.reportReady)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final roomEvidence = _evidence
        .where((item) => item.roomId == _selectedRoom?.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${_typeLabel(widget.strings, widget.inspection.type)} | ${widget.property.address}',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _exportReport,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(widget.strings.generateReport),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _rooms
              .map(
                (room) => ChoiceChip(
                  label: Text(room.name),
                  selected: room.id == _selectedRoom?.id,
                  onSelected: (_) => setState(() => _selectedRoom = room),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.strings.evidence,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton.filledTonal(
              tooltip: widget.strings.takePhoto,
              onPressed: () => _addEvidence(source: ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: widget.strings.choosePhoto,
              onPressed: () => _addEvidence(source: ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: widget.strings.addEvidence,
              onPressed: () => _addEvidence(source: null),
              icon: const Icon(Icons.note_add_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (roomEvidence.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(widget.strings.addEvidence),
            ),
          )
        else
          ...roomEvidence.map(
            (item) => _EvidenceCard(item: item, strings: widget.strings),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.strings.signatures,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _addSignature,
              icon: const Icon(Icons.draw_outlined),
              label: Text(widget.strings.addSignature),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._signatures.map(
          (signature) => ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(signature.signerName),
            subtitle: Text(signature.signerRole),
          ),
        ),
        if (_lastReport != null)
          Card(
            color: const Color(0xFFE6F1EF),
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(widget.strings.reportReady),
              subtitle: Text(_lastReport!.pdfFile.path),
            ),
          ),
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item, required this.strings});

  final EvidenceItemRecord item;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.photoPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(item.photoPath!),
                  width: 96,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 96,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1EF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.note_alt_outlined),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description.isEmpty ? strings.note : item.description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_severityLabel(strings, item.severity)} | ${item.capturedAt.toLocal()}',
                  ),
                  if (item.photoHash != null)
                    Text(
                      'SHA-256 ${item.photoHash!.substring(0, 12)}...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (item.latitude != null && item.longitude != null)
                    Text(
                      '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyDialog extends StatefulWidget {
  const _PropertyDialog({required this.strings, required this.uuid});

  final AppStrings strings;
  final Uuid uuid;

  @override
  State<_PropertyDialog> createState() => _PropertyDialogState();
}

class _PropertyDialogState extends State<_PropertyDialog> {
  final _name = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.strings.createProperty),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('property-name-field'),
            controller: _name,
            decoration: InputDecoration(labelText: widget.strings.propertyName),
          ),
          TextField(
            key: const Key('property-address-field'),
            controller: _address,
            decoration: InputDecoration(labelText: widget.strings.address),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              PropertyRecord(
                id: widget.uuid.v4(),
                name: _name.text.trim(),
                address: _address.text.trim(),
                createdAt: DateTime.now().toUtc(),
              ),
            );
          },
          child: Text(widget.strings.saveProperty),
        ),
      ],
    );
  }
}

class _EvidenceDraft {
  const _EvidenceDraft({required this.description, required this.severity});

  final String description;
  final EvidenceSeverity severity;
}

class _EvidenceSheet extends StatefulWidget {
  const _EvidenceSheet({required this.strings});

  final AppStrings strings;

  @override
  State<_EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends State<_EvidenceSheet> {
  final _description = TextEditingController();
  EvidenceSeverity _severity = EvidenceSeverity.note;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.strings.addEvidence,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: widget.strings.description,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<EvidenceSeverity>(
            segments: EvidenceSeverity.values
                .map(
                  (severity) => ButtonSegment(
                    value: severity,
                    label: Text(_severityLabel(widget.strings, severity)),
                  ),
                )
                .toList(),
            selected: {_severity},
            onSelectionChanged: (selection) =>
                setState(() => _severity = selection.first),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _EvidenceDraft(
                description: _description.text.trim(),
                severity: _severity,
              ),
            ),
            child: Text(widget.strings.saveNote),
          ),
        ],
      ),
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({
    required this.strings,
    required this.uuid,
    required this.inspectionId,
  });

  final AppStrings strings;
  final Uuid uuid;
  final String inspectionId;

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final _name = TextEditingController();
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  String _role = 'Tenant';

  @override
  void dispose() {
    _name.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    Uint8List? bytes;
    if (_controller.isNotEmpty) {
      bytes = await _controller.toPngBytes();
    }
    String? signaturePath;
    String? signatureHash;
    if (bytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final signatureDirectory = Directory(
        p.join(directory.path, 'signatures'),
      );
      await signatureDirectory.create(recursive: true);
      signaturePath = p.join(
        signatureDirectory.path,
        '${widget.uuid.v4()}.png',
      );
      await File(signaturePath).writeAsBytes(bytes, flush: true);
      signatureHash = HashService.sha256ForBytes(bytes);
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      SignatureRecord(
        id: widget.uuid.v4(),
        inspectionId: widget.inspectionId,
        signerRole: _role,
        signerName: _name.text.trim().isEmpty ? _role : _name.text.trim(),
        signedAt: DateTime.now().toUtc(),
        signaturePath: signaturePath,
        signatureHash: signatureHash,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.strings.addSignature),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'Tenant',
                  label: Text(widget.strings.tenant),
                ),
                ButtonSegment(
                  value: 'Landlord',
                  label: Text(widget.strings.landlord),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (selection) =>
                  setState(() => _role = selection.first),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: widget.strings.signerName),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE4E0D8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _controller.clear,
          child: Text(widget.strings.clear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.strings.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.strings.saveSignature),
        ),
      ],
    );
  }
}

Future<Position?> _currentPosition() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );
}

String _typeLabel(AppStrings strings, InspectionType type) {
  return switch (type) {
    InspectionType.moveIn => strings.moveIn,
    InspectionType.moveOut => strings.moveOut,
    InspectionType.general => strings.generalInspection,
  };
}

String _severityLabel(AppStrings strings, EvidenceSeverity severity) {
  return switch (severity) {
    EvidenceSeverity.good => strings.good,
    EvidenceSeverity.note => strings.note,
    EvidenceSeverity.issue => strings.issue,
    EvidenceSeverity.urgent => strings.urgent,
  };
}
