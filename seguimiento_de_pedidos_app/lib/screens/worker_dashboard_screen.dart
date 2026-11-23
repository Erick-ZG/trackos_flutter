import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/app_service.dart';
import '../widgets/product_card.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _busyOrderId;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = AppService().realtimeEvents.listen((event) {
      final type = event['type'];
      if (type == 'new_order' || type == 'order_updated') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await AppService().loadWorkerOrders();
      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runAction(String orderId, Future<void> Function() action) async {
    setState(() => _busyOrderId = orderId);
    try {
      await action();
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

  @override
  Widget build(BuildContext context) {
    final user = AppService().currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.store_rounded),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.branchName ?? 'Sede asignada',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dirección de recojo: ${user?.branchAddress ?? 'No configurada'}',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar pedidos',
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
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
              else if (_orders.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No hay pedidos asignados a esta sede todavía',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final order in _orders) _buildOrderTile(order, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTile(Order order, ColorScheme colorScheme) {
    final busy = _busyOrderId == order.id;
    final canPrepare =
        order.rawStatus == 'stock_verified' || order.rawStatus == 'pending';
    final canReady = order.rawStatus == 'preparing';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  '${order.id} · ${order.customerName ?? 'Cliente'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Chip(
                  label: Text(
                    order.statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Destino cliente: ${order.deliveryAddress}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            if (order.courierName != null)
              Text(
                'Repartidor asignado: ${order.courierName}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const Divider(height: 18),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: ProductImage(
                          product: item.product,
                          fallbackIconSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.product.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (canPrepare)
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _runAction(
                            order.id,
                            () => AppService().prepareOrder(order.id),
                          ),
                    icon: const Icon(Icons.inventory_rounded),
                    label: const Text('Alistar y marcar Preparado'),
                  ),
                if (canReady)
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _runAction(
                            order.id,
                            () => AppService().markOrderReady(order.id),
                          ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Listo para recojo'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
