import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_de_pedidos_app/models/tracking.dart';
import 'package:seguimiento_de_pedidos_app/screens/tracking_screen.dart';

class FakeTracking implements TrackingRepository {
  int index = 0;
  int version = 0;
  int advances = 0;
  int run = 0;
  bool fail = false;
  bool enabled = true;
  TrackingData get data => TrackingData(
    orderId: 'ORD-TEST',
    status: [
      'pending',
      'in_transit',
      'in_transit',
      'out_for_delivery',
      'delivered',
    ][index],
    shipment: const {},
    events: const [],
    simulation: TrackingSimulation(
      enabled: enabled,
      nodes: List.generate(
        5,
        (i) => RouteNode(
          name: 'Punto $i',
          latitude: -8.12 + i * 0.001,
          longitude: -79.03 + i * 0.001,
        ),
      ),
      currentNodeIndex: index,
      version: version,
      runId: '$run',
      routeName: 'Trujillo',
      notice: 'Ruta ilustrativa',
    ),
  );
  @override
  Future<TrackingData> loadTracking(String id) async => data;
  @override
  Future<TrackingData> advanceSimulation(String id, int expected) async {
    advances++;
    if (fail) throw Exception('Sin conexión');
    if (expected != version) throw Exception('Conflicto');
    index++;
    version++;
    return data;
  }

  @override
  Future<TrackingData> resetSimulation(String id, int expected) async {
    index = 0;
    version++;
    run++;
    return data;
  }
}

void main() {
  Future<void> open(WidgetTester tester, FakeTracking repo) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingScreen(
          orderId: 'ORD-TEST',
          repository: repo,
          loadMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAdvance(WidgetTester tester) async {
    final button = find.text('Avanzar al siguiente punto');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Avance manual, bloqueo durante animación y final de ruta', (
    tester,
  ) async {
    final repo = FakeTracking();
    await open(tester, repo);
    expect(find.text('Tramos completados: 0 de 4'), findsOneWidget);
    await tester.ensureVisible(find.text('Avanzar al siguiente punto'));
    await tester.tap(find.text('Avanzar al siguiente punto'));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Avanzar al siguiente punto'),
    );
    expect(button.onPressed, isNull);
    await tester.pumpAndSettle();
    expect(repo.advances, 1);
    expect(find.text('Tramos completados: 1 de 4'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapAdvance(tester);
    }
    expect(find.text('Entrega completada'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Entrega completada'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Reiniciar prueba'));
    await tester.tap(find.text('Reiniciar prueba'));
    await tester.pumpAndSettle();
    expect(repo.index, 0);
    expect(find.text('Tramos completados: 0 de 4'), findsOneWidget);
  });
  testWidgets('Un fallo conserva posición y exige actualizar', (tester) async {
    final repo = FakeTracking()..fail = true;
    await open(tester, repo);
    await tapAdvance(tester);
    expect(repo.index, 0);
    expect(find.textContaining('No se confirmó la operación'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Avanzar al siguiente punto'),
          )
          .onPressed,
      isNull,
    );
    repo.fail = false;
    await tester.tap(find.byTooltip('Actualizar seguimiento'));
    await tester.pumpAndSettle();
    await tapAdvance(tester);
    expect(repo.index, 1);
  });
  testWidgets('Recupera posición y respeta modo de solo lectura', (
    tester,
  ) async {
    final repo = FakeTracking()
      ..index = 2
      ..enabled = false;
    await open(tester, repo);
    expect(find.text('Tramos completados: 2 de 4'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Avanzar al siguiente punto'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('Desplazar el mapa fuera de pantalla no bloquea los controles', (
    tester,
  ) async {
    final repo = FakeTracking();
    await open(tester, repo);
    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpAndSettle();
    final advance = find.text('Avanzar al siguiente punto');
    await tester.ensureVisible(advance);
    await tester.tap(advance);
    await tester.pump();
    await tester.dragFrom(const Offset(425, 750), const Offset(0, -1600));
    await tester.pump(const Duration(seconds: 3));
    await tester.ensureVisible(advance);
    await tester.pumpAndSettle();
    expect(repo.index, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Avanzar al siguiente punto'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('En escritorio el mapa y el avance quedan visibles lado a lado', (
    tester,
  ) async {
    final repo = FakeTracking();
    await open(tester, repo);
    tester.view.physicalSize = const Size(1280, 720);
    await tester.pumpAndSettle();
    final map = tester.getRect(find.byType(FlutterMap));
    final advance = tester.getRect(
      find.widgetWithText(FilledButton, 'Avanzar al siguiente punto'),
    );
    expect(advance.left, greaterThan(map.right));
    expect(advance.bottom, lessThan(720));
    expect(map.bottom, lessThan(720));
    await tester.tap(find.text('Avanzar al siguiente punto'));
    await tester.pumpAndSettle();
    expect(repo.index, 1);
  });

  test('Rechaza un índice de ruta inválido al decodificar', () {
    expect(
      () => TrackingSimulation.fromJson({
        'route': {
          'nodes': [
            {'name': 'Origen', 'latitude': -8, 'longitude': -79},
          ],
        },
        'currentNodeIndex': 8,
      }),
      throwsFormatException,
    );
  });
}
