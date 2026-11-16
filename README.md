# Trackos - primer avance funcional

Prototipo Flutter de tienda con cuentas, catálogo, carrito, compra simulada y seguimiento. La app consume una API Node.js/Express; PostgreSQL almacena usuarios, productos, carritos, pedidos, courier y eventos. No procesa pagos ni consulta empresas logísticas reales.

## Ejecutar el backend y la base de datos

Desde la carpeta raíz del proyecto:

```powershell
docker compose up --build
```

La API queda en `http://localhost:3000` y PostgreSQL en el puerto `5432`. La primera ejecución crea tablas y datos de demostración. Health check: `http://localhost:3000/health`.

Credenciales de demostración: `demo@test.com` / `123456`.

## Ejecutar Flutter

En otra terminal:

```powershell
cd seguimiento_de_pedidos_app
flutter run
```

Android Emulator usa `10.0.2.2` para acceder al backend del host; iOS Simulator y escritorio usan `localhost`. Un teléfono físico debe estar en la misma red y requiere cambiar `_baseUrl` en `lib/services/app_service.dart` a la IP LAN del equipo que ejecuta Docker.

Al confirmar una compra se descuenta inventario, se guarda el pedido y se asignan datos ficticios de Trackos Express con una línea de tiempo de demostración. Toca una tarjeta de pedido para consultar código, courier y eventos.
