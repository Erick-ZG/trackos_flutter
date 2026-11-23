import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tracking.dart';
import '../services/app_service.dart';
import '../widgets/tracking_map.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final TrackingRepository? repository;
  const TrackingScreen({super.key, required this.orderId, this.repository});
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
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppService();
    _load();
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final sim = data?.simulation;
    final canOperate =
        !_busy && !_animating && !_needsRefresh && sim != null && sim.enabled;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento del pedido'),
        actions: [
          IconButton(
            tooltip: 'Actualizar seguimiento',
            onPressed: _busy || _animating ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: data == null && _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Chip(
                  avatar: Icon(Icons.science_outlined),
                  label: Text('Simulación académica'),
                ),
                Text(
                  widget.orderId,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: _busy ? null : _load,
                            child: const Text('Reintentar actualización'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_busy) const LinearProgressIndicator(),
                if (data != null) ...[
                  Text(
                    data.statusLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (sim != null) ...[
                    TrackingMap(
                      simulation: sim,
                      onAnimationFinished: () {
                        _animationTimeout?.cancel();
                        if (mounted) setState(() => _animating = false);
                      },
                    ),
                    Text(
                      sim.routeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(sim.notice),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: sim.progress),
                    const SizedBox(height: 8),
                    Text(
                      'Tramos completados: ${sim.currentNodeIndex} de ${sim.nodes.length - 1}',
                    ),
                    Text('Ubicación: ${sim.currentNode.name}'),
                    if (!sim.delivered)
                      Text(
                        'Siguiente: ${sim.nodes[sim.currentNodeIndex + 1].name}',
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canOperate && !sim.delivered
                          ? () => _mutate()
                          : null,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(
                        sim.delivered
                            ? 'Entrega completada'
                            : 'Avanzar al siguiente punto',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: canOperate ? () => _mutate(reset: true) : null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reiniciar simulación'),
                    ),
                    if (!sim.enabled)
                      const Text(
                        'Los controles de demostración están deshabilitados en el servidor.',
                      ),
                    const Divider(height: 24),
                    for (var i = 0; i < sim.nodes.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          i <= sim.currentNodeIndex
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: i <= sim.currentNodeIndex
                              ? Colors.deepOrange
                              : Colors.grey,
                        ),
                        title: Text('$i. ${sim.nodes[i].name}'),
                        trailing: i == sim.currentNodeIndex
                            ? const Text('Actual')
                            : null,
                      ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Este pedido no tiene ruta simulada. Crea un pedido nuevo con el modo demostración habilitado.',
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Código: ${data.shipment['tracking_code']?.toString() ?? 'No asignado'}',
                        ),
                      ),
                      if (data.shipment['tracking_code'] != null)
                        IconButton(
                          tooltip: 'Copiar código',
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text: data.shipment['tracking_code'].toString(),
                            ),
                          ),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                    ],
                  ),
                  Text(
                    'Courier: ${data.shipment['courier_name']?.toString() ?? 'No asignado'}',
                  ),
                  if (data.shipment['courier_phone'] != null)
                    Text('Contacto demo: ${data.shipment['courier_phone']}'),
                  Text(
                    'Destino: ${data.shipment['delivery_address']?.toString() ?? 'Por confirmar'}',
                  ),
                  if (data.shipment['delivered_at'] != null)
                    const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Entrega simulada confirmada'),
                    ),
                  const Divider(height: 24),
                  Text(
                    'Historial del ensayo actual',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final event in data.events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(event['description'].toString()),
                      subtitle: Text(
                        '${event['location']?.toString() ?? ''}\n${_date(event['occurred_at'])}',
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw.toString())?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
