# Plan de ejecución: teléfono, llamadas y dashboard de administrador

Fecha: 25 de noviembre de 2026. Rama de partida: `experimentos`.

## 1. Objetivo y orden obligatorio

Completar el contacto telefónico entre cliente y repartidor y, después, mejorar el panel de administrador existente.

1. **Persona 1:** implementar teléfono y llamadas, probar y entregar su código integrado en `experimentos`.
2. **Persona 2:** crear su rama desde esa versión integrada e implementar el dashboard.
3. **Ambas personas:** verificar el flujo completo y registrar el resultado final.

La persona 2 puede leer el código y preparar ideas durante la primera etapa, pero comenzará sus cambios de implementación cuando la entrega de la persona 1 esté integrada. No crear su rama de implementación desde una versión anterior.

Este documento define trabajo pendiente. Los requisitos y ejemplos de API que siguen son contratos propuestos; no indican que estén implementados.

## 2. Base existente y decisiones de alcance

| Área | Situación observada | Decisión |
|---|---|---|
| Teléfono | Existe `users.phone`, registro y visualización del perfil. | Reutilizar el campo; agregar edición y validación. |
| Llamadas | `url_launcher` ya está en `pubspec.yaml`. | Abrir el marcador mediante `tel:`; el usuario confirma la llamada. |
| Repartidores | El repartidor real es un usuario asociado mediante `orders.courier_user_id`. | Obtener su teléfono desde `users`, no desde la tabla antigua `couriers`. |
| Navegador | Un PC puede no tener una aplicación para atender enlaces `tel:`. | Mostrar siempre el número autorizado y ofrecer copiarlo; manejar el fallo de apertura. |
| Administrador | Existen Métricas, Stock y Usuarios, con API protegida por rol. | Mejorar esas tres secciones sin construir otro panel. |
| Persistencia | Los campos necesarios ya existen. | No se necesitan tablas nuevas para el alcance base. |
| Inventario | `products.stock` y el inventario por sede tienen lógica previa de disponibilidad. | Priorizar el stock por sede; no reinterpretar el campo global ni modificar compras dentro de un rediseño visual. |

### Fuera del alcance de esta entrega

- Voz dentro de la aplicación, grabación, historial de llamadas y servicios de telefonía externos.
- Llamadas automáticas, envío de SMS y verificación mediante códigos SMS.
- Números internacionales diferentes de móviles de Perú en esta primera versión.
- Gráficos históricos, exportación de reportes, gestión completa de pedidos y eliminación de usuarios.
- Rediseño del chat, mapas, GPS o estados del reparto.
- Actualizaciones generales de Flutter, Node o dependencias.

## 3. Reglas comunes para ambas personas

1. Revisar `git status` antes de empezar. Conservar los cambios ajenos y los stashes existentes; no descartarlos ni aplicarlos sin necesidad.
2. Trabajar en la rama asignada. No usar `git reset --hard`, `git clean -fd`, push forzado ni eliminar volúmenes para resolver problemas de desarrollo.
3. Hacer commits pequeños por funcionalidad. No incluir `.env`, tokens, teléfonos personales, `build/`, `.dart_tool/`, `node_modules/` ni archivos de configuración local.
4. Revisar los cambios de archivos generados por Flutter antes de incluirlos. Incorporarlos únicamente si los cambios de plugins de la tarea lo requieren.
5. Validar formularios en Flutter y volver a validar en el backend. El frontend no reemplaza la autorización del servidor.
6. Usar consultas SQL parametrizadas y la autenticación existente. Nunca aceptar desde el cliente la identidad del propietario de un recurso.
7. Mantener el patrón de errores `{ "error": "mensaje" }`. Mostrar mensajes comprensibles y permitir reintentar.
8. Deshabilitar Guardar/Crear mientras se procesa una solicitud; conservar el formulario cuando falle. Liberar controladores y suscripciones, y comprobar `mounted` antes de actualizar widgets tras un `await`.
9. Mantener compatibilidad con los pedidos existentes y con cuentas sin teléfono. Las restricciones nuevas se aplican a nuevas compras y nuevas aceptaciones de reparto, no a la consulta de pedidos antiguos.
10. No cambiar identificadores de campos o endpoints entregados por la persona 1 durante la segunda etapa. Si un ajuste es indispensable, actualizar ambos consumidores y sus pruebas en el mismo cambio.
11. Usar datos de prueba. Los teléfonos de ejemplo o de las cuentas sembradas no deben llamarse para comprobar el sistema; verificar que se abre el marcador. Una llamada real solo se prueba con un número propio o de alguien que haya aceptado participar.
12. No borrar inventario, usuarios, pedidos ni historiales. Si aparece una necesidad de migración fuera del alcance previsto, documentar el motivo y agregar un archivo nuevo; no reescribir migraciones anteriores.
13. No considerar aprobada una integración omitida por falta de base de pruebas ni una llamada real por el simple hecho de que se abrió Chrome.

