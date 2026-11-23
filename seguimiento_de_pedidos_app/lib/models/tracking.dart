class RouteNode {
  final String name;
  final double latitude;
  final double longitude;
  const RouteNode({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  factory RouteNode.fromJson(Map<String, dynamic> json) => RouteNode(
    name: json['name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

class TrackingSimulation {
  final bool enabled;
  final List<RouteNode> nodes;
  final int currentNodeIndex;
  final int version;
  final String runId;
  final String routeName;
  final String notice;
  const TrackingSimulation({
    required this.enabled,
    required this.nodes,
    required this.currentNodeIndex,
    required this.version,
    required this.runId,
    required this.routeName,
    required this.notice,
  });
  bool get delivered => currentNodeIndex == nodes.length - 1;
  double get progress =>
      nodes.length < 2 ? 0 : currentNodeIndex / (nodes.length - 1);
  RouteNode get currentNode => nodes[currentNodeIndex];
  factory TrackingSimulation.fromJson(Map<String, dynamic> json) {
    final route = Map<String, dynamic>.from(json['route'] as Map);
    final nodes = (route['nodes'] as List)
        .map((n) => RouteNode.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();
    final index = json['currentNodeIndex'] as int;
    if (nodes.length < 2 || index < 0 || index >= nodes.length) {
      throw const FormatException('Ruta de prueba académica inválida');
    }
    return TrackingSimulation(
      enabled: json['enabled'] == true,
      nodes: nodes,
      currentNodeIndex: index,
      version: json['version'] as int,
      runId: json['runId'] as String,
      routeName: route['name'] as String,
      notice: route['notice'] as String? ?? 'Recorrido ilustrativo',
    );
  }
}

class OrderMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  const OrderMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory OrderMessage.fromJson(Map<String, dynamic> json) => OrderMessage(
    id: json['id'].toString(),
    orderId: json['order_id'].toString(),
    senderId: json['sender_id'].toString(),
    senderName: json['sender_name']?.toString() ?? 'Usuario',
    senderRole: json['sender_role']?.toString() ?? 'customer',
    message: json['message']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

class TrackingData {
  final String orderId;
  final String status;
  final Map<String, dynamic> order;
  final Map<String, dynamic> shipment;
  final List<Map<String, dynamic>> events;
  final TrackingSimulation? simulation;

  const TrackingData({
    required this.orderId,
    required this.status,
    this.order = const {},
    required this.shipment,
    required this.events,
    this.simulation,
  });

  String? get courierName =>
      order['courier_name']?.toString() ?? shipment['courier_name']?.toString();
  String? get branchName => order['branch_name']?.toString();
  String? get pickupAddress => order['pickup_address']?.toString();
  double? get pickupLat => (order['pickup_lat'] as num?)?.toDouble();
  double? get pickupLng => (order['pickup_lng'] as num?)?.toDouble();
  String? get deliveryAddress =>
      order['delivery_address']?.toString() ??
      shipment['delivery_address']?.toString();
  double? get deliveryLat => (order['delivery_lat'] as num?)?.toDouble();
  double? get deliveryLng => (order['delivery_lng'] as num?)?.toDouble();
  double? get courierLat => (order['courier_lat'] as num?)?.toDouble();
  double? get courierLng => (order['courier_lng'] as num?)?.toDouble();
  double get deliveryFee => (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;
  int? get deliveryDurationSeconds =>
      (order['delivery_duration_seconds'] as num?)?.toInt();
  String? get deliveryProofImage =>
      order['delivery_proof_image']?.toString() ??
      shipment['delivery_photo_url']?.toString();
  String? get acceptedAt => order['accepted_at']?.toString();

  double get workflowProgress => switch (status) {
    'stock_verified' || 'pending' => 0.14,
    'preparing' => 0.28,
    'ready_for_pickup' => 0.42,
    'courier_arrived_store' => 0.58,
    'in_transit' || 'shipped' => 0.74,
    'out_for_delivery' || 'arrived_destination' => 0.88,
    'delivered' => 1.0,
    _ => 0.1,
  };

  String get statusLabel => switch (status) {
    'stock_verified' => 'Stock verificado',
    'preparing' => 'Preparado',
    'ready_for_pickup' => 'Listo para recojo',
    'courier_arrived_store' =>
      '${courierName ?? 'Repartidor'} llegó a la tienda',
    'in_transit' || 'shipped' => 'En camino',
    'out_for_delivery' => 'En reparto',
    'arrived_destination' => 'Llegó al punto de entrega',
    'delivered' => 'Entregado',
    _ => 'Pendiente',
  };

  factory TrackingData.fromJson(Map<String, dynamic> json) => TrackingData(
    orderId: json['orderId'] as String,
    status: json['status'] as String,
    order: Map<String, dynamic>.from(json['order'] as Map? ?? {}),
    shipment: Map<String, dynamic>.from(json['shipment'] as Map? ?? {}),
    events: (json['events'] as List? ?? []).map((e) {
      final event = Map<String, dynamic>.from(e as Map);
      event['description'] = (event['description']?.toString() ?? '')
          .replaceAll('Simulación iniciada.', 'Prueba académica iniciada.')
          .replaceAll('Pedido simulado en:', 'Pedido en punto de prueba:');
      return event;
    }).toList(),
    simulation: json['simulation'] == null
        ? null
        : TrackingSimulation.fromJson(
            Map<String, dynamic>.from(json['simulation'] as Map),
          ),
  );
}

abstract interface class TrackingRepository {
  Future<TrackingData> loadTracking(String orderId);
  Future<TrackingData> advanceSimulation(String orderId, int version);
  Future<TrackingData> resetSimulation(String orderId, int version);
}
