import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnitTraceProProducts {
  UnitTraceProProducts._();

  static const lifetime = 'unittrace_pro_lifetime';
  static const ids = <String>{lifetime};
  static const lifetimeDisplayPrice = r'$24.99';
}

enum ProPurchaseResult {
  success,
  restored,
  cancelled,
  failed,
  pending,
  unavailable,
}

class ProEntitlementState {
  const ProEntitlementState({
    required this.now,
    this.lifetimeUnlocked = false,
    this.lifetimePurchasedAt,
    this.trialStartedAt,
    this.trialEndsAt,
  });

  static const trialDuration = Duration(days: 3);

  final DateTime now;
  final bool lifetimeUnlocked;
  final DateTime? lifetimePurchasedAt;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;

  bool get isLifetimeActive => lifetimeUnlocked;

  bool get hasStartedTrial => trialStartedAt != null && trialEndsAt != null;

  bool get isTrialActive {
    final endsAt = trialEndsAt;
    return endsAt != null && now.isBefore(endsAt);
  }

  bool get canStartTrial => !lifetimeUnlocked && !hasStartedTrial;

  bool get isProActive => isLifetimeActive || isTrialActive;

  bool get isReadOnlyLocked => !isProActive && hasStartedTrial;

  bool get shouldWatermarkPdf => !isLifetimeActive;

  Duration? get trialRemaining {
    final endsAt = trialEndsAt;
    if (endsAt == null || !now.isBefore(endsAt)) return null;
    return endsAt.difference(now);
  }

  ProEntitlementState copyWith({
    DateTime? now,
    bool? lifetimeUnlocked,
    DateTime? lifetimePurchasedAt,
    DateTime? trialStartedAt,
    DateTime? trialEndsAt,
  }) {
    return ProEntitlementState(
      now: now ?? this.now,
      lifetimeUnlocked: lifetimeUnlocked ?? this.lifetimeUnlocked,
      lifetimePurchasedAt: lifetimePurchasedAt ?? this.lifetimePurchasedAt,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
    );
  }
}

abstract class ProEntitlementStore {
  Future<ProEntitlementState> load({required DateTime now});
  Future<void> save(ProEntitlementState state);
}

class SharedPreferencesProEntitlementStore implements ProEntitlementStore {
  const SharedPreferencesProEntitlementStore();

  static const _lifetimeUnlockedKey = 'unittrace.pro.lifetimeUnlocked';
  static const _lifetimePurchasedAtKey = 'unittrace.pro.lifetimePurchasedAt';
  static const _trialStartedAtKey = 'unittrace.pro.trialStartedAt';
  static const _trialEndsAtKey = 'unittrace.pro.trialEndsAt';

  @override
  Future<ProEntitlementState> load({required DateTime now}) async {
    final preferences = await SharedPreferences.getInstance();
    return ProEntitlementState(
      now: now,
      lifetimeUnlocked: preferences.getBool(_lifetimeUnlockedKey) ?? false,
      lifetimePurchasedAt: _parseDate(
        preferences.getString(_lifetimePurchasedAtKey),
      ),
      trialStartedAt: _parseDate(preferences.getString(_trialStartedAtKey)),
      trialEndsAt: _parseDate(preferences.getString(_trialEndsAtKey)),
    );
  }

  @override
  Future<void> save(ProEntitlementState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_lifetimeUnlockedKey, state.lifetimeUnlocked);
    await _setDate(
      preferences,
      _lifetimePurchasedAtKey,
      state.lifetimePurchasedAt,
    );
    await _setDate(preferences, _trialStartedAtKey, state.trialStartedAt);
    await _setDate(preferences, _trialEndsAtKey, state.trialEndsAt);
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Future<void> _setDate(
    SharedPreferences preferences,
    String key,
    DateTime? value,
  ) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value.toUtc().toIso8601String());
    }
  }
}

class MemoryProEntitlementStore implements ProEntitlementStore {
  ProEntitlementState? _state;

  @override
  Future<ProEntitlementState> load({required DateTime now}) async {
    final state = _state;
    return state == null
        ? ProEntitlementState(now: now)
        : state.copyWith(now: now);
  }

  @override
  Future<void> save(ProEntitlementState state) async {
    _state = state;
  }
}

abstract class ProPurchaseClient {
  Future<ProPurchaseResult> buyLifetime();
  Future<ProPurchaseResult> restorePurchases();
}

