import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/order.dart';
import '../services/app_service.dart';
import '../widgets/phone_requirement.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _addrCtrl = TextEditingController();
  final MapController _mapCtrl = MapController();

  LatLng _dropoff = const LatLng(-8.1065, -79.0205);
  bool _locating = true;
  bool _submitting = false;
  bool _mapExpanded = false;
  String? _locationNote;

  @override
  void initState() {
    super.initState();
    final userAddr = AppService().currentUser?.address.trim() ?? '';
    _addrCtrl.text =
        userAddr.isNotEmpty && !userAddr.toLowerCase().contains('ficticio')
        ? userAddr
        : 'Mi ubicación actual';
    _detectMyLocation();
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectMyLocation() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locating = false;
          _locationNote =
              'GPS desactivado. Toca el mapa para fijar tu punto exacto.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _locationNote = 'Permiso de ubicación denegado. Toca el mapa para elegir tu punto.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      final detected = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _dropoff = detected;
        _locating = false;
        _locationNote = 'Ubicación actual detectada';
      });
      _mapCtrl.move(detected, 16);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationNote = 'No se pudo obtener tu GPS automático. Toca el mapa para fijar tu punto.';
      });
    }
  }

  Future<void> _confirmOrder() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (!await ensureContactPhone(context) || !mounted) return;
      final Order order = await AppService().placeOrder(
        deliveryAddress: _addrCtrl.text.trim().isEmpty
            ? 'Punto en mapa (${_dropoff.latitude.toStringAsFixed(5)}, ${_dropoff.longitude.toStringAsFixed(5)})'
            : _addrCtrl.text.trim(),
        deliveryLat: _dropoff.latitude,
        deliveryLng: _dropoff.longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 860;

    final mapWidget = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _dropoff,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 19,
              onTap: (_, pt) => setState(() {
                _dropoff = pt;
                _locationNote = 'Punto seleccionado en el mapa';
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'TrackosAcademicDemo/1.0',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _dropoff,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_locating)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Detectando tu ubicación...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'my_loc',
                  tooltip: 'Usar mi ubicación actual',
                  backgroundColor: Colors.white,
                  foregroundColor: colorScheme.primary,
                  onPressed: _detectMyLocation,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  tooltip: 'Acercar',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  onPressed: () {
                    final cam = _mapCtrl.camera;
                    _mapCtrl.move(cam.center, (cam.zoom + 1).clamp(4, 19));
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  tooltip: 'Alejar',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  onPressed: () {
                    final cam = _mapCtrl.camera;
                    _mapCtrl.move(cam.center, (cam.zoom - 1).clamp(4, 19));
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'expand_map',
                  tooltip: _mapExpanded ? 'Reducir mapa' : 'Ampliar mapa',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  onPressed: () => setState(() => _mapExpanded = !_mapExpanded),
                  child: Icon(
                    _mapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final summaryPanel = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Detalles de entrega',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addrCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección o referencia de entrega',
                hintText: 'Ej. Av. Larco 450, Dpto 302',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationNote ?? 'Toca cualquier punto del mapa para mover el puntero rojo.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coordenadas: ${_dropoff.latitude.toStringAsFixed(5)}, ${_dropoff.longitude.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal productos:'),
                Text(
                  '\$${AppService().cartTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Costo de envío:'),
                Text(
                  'Calculado por distancia (\$5 - \$15)',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _confirmOrder,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _submitting ? 'Procesando pedido...' : 'Confirmar pedido',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar ubicación de entrega')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _mapExpanded
                ? Column(
                    children: [
                      Expanded(child: mapWidget),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _confirmOrder,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirmar este punto y pedir'),
                        ),
                      ),
                    ],
                  )
                : isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.78,
                          child: mapWidget,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(child: summaryPanel),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.48,
                        child: mapWidget,
                      ),
                      const SizedBox(height: 12),
                      summaryPanel,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
