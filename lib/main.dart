import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'src/data/sqlite_unittrace_store.dart';
import 'src/data/unittrace_store.dart';
import 'src/domain/entities.dart';
import 'src/domain/inspection_progress.dart';
import 'src/domain/room_templates.dart';
import 'src/l10n/app_strings.dart';
import 'src/services/app_directories.dart';
import 'src/services/hash_service.dart';
import 'src/services/pro_entitlement.dart';
import 'src/services/report_archive.dart';
import 'src/services/report_exporter.dart';
import 'src/theme/app_colors.dart';
import 'src/theme/unittrace_theme.dart';

const _mutedInk = Color(0xFF65706C);
const _deepEmerald = Color(0xFF0D3F3A);
const _mist = Color(0xFFE7F0EC);
const _warmSurface = Color(0xFFFFFCF7);
const _line = Color(0xFFE4E0D8);
const _brass = Color(0xFFD49A36);
const _danger = Color(0xFF9D3D2F);
const _appIconAsset = 'assets/app_icon/unittrace_icon_source.png';
Uri _privacyPolicyUriFor(AppStrings strings) => Uri.parse(
  strings.isChinese
      ? 'https://philyu8259-create.github.io/UnitTrace/privacy-policy-zh.html'
      : 'https://philyu8259-create.github.io/UnitTrace/privacy-policy-en.html',
);

Uri _supportUriFor(AppStrings strings) => Uri.parse(
  strings.isChinese
      ? 'https://philyu8259-create.github.io/UnitTrace/support-zh.html'
      : 'https://philyu8259-create.github.io/UnitTrace/support-en.html',
);

final Uri _standardEulaUri = Uri.parse(
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SqliteUnitTraceStore.open();
  runApp(UnitTraceApp(store: store));
}

Future<Directory> _safeApplicationDocumentsDirectory() async {
  return AppDirectories.documents();
}

abstract class UnitTraceImagePicker {
  Future<XFile?> pickImage({required ImageSource source, int? imageQuality});

  Future<List<XFile>> pickMultiImage({int? imageQuality});
}

typedef UnitTraceSignatureExporter =
    Future<Uint8List?> Function(SignatureController controller);

Future<Uint8List?> _defaultSignatureExporter(SignatureController controller) {
  return controller.toPngBytes(width: 800, height: 440);
}

class DefaultUnitTraceImagePicker implements UnitTraceImagePicker {
  DefaultUnitTraceImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<XFile?> pickImage({required ImageSource source, int? imageQuality}) {
    return _picker.pickImage(source: source, imageQuality: imageQuality);
  }

  @override
  Future<List<XFile>> pickMultiImage({int? imageQuality}) {
    return _picker.pickMultiImage(imageQuality: imageQuality);
  }
}

class UnitTraceApp extends StatelessWidget {
  const UnitTraceApp({
    super.key,
    required this.store,
    this.initialLocale,
    this.captureLocation = true,
    this.imagePicker,
    this.signatureExporter = _defaultSignatureExporter,
    this.proController,
  });

  final UnitTraceStore store;
  final Locale? initialLocale;
  final bool captureLocation;
  final UnitTraceImagePicker? imagePicker;
  final UnitTraceSignatureExporter signatureExporter;
  final ProEntitlementController? proController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnitTrace',
      locale: initialLocale,
      supportedLocales: const [Locale('en'), Locale('zh', 'Hans')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: UnitTraceTheme.build(),
      home: UnitTraceHome(
        store: store,
        captureLocation: captureLocation,
        imagePicker: imagePicker ?? DefaultUnitTraceImagePicker(),
        signatureExporter: signatureExporter,
        proController: proController ?? ProEntitlementController.local(),
      ),
    );
  }
}

class UnitTraceHome extends StatefulWidget {
  const UnitTraceHome({
    super.key,
    required this.store,
    required this.captureLocation,
    required this.imagePicker,
    required this.signatureExporter,
    required this.proController,
  });

  final UnitTraceStore store;
  final bool captureLocation;
  final UnitTraceImagePicker imagePicker;
  final UnitTraceSignatureExporter signatureExporter;
  final ProEntitlementController proController;

  @override
  State<UnitTraceHome> createState() => _UnitTraceHomeState();
}

class _UnitTraceHomeState extends State<UnitTraceHome> {
  final _uuid = const Uuid();
  List<PropertyRecord> _properties = [];
  List<InspectionRecord> _inspections = [];
  Map<String, List<RoomRecord>> _roomsByInspection = {};
  Map<String, List<EvidenceItemRecord>> _evidenceByInspection = {};
  Map<String, List<SignatureRecord>> _signaturesByInspection = {};
  Set<String> _exportedInspectionIds = {};
  PropertyRecord? _selectedProperty;
  InspectionRecord? _selectedInspection;
  int _mobileTabIndex = 0;
  bool _loading = true;

  AppStrings get strings => AppStrings.of(context);
  ProEntitlementState get proState => widget.proController.state;

  @override
  void initState() {
    super.initState();
    widget.proController.addListener(_onProChanged);
    _initializePro();
    _reload();
  }

  @override
  void dispose() {
    widget.proController.removeListener(_onProChanged);
    super.dispose();
  }

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializePro() async {
    await widget.proController.load();
    await widget.proController.beginLocalTrialIfAvailable();
  }

  Future<void> _reload() async {
    final properties = await widget.store.loadProperties();
    final inspections = await widget.store.loadInspections();
    final roomsByInspection = <String, List<RoomRecord>>{};
    final evidenceByInspection = <String, List<EvidenceItemRecord>>{};
    final signaturesByInspection = <String, List<SignatureRecord>>{};
    for (final inspection in inspections) {
      roomsByInspection[inspection.id] = await widget.store.loadRooms(
        inspection.id,
      );
      evidenceByInspection[inspection.id] = await widget.store.loadEvidence(
        inspection.id,
      );
      signaturesByInspection[inspection.id] = await widget.store.loadSignatures(
        inspection.id,
      );
    }
    if (!mounted) return;
    setState(() {
      _properties = properties;
      _inspections = inspections;
      _roomsByInspection = roomsByInspection;
      _evidenceByInspection = evidenceByInspection;
      _signaturesByInspection = signaturesByInspection;
      if (!properties.any((item) => item.id == _selectedProperty?.id)) {
        _selectedProperty = properties.firstOrNull;
      }
      final selectedInspectionStillValid = inspections.any(
        (item) =>
            item.id == _selectedInspection?.id &&
            item.propertyId == _selectedProperty?.id,
      );
      if (!selectedInspectionStillValid) {
        _selectedInspection = _selectedProperty == null
            ? null
            : _latestInspectionFrom(inspections, _selectedProperty!.id);
      }
      _loading = false;
    });
    _refreshExportedInspectionIds();
  }

  Future<void> _refreshExportedInspectionIds() async {
    try {
      final directory = await ReportExporter.reportsDirectory();
      final reports = await ReportArchive().scanDirectory(directory);
      final exportedInspectionIds = reports
          .map((report) => report.inspectionId)
          .where((id) => id.isNotEmpty)
          .toSet();
      if (!mounted) return;
      setState(() => _exportedInspectionIds = exportedInspectionIds);
    } catch (_) {
      if (!mounted) return;
      setState(() => _exportedInspectionIds = <String>{});
    }
  }

  Future<void> _createProperty() async {
    if (!await _requireProAccess()) return;
    if (!mounted) return;
    final property = await showDialog<PropertyRecord>(
      context: context,
      builder: (context) => _PropertyDialog(strings: strings, uuid: _uuid),
    );
    if (property == null) return;
    await widget.store.saveProperty(property);
    setState(() {
      _selectedProperty = property;
      _selectedInspection = null;
      _mobileTabIndex = 0;
    });
    await _reload();
  }

  Future<void> _startInspection(InspectionType type) async {
    if (!await _requireProAccess()) return;
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
    for (final entry in RoomTemplates.forLanguageCode(
      strings.languageCode,
    ).indexed) {
      await widget.store.saveRoom(
        RoomRecord(
          id: _uuid.v4(),
          inspectionId: inspection.id,
          name: entry.$2,
          sortOrder: entry.$1,
        ),
      );
    }
    setState(() {
      _selectedInspection = inspection;
      _mobileTabIndex = 0;
    });
    await _reload();
    await _openInspectionDetail(property: property, inspection: inspection);
  }

