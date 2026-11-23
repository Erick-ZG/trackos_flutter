import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguimiento_de_pedidos_app/main.dart';

void main() {
  testWidgets('La aplicación abre el formulario de acceso', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pump();
    expect(find.text('Ingresa tu email'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });
}
