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
      throw const FormatException('Ruta de simulación inválida');
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

class TrackingData {
  final String orderId;
  final String status;
  final Map<String, dynamic> shipment;
  final List<Map<String, dynamic>> events;
  final TrackingSimulation? simulation;
  const TrackingData({
    required this.orderId,
    required this.status,
    required this.shipment,
    required this.events,
    this.simulation,
  });
  String get statusLabel => switch (status) {
    'in_transit' || 'shipped' => 'En camino',
    'out_for_delivery' => 'En reparto',
    'delivered' => 'Entregado',
    _ => 'Pendiente',
  };
  factory TrackingData.fromJson(Map<String, dynamic> json) => TrackingData(
    orderId: json['orderId'] as String,
    status: json['status'] as String,
    shipment: Map<String, dynamic>.from(json['shipment'] as Map? ?? {}),
    events: (json['events'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
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