## 4. Preparación local

Los comandos siguientes usan PowerShell. Ejecutar desde la raíz del repositorio, salvo indicación distinta.

```powershell
git status
git switch experimentos
```

Si hay un remoto compartido y la rama local está limpia, sincronizar antes de crear la rama de trabajo:

```powershell
git pull --ff-only origin experimentos
```

Iniciar Docker Desktop y luego:

```powershell
docker compose up -d --build
docker compose ps
Invoke-RestMethod http://localhost:3000/health
```

En otra terminal:

```powershell
Set-Location .\seguimiento_de_pedidos_app
flutter pub get
flutter run -d chrome --web-port=8081
```

- Se usa 8081 porque en el equipo revisado el 8080 estaba ocupado por Apache.
- Si ya hay una instancia de Flutter en 8081, detener esa instancia antes de iniciar otra.
- Cada cambio de código del backend ejecutado en Docker requiere reconstruirlo: `docker compose up -d --build api`.
- Para comprobar el marcador en Android, usar preferentemente un teléfono físico: `flutter devices` y luego `flutter run -d <ID> --dart-define=API_BASE_URL=http://<IP_LAN_PC>:3000`.
- PC y teléfono deben compartir red y permitir la conexión al puerto 3000. En Android Emulator el proyecto ya usa `10.0.2.2:3000`.
- Windows requiere Modo de desarrollador para enlaces simbólicos. Si una carpeta generada tiene atributo de solo lectura, corregir ese atributo únicamente en la carpeta afectada; no cambiar permisos de todo el disco.

## 5. Etapa 1 — Persona 1: teléfono y llamadas

### 5.1. Rama y responsabilidad

```powershell
git switch -c feature/contacto-telefonico
```

Responsabilidad: entregar el flujo completo, incluyendo API, autorización, perfil, registro, restricciones previas a compra/aceptación, contacto y apertura del marcador.

### 5.2. Regla única de teléfono

Esta es una decisión de alcance del proyecto: se admitirán móviles de Perú.

- Aceptar entrada local de nueve dígitos que comience por `9`, por ejemplo `9XXXXXXXX`.
- Aceptar también la misma entrada con prefijo `+51` o `51`.
- Admitir espacios, guiones y paréntesis como separadores. Rechazar letras, extensiones, prefijos diferentes y símbolos no permitidos; no eliminar arbitrariamente cualquier carácter para convertir una entrada inválida en válida.
- Guardar siempre `+519XXXXXXXX`, sin separadores. Validar el resultado con `^\+519\d{8}$`.
- Tratar números como texto; no convertirlos a enteros.
- Permitir vacío en el registro y en cuentas antiguas. Si un usuario decide editar su teléfono, exigir uno válido; no incluir eliminación del número en este alcance.
- Exigir teléfono válido del cliente al confirmar una compra y del repartidor al aceptar un pedido, tanto en Flutter como en el servidor.
- Si una cuenta antigua contiene un teléfono válido con separadores, normalizarlo al leerlo para contacto y al volver a guardarlo. Un teléfono antiguo inválido se considera no disponible; no impide iniciar sesión.
- La validación de formato no demuestra que el número exista ni que pertenezca al usuario. No mostrarlo como «verificado».

Implementar una utilidad de backend, por ejemplo `backend/src/utils/phone.js`, y otra de Flutter, por ejemplo `lib/utils/phone_utils.dart`, con los mismos casos de entrada/salida. La persona 2 deberá reutilizarlas.

### 5.3. Contratos de API

Todas las rutas nuevas requieren `Authorization: Bearer TOKEN`.

