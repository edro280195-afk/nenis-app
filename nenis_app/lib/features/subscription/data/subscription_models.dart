/// Estado completo de la suscripción del negocio activo
/// (`GET /api/business/subscription/status`, `SubscriptionAccountStateDto`
/// en el backend). Más rico que `SellerSubscriptionSettings` (que viene de
/// `/api/business/me` y solo trae lo mínimo para temar/bloquear el shell):
/// aquí también viene el downgrade pendiente y el plan crudo (`PlanTier`,
/// distinto de `EffectivePlan` durante la prueba).
class SubscriptionAccountState {
  const SubscriptionAccountState({
    required this.effectivePlan,
    required this.planTier,
    required this.subscriptionStatus,
    required this.isLocked,
    required this.daysLeft,
    required this.pastDueGraceDays,
    this.trialEndsAt,
    this.currentPeriodEndsAt,
    this.pendingPlanTier,
    this.pendingPlanEffectiveAt,
  });

  final String effectivePlan;
  final String planTier;
  final String subscriptionStatus;
  final bool isLocked;
  final int daysLeft;
  final int pastDueGraceDays;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEndsAt;
  final String? pendingPlanTier;
  final DateTime? pendingPlanEffectiveAt;

  bool get isTrialing => subscriptionStatus == 'Trialing';
  bool get hasActivePreapproval =>
      subscriptionStatus == 'Active' || subscriptionStatus == 'PastDue';

  factory SubscriptionAccountState.fromJson(Map<String, dynamic> j) {
    return SubscriptionAccountState(
      effectivePlan: (j['effectivePlan'] ?? 'Entrada') as String,
      planTier: (j['planTier'] ?? 'Entrada') as String,
      subscriptionStatus: (j['subscriptionStatus'] ?? 'Active') as String,
      isLocked: (j['isLocked'] as bool?) ?? false,
      daysLeft: (j['daysLeft'] as num?)?.toInt() ?? 0,
      pastDueGraceDays: (j['pastDueGraceDays'] as num?)?.toInt() ?? 0,
      trialEndsAt: _parseDate(j['trialEndsAt']),
      currentPeriodEndsAt: _parseDate(j['currentPeriodEndsAt']),
      pendingPlanTier: j['pendingPlanTier'] as String?,
      pendingPlanEffectiveAt: _parseDate(j['pendingPlanEffectiveAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Precio de un plan para las 3 periodicidades (`SubscriptionPlanPriceDto`).
class PlanPrice {
  const PlanPrice({
    required this.planTier,
    required this.monthly,
    required this.quarterly,
    required this.annual,
    required this.quarterlyDiscountPct,
    required this.annualDiscountPct,
    required this.currency,
  });

  final String planTier;
  final double monthly;
  final double quarterly;
  final double annual;
  final int quarterlyDiscountPct;
  final int annualDiscountPct;
  final String currency;

  double amountFor(String periodicity) {
    switch (periodicity) {
      case 'quarterly':
        return quarterly;
      case 'annual':
        return annual;
      default:
        return monthly;
    }
  }

  factory PlanPrice.fromJson(Map<String, dynamic> j) {
    return PlanPrice(
      planTier: (j['planTier'] ?? '') as String,
      monthly: (j['monthlyPrice'] as num?)?.toDouble() ?? 0,
      quarterly: (j['quarterlyPrice'] as num?)?.toDouble() ?? 0,
      annual: (j['annualPrice'] as num?)?.toDouble() ?? 0,
      quarterlyDiscountPct: (j['quarterlyDiscountPct'] as num?)?.toInt() ?? 0,
      annualDiscountPct: (j['annualDiscountPct'] as num?)?.toInt() ?? 0,
      currency: (j['currency'] ?? 'MXN') as String,
    );
  }
}

class SubscriptionPricing {
  const SubscriptionPricing({required this.plans, required this.currency});
  final List<PlanPrice> plans;
  final String currency;

  factory SubscriptionPricing.fromJson(Map<String, dynamic> j) {
    return SubscriptionPricing(
      plans: ((j['plans'] as List?) ?? const [])
          .map((e) => PlanPrice.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      currency: (j['currency'] ?? 'MXN') as String,
    );
  }
}
