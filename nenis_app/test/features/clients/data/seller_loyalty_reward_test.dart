import 'package:flutter_test/flutter_test.dart';
import 'package:nenis_app/features/clients/data/seller_clients_models.dart';

SellerLoyaltyReward _reward(String type, {double value = 0, int cost = 100}) =>
    SellerLoyaltyReward.fromJson({
      'id': 1,
      'name': 'Premio',
      'pointsCost': cost,
      'type': type,
      'value': value,
    });

void main() {
  test('descuento fijo aplica su valor sin importar el envío', () {
    final r = _reward('FixedDiscount', value: 50);
    expect(r.type, SellerRewardType.fixedDiscount);
    expect(r.discountFor(shippingCost: 60), 50);
  });

  test('envío gratis descuenta exactamente el costo de envío del pedido', () {
    final r = _reward('FreeShipping', cost: 150);
    expect(r.type, SellerRewardType.freeShipping);
    expect(r.discountFor(shippingCost: 60), 60);
    expect(r.discountFor(shippingCost: 0), 0);
  });

  test('un regalo físico no baja el total', () {
    final r = _reward('Gift');
    expect(r.type, SellerRewardType.gift);
    expect(r.discountFor(shippingCost: 60), 0);
  });

  test('un tipo desconocido se trata como descuento fijo', () {
    expect(_reward('Otro', value: 10).type, SellerRewardType.fixedDiscount);
  });

  test('parsea nombre, costo e ícono del backend', () {
    final r = SellerLoyaltyReward.fromJson({
      'id': 7,
      'name': 'Envío gratis',
      'description': null,
      'pointsCost': 150,
      'type': 'FreeShipping',
      'value': 0,
      'icon': '🚚',
    });
    expect(r.id, 7);
    expect(r.pointsCost, 150);
    expect(r.icon, '🚚');
    expect(r.description, isNull);
  });
}
