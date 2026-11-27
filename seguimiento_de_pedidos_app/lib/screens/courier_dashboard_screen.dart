import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/order.dart';
import '../services/app_service.dart';
import '../widgets/order_chat_sheet.dart';
import '../widgets/order_contact_button.dart';
import '../widgets/phone_requirement.dart';

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  List<Order> _available = [];
  List<Order> _mine = [];
  bool _loading = true;
  String? _busyOrderId;
  StreamSubscription? _wsSub;
  Timer? _clockTimer;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _mine.any((o) => o.rawStatus != 'delivered')) {
        setState(() {});
      }
    });
    _wsSub = AppService().realtimeEvents.listen((event) {
      final type = event['type'];
      if (type == 'order_updated' || type == 'new_order') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await AppService().loadCourierOrders();
      if (mounted) {
        setState(() {
          _available = res.available;
          _mine = res.mine;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(String orderId, Future<void> Function() fn) async {
    if (_busyOrderId != null) return;
    setState(() => _busyOrderId = orderId);
    try {
      await fn();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _moveStepTowardDelivery(Order order) async {
    final curLat = order.courierLat ?? order.pickupLat ?? -8.1205;
    final curLng = order.courierLng ?? order.pickupLng ?? -79.0355;
    final targetLat = order.rawStatus == 'ready_for_pickup'
        ? (order.pickupLat ?? -8.1205)
        : (order.deliveryLat ?? -8.1065);
    final targetLng = order.rawStatus == 'ready_for_pickup'
        ? (order.pickupLng ?? -79.0355)
        : (order.deliveryLng ?? -79.0205);

    final nextLat = curLat + (targetLat - curLat) * 0.35;
    final nextLng = curLng + (targetLng - curLng) * 0.35;
    await _runAction(
      order.id,
      () => AppService().sendCourierLocation(order.id, nextLat, nextLng),
    );
  }

  Future<void> _uploadProofAndDeliver(Order order) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked == null) return;
    final Uint8List bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    await _runAction(
      order.id,
      () => AppService().deliverOrderWithProof(order.id, bytes, mimeType: mime),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Entrega confirmada con evidencia fotográfica!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openChat(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderChatSheet(
        orderId: order.id,
        title: 'Chat con ${order.customerName ?? 'Cliente'}',
      ),
    );
  }

  String _formatElapsed(Order order) {
    if (order.deliveryDurationSeconds != null) {
      final s = order.deliveryDurationSeconds!;
      return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    }
    final start = order.acceptedAt ?? order.createdAt;
    final diff = DateTime.now().difference(start).inSeconds.clamp(0, 999999);
    return '${(diff ~/ 60).toString().padLeft(2, '0')}:${(diff % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = AppService().currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final deliveredEarnings = _mine
        .where((o) => o.rawStatus == 'delivered')
        .fold<double>(0, (s, o) => s + o.deliveryFee);

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.delivery_dining_rounded),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Repartidor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Ganancias acumuladas: \$${deliveredEarnings.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 0,
                            label: Text('Disponibles (${_available.length})'),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('Mis entregas (${_mine.length})'),
                            icon: const Icon(Icons.route_outlined),
                          ),
                        ],
                        selected: {_tabIndex},
                        onSelectionChanged: (v) =>
                            setState(() => _tabIndex = v.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tabIndex == 0) ...[
                if (_available.isEmpty)
                  _emptyCard(
                    'No hay pedidos listos para recojo en este momento',
                  )
                else
                  for (final order in _available)
                    _buildAvailableCard(order, colorScheme),
              ] else ...[
                if (_mine.isEmpty)
                  _emptyCard('Aún no has aceptado ningún pedido')
                else
                  for (final order in _mine)
                    _buildMyOrderCard(order, colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String msg) => Card(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ),
  );

  Widget _buildAvailableCard(Order order, ColorScheme colorScheme) {
    final busy = _busyOrderId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ganarás: \$${order.deliveryFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Recoger en: ${order.branchName ?? 'Sede'} · ${order.pickupAddress}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Entregar en: ${order.deliveryAddress}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Productos: ${order.items.map((e) => '${e.quantity}x ${e.product.name}').join(', ')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => _runAction(order.id, () async {
                      if (!await ensureContactPhone(context) || !mounted)
                        return;
                      await AppService().acceptOrder(order.id);
                      if (mounted) setState(() => _tabIndex = 1);
                    }),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Aceptar pedido'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyOrderCard(Order order, ColorScheme colorScheme) {
    final busy = _busyOrderId == order.id;
    final isDelivered = order.rawStatus == 'delivered';
    final pickup = LatLng(
      order.pickupLat ?? -8.1205,
      order.pickupLng ?? -79.0355,
    );
    final delivery = LatLng(
      order.deliveryLat ?? -8.1065,
      order.deliveryLng ?? -79.0205,
    );
    final courierPos = LatLng(
      order.courierLat ?? pickup.latitude,
      order.courierLng ?? pickup.longitude,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${order.id} · ${order.statusLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text(_formatElapsed(order)),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(
                        '+\$${order.deliveryFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Recojo: ${order.branchName ?? 'Sede'} — ${order.pickupAddress}',
            ),
            Text('Entrega: ${order.deliveryAddress}'),
            const SizedBox(height: 12),
            if (!isDelivered) ...[
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: courierPos,
                      initialZoom: 14.2,
                      onTap: (_, point) {
                        _runAction(
                          order.id,
                          () => AppService().sendCourierLocation(
                            order.id,
                            point.latitude,
                            point.longitude,
                          ),
                        );
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'TrackosAcademicDemo/1.0',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [pickup, delivery],
                            color: Colors.blueGrey,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickup,
                            width: 36,
                            height: 36,
                            child: const Tooltip(
                              message: 'Punto de recojo (Tienda)',
                              child: CircleAvatar(
                                backgroundColor: Color(0xFF2563EB),
                                child: Icon(
                                  Icons.store,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: delivery,
                            width: 36,
                            height: 36,
                            child: const Tooltip(
                              message: 'Punto de entrega (Cliente)',
                              child: CircleAvatar(
                                backgroundColor: Color(0xFF059669),
                                child: Icon(
                                  Icons.home,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Marker(
                            point: courierPos,
                            width: 42,
                            height: 42,
                            child: CircleAvatar(
                              backgroundColor: colorScheme.primary,
                              child: const Icon(
                                Icons.delivery_dining,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toca el mapa o usa "Avanzar GPS" para enviar tu ubicación en tiempo real al cliente.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isDelivered)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _moveStepTowardDelivery(order),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Avanzar GPS'),
                  ),
                if (order.rawStatus == 'ready_for_pickup')
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _runAction(
                            order.id,
                            () => AppService().arrivedAtStore(order.id),
                          ),
                    icon: const Icon(Icons.storefront),
                    label: const Text('Llegué a la tienda'),
                  ),
                if (order.rawStatus == 'courier_arrived_store')
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _runAction(
                            order.id,
                            () => AppService().pickupOrder(order.id),
                          ),
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Recogí · En camino'),
                  ),
                if (order.rawStatus == 'in_transit')
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _runAction(
                            order.id,
                            () => AppService().arrivedAtDestination(order.id),
                          ),
                    icon: const Icon(Icons.location_on),
                    label: const Text('Llegué al punto de entrega'),
                  ),
                if (order.rawStatus == 'arrived_destination' ||
                    order.rawStatus == 'in_transit')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                    ),
                    onPressed: busy
                        ? null
                        : () => _uploadProofAndDeliver(order),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Subir foto y Entregar'),
                  ),
                OrderContactButton(
                  orderId: order.id,
                  label: 'Llamar al cliente',
                  isClosed: isDelivered,
                ),
                OutlinedButton.icon(
                  onPressed: () => _openChat(order),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat con cliente'),
                ),
              ],
            ),
            if (isDelivered && order.deliveryProofImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  AppService().resolveMediaUrl(order.deliveryProofImage),
                  height: 160,
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
}
