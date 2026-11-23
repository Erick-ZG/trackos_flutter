import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_de_pedidos_app/models/tracking.dart';
import 'package:seguimiento_de_pedidos_app/widgets/tracking_map.dart';

const nodes = [
  RouteNode(name: 'Origen', latitude: -8.1261, longitude: -79.0361),
  RouteNode(name: 'Paso', latitude: -8.1116, longitude: -79.0288),
  RouteNode(name: 'Destino', latitude: -8.0988, longitude: -79.0205),
];
TrackingSimulation simulation(int index) => TrackingSimulation(
  enabled: true,
  nodes: nodes,
  currentNodeIndex: index,
  version: index,
  runId: 'demo',
  routeName: 'Trujillo',
  notice: 'Ruta ilustrativa',
);
void main() {
  Future<void> show(WidgetTester tester, int index) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackingMap(simulation: simulation(index), loadTiles: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'OpenStreetMap es la vista inicial y conserva atribución y marcadores',
    (tester) async {
      await show(tester, 0);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        4,
      );
      await show(tester, 1);
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.last.point.latitude, nodes[1].latitude);
      expect(markers.last.point.longitude, nodes[1].longitude);
    },
  );
  testWidgets('Permite alternar esquema y mapa y volver a centrar', (
    tester,
  ) async {
    await show(tester, 0);
    await tester.tap(find.text('Vista esquemática'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Ver OpenStreetMap'), findsOneWidget);
    await tester.tap(find.text('Ver OpenStreetMap'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    await tester.tap(find.text('Centrar ruta'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
