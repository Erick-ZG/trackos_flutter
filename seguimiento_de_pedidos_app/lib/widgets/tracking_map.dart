import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../models/tracking.dart';

class TrackingMap extends StatefulWidget {
  final TrackingSimulation simulation;
  final VoidCallback? onAnimationFinished;
  // Disable external requests in widget tests while keeping the map and overlays.
  final bool loadTiles;
  const TrackingMap({
    super.key,
    required this.simulation,
    this.onAnimationFinished,
    this.loadTiles = true,
  });
  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final MapController _map = MapController();
  late LatLng _from;
  late LatLng _to;
  bool _schematic = false;
  bool _tileError = false;
  LatLng _point(RouteNode n) => LatLng(n.latitude, n.longitude);
  LatLng get _position => LatLng(
    _from.latitude + (_to.latitude - _from.latitude) * _animation.value,
    _from.longitude + (_to.longitude - _from.longitude) * _animation.value,
  );
  CameraFit get _routeFit => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(
      widget.simulation.nodes.map(_point).toList(),
    ),
    padding: const EdgeInsets.fromLTRB(36, 36, 36, 50),
    maxZoom: 15,
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
    _map.dispose();
    super.dispose();
  }

  void _reportTileError() {
    if (_tileError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.simulation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 340,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _schematic
                ? ColoredBox(
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
                  )
                : FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCameraFit: _routeFit,
                      minZoom: 10,
                      maxZoom: 18,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.all &
                            ~InteractiveFlag.rotate &
                            ~InteractiveFlag.scrollWheelZoom,
                      ),
                      backgroundColor: const Color(0xFFE8EEF0),
                    ),
                    children: [
                      if (widget.loadTiles)
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'TrackosAcademicDemo/1.0',
                          maxNativeZoom: 19,
                          errorTileCallback: (tile, error, stackTrace) =>
                              _reportTileError(),
                        ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: sim.nodes.map(_point).toList(),
                            color: Colors.blueGrey,
                            strokeWidth: 4,
                          ),
                          Polyline(
                            points: [
                              ...sim.nodes
                                  .take(sim.currentNodeIndex)
                                  .map(_point),
                              _position,
                            ],
                            color: Colors.deepOrange,
                            strokeWidth: 6,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          for (var i = 0; i < sim.nodes.length; i++)
                            Marker(
                              point: _point(sim.nodes[i]),
                              width: 32,
                              height: 32,
                              child: Tooltip(
                                message: sim.nodes[i].name,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: i <= sim.currentNodeIndex
                                        ? Colors.deepOrange
                                        : Colors.blueGrey,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$i',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Marker(
                            point: _position,
                            width: 44,
                            height: 44,
                            child: const Tooltip(
                              message: 'Repartidor de prueba',
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.local_shipping,
                                  color: Colors.deepOrange,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Material(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                '© OpenStreetMap contributors',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          children: [
            if (!_schematic)
              TextButton.icon(
                onPressed: () => _map.fitCamera(_routeFit),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Centrar ruta'),
              ),
            TextButton(
              onPressed: () => setState(() {
                _schematic = !_schematic;
                _tileError = false;
              }),
              child: Text(
                _schematic ? 'Ver OpenStreetMap' : 'Vista esquemática',
              ),
            ),
          ],
        ),
        if (_tileError && !_schematic)
          const Text(
            'No se pudo cargar parte del mapa. Comprueba Internet o utiliza Vista esquemática para continuar el ensayo.',
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