  Future<void> _openInspectionDetail({
    required PropertyRecord property,
    required InspectionRecord inspection,
  }) async {
    if (!mounted) return;
    setState(() {
      _selectedProperty = property;
      _selectedInspection = inspection;
      _mobileTabIndex = 0;
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => InspectionDetailPage(
          store: widget.store,
          property: property,
          inspection: inspection,
          captureLocation: widget.captureLocation,
          imagePicker: widget.imagePicker,
          signatureExporter: widget.signatureExporter,
          proController: widget.proController,
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<bool> _requireProAccess() async {
    if (proState.canStartTrial) {
      await widget.proController.beginLocalTrialIfAvailable();
    }
    if (!mounted) return false;
    if (proState.isProActive) return true;
    await _showProPaywall(
      context: context,
      strings: strings,
      controller: widget.proController,
      reasonTitle: strings.proReadOnlyTitle,
      reasonMessage: strings.proReadOnlyMessage,
    );
    return widget.proController.state.isProActive;
  }

  Future<void> _openReportHistory() async {
    if (MediaQuery.sizeOf(context).width < 760) {
      setState(() => _mobileTabIndex = 1);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportHistorySheet(strings: strings),
    );
  }

  Future<void> _deleteProperty(PropertyRecord property) async {
    final confirmed = await _confirmDestructiveAction(
      context: context,
      strings: strings,
      title: strings.deleteProperty,
      message: strings.deletePropertyMessage,
    );
    if (!confirmed) return;
    await widget.store.deleteProperty(property.id);
    if (!mounted) return;
    setState(() {
      if (_selectedProperty?.id == property.id) {
        _selectedProperty = null;
        _selectedInspection = null;
      }
    });
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.propertyDeleted)));
  }

  Future<void> _deleteInspection(InspectionRecord inspection) async {
    final confirmed = await _confirmDestructiveAction(
      context: context,
      strings: strings,
      title: strings.deleteInspection,
      message: strings.deleteInspectionMessage,
    );
    if (!confirmed) return;
    await widget.store.deleteInspection(inspection.id);
    if (!mounted) return;
    setState(() {
      if (_selectedInspection?.id == inspection.id) {
        _selectedInspection = null;
      }
    });
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.inspectionDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: _LoadingSkeletonPanel(),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: _AppBrandTitle(title: strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.createProperty,
            onPressed: _createProperty,
            icon: const Icon(Icons.add_home_work_outlined),
          ),
          IconButton(
            tooltip: strings.reportHistory,
            onPressed: _openReportHistory,
            icon: const Icon(Icons.folder_copy_outlined),
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
              roomsByInspection: _roomsByInspection,
              evidenceByInspection: _evidenceByInspection,
              signaturesByInspection: _signaturesByInspection,
              exportedInspectionIds: _exportedInspectionIds,
              onCreateProperty: _createProperty,
              onOpenReportHistory: _openReportHistory,
              onSelectProperty: (property) => setState(() {
                _selectedProperty = property;
                _selectedInspection = _latestInspectionForProperty(property.id);
                _mobileTabIndex = 0;
              }),
              onSelectInspection: (inspection) {
                final property = _properties
                    .where((item) => item.id == inspection.propertyId)
                    .firstOrNull;
                if (property == null) return;
                _openInspectionDetail(
                  property: property,
                  inspection: inspection,
                );
              },
              onStartInspection: _startInspection,
              onDeleteProperty: _deleteProperty,
              onDeleteInspection: _deleteInspection,
            );
            final content = _selectedProperty == null
                ? _EmptyDashboard(
                    strings: strings,
                    onCreateProperty: _createProperty,
                  )
                : _NoInspectionPanel(
                    strings: strings,
                    property: _selectedProperty!,
                  );
            if (!wide) {
              final tabBody = switch (_mobileTabIndex) {
                0 => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
                  children: [
                    sidebar,
                    if (_selectedProperty == null) ...[
                      const SizedBox(height: 16),
                      content,
                    ],
                  ],
                ),
                1 => _ReportHistoryPanel(
                  strings: strings,
                  showClose: false,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
                  onOpenInspection: () => setState(() => _mobileTabIndex = 0),
                ),
                _ => _MorePanel(
                  strings: strings,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
                  proController: widget.proController,
                ),
              };
              return tabBody;
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 4,
                        bottom: 4,
                        right: 12,
                      ),
                      child: sidebar,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 8,
                        bottom: 4,
                        right: 0,
                      ),
                      child: content,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 760
          ? null
          : _FloatingMobileTabs(
              strings: strings,
              index: _mobileTabIndex,
              onChanged: (index) => setState(() => _mobileTabIndex = index),
            ),
    );
  }

  InspectionRecord? _latestInspectionForProperty(String propertyId) {
    return _latestInspectionFrom(_inspections, propertyId);
  }
}