#### A. Actualizar el teléfono propio

`PATCH /api/auth/me/phone`

```json
{ "phone": "999 000 001" }
```

Respuesta 200:

```json
{
  "user": {
    "id": "UUID",
    "name": "Nombre",
    "email": "usuario@example.test",
    "phone": "+51999000001",
    "role": "customer"
  }
}
```

El ejemplo abrevia el usuario: devolver la estructura completa de `publicUser` ya existente, sin contraseña ni token nuevo. Actualizar solo al usuario de la sesión. Ignorar identidades enviadas por el cliente y no aceptar cambios de rol, correo o sede por esta ruta.

Actualizar `AppService.currentUser` con la respuesta sin borrar el token ni desconectar el WebSocket. No reutilizar `_acceptSession` directamente: actualmente espera un `token`, que esta respuesta no contiene.

#### B. Consultar el contacto del pedido

`GET /api/orders/:id/contact`

Respuesta 200 cuando existe un contacto autorizado:

```json
{
  "orderId": "ORD-EJEMPLO",
  "available": true,
  "reason": null,
  "contact": {
    "name": "Nombre del contacto",
    "role": "courier",
    "phone": "+51999000001"
  }
}
```

Para el cliente, devolver el repartidor asignado. Para el repartidor asignado, devolver el cliente y `role: "customer"`. Usar siempre el teléfono actual de `users` mediante las relaciones del pedido.

Respuesta 200 cuando el solicitante pertenece al pedido, pero el contacto no está disponible:

```json
{
  "orderId": "ORD-EJEMPLO",
  "available": false,
  "reason": "not_assigned",
  "contact": null
}
```

Valores cerrados de `reason`: `not_assigned`, `phone_missing`, `order_closed`. El último se usa para pedidos entregados; si más adelante existe cancelación, deberá tratarse también como cierre.

| Situación | Resultado |
|---|---|
| No hay sesión válida | 401. |
| Cliente propietario y repartidor asignado, con pedido abierto | 200; devolver a la contraparte, nunca el teléfono propio. |
| Propietario antes de la asignación | 200, `available: false`, `reason: not_assigned`. |
| Contraparte sin teléfono válido | 200, `available: false`, `reason: phone_missing`. |
| Propietario o repartidor asignado después de la entrega | 200, `available: false`, `reason: order_closed`. |
| Otro cliente, repartidor sin asignación o pedido inexistente | 404 con el mismo mensaje genérico. |
| Trabajador o administrador usando esta ruta de contacto | 403; esta ruta está destinada al flujo cliente/repartidor. |

El administrador conserva la consulta de teléfonos mediante su API de usuarios. No ampliar por este motivo los permisos de contacto de trabajadores.

#### C. Restricciones en rutas existentes

- Registro: teléfono opcional; si está informado debe validarse y almacenarse normalizado.
- Creación de pedido: si el teléfono del cliente autenticado no es válido, devolver 400 con mensaje que indique completarlo en Perfil. No crear el pedido, descontar stock ni vaciar el carrito.
- Aceptación de reparto: si falta teléfono válido del repartidor, devolver 400 antes de asignar el pedido o generar eventos.
- No cambiar las respuestas exitosas existentes de compra o aceptación.

### 5.4. Orden de implementación

1. Crear utilidades y pruebas de validación de teléfono.
2. Implementar actualización del teléfono propio en ruta, controlador y servicio de autenticación.
3. Validar el teléfono informado durante el registro.
4. Aplicar las restricciones de compra y aceptación sin alterar sus transacciones.
5. Implementar consulta de contacto autorizada, con controlador/servicio propio si facilita mantener el código.
6. Revisar las respuestas anteriores: quitar `customer_phone` de los pedidos disponibles sin asignación; centralizar la obtención del teléfono para llamada en la nueva ruta. Retirar del tracking el teléfono ficticio `courier_phone` procedente de `couriers`, conservando los demás datos de simulación.
7. Implementar edición del teléfono en Perfil y reutilizar la validación en Registro.
8. Ante falta de teléfono en checkout/aceptación, mostrar indicación y acceso a Perfil. Tras guardar, permitir volver y reintentar sin perder el carrito o el pedido seleccionado.
9. Crear un componente reutilizable de contacto: nombre, número, botón Llamar, botón Copiar y estados de carga/error/no disponible.
10. Integrarlo en seguimiento del cliente y en el pedido aceptado del repartidor, junto al chat.
11. Consultar el contacto al abrir la sección y antes de preparar la llamada; no usar como fuente un número guardado en una tarjeta antigua. Después de una consulta asíncrona, mostrar el contacto actualizado y dejar que el usuario pulse Llamar.
12. Probar e integrar la entrega.

