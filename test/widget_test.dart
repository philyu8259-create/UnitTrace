import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unittrace/main.dart';
import 'package:unittrace/src/data/in_memory_unittrace_store.dart';
import 'package:unittrace/src/domain/entities.dart';
import 'package:unittrace/src/services/app_directories.dart';
import 'package:unittrace/src/services/pro_entitlement.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class EmptyCameraPicker implements UnitTraceImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
  }) async {
    return null;
  }

  @override
  Future<List<XFile>> pickMultiImage({int? imageQuality}) async {
    return const [];
  }
}

class RecordingUrlLauncher extends UrlLauncherPlatform {
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return true;
  }
}

class FakeProPurchaseClient implements ProPurchaseClient {
  FakeProPurchaseClient({
    this.lifetimeResult = ProPurchaseResult.unavailable,
    this.restoreResult = ProPurchaseResult.unavailable,
  });

  final ProPurchaseResult lifetimeResult;
  final ProPurchaseResult restoreResult;

  @override
  Future<ProPurchaseResult> buyLifetime() async => lifetimeResult;

  @override
  Future<ProPurchaseResult> restorePurchases() async => restoreResult;
}

ProEntitlementController testProController({
  DateTime? now,
  ProPurchaseResult lifetimeResult = ProPurchaseResult.unavailable,
  ProPurchaseResult restoreResult = ProPurchaseResult.unavailable,
  ProEntitlementStore? store,
}) {
  return ProEntitlementController(
    store: store ?? MemoryProEntitlementStore(),
    purchaseClient: FakeProPurchaseClient(
      lifetimeResult: lifetimeResult,
      restoreResult: restoreResult,
    ),
    clock: () => now ?? DateTime.utc(2026, 5, 24, 12),
  );
}

final Uint8List testSignaturePngBytes = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Future<void> tapCreateProperty(WidgetTester tester) async {
  final button = find
      .descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Create property'),
      )
      .first;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> waitForInspectionWorkspace(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byTooltip('Back to Home').evaluate().isNotEmpty &&
        find.byIcon(Icons.photo_camera_outlined).evaluate().isNotEmpty) {
      return;
    }
  }
  expect(find.byTooltip('Back to Home'), findsOneWidget);
  expect(find.byIcon(Icons.photo_camera_outlined), findsAtLeastNWidgets(1));
}

Finder verticalScrollable() {
  return find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .last;
}

