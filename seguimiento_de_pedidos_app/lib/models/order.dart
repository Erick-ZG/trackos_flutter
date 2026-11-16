import 'cart_item.dart';

enum OrderStatus { pending, inTransit, outForDelivery, delivered }

class Order {
  final String id;
  final List<CartItem> items;
  OrderStatus status;
  final DateTime createdAt;
  final double? totalAmount;

  Order({
    required this.id,
    required this.items,
    this.status = OrderStatus.pending,
    required this.createdAt,
    this.totalAmount,
  });

  double get total => totalAmount ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.inTransit:
        return 'En camino';
      case OrderStatus.outForDelivery:
        return 'En reparto';
      case OrderStatus.delivered:
        return 'Entregado';
    }
  }
}
