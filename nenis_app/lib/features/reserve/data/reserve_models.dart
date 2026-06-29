import '../../orders/data/orders_models.dart' show BuyerOrder;

/// Request para apartar un producto. Se envía como JSON al backend en
/// `POST /api/me/reserve`.
class ReserveRequest {
  const ReserveRequest({
    required this.businessId,
    required this.productId,
    this.quantity = 1,
  });

  final int businessId;
  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'productId': productId,
        'quantity': quantity,
      };
}

/// Resultado exitoso de un apartado. Es el mismo `BuyerOrder` que
/// `GET /api/me/orders` para que la app pueda navegar inmediatamente a
/// `/tracking/{id}?token={accessToken}`.
typedef ReserveResult = BuyerOrder;
