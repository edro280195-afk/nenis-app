import 'package:flutter/widgets.dart';

/// Filtro de la pantalla "Sorteos". `active` muestra los sorteos en
/// estado Active (aún no sorteados); `mine` muestra los sorteos en los
/// que la compradora tiene al menos un boleto; `history` muestra los
/// sorteos ya sorteados (Completed) o cancelados.
enum RafflesFilter { active, mine, history }

extension RafflesFilterX on RafflesFilter {
  String get label {
    switch (this) {
      case RafflesFilter.active:
        return 'Activos';
      case RafflesFilter.mine:
        return 'Mis boletos';
      case RafflesFilter.history:
        return 'Historial';
    }
  }
}

/// Sorteo visto por la compradora. `isMineEntered` y `amIWinner` derivan
/// de la participación y las entradas en el backend.
class BuyerRaffle {
  const BuyerRaffle({
    required this.raffleId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    required this.clientId,
    required this.name,
    required this.prizeType,
    required this.raffleDate,
    required this.status,
    required this.myEntryCount,
    required this.isMineEntered,
    required this.amIWinner,
    this.imageUrl,
    this.prizeValue,
    this.prizeDescription,
    this.tandaName,
    this.announcedAt,
  });

  final String raffleId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final int clientId;
  final String name;
  final String? imageUrl;
  final String prizeType;
  final double? prizeValue;
  final String? prizeDescription;
  final DateTime raffleDate;
  final String status;
  final String? tandaName;
  final int myEntryCount;
  final bool isMineEntered;
  final bool amIWinner;
  final DateTime? announcedAt;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  /// Texto humano del tipo de premio.
  String get prizeLabel {
    switch (prizeType) {
      case 'discount':
        return 'Descuento';
      case 'freeShipping':
        return 'Envío gratis';
      case 'cash':
        return 'Efectivo';
      case 'giftCard':
        return 'Tarjeta de regalo';
      case 'product':
        return 'Producto';
      default:
        return 'Premio';
    }
  }

  bool get isActive => status == 'Active';
  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';

  factory BuyerRaffle.fromJson(Map<String, dynamic> j) => BuyerRaffle(
        raffleId: (j['raffleId'] ?? '') as String,
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        clientId: (j['clientId'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        imageUrl: j['imageUrl'] as String?,
        prizeType: (j['prizeType'] ?? 'product') as String,
        prizeValue: (j['prizeValue'] as num?)?.toDouble(),
        prizeDescription: j['prizeDescription'] as String?,
        raffleDate:
            DateTime.tryParse((j['raffleDate'] ?? '') as String) ??
                DateTime.now(),
        status: (j['status'] ?? 'Active') as String,
        tandaName: j['tandaName'] as String?,
        myEntryCount: (j['myEntryCount'] as num?)?.toInt() ?? 0,
        isMineEntered: (j['isMineEntered'] as bool?) ?? false,
        amIWinner: (j['amIWinner'] as bool?) ?? false,
        announcedAt: j['announcedAt'] != null
            ? DateTime.tryParse(j['announcedAt'] as String)
            : null,
      );
}
