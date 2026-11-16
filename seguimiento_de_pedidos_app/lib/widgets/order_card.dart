import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order.dart';
import '../services/app_service.dart';

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({super.key, required this.order});

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.inTransit:
        return Colors.blue;
      case OrderStatus.outForDelivery:
        return Colors.deepOrange;
      case OrderStatus.delivered:
        return Colors.green;
    }
  }

  IconData _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.inTransit:
        return Icons.local_shipping;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}  ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTracking(context),
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
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Chip(
                  avatar: Icon(_statusIcon(order.status),
                      color: _statusColor(order.status), size: 16),
                  label: Text(
                    order.statusLabel,
                    style: TextStyle(
                        color: _statusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  backgroundColor: _statusColor(order.status).withOpacity(0.1),
                  side: BorderSide(color: _statusColor(order.status), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 16),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(item.product.icon,
                          size: 18, color: item.product.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Total: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '\$${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showTracking(BuildContext context) async {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) =>
      FutureBuilder<Map<String, dynamic>>(
        future: AppService().tracking(order.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(24), child: Text('No se pudo cargar el seguimiento: ${snapshot.error}'));
          final data = snapshot.data!;
          final shipment = Map<String, dynamic>.from(data['shipment'] ?? {});
          final events = data['events'] as List? ?? [];
          return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Seguimiento ${order.id}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Código: ${shipment['tracking_code'] ?? 'No asignado'}')),
              if (shipment['tracking_code'] != null) IconButton(
                tooltip: 'Copiar código',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${shipment['tracking_code']}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código de seguimiento copiado')));
                },
              ),
            ]),
            Text('Courier: ${shipment['courier_name'] ?? 'Trackos Express'}'),
            if ((shipment['courier_phone'] ?? '').toString().isNotEmpty) Text('Contacto: ${shipment['courier_phone']}'),
            const Divider(height: 24),
            for (final raw in events) ...[
              Builder(builder: (context) {
                final event = Map<String, dynamic>.from(raw as Map);
                final at = DateTime.tryParse('${event['occurred_at']}')?.toLocal();
                final date = at == null ? '' : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.radio_button_checked, color: Colors.deepOrange), title: Text('${event['description']}'), subtitle: Text('${event['location']}\n$date'));
              }),
            ],
            if (shipment['delivered_at'] != null) const ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Entrega confirmada')),
          ]))));
        },
      ));
  }
}