Para web, iniciar `launchUrl` directamente desde el gesto del botón Llamar, evitando una petición HTTP antes de esa apertura. Si se necesita volver a consultar el contacto, hacerlo antes y exigir una nueva pulsación para llamar. Manejar tanto retorno `false` como excepciones.

Usar `Uri(scheme: 'tel', path: phone)` con el valor normalizado. No solicitar `CALL_PHONE` para este alcance: se delega la acción al marcador. Si se usa `canLaunchUrl`, revisar la configuración de consultas de esquemas en Android/iOS; no deshabilitar el botón únicamente porque esa comprobación devuelva `false`.

### 5.5. Archivos de referencia

| Capa | Archivos o directorios |
|---|---|
| Perfil y registro | `lib/screens/profile_screen.dart`, `register_screen.dart`. |
| Contacto en pedidos | `lib/screens/tracking_screen.dart`, `courier_dashboard_screen.dart`, `checkout_screen.dart`. |
| Modelos y HTTP | `lib/services/app_service.dart`, `lib/models/user.dart`; crear modelo de contacto si evita mapas dinámicos. |
| API de perfil | `backend/src/routes/auth.routes.js`, `controllers/auth.controller.js`, `services/auth.service.js`. |
| Contacto y restricciones | `backend/src/routes/orders.routes.js`, `routes/courier.routes.js`, `services/orders.service.js`, `services/tracking.service.js`. |

Las rutas `lib/...` son relativas a `seguimiento_de_pedidos_app/`.

### 5.6. Criterios de entrega de la persona 1

- [ ] Registro admite vacío, acepta formatos acordados y rechaza teléfonos inválidos.
- [ ] Perfil guarda el teléfono; persiste tras cerrar sesión y volver a entrar, sin perder la sesión al editar.
- [ ] Una compra bloqueada por falta de teléfono conserva carrito e inventario.
- [ ] Una aceptación bloqueada por falta de teléfono no asigna el pedido.
- [ ] Cliente y repartidor ven únicamente el contacto correspondiente y disponible.
- [ ] Usuarios ajenos no obtienen teléfonos por la ruta nueva ni por el listado de pedidos disponibles.
- [ ] Un pedido sin asignación, entregado o con teléfono ausente muestra el estado definido.
- [ ] Android físico abre el marcador con el número correcto sin realizar la llamada automáticamente.
- [ ] Chrome permite copiar el número y explica cuando no se puede abrir una aplicación de teléfono.
- [ ] Chat, mapa, seguimiento, compra y entrega mantienen su funcionamiento.
- [ ] Se entrega un resumen de cambios, comandos ejecutados, resultados y limitaciones reales.

## 6. Puerta de entrega entre ambas personas

1. Persona 1 revisa el diff, hace commit y publica su rama si existe remoto compartido.
2. Persona 2 revisa el contrato, los casos de prueba y ejecuta el flujo telefónico antes de aprobar la integración.
3. Integrar `feature/contacto-telefonico` en `experimentos`, preferentemente mediante pull request. Si trabajan solo con Git local, hacer el merge después de la revisión.
4. Registrar el hash del commit integrado y los resultados en la sección de seguimiento de este documento.
5. Detener y reiniciar Flutter al cambiar de rama; reconstruir la API para probar exactamente el código integrado.
6. Solo entonces, la persona 2 actualiza su copia de `experimentos` y crea su rama:

```powershell
git switch experimentos
git pull --ff-only origin experimentos
git switch -c feature/mejoras-admin
```

Omitir `git pull` si no se utiliza un remoto compartido. No mezclar trabajo incompleto de la primera etapa con el dashboard.

## 7. Etapa 2 — Persona 2: dashboard de administrador

### 7.1. Responsabilidad y alcance visual

