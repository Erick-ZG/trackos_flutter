# Trackos — seguimiento simulado en Trujillo

Aplicación académica Flutter + Express + PostgreSQL. Incluye cuentas, catálogo, carrito, compra simulada y seguimiento manual por cinco nodos. OpenStreetMap muestra el recorrido en web y Android; el backend administra el avance y lo conserva por pedido. No utiliza GPS, pagos, repartidores reales ni APIs de cálculo de rutas.

## Presentación virtual desde el navegador

No se necesita dispositivo, emulador, cuenta de mapas ni clave de API. Ejecuta los siguientes comandos con **Git Bash** desde la raíz del repositorio.

### Opción rápida: versión web compilada

Terminal 1:

```bash
docker compose up -d --build
(cd seguimiento_de_pedidos_app && flutter pub get && flutter build web)
(cd backend && npm ci && npm run demo:web)
```

Abrir **http://localhost:8080** en Chrome o Edge. Mantener esa terminal abierta durante el ensayo y compartir esa pestaña o ventana en Meet. El servidor web escucha solo en tu equipo; tus compañeros ven la aplicación mediante la pantalla compartida.

Credenciales: **demo@test.com / 123456**. Crear un pedido nuevo, abrirlo desde Mis Pedidos y usar Avanzar al siguiente punto. El mapa de Trujillo se muestra directamente con OpenStreetMap.

La compilación solo hace falta la primera vez o cuando cambie el código Flutter. Para volver a presentar:

```bash
docker compose up -d
(cd backend && npm run demo:web)
```

### Opción de desarrollo con Chrome

Con la API de Docker iniciada, en otra terminal:

```bash
cd seguimiento_de_pedidos_app
flutter pub get
flutter run -d chrome --web-port=8080
```

Usar una sola de las dos opciones: ambas utilizan el puerto 8080. Para cambiar el puerto del servidor compilado: `WEB_PORT=8081 npm run demo:web` dentro de la carpeta backend.

### Conexión y requisitos

La API está en el puerto **3000** y PostgreSQL en **55432** del host; dentro de Docker la base sigue en 5432. El puerto del host es configurable con `POSTGRES_PORT=55433 docker compose up -d`.

En web, la aplicación usa el mismo nombre de host de la página y el puerto 3000 para la API. Se puede cambiar con `--dart-define=API_BASE_URL=http://localhost:3000` al compilar o ejecutar Flutter. Para Android Emulator se conserva `10.0.2.2:3000`; un teléfono físico requiere la IP LAN del PC. [demo.example.json](seguimiento_de_pedidos_app/config/demo.example.json) contiene una configuración opcional para web; ya no contiene claves de mapas.

OpenStreetMap requiere Internet para cargar las calles. Los controles de simulación requieren la API local y PostgreSQL. En ventanas de al menos 900 px, el mapa y los controles se colocan lado a lado para compartir pantalla. Si las teselas del mapa fallan, **Vista esquemática** permite continuar con el mismo recorrido y los mismos pedidos.

Si ya existe un volumen anterior, se conserva su usuario y dirección. Los nuevos envíos de demostración muestran un destino ficticio de Trujillo, independiente del perfil.

## OpenStreetMap y atribución

El widget usa [flutter_map](https://docs.fleaflet.dev/) con el servidor estándar de OpenStreetMap por HTTPS. No hay claves, SDK de Google ni configuración de facturación. Se mantiene visible la atribución enlazada a [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

La prueba académica hace consultas interactivas de las áreas visibles; no descarga mapas completos ni realiza precarga masiva. La caché HTTP del navegador y la caché predeterminada de flutter_map en plataformas nativas se mantienen habilitadas. El servicio público tiene disponibilidad de mejor esfuerzo y debe utilizarse según su [política de teselas](https://operations.osmfoundation.org/policies/tiles/).

## Uso y alcance de la simulación

1. Iniciar sesión, agregar un producto y confirmar la compra.
2. Abrir **Mis Pedidos** y tocar el pedido nuevo.
3. Pulsar **Avanzar al siguiente punto**: el servidor confirma un nodo y el marcador realiza una transición visual de dos segundos. Durante la operación los controles se bloquean.
4. Repetir hasta llegar al destino. El estado pasa por pendiente, en camino, en reparto y entregado; la tarjeta también se actualiza al regresar.
5. **Reiniciar prueba** crea otro ensayo desde el origen. No realiza otra compra ni altera inventario, artículos o total. Los eventos anteriores permanecen en PostgreSQL; la pantalla muestra el ensayo actual.

Cada pedido tiene posición, versión e historial independientes aunque todos reutilizan la misma ruta. **Actualizar seguimiento** recupera el estado confirmado, también después de cerrar la aplicación y volver a iniciar sesión. No hay actualización automática entre dispositivos: usar ese botón o reabrir la pantalla.

Si una operación falla o su respuesta se pierde, la pantalla conserva la última posición conocida y exige actualizar antes de continuar: el servidor podría haber confirmado la operación. La versión esperada y el bloqueo transaccional evitan que dos pulsaciones con la misma versión salten dos nodos.

Los pedidos anteriores a esta funcionalidad siguen siendo consultables y no reciben una ruta automáticamente. Crear un pedido nuevo para ensayar.

### Recorrido

La definición está en [trujillo-route.json](backend/src/data/trujillo-route.json): almacén ficticio cerca del Óvalo Papal, referencia de avenida España, Plaza de Armas, plazuela El Recreo y destino ficticio en el sector América Norte.

**Las coordenadas son aproximadas y la línea entre nodos es ilustrativa.** La interpolación puede cruzar manzanas: no es una ruta vial validada ni una estimación de tiempo de entrega. Los nodos son referencias académicas; no representan ubicaciones operativas de un courier. Antes de exponer, comprobar visualmente el área de los marcadores. Cambiar el identificador de ruta si se modifica su significado; los pedidos con una ruta desconocida no se reinterpretan.

Si OpenStreetMap no carga por un problema de red, usar **Vista esquemática**. La simulación siempre necesita conexión con la API; la vista alternativa no convierte la aplicación en una aplicación sin conexión.

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
(cd seguimiento_de_pedidos_app && flutter test --platform chrome)
(cd seguimiento_de_pedidos_app && flutter build web)
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

Ensayo técnico adicional: doble pulsación, pérdida de red/API, recuperación con Actualizar, acceso con otro usuario y mapa sin conexión a Internet. Las pruebas automatizadas cubren transiciones, concurrencia, aislamiento, entrega, reinicio, permisos y recuperación de interfaz. Las pruebas del mapa se ejecutan sin descargar teselas externas; verificar visualmente las calles y el avance del marcador antes de compartir pantalla. En esta sesión el ejecutor de pruebas de Chrome quedó detenido durante el arranque y se canceló; no se considera una comprobación visual aprobada. La compilación web, el servidor local, CORS y la disponibilidad de las teselas se comprueban por separado.

Las dependencias Flutter se ajustaron a Dart 3.13.5, incluido en Flutter 3.47.6 del entorno, y los archivos de bloqueo se conservan para instalaciones repetibles.

En Windows se deshabilitó la compilación incremental de Kotlin para evitar el fallo de caché entre el proyecto en `E:` y la caché Pub en `C:`. La salida para navegador se genera en [build/web/](seguimiento_de_pedidos_app/build/web/).
