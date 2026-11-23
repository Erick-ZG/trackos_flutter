import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/tracking.dart';

class TrackingMap extends StatefulWidget {
  final TrackingSimulation simulation;
  final VoidCallback? onAnimationFinished;
  const TrackingMap({
    super.key,
    required this.simulation,
    this.onAnimationFinished,
  });
  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  GoogleMapController? _map;
  late LatLng _from;
  late LatLng _to;
  bool _schematic = false;
  static const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  bool get _canShowMap =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _apiKey.isNotEmpty;
  LatLng _point(RouteNode n) => LatLng(n.latitude, n.longitude);
  LatLng get _position => LatLng(
    _from.latitude + (_to.latitude - _from.latitude) * _animation.value,
    _from.longitude + (_to.longitude - _from.longitude) * _animation.value,
  );
  @override
  void initState() {
    super.initState();
    _from = _to = _point(widget.simulation.currentNode);
    _animation =
        AnimationController(
            vsync: this,
            duration: const Duration(seconds: 2),
            value: 1,
          )
          ..addListener(() => setState(() {}))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onAnimationFinished?.call();
            }
          });
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.simulation;
    final next = widget.simulation;
    if (previous.runId != next.runId ||
        previous.currentNodeIndex != next.currentNodeIndex) {
      _from = previous.runId == next.runId
          ? _position
          : _point(next.currentNode);
      _to = _point(next.currentNode);
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _center() async {
    final controller = _map;
    if (controller == null) return;
    final nodes = widget.simulation.nodes;
    final lats = nodes.map((n) => n.latitude);
    final lngs = nodes.map((n) => n.longitude);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.simulation;
    final showMap = _canShowMap && !_schematic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 290,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: showMap
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _point(sim.nodes[sim.nodes.length ~/ 2]),
                      zoom: 13,
                    ),
                    onMapCreated: (controller) {
                      _map = controller;
                      _center();
                    },
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    markers: {
                      for (var i = 0; i < sim.nodes.length; i++)
                        Marker(
                          markerId: MarkerId('node-$i'),
                          position: _point(sim.nodes[i]),
                          infoWindow: InfoWindow(title: sim.nodes[i].name),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            i == 0
                                ? BitmapDescriptor.hueGreen
                                : BitmapDescriptor.hueAzure,
                          ),
                        ),
                      Marker(
                        markerId: const MarkerId('courier'),
                        position: _position,
                        zIndexInt: 10,
                        infoWindow: const InfoWindow(
                          title: 'Repartidor simulado',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                      ),
                    },
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: sim.nodes.map(_point).toList(),
                        color: Colors.blueGrey,
                        width: 4,
                      ),
                      Polyline(
                        polylineId: const PolylineId('completed'),
                        points: [
                          ...sim.nodes.take(sim.currentNodeIndex).map(_point),
                          _position,
                        ],
                        color: Colors.deepOrange,
                        width: 6,
                      ),
                    },
                  )
                : ColoredBox(
                    color: const Color(0xFFF0F4F6),
                    child: CustomPaint(
                      painter: _RoutePainter(sim.nodes, _position),
                      child: const Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Vista esquemática · Trujillo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            if (showMap)
              TextButton.icon(
                onPressed: _center,
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Centrar ruta'),
              ),
            if (_canShowMap)
              TextButton(
                onPressed: () => setState(() => _schematic = !_schematic),
                child: Text(
                  _schematic ? 'Ver Google Maps' : 'Vista esquemática',
                ),
              ),
          ],
        ),
        if (!_canShowMap)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Google Maps requiere Android y una clave configurada. Puedes ensayar con esta vista esquemática.',
            ),
          ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<RouteNode> nodes;
  final LatLng position;
  _RoutePainter(this.nodes, this.position);
  @override
  void paint(Canvas canvas, Size size) {
    final minLat = nodes.map((n) => n.latitude).reduce(math.min);
    final maxLat = nodes.map((n) => n.latitude).reduce(math.max);
    final minLng = nodes.map((n) => n.longitude).reduce(math.min);
    final maxLng = nodes.map((n) => n.longitude).reduce(math.max);
    Offset project(double lat, double lng) => Offset(
      38 +
          (lng - minLng) /
              math.max(maxLng - minLng, 0.0001) *
              (size.width - 76),
      size.height -
          32 -
          (lat - minLat) /
              math.max(maxLat - minLat, 0.0001) *
              (size.height - 96),
    );
    final points = nodes.map((n) => project(n.latitude, n.longitude)).toList();
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.blueGrey
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 12, Paint()..color = Colors.white);
      final text = TextPainter(
        text: TextSpan(
          text: '$i',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, points[i] - Offset(text.width / 2, text.height / 2));
    }
    canvas.drawCircle(
      project(position.latitude, position.longitude),
      9,
      Paint()..color = Colors.deepOrange,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.nodes != nodes;
}