Mejorar las secciones Resumen, Inventario y Usuarios del panel existente. Reutilizar el tema Material y componentes del proyecto. Crear componentes pequeños cuando reduzcan duplicación, sin incorporar un gestor de estado o librería de gráficos nueva.

- Escritorio: tablas o listas con columnas claras y filtros visibles.
- Móvil: tarjetas y controles que se ajusten al ancho disponible.
- Comprobar al menos anchos de 360 px y 1280 px.
- Usar carga independiente por sección, estados vacíos, mensajes de error y reintento. Un error al cargar usuarios no debe ocultar métricas que sí cargaron.
- Mantener actualización manual. No agregar otra conexión WebSocket ni consultas periódicas para este alcance.

### 7.2. Resumen y métricas

1. Convertir importes recibidos como texto a número antes de formatearlos. Gestionar valores ausentes sin lanzar excepciones.
2. Mantener los campos actuales de `/api/admin/metrics` para compatibilidad y agregar los necesarios para el nuevo resumen.
3. Incorporar estas tarjetas con definición explícita:

| Tarjeta | Campo nuevo propuesto | Definición |
|---|---|---|
| Pedidos totales | Reutilizar `summary.total_orders`. | Todos los pedidos. |
| Pedidos activos | `summary.active_orders` | Pedidos en estados abiertos del flujo real. No contar estados desconocidos automáticamente como activos. |
| Entregados | Reutilizar `summary.delivered_orders`. | Pedidos con estado `delivered`. |
| Monto de pedidos entregados | `summary.delivered_order_amount` | Suma de `orders.total` solo de entregados; incluye el delivery si ya está incluido en el total. |
| Tarifas de delivery de entregados | `summary.delivered_delivery_fees` | Suma de `delivery_fee` solo de entregados; es un componente del monto anterior. |
| Tiempo promedio de entrega | Reutilizar/corregir `summary.avg_delivery_seconds`. | Promedio de `delivery_duration_seconds` no nulo de pedidos entregados. Sin datos: mostrar «Sin datos». |

Estados abiertos del flujo real de esta rama: `stock_verified`, `preparing`, `ready_for_pickup`, `courier_arrived_store`, `in_transit`, `arrived_destination`. Revisar los estados heredados presentes en la base y mostrarlos aparte si existen, sin cambiarlos.

No sumar nuevamente delivery al total ni llamar «ganancia» a una tarifa. Mostrar un aviso breve de que los montos corresponden a pedidos simulados y no acreditan pagos cobrados. Mantener el símbolo monetario actual del catálogo; no convertir monedas como parte de este trabajo.

Conservar las métricas por trabajador y repartidor. Mostrar estado vacío cuando no existan datos y calcular «activos» del repartidor con la misma lista de estados abiertos. No implementar filtros de fechas en esta entrega.

### 7.3. Usuarios

1. Agregar búsqueda local por nombre/correo y filtro por rol usando la lista ya cargada. Para el volumen académico no se necesita paginación del servidor.
2. Mostrar nombre, correo, rol, teléfono y sede; usar etiquetas en español para los roles.
3. Agregar teléfono al formulario de creación y a `AppService.createAdminUser`. Campo opcional; si se informa, reutilizar la validación de la etapa 1 en Flutter y backend.
4. Reutilizar `PATCH /api/admin/users/:id/role` y `AppService.updateUserRole` para editar rol/sede.
5. Exigir una sede existente al elegir trabajador. Al elegir otro rol, guardar `branch_id = null`.
6. Bloquear en interfaz y backend que un administrador cambie su propio rol. Para este alcance es la protección más simple contra perder el acceso; otro administrador puede gestionar esa cuenta.
7. Impedir cambios de rol/sede de trabajador o repartidor mientras tenga pedidos activos vinculados, para conservar el flujo operativo. Verificar en servidor y devolver 409 con explicación; no reasignar pedidos automáticamente.
8. Al crear usuarios, exigir contraseña de 6 a 72 bytes como en autenticación, sin precargar `123456`. Mostrar errores junto al formulario y confirmar cambios de rol antes de enviarlos.

### 7.4. Inventario por sede