class InAppPurchaseProClient implements ProPurchaseClient {
  InAppPurchaseProClient({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  Future<ProPurchaseResult> _buy(String productId) async {
    final available = await _inAppPurchase.isAvailable();
    if (!available) return ProPurchaseResult.unavailable;
    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return ProPurchaseResult.unavailable;
    final completer = Completer<ProPurchaseResult>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _inAppPurchase.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != productId) continue;
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        switch (purchase.status) {
          case PurchaseStatus.purchased:
            if (!completer.isCompleted) {
              completer.complete(ProPurchaseResult.success);
            }
          case PurchaseStatus.restored:
            if (!completer.isCompleted) {
              completer.complete(ProPurchaseResult.restored);
            }
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) {
              completer.complete(ProPurchaseResult.cancelled);
            }
          case PurchaseStatus.error:
            if (!completer.isCompleted) {
              completer.complete(ProPurchaseResult.failed);
            }
          case PurchaseStatus.pending:
            break;
        }
      }
    });
    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    final started = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    if (!started) {
      await subscription.cancel();
      return ProPurchaseResult.failed;
    }
    final result = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => ProPurchaseResult.pending,
    );
    await subscription.cancel();
    return result;
  }

  @override
  Future<ProPurchaseResult> buyLifetime() {
    return _buy(UnitTraceProProducts.lifetime);
  }

  @override
  Future<ProPurchaseResult> restorePurchases() async {
    final available = await _inAppPurchase.isAvailable();
    if (!available) return ProPurchaseResult.unavailable;
    final completer = Completer<ProPurchaseResult>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _inAppPurchase.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != UnitTraceProProducts.lifetime) continue;
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
        if (purchase.status == PurchaseStatus.restored ||
            purchase.status == PurchaseStatus.purchased) {
          if (!completer.isCompleted) {
            completer.complete(ProPurchaseResult.restored);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          if (!completer.isCompleted) {
            completer.complete(ProPurchaseResult.failed);
          }
        }
      }
    });
    await _inAppPurchase.restorePurchases();
    final result = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => ProPurchaseResult.unavailable,
    );
    await subscription.cancel();
    return result;
  }
}

class ProEntitlementController extends ChangeNotifier {
  ProEntitlementController({
    required ProEntitlementStore store,
    required ProPurchaseClient purchaseClient,
    DateTime Function()? clock,
  }) : _store = store,
       _purchaseClient = purchaseClient,
       _clock = clock ?? DateTime.now,
       _state = ProEntitlementState(now: (clock ?? DateTime.now)().toUtc());

  factory ProEntitlementController.local() {
    return ProEntitlementController(
      store: const SharedPreferencesProEntitlementStore(),
      purchaseClient: InAppPurchaseProClient(),
    );
  }

  final ProEntitlementStore _store;
  final ProPurchaseClient _purchaseClient;
  final DateTime Function() _clock;
  ProEntitlementState _state;

  ProEntitlementState get state => _state.copyWith(now: _now());

  DateTime _now() => _clock().toUtc();

  Future<void> load() async {
    _state = await _store.load(now: _now());
    notifyListeners();
  }

  Future<ProPurchaseResult> startTrial() async {
    if (!state.canStartTrial) return ProPurchaseResult.unavailable;
    await beginLocalTrialIfAvailable();
    return ProPurchaseResult.success;
  }

  Future<bool> beginLocalTrialIfAvailable() async {
    if (!state.canStartTrial) return false;
    final startedAt = _now();
    _state = state.copyWith(
      now: startedAt,
      trialStartedAt: startedAt,
      trialEndsAt: startedAt.add(ProEntitlementState.trialDuration),
    );
    await _store.save(_state);
    notifyListeners();
    return true;
  }

  Future<ProPurchaseResult> buyLifetime() async {
    final result = await _purchaseClient.buyLifetime();
    if (result == ProPurchaseResult.success ||
        result == ProPurchaseResult.restored) {
      await unlockLifetime();
    }
    return result;
  }

  Future<ProPurchaseResult> restorePurchases() async {
    final result = await _purchaseClient.restorePurchases();
    if (result == ProPurchaseResult.success ||
        result == ProPurchaseResult.restored) {
      await unlockLifetime();
    }
    return result;
  }

  Future<void> unlockLifetime() async {
    final purchasedAt = _now();
    _state = state.copyWith(
      now: purchasedAt,
      lifetimeUnlocked: true,
      lifetimePurchasedAt: purchasedAt,
    );
    await _store.save(_state);
    notifyListeners();
  }
}