InspectionRecord? _latestInspectionFrom(
  List<InspectionRecord> inspections,
  String propertyId,
) {
  final sorted =
      inspections
          .where((inspection) => inspection.propertyId == propertyId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.firstOrNull;
}

class _AppBrandTitle extends StatelessWidget {
  const _AppBrandTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppBrandMark(size: 32, radius: 9),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _AppBrandMark extends StatelessWidget {
  const _AppBrandMark({this.size = 28, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10172321),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(_appIconAsset, fit: BoxFit.cover),
    );
  }
}

class _FloatingMobileTabs extends StatelessWidget {
  const _FloatingMobileTabs({
    required this.strings,
    required this.index,
    required this.onChanged,
  });

  final AppStrings strings;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.hairline),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0D3F3A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onChanged,
              height: 60,
              backgroundColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              indicatorColor: _mist,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.apartment_outlined),
                  selectedIcon: const Icon(Icons.apartment),
                  label: strings.propertiesTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.folder_copy_outlined),
                  selectedIcon: const Icon(Icons.folder_copy),
                  label: strings.reportsTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz),
                  selectedIcon: const Icon(Icons.more),
                  label: strings.moreTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeletonPanel extends StatelessWidget {
  const _LoadingSkeletonPanel({this.lines = 5});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: _PremiumSurface(
        backgroundColor: _warmSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBar(widthFactor: 0.56),
            const SizedBox(height: 14),
            _SkeletonBar(widthFactor: 0.88),
            const SizedBox(height: 10),
            const Row(
              children: [
                _SkeletonBar(width: 18, height: 18),
                SizedBox(width: 8),
                _SkeletonBar(width: 110, height: 12),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < lines; i++) ...[
              _SkeletonBar(
                widthFactor: i.isEven ? 0.95 : (i % 3 == 1 ? 0.74 : 0.84),
                height: 12 + (i % 2 == 0 ? 1.0 : 0.0),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({this.width, this.widthFactor, this.height = 14})
    : assert(width == null || width > 0),
      assert(widthFactor == null || (widthFactor > 0 && widthFactor <= 1));

  final double? width;
  final double? widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1EA),
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return width == null && widthFactor != null
        ? FractionallySizedBox(widthFactor: widthFactor, child: bar)
        : bar;
  }
}

class _PremiumSurface extends StatelessWidget {
  const _PremiumSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = _warmSurface,
    this.borderColor = _line,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.9), backgroundColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          gradient: const LinearGradient(
            colors: [Colors.white54, Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.2],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.asset,
    this.height = 168,
    this.fillWidth = true,
  });

  final String asset;
  final double height;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        asset,
        height: height,
        width: fillWidth ? double.infinity : null,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({
    required this.icon,
    required this.label,
    this.verified = false,
    this.uppercase = false,
  });

  final IconData icon;
  final String label;
  final bool verified;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: verified ? AppColors.brassSoft : AppColors.estateGreenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: verified ? AppColors.brass : AppColors.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: verified ? AppColors.brass : AppColors.estateGreen,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              uppercase
                  ? label.toUpperCase()
                  : (verified ? label.toUpperCase() : label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: verified ? AppColors.brass : AppColors.estateGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ...(subtitle == null
                  ? const <Widget>[]
                  : [
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]),
            ],
          ),
        ),
        ...(trailing == null ? const <Widget>[] : [trailing!]),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF8F7F2)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D3F3A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _deepEmerald, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final List<_GuideStepData> steps;

  @override
  Widget build(BuildContext context) {
    return _PremiumSurface(
      padding: const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 12),
          ...steps.indexed.map((entry) {
            final index = entry.$1;
            final step = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _mist,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(step.icon, color: _deepEmerald, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.body,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GuideStepData {
  const _GuideStepData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.strings,
    required this.properties,
    required this.selectedProperty,
    required this.inspections,
    required this.selectedInspection,
    required this.roomsByInspection,
    required this.evidenceByInspection,
    required this.signaturesByInspection,
    required this.exportedInspectionIds,
    required this.onCreateProperty,
    required this.onSelectProperty,
    required this.onSelectInspection,
    required this.onStartInspection,
    required this.onOpenReportHistory,
    required this.onDeleteProperty,
    required this.onDeleteInspection,
  });

  final AppStrings strings;
  final List<PropertyRecord> properties;
  final PropertyRecord? selectedProperty;
  final List<InspectionRecord> inspections;
  final InspectionRecord? selectedInspection;
  final Map<String, List<RoomRecord>> roomsByInspection;
  final Map<String, List<EvidenceItemRecord>> evidenceByInspection;
  final Map<String, List<SignatureRecord>> signaturesByInspection;
  final Set<String> exportedInspectionIds;
  final VoidCallback onCreateProperty;
  final ValueChanged<PropertyRecord> onSelectProperty;
  final ValueChanged<InspectionRecord> onSelectInspection;
  final ValueChanged<InspectionType> onStartInspection;
  final VoidCallback onOpenReportHistory;
  final ValueChanged<PropertyRecord> onDeleteProperty;
  final ValueChanged<InspectionRecord> onDeleteInspection;

  @override
  Widget build(BuildContext context) {
    final propertyInspections =
        inspections
            .where((item) => item.propertyId == selectedProperty?.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final selectedSummary = selectedInspection == null
        ? null
        : InspectionProgressSummary.build(
            inspection: selectedInspection!,
            rooms: roomsByInspection[selectedInspection!.id] ?? const [],
            evidenceItems:
                evidenceByInspection[selectedInspection!.id] ?? const [],
            signatures:
                signaturesByInspection[selectedInspection!.id] ?? const [],
          );
    final deskReady = selectedSummary?.canExport ?? false;
    final deskBadge = deskReady ? strings.verified : strings.localOnly;
    final Widget? primaryAction = selectedInspection == null
        ? selectedProperty == null
              ? FilledButton.icon(
                  onPressed: onCreateProperty,
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: Text(strings.createProperty),
                )
              : null
        : FilledButton.icon(
            onPressed: () => onSelectInspection(selectedInspection!),
            icon: const Icon(Icons.play_arrow_outlined),
            label: Text(strings.continueInspection),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PremiumSurface(
          backgroundColor: AppColors.estateGreenSoft,
          borderColor: AppColors.hairline,
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      strings.brandKicker,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.graphite,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  _TrustPill(
                    icon: deskReady
                        ? Icons.verified_outlined
                        : Icons.cloud_off_outlined,
                    label: deskBadge,
                    verified: deskReady,
                    uppercase: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                strings.localEvidenceVault,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                strings.evidenceDeskTagline,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                strings.evidenceDeskTraits,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricBadge(
                      value: '${properties.length}',
                      label: strings.propertiesMetric,
                      icon: Icons.apartment,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricBadge(
                      value: '${inspections.length}',
                      label: strings.inspectionsMetric,
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricBadge(
                      value: '${exportedInspectionIds.length}',
                      label: strings.generatedReports,
                      icon: Icons.picture_as_pdf_outlined,
                    ),
                  ),
                ],
              ),
              if (primaryAction != null) ...[
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: primaryAction),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: strings.propertiesTab,
          subtitle: strings.activeProperty,
          trailing: IconButton.outlined(
            tooltip: strings.createProperty,
            onPressed: onCreateProperty,
            icon: const Icon(Icons.add_home_work_outlined),
          ),
        ),
        const SizedBox(height: 8),
        ...properties.map(
          (property) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PropertyDashboardCard(
              strings: strings,
              property: property,
              selected: property.id == selectedProperty?.id,
              latestInspection: _latestInspectionForProperty(property.id),
              latestSummary: _latestSummaryForProperty(property.id),
              reportGenerated: exportedInspectionIds.contains(
                _latestInspectionForProperty(property.id)?.id,
              ),
              onTap: () => onSelectProperty(property),
              onDelete: () => onDeleteProperty(property),
            ),
          ),
        ),
        if (selectedProperty != null) ...[
          const SizedBox(height: 10),
          _SectionHeader(
            title: strings.startInspection,
            subtitle: strings.homeFlowSubtitle,
          ),
          const SizedBox(height: 8),
          _InspectionTypeCard(
            icon: Icons.login,
            title: strings.moveIn,
            body: strings.moveInCardBody,
            onTap: () => onStartInspection(InspectionType.moveIn),
            emphasized: propertyInspections.isEmpty,
          ),
          const SizedBox(height: 8),
          _InspectionTypeCard(
            icon: Icons.logout,
            title: strings.moveOut,
            body: strings.moveOutCardBody,
            onTap: () => onStartInspection(InspectionType.moveOut),
          ),
          const SizedBox(height: 8),
          _InspectionTypeCard(
            icon: Icons.fact_check_outlined,
            title: strings.generalInspection,
            body: strings.generalCardBody,
            onTap: () => onStartInspection(InspectionType.general),
          ),
          if (propertyInspections.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionHeader(
              title: strings.recentInspection,
              subtitle: strings.inspectionProgress,
              trailing: IconButton.outlined(
                tooltip: strings.reportHistory,
                onPressed: onOpenReportHistory,
                icon: const Icon(Icons.folder_copy_outlined),
              ),
            ),
            const SizedBox(height: 8),
            ...propertyInspections.map(
              (inspection) => _InspectionDashboardTile(
                strings: strings,
                inspection: inspection,
                selected: inspection.id == selectedInspection?.id,
                summary: InspectionProgressSummary.build(
                  inspection: inspection,
                  rooms: roomsByInspection[inspection.id] ?? const [],
                  evidenceItems:
                      evidenceByInspection[inspection.id] ?? const [],
                  signatures: signaturesByInspection[inspection.id] ?? const [],
                ),
                reportGenerated: exportedInspectionIds.contains(inspection.id),
                onTap: () => onSelectInspection(inspection),
                onDelete: () => onDeleteInspection(inspection),
              ),
            ),
          ],
        ],
      ],
    );
  }

  InspectionRecord? _latestInspectionForProperty(String propertyId) {
    final sorted =
        inspections
            .where((inspection) => inspection.propertyId == propertyId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.firstOrNull;
  }

  InspectionProgressSummary? _latestSummaryForProperty(String propertyId) {
    final latest = _latestInspectionForProperty(propertyId);
    if (latest == null) return null;
    return InspectionProgressSummary.build(
      inspection: latest,
      rooms: roomsByInspection[latest.id] ?? const [],
      evidenceItems: evidenceByInspection[latest.id] ?? const [],
      signatures: signaturesByInspection[latest.id] ?? const [],
    );
  }
}

class _PropertyDashboardCard extends StatelessWidget {
  const _PropertyDashboardCard({
    required this.strings,
    required this.property,
    required this.selected,
    required this.latestInspection,
    required this.latestSummary,
    required this.reportGenerated,
    required this.onTap,
    required this.onDelete,
  });

  final AppStrings strings;
  final PropertyRecord property;
  final bool selected;
  final InspectionRecord? latestInspection;
  final InspectionProgressSummary? latestSummary;
  final bool reportGenerated;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasInspection = latestInspection != null;
    final exportReady = latestSummary?.canExport ?? false;
    final latestType = !hasInspection
        ? strings.noRecentInspection
        : _typeLabel(strings, latestInspection!.type);
    final evidenceCount = latestSummary?.evidenceCount ?? 0;
    final signatureCount = latestSummary?.signatureCount ?? 0;
    final exportStatus = !hasInspection
        ? null
        : reportGenerated
        ? strings.reportReady
        : exportReady
        ? strings.readyToExport
        : strings.needsSignature;
    final signatureStatus = !hasInspection
        ? null
        : signatureCount > 0
        ? strings.signatures
        : strings.needSignatureLabel;
    final progress = latestSummary?.completionRatio ?? 0.0;
    final caseId = latestInspection == null
        ? '--'
        : _caseIdForInspection(latestInspection!);
    return _PremiumSurface(
      padding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      borderColor: selected ? const Color(0xFFB8D0C7) : AppColors.hairline,
      radius: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.estateGreenSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.estateGreenSoft),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: AppColors.estateGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        property.address.isEmpty
                            ? strings.address
                            : property.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (selected)
                            _StatusPill(
                              label: strings.activeProperty,
                              emphasized: true,
                            ),
                          _StatusPill(label: latestType),
                          _StatusPill(
                            label: '${strings.evidence} $evidenceCount',
                            emphasized: evidenceCount > 0,
                          ),
                          if (signatureStatus != null)
                            _StatusPill(
                              label: signatureStatus,
                              emphasized: signatureCount > 0,
                            ),
                          if (exportStatus != null)
                            _StatusPill(
                              label: exportStatus,
                              emphasized: exportReady || reportGenerated,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${strings.caseIdLabel}: $caseId',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: AppColors.paper,
                        color: exportReady ? AppColors.success : _line,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${strings.progressLabel}: ${(progress * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  children: [
                    IconButton(
                      tooltip: strings.deleteProperty,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    if (selected)
                      const Icon(
                        Icons.radio_button_checked,
                        color: AppColors.success,
                        size: 16,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectionTypeCard extends StatelessWidget {
  const _InspectionTypeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return _PremiumSurface(
      padding: EdgeInsets.zero,
      backgroundColor: emphasized ? _mist : Colors.white,
      borderColor: emphasized ? const Color(0xFFC9DCD5) : _line,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: emphasized ? _deepEmerald : _mist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: emphasized ? Colors.white : _deepEmerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(body, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _mutedInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectionDashboardTile extends StatelessWidget {
  const _InspectionDashboardTile({
    required this.strings,
    required this.inspection,
    required this.summary,
    required this.reportGenerated,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final AppStrings strings;
  final InspectionRecord inspection;
  final InspectionProgressSummary summary;
  final bool reportGenerated;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(inspection.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _PremiumSurface(
        padding: EdgeInsets.zero,
        backgroundColor: selected ? _mist : Colors.white,
        borderColor: selected ? const Color(0xFFC9DCD5) : _line,
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.description_outlined),
          title: Text(_typeLabel(strings, inspection.type)),
          subtitle: Text(
            '$date | ${summary.evidenceCount} ${strings.evidence} | ${summary.signatureCount} ${strings.signatures}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusPill(
                label: reportGenerated
                    ? strings.reportReady
                    : summary.canExport
                    ? strings.readyToExport
                    : strings.inProgress,
                emphasized: summary.canExport || reportGenerated,
              ),
              IconButton(
                tooltip: strings.deleteInspection,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized ? _deepEmerald : AppColors.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized ? _deepEmerald : const Color(0xFFD5E1DC),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: emphasized ? Colors.white : _deepEmerald,
          fontWeight: FontWeight.w800,
        ),
      ),
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
        child: _PremiumSurface(
          padding: const EdgeInsets.all(18),
          backgroundColor: const Color(0xFFF8F2E8),
          child: Column(
            children: [
              const _HeroImage(
                asset: 'assets/images/workbench_hero.png',
                height: 250,
              ),
              const SizedBox(height: 18),
              Text(
                strings.noProperties,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _SectionHeader(
                title: strings.createProperty,
                subtitle: strings.noActiveInspectionSubtitle(''),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoInspectionPanel extends StatelessWidget {
  const _NoInspectionPanel({required this.strings, required this.property});

  final AppStrings strings;
  final PropertyRecord property;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: _PremiumSurface(
          padding: const EdgeInsets.all(18),
          backgroundColor: const Color(0xFFF8F2E8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeroImage(
                asset: 'assets/images/evidence_capture.png',
                height: 190,
              ),
              const SizedBox(height: 18),
              Text(
                strings.homeInspectionGuideTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                strings.homeInspectionGuideSubtitle(property.name),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TrustPill(
                    icon: Icons.photo_camera_outlined,
                    label: strings.evidence,
                  ),
                  _TrustPill(
                    icon: Icons.draw_outlined,
                    label: strings.signatures,
                  ),
                  _TrustPill(
                    icon: Icons.picture_as_pdf_outlined,
                    label: strings.pdfEvidence,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InspectionDetailPage extends StatelessWidget {
  const InspectionDetailPage({
    super.key,
    required this.store,
    required this.property,
    required this.inspection,
    required this.captureLocation,
    required this.imagePicker,
    required this.signatureExporter,
    required this.proController,
  });

  final UnitTraceStore store;
  final PropertyRecord property;
  final InspectionRecord inspection;
  final bool captureLocation;
  final UnitTraceImagePicker imagePicker;
  final UnitTraceSignatureExporter signatureExporter;
  final ProEntitlementController proController;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.backToHome,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home_outlined),
        ),
        title: Text(
          '${_typeLabel(strings, inspection.type)} · ${property.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: strings.deleteInspection,
            onPressed: () async {
              final confirmed = await _confirmDestructiveAction(
                context: context,
                strings: strings,
                title: strings.deleteInspection,
                message: strings.deleteInspectionMessage,
              );
              if (!confirmed || !context.mounted) return;
              await store.deleteInspection(inspection.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: InspectionWorkspace(
            key: ValueKey(inspection.id),
            store: store,
            property: property,
            inspection: inspection,
            strings: strings,
            captureLocation: captureLocation,
            imagePicker: imagePicker,
            signatureExporter: signatureExporter,
            proController: proController,
          ),
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
    required this.captureLocation,
    required this.imagePicker,
    required this.signatureExporter,
    required this.proController,
  });

  final UnitTraceStore store;
  final PropertyRecord property;
  final InspectionRecord inspection;
  final AppStrings strings;
  final bool captureLocation;
  final UnitTraceImagePicker imagePicker;
  final UnitTraceSignatureExporter signatureExporter;
  final ProEntitlementController proController;

  @override
  State<InspectionWorkspace> createState() => _InspectionWorkspaceState();
}

class _InspectionWorkspaceState extends State<InspectionWorkspace> {
  final _uuid = const Uuid();
  List<RoomRecord> _rooms = [];
  List<EvidenceItemRecord> _evidence = [];
  List<SignatureRecord> _signatures = [];
  RoomRecord? _selectedRoom;
  ReportExportResult? _lastReport;
  String? _documentsPath;
  bool _busy = true;
  bool _locationExplained = false;
  ProEntitlementState get _proState => widget.proController.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final documentsDirectory = await _safeApplicationDocumentsDirectory();
    final rooms = await widget.store.loadRooms(widget.inspection.id);
    final evidence = await widget.store.loadEvidence(widget.inspection.id);
    final signatures = await widget.store.loadSignatures(widget.inspection.id);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _evidence = evidence;
      _signatures = signatures;
      _documentsPath = documentsDirectory.path;
      _selectedRoom ??= rooms.firstOrNull;
      _busy = false;
    });
  }

  File? _resolveEvidencePhotoFile(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return null;
    final directFile = File(photoPath);
    if (directFile.existsSync()) return directFile;
    final documentsPath = _documentsPath;
    if (documentsPath == null) return directFile;
    final candidate = p.isAbsolute(photoPath)
        ? File(p.join(documentsPath, 'evidence', p.basename(photoPath)))
        : File(p.join(documentsPath, photoPath));
    return candidate.existsSync() ? candidate : directFile;
  }

  Future<void> _addEvidence({required ImageSource? source}) async {
    if (!await _requireProAccess()) return;
    final room = _selectedRoom;
    if (room == null) return;
    var pickedPhotos = const <_PickedEvidencePhoto>[];
    if (source != null) {
      final proceed = await _showPermissionExplanation(
        source == ImageSource.camera
            ? _PermissionExplainTarget.camera
            : _PermissionExplainTarget.gallery,
      );
      if (!proceed) return;
      pickedPhotos = await _pickEvidencePhotos(source);
      if (pickedPhotos.isEmpty) {
        return;
      }
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<_EvidenceDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EvidenceSheet(
        strings: widget.strings,
        photos: pickedPhotos,
        source: source,
      ),
    );
    if (result == null) return;

    Position? position;
    if (widget.captureLocation) {
      try {
        if (!_locationExplained) {
          _locationExplained = true;
          final proceed = await _showPermissionExplanation(
            _PermissionExplainTarget.location,
          );
          if (!proceed) return;
        }
        position = await _currentPosition().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      } catch (_) {
        position = null;
      }
    }

    final capturedAt = DateTime.now().toUtc();
    final List<_PickedEvidencePhoto?> photosToSave = pickedPhotos.isEmpty
        ? const <_PickedEvidencePhoto?>[null]
        : pickedPhotos;
    for (final photo in photosToSave) {
      final evidence = EvidenceItemRecord(
        id: _uuid.v4(),
        inspectionId: widget.inspection.id,
        roomId: room.id,
        description: result.description,
        severity: result.severity,
        capturedAt: capturedAt,
        photoPath: photo?.storedPhotoPath,
        photoHash: photo?.photoHash,
        latitude: position?.latitude,
        longitude: position?.longitude,
        exifSummary: photo?.exifSummary,
      );
      await widget.store.saveEvidence(evidence);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.strings.evidenceSaved(photosToSave.length)),
      ),
    );
  }

  Future<bool> _showPermissionExplanation(
    _PermissionExplainTarget target,
  ) async {
    final (title, body, icon) = switch (target) {
      _PermissionExplainTarget.camera => (
        widget.strings.cameraPermissionTitle,
        widget.strings.cameraPermissionBody,
        Icons.photo_camera_outlined,
      ),
      _PermissionExplainTarget.gallery => (
        widget.strings.galleryPermissionTitle,
        widget.strings.galleryPermissionBody,
        Icons.photo_library_outlined,
      ),
      _PermissionExplainTarget.location => (
        widget.strings.locationPermissionTitle,
        widget.strings.locationPermissionBody,
        Icons.location_on_outlined,
      ),
    };
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmptyActionPanel(
                icon: icon,
                title: title,
                subtitle: body,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(widget.strings.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(widget.strings.continueAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<List<_PickedEvidencePhoto>> _pickEvidencePhotos(
    ImageSource source,
  ) async {
    try {
      final List<XFile> images;
      if (source == ImageSource.gallery) {
        images = await widget.imagePicker.pickMultiImage(imageQuality: 88);
      } else {
        final image = await widget.imagePicker.pickImage(
          source: source,
          imageQuality: 88,
        );
        images = image == null ? const [] : [image];
      }
      if (images.isEmpty) {
        if (source == ImageSource.camera && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.strings.noPhotoCaptured)),
          );
        }
        return const [];
      }

      final directory = await _safeApplicationDocumentsDirectory();
      final evidenceDirectory = Directory(p.join(directory.path, 'evidence'));
      await evidenceDirectory.create(recursive: true);
      final photos = <_PickedEvidencePhoto>[];
      for (final image in images) {
        final extension = p.extension(image.path).isEmpty
            ? '.jpg'
            : p.extension(image.path);
        final fileName = '${_uuid.v4()}$extension';
        final photoPath = p.join(evidenceDirectory.path, fileName);
        final storedPhotoPath = p.join('evidence', fileName);
        await File(image.path).copy(photoPath);
        final photoHash = await HashService.sha256ForFile(File(photoPath));
        photos.add(
          _PickedEvidencePhoto(
            photoPath: photoPath,
            storedPhotoPath: storedPhotoPath,
            photoHash: photoHash,
            exifSummary:
                'Source: ${source.name}; File: ${p.basename(photoPath)}',
          ),
        );
      }
      return photos;
    } on PlatformException catch (error) {
      if (!mounted) return const [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.photoAccessFailed(error.message ?? error.code),
          ),
        ),
      );
      return const [];
    } on FileSystemException catch (error) {
      if (!mounted) return const [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.photoSaveFailed(error.message))),
      );
      return const [];
    }
  }

  Future<void> _addSignature() async {
    if (!await _requireProAccess()) return;
    if (!mounted) return;
    final signature = await showModalBottomSheet<SignatureRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _warmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _SignatureDialog(
        strings: widget.strings,
        uuid: _uuid,
        inspectionId: widget.inspection.id,
        signatureExporter: widget.signatureExporter,
      ),
    );
    if (signature == null) return;
    await widget.store.saveSignature(signature);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.strings.signatureSaved)));
  }

  Future<void> _deleteSignature(SignatureRecord signature) async {
    if (!await _requireProAccess()) return;
    if (!mounted) return;
    final confirmed = await _confirmDestructiveAction(
      context: context,
      strings: widget.strings,
      title: widget.strings.deleteSignature,
      message: widget.strings.deleteSignatureMessage,
    );
    if (!confirmed) return;
    await widget.store.deleteSignature(signature.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.strings.signatureDeleted)));
  }

  Future<void> _deleteEvidence(EvidenceItemRecord evidence) async {
    if (!await _requireProAccess()) return;
    if (!mounted) return;
    final confirmed = await _confirmDestructiveAction(
      context: context,
      strings: widget.strings,
      title: widget.strings.deleteEvidence,
      message: widget.strings.deleteEvidenceMessage,
    );
    if (!confirmed) return;
    await widget.store.deleteEvidence(evidence.id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.strings.evidenceDeleted)));
  }

  String _roomName(RoomRecord room) {
    return RoomTemplates.displayName(room.name, widget.strings.languageCode);
  }

  Future<void> _exportReport() async {
    if (!await _requireProAccess()) return;
    setState(() => _busy = true);
    try {
      final result = await ReportExporter().export(
        property: widget.property,
        inspection: widget.inspection,
        rooms: _rooms,
        evidenceItems: _evidence,
        signatures: _signatures,
        strings: widget.strings,
        watermarked: _proState.shouldWatermarkPdf,
      );
      await Printing.sharePdf(
        bytes: await result.pdfFile.readAsBytes(),
        filename: p.basename(result.pdfFile.path),
      );
      if (!mounted) return;
      setState(() => _lastReport = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.strings.reportShareReady)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _requireProAccess() async {
    if (_proState.canStartTrial) {
      await widget.proController.beginLocalTrialIfAvailable();
    }
    if (!mounted) return false;
    if (_proState.isProActive) return true;
    await _showProPaywall(
      context: context,
      strings: widget.strings,
      controller: widget.proController,
      reasonTitle: widget.strings.proReadOnlyTitle,
      reasonMessage: widget.strings.proReadOnlyMessage,
    );
    return widget.proController.state.isProActive;
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _LoadingSkeletonPanel(lines: 7),
      );
    }
    final roomEvidence = _evidence
        .where((item) => item.roomId == _selectedRoom?.id)
        .toList();
    final summary = InspectionProgressSummary.build(
      inspection: widget.inspection,
      rooms: _rooms,
      evidenceItems: _evidence,
      signatures: _signatures,
    );
    final roomStatuses = RoomChecklistStatus.build(
      rooms: _rooms,
      evidenceItems: _evidence,
    );
    final nextStepMessage = switch (summary.nextStepKind) {
      InspectionNextStep.addEvidence => widget.strings.nextStepEvidence,
      InspectionNextStep.addSignature => widget.strings.nextStepSignature,
      InspectionNextStep.exportReport => widget.strings.nextStepReport,
    };
    final readiness = (summary.completionRatio * 100).round();
    final integrityReady = summary.canExport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PremiumSurface(
          padding: const EdgeInsets.all(14),
          backgroundColor: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.strings.evidenceIntegrity} · ${widget.property.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _typeLabel(widget.strings, widget.inspection.type),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TrustPill(
                      icon: Icons.shield_outlined,
                      label: widget.strings.evidenceIntegrity,
                      verified: integrityReady,
                      uppercase: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TrustPill(
                    icon: integrityReady
                        ? Icons.verified_outlined
                        : Icons.hourglass_top_outlined,
                    label: integrityReady
                        ? '${widget.strings.ready} ${widget.strings.reportReady}'
                        : widget.strings.inProgress,
                    verified: integrityReady,
                    uppercase: false,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TrustPill(
                    icon: Icons.photo_library_outlined,
                    label:
                        '${widget.strings.photo}: ${widget.strings.photoMetric(summary.photoCount)}',
                    verified: summary.photoCount > 0,
                    uppercase: false,
                  ),
                  _TrustPill(
                    icon: Icons.fingerprint,
                    label:
                        '${widget.strings.hashStatus}: ${widget.strings.hashMetric(summary.hashCount)}',
                    verified: summary.hashCount > 0,
                    uppercase: false,
                  ),
                  _TrustPill(
                    icon: Icons.location_on_outlined,
                    label:
                        '${widget.strings.locationStatus}: ${widget.strings.locationMetric(summary.locationCount)}',
                    verified: summary.locationCount > 0,
                    uppercase: false,
                  ),
                  _TrustPill(
                    icon: Icons.draw_outlined,
                    label:
                        '${widget.strings.signatures}: ${summary.signatureCount} ${summary.signatureCount > 0 ? widget.strings.signatureReady : widget.strings.needsSignature}',
                    verified: summary.signatureCount > 0,
                    uppercase: false,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.strings.evidenceIntegrity} ${widget.strings.progressLabel}: $readiness%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: summary.completionRatio.clamp(0, 1),
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppColors.paper,
                color: _deepEmerald,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.checklist_rtl_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nextStepMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GuidePanel(
          title: widget.strings.inspectionGuideTitle,
          subtitle: widget.strings.inspectionGuideSubtitle,
          steps: [
            _GuideStepData(
              icon: Icons.meeting_room_outlined,
              title: widget.strings.rooms,
              body: widget.strings.stepInspectionBody,
            ),
            _GuideStepData(
              icon: Icons.photo_library_outlined,
              title: widget.strings.evidence,
              body: widget.strings.emptyEvidenceSubtitle,
            ),
            _GuideStepData(
              icon: Icons.picture_as_pdf_outlined,
              title: widget.strings.stepReport,
              body: widget.strings.stepReportBody,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: widget.strings.selectedRoomEvidence,
          subtitle: _selectedRoom == null
              ? widget.strings.hashReady
              : '${widget.strings.roomDetail}: ${_roomName(_selectedRoom!)}',
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton.filledTonal(
                tooltip: widget.strings.takePhoto,
                onPressed: () => _addEvidence(source: ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton.filledTonal(
                tooltip: widget.strings.choosePhoto,
                onPressed: () => _addEvidence(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
              ),
              if (roomEvidence.isNotEmpty)
                IconButton.filledTonal(
                  tooltip: widget.strings.addNote,
                  onPressed: () => _addEvidence(source: null),
                  icon: const Icon(Icons.note_add_outlined),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: roomStatuses
                .map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        '${_roomName(status.room)} · ${status.evidenceCount}',
                      ),
                      selected: status.room.id == _selectedRoom?.id,
                      onSelected: (_) =>
                          setState(() => _selectedRoom = status.room),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        if (roomEvidence.isEmpty)
          _EmptyActionPanel(
            icon: Icons.add_photo_alternate_outlined,
            title: widget.strings.emptyEvidenceTitle,
            subtitle: widget.strings.emptyEvidenceSubtitle,
            actions: [
              FilledButton.icon(
                onPressed: () => _addEvidence(source: null),
                icon: const Icon(Icons.note_add_outlined),
                label: Text(widget.strings.addNote),
              ),
            ],
          )
        else
          ...roomEvidence.map(
            (item) => _EvidenceCard(
              item: item,
              photoFile: _resolveEvidencePhotoFile(item.photoPath),
              strings: widget.strings,
              onDelete: () => _deleteEvidence(item),
            ),
          ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: widget.strings.signatures,
          subtitle: _signatures.isEmpty
              ? widget.strings.needsSignature
              : widget.strings.signatureReady,
          trailing: IconButton.filledTonal(
            tooltip: widget.strings.addSignature,
            onPressed: _addSignature,
            icon: const Icon(Icons.draw_outlined),
          ),
        ),
        const SizedBox(height: 10),
        if (_signatures.isEmpty)
          _EmptyActionPanel(
            icon: Icons.draw_outlined,
            title: widget.strings.emptySignatureTitle,
            subtitle: widget.strings.emptySignatureSubtitle,
            actions: [
              FilledButton.icon(
                onPressed: _addSignature,
                icon: const Icon(Icons.draw_outlined),
                label: Text(widget.strings.addSignature),
              ),
            ],
          )
        else
          ..._signatures.map(
            (signature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PremiumSurface(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(signature.signerName),
                  subtitle: Text(
                    _signatureRoleLabel(widget.strings, signature.signerRole),
                  ),
                  trailing: IconButton(
                    tooltip: widget.strings.deleteSignature,
                    onPressed: () => _deleteSignature(signature),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: widget.strings.finalReportTitle,
          subtitle: _evidence.isEmpty
              ? widget.strings.finalReportNeedsEvidence
              : _signatures.isEmpty
              ? widget.strings.needsSignature
              : widget.strings.finalReportSubtitle,
        ),
        const SizedBox(height: 10),
        _PremiumSurface(
          backgroundColor: summary.canExport ? _mist : _warmSurface,
          borderColor: summary.canExport ? const Color(0xFFC9DCD5) : _line,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: _deepEmerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_typeLabel(widget.strings, widget.inspection.type)} · ${widget.property.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: summary.canExport ? _exportReport : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(widget.strings.generateReport),
                ),
              ),
            ],
          ),
        ),
        if (_lastReport != null)
          _PremiumSurface(
            backgroundColor: _mist,
            borderColor: const Color(0xFFC9DCD5),
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: _deepEmerald,
              ),
              title: Text(widget.strings.reportReady),
              subtitle: Text(_lastReport!.pdfFile.path),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: widget.strings.viewReport,
                    onPressed: () => _openPdfPreview(
                      context,
                      widget.strings,
                      _lastReport!.pdfFile,
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  IconButton(
                    tooltip: widget.strings.shareReportAction,
                    onPressed: () => _sharePdf(_lastReport!.pdfFile),
                    icon: const Icon(Icons.ios_share_outlined),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: widget.strings.roomChecklist,
          subtitle: widget.strings.roomChecklistSubtitle,
        ),
        const SizedBox(height: 8),
        ...roomStatuses.map(
          (status) => _RoomChecklistCard(
            strings: widget.strings,
            roomName: _roomName(status.room),
            status: status,
            selected: status.room.id == _selectedRoom?.id,
            onTap: () => setState(() => _selectedRoom = status.room),
          ),
        ),
      ],
    );
  }
}

class _RoomChecklistCard extends StatelessWidget {
  const _RoomChecklistCard({
    required this.strings,
    required this.roomName,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final AppStrings strings;
  final String roomName;
  final RoomChecklistStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = status.isComplete
        ? strings.completed
        : status.evidenceCount == 0
        ? strings.notStarted
        : strings.inProgress;
    final evidenceRatio =
        (status.evidenceCount > 0 ? 0.33 : 0.0) +
        (status.hashReady ? 0.34 : 0.0) +
        (status.locationReady ? 0.33 : 0.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _PremiumSurface(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        borderColor: selected ? const Color(0xFFB8D0C7) : AppColors.hairline,
        radius: 16,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: status.isComplete
                        ? AppColors.success
                        : AppColors.estateGreenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    status.isComplete
                        ? Icons.check_circle_outline
                        : Icons.meeting_room_outlined,
                    color: status.isComplete
                        ? Colors.white
                        : AppColors.deepEmerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${status.evidenceCount} ${strings.evidence} · ${strings.photoCountLabel(status.photoCount)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: evidenceRatio.clamp(0, 1),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: AppColors.paper,
                        color: status.isComplete
                            ? AppColors.success
                            : selected
                            ? AppColors.deepEmerald
                            : _line,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatusPill(
                            label:
                                '${status.evidenceCount} ${strings.evidence}',
                          ),
                          _StatusPill(
                            label: '${status.issueCount} ${strings.issue}',
                          ),
                          _StatusPill(
                            label: strings.photoCountLabel(status.photoCount),
                          ),
                          _StatusPill(
                            label: status.hashReady
                                ? strings.hashCaptured
                                : strings.hashMissing,
                            emphasized: status.hashReady,
                          ),
                          _StatusPill(
                            label: status.locationReady
                                ? strings.locationCaptured
                                : strings.locationMissing,
                            emphasized: status.locationReady,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TrustPill(
                  icon: status.isComplete
                      ? Icons.verified_outlined
                      : Icons.pending_outlined,
                  label: stateLabel,
                  verified: status.isComplete,
                  uppercase: status.isComplete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PermissionExplainTarget { camera, gallery, location }

class _EmptyActionPanel extends StatelessWidget {
  const _EmptyActionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _PremiumSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _deepEmerald, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class _ReportHistorySheet extends StatefulWidget {
  const _ReportHistorySheet({required this.strings});

  final AppStrings strings;

  @override
  State<_ReportHistorySheet> createState() => _ReportHistorySheetState();
}

class _ReportHistorySheetState extends State<_ReportHistorySheet> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _ReportHistoryPanel(
            strings: widget.strings,
            scrollController: scrollController,
            showClose: true,
            padding: const EdgeInsets.all(20),
          );
        },
      ),
    );
  }
}

class _ReportHistoryPanel extends StatefulWidget {
  const _ReportHistoryPanel({
    required this.strings,
    required this.padding,
    this.scrollController,
    this.showClose = false,
    this.onOpenInspection,
  });

  final AppStrings strings;
  final EdgeInsetsGeometry padding;
  final ScrollController? scrollController;
  final bool showClose;
  final VoidCallback? onOpenInspection;

  @override
  State<_ReportHistoryPanel> createState() => _ReportHistoryPanelState();
}

class _ReportHistoryPanelState extends State<_ReportHistoryPanel> {
  late Future<List<ReportArchiveEntry>> _reportsFuture;
  ReportArchiveFilter _filter = ReportArchiveFilter.all;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _loadReports();
  }

  Future<List<ReportArchiveEntry>> _loadReports() async {
    final directory = await ReportExporter.reportsDirectory();
    return ReportArchive().scanDirectory(directory);
  }

  Future<void> _deleteReport(ReportArchiveEntry report) async {
    final confirmed = await _confirmDestructiveAction(
      context: context,
      strings: widget.strings,
      title: widget.strings.deleteReport,
      message: widget.strings.deleteReportMessage,
    );
    if (!confirmed) return;
    if (await report.pdfFile.exists()) {
      await report.pdfFile.delete();
    }
    if (await report.manifestFile.exists()) {
      await report.manifestFile.delete();
    }
    if (!mounted) return;
    setState(() => _reportsFuture = _loadReports());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.strings.reportDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReportArchiveEntry>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <ReportArchiveEntry>[];
        final filteredReports = reports
            .where((report) => _filter.matches(report.inspectionTypeKey))
            .toList();
        return ListView(
          controller: widget.scrollController,
          padding: widget.padding,
          children: [
            _SectionHeader(
              title: widget.strings.reportHistory,
              subtitle: widget.strings.archiveSubtitle,
              trailing: widget.showClose
                  ? IconButton(
                      tooltip: widget.strings.cancel,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            const _HeroImage(
              asset: 'assets/images/report_archive.png',
              height: 150,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReportArchiveFilter.values
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(_reportFilterLabel(widget.strings, filter)),
                      selected: filter == _filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const _LoadingSkeletonPanel(lines: 7)
            else if (reports.isEmpty)
              _EmptyActionPanel(
                icon: Icons.inventory_2_outlined,
                title: widget.strings.reportsGuideTitle,
                subtitle: widget.strings.reportsGuideSubtitle,
                actions: [
                  if (widget.onOpenInspection != null)
                    FilledButton.icon(
                      onPressed: widget.onOpenInspection,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(widget.strings.goToInspection),
                    ),
                ],
              )
            else if (filteredReports.isEmpty)
              _EmptyActionPanel(
                icon: Icons.filter_list_off_outlined,
                title: widget.strings.noReportsForFilter,
                subtitle: widget.strings.archiveSubtitle,
                actions: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _filter = ReportArchiveFilter.all),
                    icon: const Icon(Icons.clear_all_outlined),
                    label: Text(widget.strings.reportFilterAll),
                  ),
                ],
              )
            else
              ...filteredReports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(
                    builder: (context) {
                      final inspectionType = InspectionType.fromStorageKey(
                        report.inspectionTypeKey,
                      );
                      final inspectionLabel = _typeLabel(
                        widget.strings,
                        inspectionType,
                      );
                      final generatedAt = MaterialLocalizations.of(
                        context,
                      ).formatFullDate(report.generatedAt.toLocal());
                      final generatedTime = TimeOfDay.fromDateTime(
                        report.generatedAt.toLocal(),
                      ).format(context);
                      final sampleHash = report.manifestHash.isEmpty
                          ? widget.strings.hashMissing
                          : _shortHashWithEdges(report.manifestHash);
                      return _PremiumSurface(
                        padding: const EdgeInsets.all(12),
                        backgroundColor: Colors.white,
                        borderColor: AppColors.hairline,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.estateGreenSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: AppColors.deepEmerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.strings.reportArchiveBadge,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.mutedInk,
                                              fontSize: 10,
                                              letterSpacing: 0.6,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${report.propertyName} · $inspectionLabel',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                _TrustPill(
                                  icon: Icons.verified_outlined,
                                  label: widget.strings.verified,
                                  verified: true,
                                  uppercase: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.strings.reportHistory} · $generatedAt, $generatedTime',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _StatusPill(
                                  label:
                                      '${widget.strings.evidence}: ${report.evidenceCount}',
                                ),
                                _StatusPill(
                                  label:
                                      '${widget.strings.photos}: ${report.photoCount}',
                                ),
                                _StatusPill(
                                  label:
                                      '${widget.strings.hashStatus}: $sampleHash',
                                  emphasized: report.manifestHash.isNotEmpty,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.strings.reportIdLabel}: ${report.reportId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Wrap(
                                spacing: 2,
                                runSpacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: widget.strings.viewReport,
                                    onPressed: () => _openPdfPreview(
                                      context,
                                      widget.strings,
                                      report.pdfFile,
                                    ),
                                    icon: const Icon(Icons.visibility_outlined),
                                  ),
                                  IconButton(
                                    tooltip: widget.strings.shareReportAction,
                                    onPressed: () => _sharePdf(report.pdfFile),
                                    icon: const Icon(Icons.ios_share_outlined),
                                  ),
                                  IconButton(
                                    tooltip: widget.strings.deleteReport,
                                    onPressed: () => _deleteReport(report),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MorePanel extends StatelessWidget {
  const _MorePanel({
    required this.strings,
    required this.padding,
    required this.proController,
  });

  final AppStrings strings;
  final EdgeInsetsGeometry padding;
  final ProEntitlementController proController;

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.linkOpenFailed(uri.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: proController,
      builder: (context, _) => ListView(
        padding: padding,
        children: [
          _SectionHeader(
            title: strings.moreComplianceTitle,
            subtitle: strings.moreSubtitle,
          ),
          const SizedBox(height: 12),
          _MoreBrandCard(strings: strings),
          const SizedBox(height: 12),
          _MoreGroupHeader(title: strings.proSectionTitle),
          _PremiumSurface(
            backgroundColor: const Color(0xFFF8F2E8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.proTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  strings.proSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showProPaywall(
                    context: context,
                    strings: strings,
                    controller: proController,
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    proController.state.isLifetimeActive
                        ? strings.proActiveBadge
                        : strings.buyLifetimeAction,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MoreGroupHeader(title: strings.privacyDataSectionTitle),
          _MoreTile(
            icon: Icons.privacy_tip_outlined,
            title: strings.privacyPolicy,
            subtitle: strings.privacySubtitle,
            trailing: const Icon(Icons.open_in_new_outlined),
            onTap: () => _openLink(context, _privacyPolicyUriFor(strings)),
          ),
          _MoreTile(
            icon: Icons.folder_off_outlined,
            title: strings.localDataTitle,
            subtitle: strings.localDataSubtitle,
          ),
          _MoreTile(
            icon: Icons.admin_panel_settings_outlined,
            title: strings.permissionUseTitle,
            subtitle: strings.permissionUseSubtitle,
          ),
          const SizedBox(height: 2),
          _MoreGroupHeader(title: strings.supportSectionTitle),
          _MoreTile(
            icon: Icons.support_agent_outlined,
            title: strings.support,
            subtitle: strings.supportSubtitle,
            trailing: const Icon(Icons.open_in_new_outlined),
            onTap: () => _openLink(context, _supportUriFor(strings)),
          ),
          _MoreTile(
            icon: Icons.restore_outlined,
            title: strings.restorePurchases,
            subtitle: proController.state.isLifetimeActive
                ? strings.proActiveBadge
                : strings.proLifetimeSubtitle,
            onTap: () => _restoreProPurchase(context, strings, proController),
          ),
          const SizedBox(height: 2),
          _MoreGroupHeader(title: strings.legalSectionTitle),
          _MoreTile(
            icon: Icons.gavel_outlined,
            title: strings.disclaimerTitle,
            subtitle: strings.disclaimer,
          ),
          _MoreTile(
            icon: Icons.description_outlined,
            title: strings.eulaTitle,
            subtitle: strings.eulaSubtitle,
            trailing: const Icon(Icons.open_in_new_outlined),
            onTap: () => _openLink(context, _standardEulaUri),
          ),
          const SizedBox(height: 2),
          _MoreGroupHeader(title: strings.appInfoSectionTitle),
          _MoreTile(
            icon: Icons.info_outline,
            title: strings.version,
            subtitleWidget: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final version = info == null
                    ? strings.loading
                    : '${info.version} (${info.buildNumber})';
                return Text(version);
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showProPaywall({
  required BuildContext context,
  required AppStrings strings,
  required ProEntitlementController controller,
  String? reasonTitle,
  String? reasonMessage,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: _warmSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ProPaywallSheet(
      strings: strings,
      controller: controller,
      reasonTitle: reasonTitle,
      reasonMessage: reasonMessage,
    ),
  );
}

Future<void> _restoreProPurchase(
  BuildContext context,
  AppStrings strings,
  ProEntitlementController controller,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await controller.restorePurchases();
  if (!context.mounted) return;
  messenger.showSnackBar(
    SnackBar(content: Text(_proResultMessage(strings, result))),
  );
}

String _proResultMessage(AppStrings strings, ProPurchaseResult result) {
  return switch (result) {
    ProPurchaseResult.success => strings.proPurchaseSuccess,
    ProPurchaseResult.restored => strings.restoreSuccess,
    ProPurchaseResult.cancelled => strings.proPurchaseCancelled,
    ProPurchaseResult.failed => strings.proPurchaseFailed,
    ProPurchaseResult.pending => strings.proPurchasePending,
    ProPurchaseResult.unavailable => strings.restoreUnavailable,
  };
}

class _ProPaywallSheet extends StatefulWidget {
  const _ProPaywallSheet({
    required this.strings,
    required this.controller,
    this.reasonTitle,
    this.reasonMessage,
  });

  final AppStrings strings;
  final ProEntitlementController controller;
  final String? reasonTitle;
  final String? reasonMessage;

  @override
  State<_ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends State<_ProPaywallSheet> {
  bool _busy = false;

  Future<void> _openLegalLink(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.linkOpenFailed(uri.toString()))),
    );
  }

  Future<void> _run(Future<ProPurchaseResult> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_proResultMessage(widget.strings, result))),
    );
    if (widget.controller.state.isLifetimeActive) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final state = widget.controller.state;
    final remaining = state.trialRemaining;
    final remainingDays = remaining == null
        ? 0
        : (remaining.inHours / 24).ceil().clamp(1, 3);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          6,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PremiumSurface(
              backgroundColor: AppColors.paper,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.estateGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reasonTitle ?? strings.proLifetimeTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.reasonMessage ??
                                  strings.proLifetimeSubtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TrustPill(
                        icon: Icons.workspace_premium_outlined,
                        label: state.isLifetimeActive
                            ? strings.proActiveBadge
                            : state.isTrialActive
                            ? strings.trialEndsIn(remainingDays)
                            : strings.proReadOnlyTitle,
                        verified: state.isLifetimeActive,
                      ),
                      _TrustPill(
                        icon: Icons.picture_as_pdf_outlined,
                        label: strings.proBenefitNoWatermark,
                      ),
                      _TrustPill(
                        icon: Icons.apartment_outlined,
                        label: strings.proBenefitMoreProperties,
                      ),
                      _TrustPill(
                        icon: Icons.cloud_off_outlined,
                        label: strings.proBenefitLocalPrivate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.lock_open_outlined,
              title: strings.buyLifetimeAction,
              subtitle: strings.proLifetimeSubtitle,
              onTap: _busy ? null : () => _run(widget.controller.buyLifetime),
            ),
            if (state.canStartTrial)
              _MoreTile(
                icon: Icons.timer_outlined,
                title: strings.proTrialTitle,
                subtitle: strings.proTrialSubtitle,
                onTap: _busy ? null : () => _run(widget.controller.startTrial),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(widget.controller.restorePurchases),
                    icon: const Icon(Icons.restore_outlined),
                    label: Text(strings.restorePurchases),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 0,
                children: [
                  Text(
                    strings.proAgreementPrefix,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openLegalLink(_standardEulaUri),
                    child: Text(strings.eulaTitle),
                  ),
                  Text(
                    strings.proAgreementJoiner,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () =>
                        _openLegalLink(_privacyPolicyUriFor(strings)),
                    child: Text(strings.privacyPolicy),
                  ),
                ],
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoreBrandCard extends StatelessWidget {
  const _MoreBrandCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _PremiumSurface(
      padding: const EdgeInsets.all(18),
      backgroundColor: AppColors.paper,
      borderColor: AppColors.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AppBrandMark(size: 54, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.moreBrandTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.moreComplianceSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TrustPill(
                icon: Icons.lock_outline,
                label: strings.moreBrandBadge,
                verified: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            strings.moreBrandSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedInk, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TrustPill(
                icon: Icons.person_off_outlined,
                label: strings.noAccountRequired,
              ),
              _TrustPill(
                icon: Icons.cloud_off_outlined,
                label: strings.noPhotoUpload,
              ),
              _TrustPill(
                icon: Icons.picture_as_pdf_outlined,
                label: strings.pdfJsonEvidence,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreGroupHeader extends StatelessWidget {
  const _MoreGroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _mutedInk,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PremiumSurface(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _mist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _deepEmerald, size: 20),
          ),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child:
                subtitleWidget ??
                Text(
                  subtitle ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ),
          trailing: trailing,
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.item,
    required this.photoFile,
    required this.strings,
    required this.onDelete,
  });

  final EvidenceItemRecord item;
  final File? photoFile;
  final AppStrings strings;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final severityColor = item.severity == EvidenceSeverity.urgent
        ? _danger
        : item.severity == EvidenceSeverity.issue
        ? _brass
        : _deepEmerald;
    final hasPhotoFile = photoFile?.existsSync() ?? false;
    final shortHash = item.photoHash == null || item.photoHash!.isEmpty
        ? strings.hashMissing
        : _shortHashWithEdges(item.photoHash!);
    final timestamp =
        '${MaterialLocalizations.of(context).formatMediumDate(item.capturedAt.toLocal())} '
        '${TimeOfDay.fromDateTime(item.capturedAt.toLocal()).format(context)}';
    final gps = item.latitude == null || item.longitude == null
        ? strings.locationMissing
        : '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}';
    final watermark = item.photoHash == null
        ? strings.evidenceWatermarkBrand
        : '${strings.evidenceWatermarkBrand} · ${item.photoHash!}${item.photoHash!.isNotEmpty ? ' · $timestamp' : ''}';
    final isTextOnly = item.photoPath == null && !hasPhotoFile;
    final title = item.description.isEmpty
        ? _severityLabel(strings, item.severity)
        : item.description;
    final metadataPills = <Widget>[
      _StatusPill(label: '${strings.timestamp}: $timestamp'),
      if (!isTextOnly)
        _StatusPill(
          label: hasPhotoFile ? strings.photoAvailable : strings.photoMissing,
          emphasized: hasPhotoFile,
        ),
      _StatusPill(
        label: '${strings.hashBadgeLabel}: $shortHash',
        emphasized: item.photoHash != null,
      ),
      _StatusPill(
        label: '${strings.locationStatus}: $gps',
        emphasized: item.latitude != null && item.longitude != null,
      ),
      if (item.description.isNotEmpty)
        _StatusPill(label: '${strings.note}: ${item.description}'),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PremiumSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isTextOnly)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPhotoFile)
                        Image.file(photoFile!, fit: BoxFit.cover)
                      else
                        Container(
                          color: AppColors.mist,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.deepEmerald,
                          ),
                        ),
                      if (hasPhotoFile)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      if (hasPhotoFile)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              watermark,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, isTextOnly ? 12 : 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.estateGreenSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isTextOnly
                              ? Icons.sticky_note_2_outlined
                              : Icons.image_outlined,
                          size: 18,
                          color: AppColors.deepEmerald,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: severityColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _severityLabel(strings, item.severity),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: severityColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: strings.deleteEvidence,
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: metadataPills),
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
      backgroundColor: _warmSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.strings.createProperty),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HeroImage(
            asset: 'assets/images/workbench_hero.png',
            height: 128,
            fillWidth: false,
          ),
          const SizedBox(height: 14),
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

class _PickedEvidencePhoto {
  const _PickedEvidencePhoto({
    required this.photoPath,
    required this.storedPhotoPath,
    required this.photoHash,
    required this.exifSummary,
  });

  final String photoPath;
  final String storedPhotoPath;
  final String photoHash;
  final String exifSummary;
}

class _EvidenceSheet extends StatefulWidget {
  const _EvidenceSheet({
    required this.strings,
    required this.photos,
    this.source,
  });

  final AppStrings strings;
  final List<_PickedEvidencePhoto> photos;
  final ImageSource? source;

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
    final photos = widget.photos;
    final isNoteOnly = photos.isEmpty;
    return SafeArea(
      child: SingleChildScrollView(
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
            _SectionHeader(
              title: isNoteOnly
                  ? widget.strings.addNote
                  : widget.strings.addEvidence,
              subtitle: isNoteOnly
                  ? widget.strings.noteEvidenceSubtitle
                  : widget.strings.hashReady,
            ),
            const SizedBox(height: 12),
            if (isNoteOnly)
              const _HeroImage(
                asset: 'assets/images/evidence_capture.png',
                height: 120,
              )
            else
              _PremiumSurface(
                padding: const EdgeInsets.all(10),
                backgroundColor: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(photos[index].photoPath),
                              width: 96,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.strings.photosAttached(photos.length),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.strings.photosHashReady(photos.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('evidence-description-field'),
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: widget.strings.description,
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
              child: Text(
                isNoteOnly
                    ? widget.strings.saveNote
                    : widget.strings.saveEvidence,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog({
    required this.strings,
    required this.uuid,
    required this.inspectionId,
    required this.signatureExporter,
  });

  final AppStrings strings;
  final Uuid uuid;
  final String inspectionId;
  final UnitTraceSignatureExporter signatureExporter;

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
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncSignatureState);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSignatureState);
    _name.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncSignatureState() {
    final hasSignature = _controller.isNotEmpty;
    if (hasSignature == _hasSignature) return;
    setState(() => _hasSignature = hasSignature);
  }

  Future<void> _save() async {
    if (!_hasSignature) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.strings.signatureRequired)));
      return;
    }
    Uint8List? bytes;
    bytes = await widget.signatureExporter(_controller);
    if (bytes == null) return;
    String? signaturePath;
    String? signatureHash;
    final directory = await _safeApplicationDocumentsDirectory();
    final signatureDirectory = Directory(p.join(directory.path, 'signatures'));
    await signatureDirectory.create(recursive: true);
    signaturePath = p.join(signatureDirectory.path, '${widget.uuid.v4()}.png');
    await File(signaturePath).writeAsBytes(bytes, flush: true);
    signatureHash = HashService.sha256ForBytes(bytes);
    if (!mounted) return;
    Navigator.pop(
      context,
      SignatureRecord(
        id: widget.uuid.v4(),
        inspectionId: widget.inspectionId,
        signerRole: _role,
        signerName: _name.text.trim().isEmpty
            ? _signatureRoleLabel(widget.strings, _role)
            : _name.text.trim(),
        signedAt: DateTime.now().toUtc(),
        signaturePath: signaturePath,
        signatureHash: signatureHash,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      0.0,
      520.0,
    );
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: SizedBox(
              width: sheetWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.strings.addSignature,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const _HeroImage(
                    asset: 'assets/images/signature_verify.png',
                    height: 112,
                    fillWidth: false,
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: widget.strings.signerName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A172321),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Signature(
                        key: const Key('signature-pad'),
                        controller: _controller,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.strings.signatureRequired,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  OverflowBar(
                    spacing: 8,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.spaceBetween,
                    overflowAlignment: OverflowBarAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _controller.clear();
                          _syncSignatureState();
                        },
                        child: Text(widget.strings.clear),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(widget.strings.cancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _hasSignature ? _save : null,
                        child: Text(widget.strings.saveSignature),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmDestructiveAction({
  required BuildContext context,
  required AppStrings strings,
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _warmSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(strings.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _sharePdf(File pdfFile) async {
  await Printing.sharePdf(
    bytes: await pdfFile.readAsBytes(),
    filename: p.basename(pdfFile.path),
  );
}

Future<void> _openPdfPreview(
  BuildContext context,
  AppStrings strings,
  File pdfFile,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.pdfPreview),
          actions: [
            IconButton(
              tooltip: strings.shareReportAction,
              onPressed: () => _sharePdf(pdfFile),
              icon: const Icon(Icons.ios_share_outlined),
            ),
            IconButton(
              tooltip: strings.cancel,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: PdfPreview(
          canChangeOrientation: false,
          canChangePageFormat: false,
          allowPrinting: false,
          allowSharing: false,
          build: (_) => pdfFile.readAsBytes(),
        ),
      ),
    ),
  );
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

String _shortHashWithEdges(String hash) {
  if (hash.length <= 10) {
    return hash;
  }
  return '${hash.substring(0, 6)} · ${hash.substring(hash.length - 4)}';
}

String _caseIdForInspection(InspectionRecord inspection) {
  final date = inspection.createdAt.toUtc().toIso8601String().split('T').first;
  final dateTag = date.replaceAll('-', '');
  final suffixSource = inspection.id.replaceAll('-', '');
  final suffix = suffixSource.length >= 4
      ? suffixSource.substring(0, 4).toUpperCase()
      : suffixSource.toUpperCase().padRight(4, '0');
  return 'UT-$dateTag-$suffix';
}

String _typeLabel(AppStrings strings, InspectionType type) {
  return switch (type) {
    InspectionType.moveIn => strings.moveIn,
    InspectionType.moveOut => strings.moveOut,
    InspectionType.general => strings.generalInspection,
  };
}

String _signatureRoleLabel(AppStrings strings, String role) {
  return switch (role) {
    'Landlord' => strings.landlord,
    _ => strings.tenant,
  };
}

String _reportFilterLabel(AppStrings strings, ReportArchiveFilter filter) {
  return switch (filter) {
    ReportArchiveFilter.all => strings.reportFilterAll,
    ReportArchiveFilter.moveIn => strings.reportFilterMoveIn,
    ReportArchiveFilter.moveOut => strings.reportFilterMoveOut,
    ReportArchiveFilter.general => strings.reportFilterGeneral,
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
