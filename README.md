# Naye Fashion Store

Aplicación móvil Flutter con API REST para la gestión de productos, ventas y sincronización de inventario. En esta versión se integra la cámara del dispositivo para registrar fotos de productos y la conectividad de red para sincronizar la información con el backend cuando la red vuelve a estar disponible.

## 1) Selección de capacidades nativas

Se eligieron dos capacidades nativas con valor directo para la solución:

- Cámara: esencial para capturar la fotografía del producto al crear el registro. Permite documentar el inventario y mejorar la experiencia de ventas con visualización rápida del producto.
- Conectividad de red: esencial para detectar si el dispositivo tiene acceso a internet y sincronizar productos pendientes con el backend, incluso cuando la red estaba indisponible.

También se consideró la posibilidad de usar galería, pero fue declarada opcional y no se implementó como requisito mínimo para mantener un diseño de permisos más seguro y menos invasivo.

## 2) Vía de acceso y verificación de plugins

Los plugins elegidos fueron:

- `image_picker` para capturar imágenes desde la cámara.
- `permission_handler` para gestionar permisos con estados explícitos y degradación segura.
- `connectivity_plus` para detectar conexión a red y branch de sincronización.
- `shared_preferences` para persistir productos pendientes cuando no hay conectividad.

Verificación realizada:

- Se validó que los paquetes estén incluidos en `naye_fashion_store/pubspec.yaml`.
- La integración queda encapsulada en `ProductSyncService` y en `NuevoProductoPagina` para mantener la lógica separada y reutilizable.
- La app detecta red y guarda la colección de productos pendientes localmente cuando hay ausencia de conexión.

## 3) Declaración de permisos

### Android
Se declaran únicamente permisos específicos:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" android:maxSdkVersion="33" />
```

Esto cumple con la recomendación de no declarar permisos ampliados innecesarios. La cámara se usa para documentar productos; el acceso a fotos/galería es opcional y solo se limita a API 33+.

### iOS
En `ios/Runner/Info.plist` se agregaron descripciones específicas de uso:

- `NSCameraUsageDescription`: “Naye Fashion Store necesita acceso a la cámara para tomar fotos del producto y registrarlas en el inventario.”
- `NSPhotoLibraryUsageDescription`: “Naye Fashion Store usa la galería para seleccionar imágenes del producto si prefieres elegir una foto existente.”

## 4) Solicitud de permisos y estados

La solicitud se realiza en el momento de uso, justo antes de tomar la foto del producto, con una explicación previa al usuario:

- Se muestra un diálogo explicando que la cámara es necesaria para capturar la foto del producto.
- Luego se ejecuta `Permission.camera.request()`.
- Se gestionan los estados de permiso: granted, denied, permanentlyDenied, restricted/limited.

Cuando el permiso está denegado permanentemente, la app abre la pantalla de configuración del sistema mediante `openAppSettings()`.

## 5) Degradación y manejo de indisponibilidad

Se implementó comportamiento para cada situación:

- Sin conexión: el producto se guarda en cola local y se sincroniza al recuperar la red.
- Cámara no disponible: se muestra un mensaje informativo y se permite continuar sin foto.
- Permiso denegado: el flujo informa al usuario y no rompe la experiencia.
- Permiso denegado permanentemente: se redirige a los ajustes del sistema.

## 6) Integración con persistencia local y backend

La aplicación combina estas capas:

- Local: `SharedPreferences` guarda la cola de productos pendientes.
- UI: `NuevoProductoPagina` captura la foto y arma el payload del producto.
- Backend: al detectar conexión, `ProductSyncService.syncPendingProducts()` envía los productos pendientes al endpoint `POST /api/productos`.

Esto permite que el usuario pueda seguir registrando productos aunque el servicio temporalmente no esté disponible.

## 7) Cumplimiento de permisos y API objetivo

- No se declaran permisos de almacenamiento amplio innecesarios. Se evita `WRITE_EXTERNAL_STORAGE` salvo que sea estrictamente necesario.
- En Android, la integración usa la cámara y la conectividad de forma específica, sin hacer uso de permisos del catálogo del sistema más amplio de lo necesario.
- Para el nivel de API objetivo, se deja la app en el valor recomendado por Flutter y se recomienda revisarlo con la política vigente de Google Play antes de publicación comercial.

## 8) Pruebas

Se ejecutaron pruebas relevantes para validar la lógica de sincronización:

- `ProductSyncService.buildProductPayload` debe incluir el nombre, categoría, precio y `fotoUrl`.
- `ProductSyncService.isOnlineResult('none')` debe devolver `false`.
- `ProductSyncService.isOnlineResult('wifi')` debe devolver `true`.

Comando ejecutado:

```powershell
cd naye_fashion_store
flutter test test/product_sync_test.dart
```

## Ejecución del proyecto

```powershell
cd naye_fashion_store
flutter pub get
flutter run
```

Para usar una API local, se puede sobrescribir la url con:

```powershell
flutter run --dart-define=URL_API=http://10.0.2.2:3000
```

## Resultado esperado

La app permite:

1. Iniciar sesión.
2. Agregar productos con foto desde la cámara.
3. Guardar productos pendientes si no hay red.
4. Sincronizar automáticamente con el backend cuando hay conectividad.
5. Mantener la experiencia práctica y preparada para el taller de capacidades nativas.

