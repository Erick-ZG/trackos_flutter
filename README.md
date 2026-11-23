# Trackos — seguimiento simulado en Trujillo

Aplicación académica Flutter + Express + PostgreSQL. Incluye cuentas, catálogo, carrito, compra simulada y seguimiento manual por cinco nodos. Google Maps muestra el recorrido en Android; el backend administra el avance y lo conserva por pedido. No utiliza GPS, pagos, repartidores reales ni APIs de cálculo de rutas.

## Inicio rápido con Git Bash en Windows

Desde la raíz del repositorio:

```bash
docker compose up -d --build
curl http://localhost:3000/health
cd seguimiento_de_pedidos_app
flutter pub get
flutter devices
flutter run -d ID_DEL_DISPOSITIVO_ANDROID
```

Selecciona un Android conectado; el repositorio no crea un emulador automáticamente. Sin clave se usa una vista esquemática con los mismos controles y persistencia. Google Maps está habilitado únicamente para Android en esta entrega. En Chrome puede ensayarse la vista esquemática con `flutter run -d chrome`; iOS y escritorio no están validados.

Credenciales de demostración: **demo@test.com / 123456**. Si ya existe un volumen anterior, se conserva su usuario y dirección. Los nuevos envíos de demostración muestran un destino ficticio en Trujillo, independiente de la dirección del perfil.

La API publica el puerto **3000**. PostgreSQL publica **55432** en el host para evitar el conflicto observado con PostgreSQL local en Windows; dentro de Docker sigue usando **5432**. Puedes cambiar el puerto del host con `POSTGRES_PORT=55433 docker compose up -d`.

## Activar Google Maps en Android

1. Crear o elegir un proyecto de Google Cloud, habilitar facturación y **Maps SDK for Android**, y crear una clave. Revisar las tarifas vigentes de la cuenta.
2. Restringir la clave al SDK Android y al paquete `com.example.seguimiento_de_pedidos_app`, incluyendo el SHA-1 del certificado usado para firmar la aplicación.
3. Desde la carpeta Flutter, copiar la configuración y editar únicamente la copia local:

```bash
cp config/demo.example.json config/demo.local.json
```

Completar `GOOGLE_MAPS_API_KEY` con la clave. El archivo local está excluido de Git. Para un teléfono físico, cambiar `API_BASE_URL` a `http://IP_LAN_DEL_PC:3000`; el teléfono y el PC deben estar en la misma red y el firewall debe permitir el puerto. En Android Emulator se usa `http://10.0.2.2:3000`.

```bash
flutter run -d ID_DEL_DISPOSITIVO_ANDROID --dart-define-from-file=config/demo.local.json
```

El mismo parámetro configura la selección del mapa en Dart y la clave del manifiesto Android mediante Gradle. Requiere reconstruir la aplicación después de modificarlo; un hot reload no actualiza el manifiesto. Android mínimo: API 24. La clave móvil forma parte del APK: la exclusión de Git no sustituye las restricciones de Google Cloud.

Para obtener el SHA-1 desde Git Bash, con Java disponible:

```bash
keytool -list -v -alias androiddebugkey -keystore "$HOME/.android/debug.keystore" -storepass android -keypass android
```

El certificado de depuración se genera al compilar Android. La clave de Google Cloud y el acceso autorizado a la cuenta deben aportarse localmente; no se incluyen credenciales en el proyecto.