Future<void> tapInspectionType(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label).last,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 140));
  await tester.pumpAndSettle();
  final card = find
      .ancestor(of: find.text(label).last, matching: find.byType(InkWell))
      .last;
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> drawTestSignature(WidgetTester tester) async {
  final pad = find.byKey(const Key('signature-pad'));
  await tester.ensureVisible(pad);
  final center = tester.getCenter(pad);
  final gesture = await tester.startGesture(center.translate(-72, -18));
  await gesture.moveBy(const Offset(36, 28));
  await gesture.moveBy(const Offset(38, -22));
  await gesture.moveBy(const Offset(42, 30));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('creates a property from the empty dashboard', (tester) async {
    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UnitTrace'), findsWidgets);
    expect(find.text('Create property'), findsAtLeastNWidgets(1));

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.enterText(
      find.byKey(const Key('property-address-field')),
      '12 Oak Street',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();
    expect(find.text('Oak Street Apt'), findsAtLeastNWidgets(1));
    expect(find.text('Start inspection'), findsOneWidget);
  });

  testWidgets('Chinese dashboard does not mix English hero copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('zh', 'Hans'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('房况留证'), findsWidgets);
    expect(find.text('本地证据保险箱'), findsOneWidget);
    expect(find.text('时间戳 · 哈希 · 签名'), findsOneWidget);
    expect(find.text('Local Evidence Vault'), findsNothing);
    expect(find.text('Timestamp · Hash · Signature'), findsNothing);
    expect(find.text('UNITTRACE'), findsNothing);
  });

  testWidgets('More links route to English public pages in English locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousLauncher = UrlLauncherPlatform.instance;
    final launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Privacy Policy'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Support'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Support'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'End User License Agreement'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, 'End User License Agreement'),
    );
    await tester.pumpAndSettle();

    expect(
      launcher.launchedUrls,
      containsAllInOrder([
        'https://philyu8259-create.github.io/UnitTrace/privacy-policy-en.html',
        'https://philyu8259-create.github.io/UnitTrace/support-en.html',
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      ]),
    );
  });

  testWidgets('More links route to Chinese public pages in Chinese locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousLauncher = UrlLauncherPlatform.instance;
    final launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('zh', 'Hans'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, '隐私政策'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '隐私政策'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, '支持与反馈'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '支持与反馈'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, '最终用户许可协议'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '最终用户许可协议'));
    await tester.pumpAndSettle();

    expect(
      launcher.launchedUrls,
      containsAllInOrder([
        'https://philyu8259-create.github.io/UnitTrace/privacy-policy-zh.html',
        'https://philyu8259-create.github.io/UnitTrace/support-zh.html',
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      ]),
    );
  });

  testWidgets('More page keeps Chinese and English fixed copy separated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('zh', 'Hans'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('关于与合规'), findsOneWidget);
    expect(find.text('一次性购买 \$24.99'), findsOneWidget);
    expect(find.text('About & Compliance'), findsNothing);
    expect(find.text('Local Data'), findsNothing);
    expect(find.text('Buy once \$24.99'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('本地数据说明'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('本地数据说明'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('About & Compliance'), findsOneWidget);
    expect(find.text('Buy once \$24.99'), findsOneWidget);
    expect(find.text('关于与合规'), findsNothing);
    expect(find.text('本地数据说明'), findsNothing);
    expect(find.text('一次性购买 \$24.99'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Local Data'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Local Data'), findsOneWidget);
  });

  testWidgets('Restore purchases shows localized unavailable feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Restore Purchases'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Restore Purchases').last);
    await tester.pump();

    expect(find.text('No purchases to restore'), findsOneWidget);
  });

  testWidgets('expired trial keeps existing data readable and gates edits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 5, 24, 12);
    final entitlementStore = MemoryProEntitlementStore();
    await entitlementStore.save(
      ProEntitlementState(
        now: now,
        trialStartedAt: now.subtract(const Duration(days: 4)),
        trialEndsAt: now.subtract(const Duration(days: 1)),
      ),
    );
    final store = InMemoryUnitTraceStore();
    await store.saveProperty(
      PropertyRecord(
        id: 'property-1',
        name: 'Readable Apt',
        address: '10 Market Street',
        createdAt: now,
      ),
    );

    await tester.pumpWidget(
      UnitTraceApp(
        store: store,
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(now: now, store: entitlementStore),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Readable Apt'), findsOneWidget);
    await tapCreateProperty(tester);
    await tester.pumpAndSettle();

    expect(find.text('Trial ended'), findsWidgets);
    expect(find.text('Buy once \$24.99'), findsWidgets);
  });

  testWidgets('lifetime purchase unlocks Pro from paywall', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 5, 24, 12);
    final entitlementStore = MemoryProEntitlementStore();
    await entitlementStore.save(
      ProEntitlementState(
        now: now,
        trialStartedAt: now.subtract(const Duration(days: 4)),
        trialEndsAt: now.subtract(const Duration(days: 1)),
      ),
    );
    final controller = testProController(
      now: now,
      store: entitlementStore,
      lifetimeResult: ProPurchaseResult.success,
    );

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: controller,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy once \$24.99'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Buy once \$24.99'));
    await tester.pumpAndSettle();

    expect(controller.state.isLifetimeActive, isTrue);
    expect(find.text('Pro unlocked'), findsWidgets);
  });

  testWidgets('Pro paywall exposes EULA and privacy links', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousLauncher = UrlLauncherPlatform.instance;
    final launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);

    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy once \$24.99'));
    await tester.pumpAndSettle();

    expect(find.text('By purchasing, you agree to the'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'End User License Agreement'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Privacy Policy'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(TextButton, 'End User License Agreement'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Privacy Policy'));
    await tester.pumpAndSettle();

    expect(
      launcher.launchedUrls,
      containsAllInOrder([
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
        'https://philyu8259-create.github.io/UnitTrace/privacy-policy-en.html',
      ]),
    );
  });

  testWidgets('runs inspection note and signature flow', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = InMemoryUnitTraceStore();
    final documents = Directory.systemTemp.createTempSync(
      'unittrace-widget-signature-',
    );
    AppDirectories.setDocumentsDirectoryForTesting(documents);
    addTearDown(() {
      AppDirectories.resetForTesting();
      documents.deleteSync(recursive: true);
    });
    var signatureExportCount = 0;
    await tester.pumpWidget(
      UnitTraceApp(
        store: store,
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
        signatureExporter: (_) async {
          signatureExportCount += 1;
          return testSignaturePngBytes;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.enterText(
      find.byKey(const Key('property-address-field')),
      '12 Oak Street',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    await tapInspectionType(tester, 'Move-in');
    for (var i = 0; i < 10 && (await store.loadInspections()).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.loadInspections(), isNotEmpty);
    await waitForInspectionWorkspace(tester);
    await tester.scrollUntilVisible(
      find.text('Add note').first,
      300,
      scrollable: verticalScrollable(),
    );
    expect(find.byTooltip('Add note'), findsNothing);
    expect(find.byIcon(Icons.photo_camera_outlined), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.photo_library_outlined), findsAtLeastNWidgets(1));
    expect(find.text('Add note'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Add evidence'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Add signature'), findsOneWidget);

    final addEvidence = find.text('Add note').first;
    await tester.ensureVisible(addEvidence);
    await tester.tap(addEvidence);
    await tester.pumpAndSettle();
    expect(find.text('Add note'), findsWidgets);
    expect(
      find.text('Text notes are saved in the evidence manifest.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('evidence-description-field')),
      'Scratch near the entry door',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.ensureVisible(find.text('Save note'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save note'));
    await tester.pumpAndSettle();
    final inspections = await store.loadInspections();
    final evidence = await store.loadEvidence(inspections.single.id);
    expect(evidence.single.description, 'Scratch near the entry door');
    await tester.scrollUntilVisible(
      find.text('Scratch near the entry door'),
      220,
      scrollable: verticalScrollable(),
    );
    expect(find.text('Scratch near the entry door'), findsOneWidget);

    final addSignature = find
        .widgetWithText(FilledButton, 'Add signature')
        .first;
    await tester.ensureVisible(addSignature);
    await tester.tap(addSignature);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Alex Tenant');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save signature'),
          )
          .onPressed,
      isNull,
    );
    await drawTestSignature(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save signature'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(signatureExportCount, 0);
    await store.saveSignature(
      SignatureRecord(
        id: 'signature-tenant',
        inspectionId: inspections.single.id,
        signerRole: 'Tenant',
        signerName: 'Alex Tenant',
        signedAt: DateTime.utc(2026, 5, 24, 14),
        signaturePath: '/tmp/alex-signature.png',
        signatureHash: 'tenant-signature-hash',
      ),
    );
    expect(
      (await store.loadSignatures(
        inspections.single.id,
      )).map((signature) => signature.signerName),
      contains('Alex Tenant'),
    );
    await store.saveSignature(
      SignatureRecord(
        id: 'signature-landlord',
        inspectionId: inspections.single.id,
        signerRole: 'Landlord',
        signerName: 'Laura Landlord',
        signedAt: DateTime.utc(2026, 5, 24, 15),
        signaturePath: '/tmp/laura-signature.png',
        signatureHash: 'landlord-signature-hash',
      ),
    );
    expect(
      (await store.loadSignatures(
        inspections.single.id,
      )).map((signature) => signature.signerName),
      containsAll(<String>['Alex Tenant', 'Laura Landlord']),
    );
  });

  testWidgets('deletes inspections and properties with confirmation', (
    tester,
  ) async {
    final store = InMemoryUnitTraceStore();
    await tester.pumpWidget(
      UnitTraceApp(
        store: store,
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.enterText(
      find.byKey(const Key('property-address-field')),
      '12 Oak Street',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Move-in').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Move-in').first);
    await tester.pumpAndSettle();
    for (var i = 0; i < 10 && (await store.loadInspections()).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(await store.loadInspections(), hasLength(1));

    await tester.tap(find.byTooltip('Delete inspection'));
    await tester.pumpAndSettle();
    expect(find.text('Delete inspection'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await store.loadInspections(), isEmpty);
    expect(find.text('Local Evidence Vault'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('Delete property'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Delete property'));
    await tester.pumpAndSettle();
    expect(find.text('Delete property'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await store.loadProperties(), isEmpty);
    expect(
      find.text(
        'No properties yet. Create a property to start an evidence report.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile inspect tab starts an inspection for the selected property',
    (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = InMemoryUnitTraceStore();
      await tester.pumpWidget(
        UnitTraceApp(
          store: store,
          initialLocale: const Locale('en'),
          captureLocation: false,
          proController: testProController(),
        ),
      );
      await tester.pumpAndSettle();

      await tapCreateProperty(tester);
      await tester.enterText(
        find.byKey(const Key('property-name-field')),
        'Oak Street Apt',
      );
      await tester.enterText(
        find.byKey(const Key('property-address-field')),
        '12 Oak Street',
      );
      await tester.tap(find.text('Save property'));
      await tester.pumpAndSettle();

      expect(find.text('Start first inspection'), findsNothing);
      expect(find.text('No inspection workspace yet'), findsNothing);
      expect(find.text('Move-in'), findsOneWidget);
      expect(find.textContaining('Oak Street Apt'), findsWidgets);

      await tapInspectionType(tester, 'Move-in');
      for (var i = 0; i < 10 && (await store.loadInspections()).isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await waitForInspectionWorkspace(tester);
      expect(await store.loadInspections(), isNotEmpty);
      expect(find.byTooltip('Back to Home'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Generate PDF report'),
        500,
        scrollable: verticalScrollable(),
      );
      expect(find.text('Generate PDF report'), findsOneWidget);
      expect(find.text('Selected room evidence'), findsWidgets);

      await tester.tap(find.byTooltip('Back to Home'));
      await tester.pumpAndSettle();
      expect(find.text('Local Evidence Vault'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('camera empty result shows a clear capture message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = InMemoryUnitTraceStore();
    await tester.pumpWidget(
      UnitTraceApp(
        store: store,
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
        imagePicker: EmptyCameraPicker(),
      ),
    );
    await tester.pumpAndSettle();

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.enterText(
      find.byKey(const Key('property-address-field')),
      '12 Oak Street',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    await tapInspectionType(tester, 'Move-in');
    for (var i = 0; i < 10 && (await store.loadInspections()).isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await waitForInspectionWorkspace(tester);

    final cameraButton = find.byIcon(Icons.photo_camera_outlined).first;
    await tester.ensureVisible(cameraButton);
    await tester.tap(cameraButton);
    await tester.pumpAndSettle();
    expect(find.text('Allow camera for evidence photos'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.text(
        'No photo captured. Confirm camera access is available and allowed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('active trial allows more than two properties', (tester) async {
    await tester.pumpWidget(
      UnitTraceApp(
        store: InMemoryUnitTraceStore(),
        initialLocale: const Locale('en'),
        captureLocation: false,
        proController: testProController(),
      ),
    );
    await tester.pumpAndSettle();

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Oak Street Apt',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Pine Street Apt',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();
    expect(find.text('Pine Street Apt'), findsAtLeastNWidgets(1));

    await tapCreateProperty(tester);
    await tester.enterText(
      find.byKey(const Key('property-name-field')),
      'Cedar Street Apt',
    );
    await tester.tap(find.text('Save property'));
    await tester.pumpAndSettle();
    expect(find.text('Cedar Street Apt'), findsAtLeastNWidgets(1));
  });
}
