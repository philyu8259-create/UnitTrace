import 'package:flutter_test/flutter_test.dart';
import 'package:unittrace/src/services/pro_entitlement.dart';

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

void main() {
  final now = DateTime.utc(2026, 5, 24, 12);

  group('ProEntitlementState', () {
    test('has available trial before any purchase or trial', () {
      final state = ProEntitlementState(now: now);

      expect(state.isLifetimeActive, isFalse);
      expect(state.isTrialActive, isFalse);
      expect(state.isProActive, isFalse);
      expect(state.isReadOnlyLocked, isFalse);
      expect(state.canStartTrial, isTrue);
      expect(state.shouldWatermarkPdf, isTrue);
    });

    test('keeps trial active for the three day window', () {
      final startedAt = now.subtract(const Duration(days: 2, hours: 23));
      final state = ProEntitlementState(
        now: now,
        trialStartedAt: startedAt,
        trialEndsAt: startedAt.add(ProEntitlementState.trialDuration),
      );

      expect(state.isTrialActive, isTrue);
      expect(state.isProActive, isTrue);
      expect(state.isReadOnlyLocked, isFalse);
      expect(state.canStartTrial, isFalse);
      expect(state.shouldWatermarkPdf, isTrue);
    });

    test('locks write actions after trial expires but keeps read access', () {
      final startedAt = now.subtract(const Duration(days: 4));
      final state = ProEntitlementState(
        now: now,
        trialStartedAt: startedAt,
        trialEndsAt: startedAt.add(ProEntitlementState.trialDuration),
      );

      expect(state.isTrialActive, isFalse);
      expect(state.isProActive, isFalse);
      expect(state.isReadOnlyLocked, isTrue);
      expect(state.canStartTrial, isFalse);
    });

    test('lifetime purchase unlocks Pro and removes PDF watermark', () {
      final state = ProEntitlementState(
        now: now,
        lifetimeUnlocked: true,
        lifetimePurchasedAt: now.subtract(const Duration(days: 30)),
      );

      expect(state.isLifetimeActive, isTrue);
      expect(state.isProActive, isTrue);
      expect(state.isReadOnlyLocked, isFalse);
      expect(state.shouldWatermarkPdf, isFalse);
    });
  });

  group('ProEntitlementController', () {
    test('starts trial and persists three day end date', () async {
      final store = MemoryProEntitlementStore();
      final controller = ProEntitlementController(
        store: store,
        purchaseClient: FakeProPurchaseClient(),
        clock: () => now,
      );
      await controller.load();

      final result = await controller.startTrial();

      expect(result, ProPurchaseResult.success);
      expect(controller.state.isTrialActive, isTrue);
      expect(controller.state.trialEndsAt, now.add(const Duration(days: 3)));
      expect(
        (await store.load(now: now)).trialEndsAt,
        now.add(const Duration(days: 3)),
      );
    });

    test('restored lifetime purchase unlocks Pro', () async {
      final controller = ProEntitlementController(
        store: MemoryProEntitlementStore(),
        purchaseClient: FakeProPurchaseClient(
          restoreResult: ProPurchaseResult.restored,
        ),
        clock: () => now,
      );
      await controller.load();

      final result = await controller.restorePurchases();

      expect(result, ProPurchaseResult.restored);
      expect(controller.state.isLifetimeActive, isTrue);
      expect(controller.state.shouldWatermarkPdf, isFalse);
    });
  });
}