1. Mostrar producto, sede y cantidad como datos principales. Búsqueda local por nombre y filtro por sede.
2. Señalar sin stock cuando la cantidad es 0 y stock bajo entre 1 y 5 inclusive. Aplicar el umbral por sede.
3. El ajuste obliga a seleccionar una sede y muestra cantidad actual, nueva cantidad y confirmación.
4. Reutilizar `PATCH /api/admin/products/:id/stock` con `{ "stock": 10, "branchId": "br-centro" }`.
5. Validar entero no negativo, producto existente y sede existente en el backend. Usar la transacción actual y manejar 400/404 sin dejar cambios parciales.
6. Mantener bloqueos compatibles con compras: bloquear primero la fila del producto antes de ajustar su inventario por sede y confirmar ambos cambios dentro de la transacción. Probar un ajuste concurrente con una compra para evitar actualizaciones perdidas.
7. No incluir en la interfaz una acción que escriba la misma cantidad en todas las sedes. No eliminar el soporte previo del endpoint durante esta entrega.
8. Si se muestra un total de existencias, calcularlo sumando `branch_inventory.stock` y etiquetarlo «Total en sedes». No usar `products.stock` como ese total ni sustituir su lógica por una suma dentro de esta tarea.

**Límite conocido:** la lógica previa recalcula `products.stock` con `MAX` al ajustar una sede, mientras las compras lo descuentan. Este campo no representa un total consolidado. La pantalla debe evitar afirmarlo. Una unificación del algoritmo de disponibilidad exige revisar también catálogo y compras y queda como tarea posterior, registrada en la entrega. El ajuste debe preservar el comportamiento de compra existente y no modificar otras sedes.

### 7.5. Orden de implementación y archivos

1. Revisar el código integrado de teléfono y ejecutar sus pruebas.
2. Corregir normalización de métricas y definir campos agregados en `backend/src/routes/admin.routes.js`.
3. Separar carga y estado de las tres secciones en `lib/screens/admin_dashboard_screen.dart`; extraer widgets si ayuda a su legibilidad.
4. Implementar Resumen y comprobar cifras con datos controlados.
5. Implementar Usuarios, teléfono y cambios de rol/sede con validación en servidor.
6. Implementar Inventario, filtros y edición por sede.
7. Ajustar `lib/services/app_service.dart` únicamente donde haga falta, conservando los métodos de contacto.
8. Probar escritorio, móvil y regresión telefónica; integrar en `experimentos` tras revisión de la persona 1.

### 7.6. Criterios de entrega de la persona 2

- [ ] El panel abre sin fallos con importes numéricos o recibidos como texto y con listas vacías.
- [ ] Métricas coinciden con las definiciones; delivery no se suma dos veces y no se presenta como ganancia.
- [ ] Búsqueda y filtros funcionan combinados y permiten limpiar la selección.
- [ ] Crear usuario admite teléfono normalizado y muestra errores sin cerrar el formulario.
- [ ] Cambios de rol/sede se reflejan al actualizar; trabajador requiere sede válida.
- [ ] No se permite cambiar el rol propio ni modificar asignaciones con pedidos activos.
- [ ] Cambiar el stock de una sede no cambia las existencias de otra.
- [ ] Cantidades negativas/decimales e identificadores inexistentes se rechazan sin escritura parcial.
- [ ] Usuarios sin rol administrador reciben 403 en las rutas administrativas; sin sesión reciben 401.
- [ ] A 360 px y 1280 px no hay desbordamientos ni acciones inaccesibles.
- [ ] El flujo de teléfono y llamadas de la etapa 1 continúa funcionando.

## 8. Pruebas obligatorias y evidencia

### 8.1. Automatizadas

Crear pruebas centradas en reglas y comportamiento observable, aprovechando `node:test`, las integraciones HTTP/SQL existentes y Flutter Test. No agregar frameworks nuevos.

| Responsable | Casos mínimos |
|---|---|
| Persona 1 | Normalización válida/inválida; actualización solo del perfil propio; contacto de propietario/asignado; rechazo de usuarios ajenos; teléfono ausente; pedido cerrado; compra/aceptación bloqueadas sin efectos secundarios. |
| Persona 1 | Widget de contacto: disponible, ausente, fallo al abrir marcador y copiar; simular el lanzador en pruebas, sin llamadas reales. |
| Persona 2 | Métricas con pedidos abiertos/entregados y números como texto; permisos administrativos; validación de roles/sedes; ajuste aislado por sede; ajuste concurrente con compra. |
| Persona 2 | Widgets de búsqueda/filtros, estados vacíos/error, formulario inválido y adaptación de las acciones principales. |