Documentación oficial: [paquete Google Maps Flutter](https://pub.dev/packages/google_maps_flutter), [configuración de Google Maps](https://developers.google.com/maps/flutter-package/config).

## Uso y alcance de la simulación

1. Iniciar sesión, agregar un producto y confirmar la compra.
2. Abrir **Mis Pedidos** y tocar el pedido nuevo.
3. Pulsar **Avanzar al siguiente punto**: el servidor confirma un nodo y el marcador realiza una transición visual de dos segundos. Durante la operación los controles se bloquean.
4. Repetir hasta llegar al destino. El estado pasa por pendiente, en camino, en reparto y entregado; la tarjeta también se actualiza al regresar.
5. **Reiniciar simulación** crea otro ensayo desde el origen. No realiza otra compra ni altera inventario, artículos o total. Los eventos anteriores permanecen en PostgreSQL; la pantalla muestra el ensayo actual.

Cada pedido tiene posición, versión e historial independientes aunque todos reutilizan la misma ruta. **Actualizar seguimiento** recupera el estado confirmado, también después de cerrar la aplicación y volver a iniciar sesión. No hay actualización automática entre dispositivos: usar ese botón o reabrir la pantalla.

Si una operación falla o su respuesta se pierde, la pantalla conserva la última posición conocida y exige actualizar antes de continuar: el servidor podría haber confirmado la operación. La versión esperada y el bloqueo transaccional evitan que dos pulsaciones con la misma versión salten dos nodos.

Los pedidos anteriores a esta funcionalidad siguen siendo consultables y no reciben una ruta automáticamente. Crear un pedido nuevo para ensayar.

### Recorrido

La definición está en [trujillo-route.json](backend/src/data/trujillo-route.json): almacén ficticio cerca del Óvalo Papal, referencia de avenida España, Plaza de Armas, plazuela El Recreo y destino ficticio en el sector América Norte.

**Las coordenadas son aproximadas y la línea entre nodos es ilustrativa.** La interpolación puede cruzar manzanas: no es una ruta vial validada ni una estimación de tiempo de entrega. Los nodos son referencias académicas; no representan ubicaciones operativas de un courier. Antes de exponer, comprobar visualmente el área de los marcadores. Cambiar el identificador de ruta si se modifica su significado; los pedidos con una ruta desconocida no se reinterpretan.

Si Google Maps no carga por clave, red o servicios de Google, usar **Vista esquemática**. La simulación siempre necesita conexión con la API; la vista alternativa no convierte la aplicación en una aplicación sin conexión.

## Arquitectura Express

```text
backend/
├── server.js                      # Arranque y cierre del servidor
├── init.sql                       # Esquema base y datos iniciales
├── src/
│   ├── app.js                     # Express, routers y errores
│   ├── config/                    # Conexión PostgreSQL y entorno
│   ├── routes/                    # Auth, products, cart y orders
│   ├── controllers/               # Adaptación de HTTP a servicios
│   ├── services/                  # Auth, tienda, compras y seguimiento
│   ├── middleware/                # Autenticación
│   ├── database/
│   │   ├── migrate.js             # Migración transaccional al arrancar
│   │   └── migrations/            # SQL idempotente para volúmenes existentes
│   └── data/                      # Ruta de demostración
└── test/                          # Pruebas unitarias e integración HTTP/SQL
```

Se conservan las rutas anteriores de autenticación, catálogo, carrito y pedidos. El backend usa Node.js 22.9 o posterior; la imagen Docker usa Node.js 24. La migración también corrige exclusivamente el hash inválido conocido del usuario demo de la versión anterior, conservando contraseñas que hayan sido cambiadas.

Los identificadores se generan con `node:crypto`, sin dependencia de UUID externa.

### API de seguimiento

Todas requieren `Authorization: Bearer TOKEN` y verificar la propiedad del pedido.

| Método | Ruta | Función |
|---|---|---|
| GET | /api/orders/:id/tracking | Estado, envío, eventos y simulación |
| POST | /api/orders/:id/simulation/advance | Avanzar un nodo |
| POST | /api/orders/:id/simulation/reset | Empezar un nuevo ensayo |

Las dos operaciones POST reciben `{"expectedVersion": 0}` con la versión obtenida en la última consulta. Una versión obsoleta devuelve 409; una versión inválida, 400; un pedido ajeno, 404; y los controles deshabilitados, 403.

`DEMO_SIMULATION=true` habilita la asignación de rutas y los controles en el servidor. Docker Compose lo habilita expresamente para esta demostración. Fuera de Compose el valor predeterminado es deshabilitado. Deshabilitarlo no borra datos existentes.

El estado se guarda en `order_simulations` con versión y ejecución. Los eventos permiten repetir estados en distintos nodos. El cambio de nodo, estado del pedido, fecha de entrega y evento se confirma en una misma transacción. Reiniciar cambia de ejecución y conserva el historial previo.

### Ejecutar la API fuera de Docker

Primero iniciar PostgreSQL con Compose; después, desde la raíz:

```bash
cd backend
cp .env.example .env
npm ci
npm start
```

Si la API de Docker ya está usando 3000, detener solo ese servicio o elegir otro `PORT` para el proceso local. No hace falta editar el código para configurar direcciones.

## Pruebas y ensayo académico

Desde la raíz:

```bash
(cd seguimiento_de_pedidos_app && flutter analyze && flutter test)
(cd backend && npm test)
(cd backend && TEST_DATABASE_URL=postgresql://pedidoapp:pedidoapp123@127.0.0.1:55432/pedidoapp npm run test:integration)
(cd seguimiento_de_pedidos_app && flutter build apk --debug)
```

Sin `TEST_DATABASE_URL`, la integración se omite y las pruebas unitarias se ejecutan normalmente. La integración crea una base temporal con nombre propio, carga datos y migraciones, ejecuta peticiones HTTP y elimina exclusivamente esa base al terminar. Necesita un usuario con permiso para crear bases. No usa pedidos de la demostración ni modifica el inventario de la base principal.

Guion de exposición de aproximadamente cinco minutos:

| Paso | Acción | Evidencia esperada |
|---|---|---|
| 1 | Comprar dos pedidos | Ambos pendientes y con origen independiente |
| 2 | Abrir el primero y avanzar | Marcador animado, evento y un tramo completado |
| 3 | Avanzar otra vez | Segundo evento en camino, sin conflicto de estado repetido |
| 4 | Cerrar y reabrir el seguimiento | Se conserva la ubicación |
| 5 | Consultar el segundo pedido | Sigue en el origen |
| 6 | Completar el primero | En reparto, luego entregado; avance deshabilitado |
| 7 | Volver al listado | La tarjeta indica entregado |
| 8 | Reiniciar el primero | Origen, nueva ejecución, compra e inventario intactos |

Ensayo técnico adicional: doble pulsación, pérdida de red/API, recuperación con Actualizar, acceso con otro usuario y mapa sin clave. Las pruebas automatizadas cubren transiciones, concurrencia, aislamiento, entrega, reinicio, permisos y recuperación de interfaz. La visualización del mapa de Google requiere una prueba manual final en Android con una clave válida y servicios de Google disponibles.

Las dependencias Flutter se ajustaron a Dart 3.13.5, incluido en Flutter 3.47.6 del entorno, y los archivos de bloqueo se conservan para instalaciones repetibles.

En Windows se deshabilitó la compilación incremental de Kotlin para evitar el fallo de caché entre el proyecto en `E:` y la caché Pub en `C:`. La APK de depuración se genera en [app-debug.apk](seguimiento_de_pedidos_app/build/app/outputs/flutter-apk/app-debug.apk).
