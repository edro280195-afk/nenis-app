import 'package:flutter/widgets.dart';

/// Dirección de la compradora en una tienda (cross-tenant por AccountId).
/// Es la "dirección de entrega" que la tienda tiene guardada. El modelo
/// actual asume 1 dirección por Client.
class BuyerAddress {
  const BuyerAddress({
    required this.clientId,
    required this.businessId,
    required this.businessName,
    required this.brandPrimaryColor,
    this.logoUrl,
    this.address,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
  });

  final int clientId;
  final int businessId;
  final String businessName;
  final String brandPrimaryColor;
  final String? logoUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? deliveryInstructions;

  String get initial => businessName.isNotEmpty
      ? businessName.characters.first.toUpperCase()
      : '?';

  bool get hasAddress =>
      (address != null && address!.trim().isNotEmpty) ||
      (latitude != null && longitude != null);

  factory BuyerAddress.fromJson(Map<String, dynamic> j) => BuyerAddress(
        clientId: (j['clientId'] as num).toInt(),
        businessId: (j['businessId'] as num).toInt(),
        businessName: (j['businessName'] ?? '') as String,
        brandPrimaryColor: (j['brandPrimaryColor'] ?? '#FB6F9C') as String,
        logoUrl: j['logoUrl'] as String?,
        address: j['address'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        deliveryInstructions: j['deliveryInstructions'] as String?,
      );
}

/// Body para que la compradora actualice su dirección. Solo los campos
/// no-null se modifican; los null se dejan sin tocar. `clearX` fuerza
/// el borrado del campo aunque sea string vacío.
class UpdateAddressRequest {
  const UpdateAddressRequest({
    this.address,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
    this.clearAddress = false,
    this.clearLatLng = false,
    this.clearInstructions = false,
  });

  final String? address;
  final double? latitude;
  final double? longitude;
  final String? deliveryInstructions;
  final bool clearAddress;
  final bool clearLatLng;
  final bool clearInstructions;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (clearAddress) {
      json['address'] = '';
    } else if (address != null) {
      json['address'] = address;
    }
    if (clearLatLng) {
      json['latitude'] = null;
      json['longitude'] = null;
    } else {
      if (latitude != null) json['latitude'] = latitude;
      if (longitude != null) json['longitude'] = longitude;
    }
    if (clearInstructions) {
      json['deliveryInstructions'] = '';
    } else if (deliveryInstructions != null) {
      json['deliveryInstructions'] = deliveryInstructions;
    }
    return json;
  }
}
