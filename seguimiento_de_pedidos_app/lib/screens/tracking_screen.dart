import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/tracking.dart';
import '../services/app_service.dart';
import '../widgets/order_chat_sheet.dart';
import '../widgets/order_contact_button.dart';
import '../widgets/tracking_map.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final TrackingRepository? repository;
  final bool loadMapTiles;
  const TrackingScreen({
    super.key,
    required this.orderId,
    this.repository,
    this.loadMapTiles = true,
  });
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  TrackingData? _data;
  String? _error;
  bool _busy = true;
  bool _animating = false;
  Timer? _animationTimeout;
  bool _needsRefresh = false;
  late final TrackingRepository _repository;
  StreamSubscription? _wsSub;
  double? _liveCourierLat;
  double? _liveCourierLng;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppService();
    if (widget.repository == null) {
      AppService().subscribeOrder(widget.orderId);
      _wsSub = AppService().realtimeEvents.listen((event) {
        final type = event['type'];
        final payload = event['payload'];
        if (payload is! Map || '${payload['orderId']}' != widget.orderId) {
          return;
        }
        if (type == 'courier_location') {
          if (mounted) {
            setState(() {
              _liveCourierLat = (payload['lat'] as num?)?.toDouble();
              _liveCourierLng = (payload['lng'] as num?)?.toDouble();
            });
          }
        } else if (type == 'order_updated') {
          _load();
        }
      });
    }
    _load();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _animationTimeout?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _repository.loadTracking(widget.orderId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _liveCourierLat = data.courierLat ?? _liveCourierLat;
        _liveCourierLng = data.courierLng ?? _liveCourierLng;
        _needsRefresh = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo actualizar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutate({bool reset = false}) async {
    final sim = _data?.simulation;
    if (sim == null || _busy || _animating || _needsRefresh) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = reset
          ? await _repository.resetSimulation(widget.orderId, sim.version)
          : await _repository.advanceSimulation(widget.orderId, sim.version);
      if (!mounted) return;
      setState(() {
        _data = data;
        _animating = true;
      });
      // ListView may dispose the map while scrolling. Never depend on its callback to unlock controls.
      _animationTimeout?.cancel();
      _animationTimeout = Timer(const Duration(milliseconds: 2100), () {
        if (mounted) setState(() => _animating = false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _needsRefresh = true;
        _error =
            'No se confirmó la operación. Actualiza antes de continuar: $error';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'delivered':
        return const Color(0xFF059669);
      case 'out_for_delivery':
      case 'arrived_destination':
      case 'courier_arrived_store':
        return scheme.primary;
      case 'in_transit':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFD97706);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'out_for_delivery':
      case 'courier_arrived_store':
        return Icons.delivery_dining_rounded;
      case 'arrived_destination':
        return Icons.location_on_rounded;
      case 'in_transit':
        return Icons.local_shipping_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  void _openChat(TrackingData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderChatSheet(
        orderId: widget.orderId,
        title: 'Chat con ${data.courierName ?? 'Repartidor'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final sim = data?.simulation;
    final colorScheme = Theme.of(context).colorScheme;
    final canOperate =
        !_busy && !_animating && !_needsRefresh && sim != null && sim.enabled;
    final hasRealtimeCoords =
        data != null &&
        data.pickupLat != null &&
        data.pickupLng != null &&
        data.deliveryLat != null &&
        data.deliveryLng != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento del pedido',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.orderId,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        actions: [
          if (data?.courierName != null && widget.repository == null)
            IconButton(
              tooltip: 'Chatear con repartidor',
              onPressed: () => _openChat(data!),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          IconButton(
            tooltip: 'Actualizar seguimiento',
            onPressed: _busy || _animating ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: data == null && _busy
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null)
                      Card(
                        color: colorScheme.errorContainer,
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: _busy ? null : _load,
                                child: const Text('Reintentar actualización'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (data != null) ...[
                      _buildHeaderCard(
                        context,
                        data,
                        sim,
                        hasRealtimeCoords,
                        colorScheme,
                      ),
                      const SizedBox(height: 10),
                      if (hasRealtimeCoords) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final liveMap = _buildLiveMapCard(
                              data,
                              colorScheme,
                            );
                            final workflowCard = _buildWorkflowCard(
                              data,
                              colorScheme,
                            );
                            if (constraints.maxWidth >= 900) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: liveMap),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 2, child: workflowCard),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                liveMap,
                                const SizedBox(height: 12),
                                workflowCard,
                              ],
                            );
                          },
                        ),
                      ] else if (sim != null) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final mapCard = Card(
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: TrackingMap(
                                  simulation: sim,
                                  loadTiles: widget.loadMapTiles,
                                  onAnimationFinished: () {
                                    _animationTimeout?.cancel();
                                    if (mounted) {
                                      setState(() => _animating = false);
                                    }
                                  },
                                ),
                              ),
                            );

                            final controlPanel = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSimulationControlsCard(
                                  context,
                                  sim,
                                  canOperate,
                                  colorScheme,
                                ),
                                const SizedBox(height: 14),
                                _buildRouteTimelineCard(
                                  context,
                                  sim,
                                  colorScheme,
                                ),
                              ],
                            );

                            if (constraints.maxWidth >= 900) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: mapCard),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 2, child: controlPanel),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                mapCard,
                                const SizedBox(height: 14),
                                controlPanel,
                              ],
                            );
                          },
                        ),
                      ] else
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Este pedido aún no tiene coordenadas de seguimiento.',
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final shipmentCard = _buildShipmentCard(
                            context,
                            data,
                            colorScheme,
                          );
                          final eventsCard = _buildEventsCard(context, data);
                          if (constraints.maxWidth >= 900) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: shipmentCard),
                                const SizedBox(width: 18),
                                Expanded(child: eventsCard),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              shipmentCard,
                              const SizedBox(height: 14),
                              eventsCard,
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    TrackingData data,
    TrackingSimulation? sim,
    bool hasRealtime,
    ColorScheme colorScheme,
  ) {
    final statusColor = _statusColor(data.status, colorScheme);
    final progress = hasRealtime
        ? data.workflowProgress
        : (sim?.progress ?? data.workflowProgress);
    final headline = hasRealtime
        ? data.statusLabel
        : (sim != null
              ? (sim.delivered
                    ? 'Tu pedido llegó a su destino'
                    : 'Ubicación actual: ${sim.currentNode.name}')
              : data.statusLabel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(data.status),
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        data.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.repository == null &&
                    AppService().currentUser?.isCustomer == true)
                  OrderContactButton(
                    orderId: widget.orderId,
                    label: 'Llamar al repartidor',
                    isClosed:
                        data.status == 'delivered' ||
                        data.status == 'cancelled' ||
                        data.status == 'canceled',
                  ),
                if (data.courierName != null && widget.repository == null)
                  FilledButton.tonalIcon(
                    onPressed: () => _openChat(data),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text('Mensaje a ${data.courierName}'),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.science_outlined, size: 16),
                    label: Text('Tiempo real', style: TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    headline,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMapCard(TrackingData data, ColorScheme colorScheme) {
    final pickup = LatLng(data.pickupLat!, data.pickupLng!);
    final delivery = LatLng(data.deliveryLat!, data.deliveryLng!);
    final courierLat = _liveCourierLat ?? data.courierLat;
    final courierLng = _liveCourierLng ?? data.courierLng;
    final hasCourier = courierLat != null && courierLng != null;
    final points = [
      pickup,
      delivery,
      if (hasCourier) LatLng(courierLat, courierLng),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 360,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 16,
                    ),
                  ),
                  children: [
                    if (widget.loadMapTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'TrackosAcademicDemo/1.0',
                      ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [pickup, delivery],
                          color: Colors.blueGrey.shade300,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pickup,
                          width: 40,
                          height: 40,
                          child: Tooltip(
                            message:
                                'Recojo: ${data.branchName ?? 'Sede'} (${data.pickupAddress ?? ''})',
                            child: const CircleAvatar(
                              backgroundColor: Color(0xFF2563EB),
                              child: Icon(
                                Icons.store,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Marker(
                          point: delivery,
                          width: 40,
                          height: 40,
                          child: Tooltip(
                            message:
                                'Tu punto de entrega: ${data.deliveryAddress ?? ''}',
                            child: const CircleAvatar(
                              backgroundColor: Color(0xFF059669),
                              child: Icon(
                                Icons.home,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        if (hasCourier)
                          Marker(
                            point: LatLng(courierLat, courierLng),
                            width: 46,
                            height: 46,
                            child: Tooltip(
                              message:
                                  '${data.courierName ?? 'Repartidor'} en vivo',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delivery_dining,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _legendItem(
                  const Color(0xFF2563EB),
                  Icons.store,
                  'Punto de recojo',
                ),
                _legendItem(
                  colorScheme.primary,
                  Icons.delivery_dining,
                  'Motorizado en vivo',
                ),
                _legendItem(const Color(0xFF059669), Icons.home, 'Tu entrega'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _buildWorkflowCard(TrackingData data, ColorScheme colorScheme) {
    final steps = [
      ('stock_verified', 'Stock verificado en almacén'),
      ('preparing', 'Preparado'),
      ('ready_for_pickup', 'Listo para recojo'),
      (
        'courier_arrived_store',
        '${data.courierName ?? 'Repartidor'} llegó a la tienda',
      ),
      ('in_transit', 'En camino'),
      ('arrived_destination', 'Llegó al punto de entrega'),
      ('delivered', 'Entregado'),
    ];
    final orderIndex = steps.indexWhere((s) => s.$1 == data.status);
    final activeIdx = orderIndex == -1 ? 0 : orderIndex;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado del pedido',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Recojo: ${data.branchName ?? 'Sede'} · ${data.pickupAddress ?? ''}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            Text(
              'Entrega: ${data.deliveryAddress ?? ''}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            const Divider(height: 18),
            for (var i = 0; i < steps.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: i <= activeIdx
                              ? colorScheme.primary
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          i < activeIdx
                              ? Icons.check
                              : (i == activeIdx
                                    ? Icons.radio_button_checked
                                    : Icons.circle),
                          size: i <= activeIdx ? 14 : 8,
                          color: i <= activeIdx
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (i < steps.length - 1)
                        Container(
                          width: 2,
                          height: 20,
                          color: i < activeIdx
                              ? colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      child: Text(
                        steps[i].$2,
                        style: TextStyle(
                          fontWeight: i == activeIdx
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i <= activeIdx
                              ? const Color(0xFF0F172A)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (data.deliveryProofImage != null &&
                data.deliveryProofImage!.isNotEmpty) ...[
              const Divider(height: 18),
              const Text(
                'Evidencia fotográfica de entrega',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  AppService().resolveMediaUrl(data.deliveryProofImage),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationControlsCard(
    BuildContext context,
    TrackingSimulation sim,
    bool canOperate,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: canOperate && !sim.delivered ? () => _mutate() : null,
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                sim.delivered
                    ? 'Entrega completada'
                    : 'Avanzar al siguiente punto',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canOperate ? () => _mutate(reset: true) : null,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reiniciar prueba'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.route_rounded, color: colorScheme.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sim.routeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sim.notice,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tramos completados: ${sim.currentNodeIndex} de ${sim.nodes.length - 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ubicación: ${sim.currentNode.name}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                  if (!sim.delivered) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Siguiente: ${sim.nodes[sim.currentNodeIndex + 1].name}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!sim.enabled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Los controles de demostración están deshabilitados en el servidor.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteTimelineCard(
    BuildContext context,
    TrackingSimulation sim,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recorrido en tiempo real',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < sim.nodes.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: i <= sim.currentNodeIndex
                              ? colorScheme.primary
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          i < sim.currentNodeIndex
                              ? Icons.check
                              : (i == sim.currentNodeIndex
                                    ? Icons.delivery_dining
                                    : Icons.circle),
                          size: i <= sim.currentNodeIndex ? 15 : 8,
                          color: i <= sim.currentNodeIndex
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (i < sim.nodes.length - 1)
                        Container(
                          width: 2,
                          height: 24,
                          color: i < sim.currentNodeIndex
                              ? colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3, bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$i. ${sim.nodes[i].name}',
                              style: TextStyle(
                                fontWeight: i == sim.currentNodeIndex
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: i <= sim.currentNodeIndex
                                    ? const Color(0xFF0F172A)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          if (i == sim.currentNodeIndex)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Actual',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentCard(
    BuildContext context,
    TrackingData data,
    ColorScheme colorScheme,
  ) {
    final trackingCode = data.shipment['tracking_code']?.toString();
    final dur = data.deliveryDurationSeconds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalles del envío',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Código: ${trackingCode ?? 'No asignado'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (trackingCode != null)
                  IconButton(
                    tooltip: 'Copiar código',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: trackingCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado al portapapeles'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Repartidor: ${data.courierName ?? 'Por asignar'}'),
            Text('Costo de delivery: \$${data.deliveryFee.toStringAsFixed(2)}'),
            if (dur != null)
              Text(
                'Tiempo total de entrega: ${dur ~/ 60}m ${dur % 60}s',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 4),
            Text('Destino: ${data.deliveryAddress ?? 'Por confirmar'}'),
            if (data.shipment['delivered_at'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Text(
                      'Entrega confirmada',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventsCard(BuildContext context, TrackingData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial en tiempo real',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (data.events.isEmpty)
              Text(
                'Sin eventos registrados todavía.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              for (final event in data.events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(
                    event['description'].toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${event['location']?.toString() ?? ''}\n${_date(event['occurred_at'])}',
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw.toString())?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
