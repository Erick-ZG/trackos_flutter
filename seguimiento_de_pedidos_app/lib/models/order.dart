import 'cart_item.dart';

enum OrderStatus {
  pending,
  stockVerified,
  preparing,
  readyForPickup,
  courierArrivedStore,
  inTransit,
  outForDelivery,
  arrivedDestination,
  delivered,
}

class Order {
  final String id;
  final List<CartItem> items;
  OrderStatus status;
  final String rawStatus;
  final DateTime createdAt;
  final double? totalAmount;
  final double deliveryFee;
  final String? branchId;
  final String? branchName;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? customerName;
  final String? courierUserId;
  final String? courierName;
  final double? courierLat;
  final double? courierLng;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final int? deliveryDurationSeconds;
  final String? deliveryProofImage;

  Order({
    required this.id,
    required this.items,
    this.status = OrderStatus.pending,
    this.rawStatus = 'pending',
    required this.createdAt,
    this.totalAmount,
    this.deliveryFee = 5.0,
    this.branchId,
    this.branchName,
    this.pickupAddress = '',
    this.pickupLat,
    this.pickupLng,
    this.deliveryAddress = '',
    this.deliveryLat,
    this.deliveryLng,
    this.customerName,
    this.courierUserId,
    this.courierName,
    this.courierLat,
    this.courierLng,
    this.acceptedAt,
    this.deliveredAt,
    this.deliveryDurationSeconds,
    this.deliveryProofImage,
  });

  double get total =>
      totalAmount ?? items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.stockVerified:
        return 'Stock verificado';
      case OrderStatus.preparing:
        return 'Preparado';
      case OrderStatus.readyForPickup:
        return 'Listo para recojo';
      case OrderStatus.courierArrivedStore:
        final who = (courierName != null && courierName!.isNotEmpty)
            ? courierName!
            : 'Repartidor';
        return '$who llegó a la tienda';
      case OrderStatus.inTransit:
        return 'En camino';
      case OrderStatus.outForDelivery:
        return 'En reparto';
      case OrderStatus.arrivedDestination:
        return 'Llegó al punto de entrega';
      case OrderStatus.delivered:
        return 'Entregado';
    }
  }

  static OrderStatus parseStatus(String raw) {
    switch (raw) {
      case 'stock_verified':
        return OrderStatus.stockVerified;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready_for_pickup':
        return OrderStatus.readyForPickup;
      case 'courier_arrived_store':
        return OrderStatus.courierArrivedStore;
      case 'in_transit':
      case 'shipped':
        return OrderStatus.inTransit;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'arrived_destination':
        return OrderStatus.arrivedDestination;
      case 'delivered':
        return OrderStatus.delivered;
      default:
        return OrderStatus.pending;
    }
  }
}