Desde `seguimiento_de_pedidos_app/`:

```powershell
flutter analyze
flutter test
flutter build web
```

Desde `backend/`:

```powershell
npm ci
npm test
$env:TEST_DATABASE_URL = 'postgresql://pedidoapp:pedidoapp123@127.0.0.1:55432/pedidoapp'
npm run test:integration
Remove-Item Env:TEST_DATABASE_URL
```

La integración existente crea una base temporal y necesita permiso para crear bases. Extender ese mecanismo para probar roles y teléfonos; cargar las migraciones de esta rama. Actualizar fixtures cuando una compra requiera teléfono. No quitar la validación para conservar un fixture antiguo ni apuntar pruebas destructivas a los datos de demostración.

### 8.2. Guion manual de aceptación conjunta

1. Crear un cliente sin teléfono; comprobar que puede entrar, pero al comprar se solicita completar Perfil y el carrito se conserva.
2. Guardar un número de prueba válido; confirmar que persiste y continuar la compra.
3. Con trabajador, preparar el pedido hasta dejarlo listo para recoger.
4. Con repartidor sin teléfono, intentar aceptarlo; comprobar el bloqueo sin asignación. Completar Perfil y aceptar.
5. Abrir seguimiento como cliente y verificar nombre/número del repartidor asignado; como repartidor, verificar contacto del cliente.
6. Con otro cliente y otro repartidor, verificar por HTTP que no se obtiene el contacto del pedido.
7. En Android físico abrir el marcador y cerrarlo sin llamar. En Chrome comprobar número, copia y manejo de la apertura de `tel:`.
8. Completar el reparto; comprobar que el contacto pasa a «Pedido finalizado» y que el resto del seguimiento se conserva.
9. Como administrador, buscar usuarios, crear uno con teléfono, cambiar rol/sede de una cuenta sin pedidos activos y comprobar las restricciones.
10. Ajustar stock de una sede; comprobar que otra sede mantiene su cantidad y que el catálogo y una compra básica siguen funcionando.
11. Revisar métricas de abiertos/entregados con los pedidos anteriores y repetir la vista en anchos móvil/escritorio.

Cuentas de demostración existentes: `demo@test.com`, `trabajador@test.com`, `repartidor@test.com`, `admin@test.com`; contraseña inicial `123456`, salvo que el volumen local conserve cambios anteriores. Crear cuentas adicionales para probar aislamiento.

## 9. Cierre, revisión y seguimiento

Cada persona entregará:

- Rama y commit/PR de entrega.
- Resumen de funcionalidades y archivos relevantes.
- Resultado de cada comando de verificación, con fecha y entorno.
- Evidencia manual de su flujo, sin publicar datos personales ni tokens.
- Limitaciones conocidas y cualquier prueba pendiente; una prueba pendiente impide marcar su criterio como aprobado.

La persona 2 revisa la primera entrega y la persona 1 revisa la segunda. La revisión no sustituye las pruebas.

| Hito | Responsable | Estado inicial | Commit/PR y evidencia |
|---|---|---|---|
| Teléfono y llamadas implementados | Persona 1 | Pendiente | Por completar. |
| Etapa 1 verificada e integrada en `experimentos` | Ambas | Pendiente | Por completar. |
| Dashboard implementado | Persona 2 | Pendiente | Por completar. |
| Regresión conjunta e integración final | Ambas | Pendiente | Por completar. |

No estimar avance por pantallas dibujadas: una etapa termina cuando cumple sus criterios, conserva los flujos existentes y está integrada.

## 10. Referencia técnica

- [Documentación oficial de url_launcher](https://pub.dev/packages/url_launcher): esquemas `tel:`, diferencias de plataforma, configuración de consultas y manejo de fallos.
- `README.md`: arquitectura, Docker y ejecución local. Sus ejemplos Bash deben adaptarse a PowerShell usando las indicaciones de este documento.
- Código de referencia: `backend/src/routes/admin.routes.js`, `backend/src/services/tracking.service.js` y `seguimiento_de_pedidos_app/lib/screens/admin_dashboard_screen.dart`.
