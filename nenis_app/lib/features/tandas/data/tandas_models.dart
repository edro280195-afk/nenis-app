import 'package:flutter/widgets.dart';

/// Filtro de la pantalla "Tandas". `mine` muestra las tandas donde la
/// compradora está inscrita; `available` muestra las tandas activas de sus
/// tiendas donde aún NO está inscrita.
enum TandasFilter { mine, available }

extension TandasFilterX on TandasFilter {
  String get label {
    switch (this) {
      case TandasFilter.mine:
        return 'Mis tandas';
      case TandasFilter.available:
        return 'Disponibles';
    }
  }
}

/// Tanda vista por la compradora. Si `isMine` es `false`, los campos de
/// participación (`myTurn`, `hasPaidThisWeek`, `paidWeeks`,
/// `amIThisWeekWinner`) quedan en null.
class BuyerTanda {
  const BuyerTanda({
    required this.tandaId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.clientId,
    required this.name,
    required this.productName,
    required this.totalWeeks,
    required this.weeklyAmount,
    required this.startDate,
    required this.status,
    required this.currentWeek,
    required this.isMine,
    this.myTurn,
    this.hasPaidThisWeek,
    this.paidWeeks = const [],
    this.amIThisWeekWinner,
  });

  final String tandaId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final int clientId;
  final String name;
  final String productName;
  final int totalWeeks;
  final double weeklyAmount;
  final DateTime startDate;
  final String status;
  final int currentWeek;
  final bool isMine;
  final int? myTurn;
  final bool? hasPaidThisWeek;
  final List<int> paidWeeks;
  final bool? amIThisWeekWinner;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  /// Progreso de pagos: 0..1 (1 = todas pagadas, 0 = ninguna).
  double get progress {
    if (!isMine || totalWeeks <= 0) return 0;
    return (paidWeeks.length / totalWeeks).clamp(0.0, 1.0);
  }

  String get weeklyAmountLabel => '\$${weeklyAmount.toStringAsFixed(0)} / sem';

  factory BuyerTanda.fromJson(Map<String, dynamic> j) => BuyerTanda(
        tandaId: (j['tandaId'] ?? '') as String,
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        clientId: (j['clientId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        productName: (j['productName'] ?? '') as String,
        totalWeeks: (j['totalWeeks'] as num?)?.toInt() ?? 0,
        weeklyAmount: (j['weeklyAmount'] as num?)?.toDouble() ?? 0,
        startDate:
            DateTime.tryParse((j['startDate'] ?? '') as String) ?? DateTime.now(),
        status: (j['status'] ?? 'Active') as String,
        currentWeek: (j['currentWeek'] as num?)?.toInt() ?? 1,
        isMine: (j['isMine'] as bool?) ?? false,
        myTurn: (j['myTurn'] as num?)?.toInt(),
        hasPaidThisWeek: j['hasPaidThisWeek'] as bool?,
        paidWeeks: ((j['paidWeeks'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        amIThisWeekWinner: j['amIThisWeekWinner'] as bool?,
      );
}
