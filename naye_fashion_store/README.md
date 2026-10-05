# Naye Fashion Store

Aplicacion Flutter para gestionar productos y ventas de una tienda de moda.

## Capacidades nativas

| Capacidad | Funcion | Valor | Disponibilidad |
| --- | --- | --- | --- |
| Camara | Tomar una fotografia al registrar un producto | Documenta el catalogo con imagenes propias | Esencial para fotos nuevas. Si falla, se puede elegir una imagen existente o guardar sin foto. |
| Conectividad | Consultar y sincronizar productos con el backend REST | Mantiene el inventario actualizado | Esencial para sincronizar. Sin Internet, el producto se conserva localmente en una cola y se reintenta. |

La camara se solicita solo al pulsar **Tomar foto**. La galeria usa el selector del sistema de `image_picker`, por lo que Android no necesita permiso amplio de almacenamiento.

## Plugins seleccionados

- `image_picker ^1.1.2`: plugin estable y mantenido para camara y galeria en Android/iOS, con null safety. Se eligio frente a `camera` porque el flujo necesita una captura puntual y no un visor/control manual.
- `connectivity_plus ^6.1.4`: detecta el tipo de red. No garantiza acceso real a Internet, por eso cada sincronizacion tambien maneja errores HTTP.
- `http ^1.6.0`: cliente mantenido suficiente para JSON y `MultipartRequest`; no se agrega `dio` sin necesidad.
- `shared_preferences ^2.5.3`: persistencia sencilla de la cola. Para catalogos grandes se recomienda `sqflite` o `hive`.
- `permission_handler ^12.0.1`: controla estados de permiso antes de abrir la camara. No solicita permisos al iniciar.

Las versiones son las declaradas en `pubspec.yaml`. Verifica actualizaciones con `flutter pub outdated`. No se usan claves secretas; la URL se puede sustituir con `--dart-define=URL_API=...`.

## Permisos

Android declara `CAMERA`, `INTERNET` y `ACCESS_NETWORK_STATE`. No declara ubicacion, contactos, audio ni almacenamiento amplio. iOS declara `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription`; no declara permiso para guardar en la galeria porque la app no exporta imagenes.

Flujo: se muestra una explicacion, el usuario puede continuar o cancelar, y luego se solicita camara. Un rechazo temporal permite usar la galeria; un bloqueo permanente muestra **Abrir ajustes**; un estado restringido permite galeria o producto sin fotografia.

## Persistencia y sincronizacion

El registro valida los campos. Si hay imagen, se comprueba que exista y no supere 5 MB, se guarda su ruta local y se envia mediante `MultipartRequest` en el campo `foto`. Sin imagen se conserva el envio JSON existente. Si no hay red, el backend falla o se interrumpe la sincronizacion, el payload queda en `SharedPreferences` y se reintenta al abrir la pantalla o mediante el boton de sincronizacion.

## Android API objetivo

`android/app/build.gradle.kts` usa `flutter.compileSdkVersion` y `flutter.targetSdkVersion` para no fijar numeros incompatibles con el SDK instalado. Antes de publicar en septiembre de 2026 hay que comprobar que el Flutter SDK resuelva ambos a API 36 o superior:

```powershell
flutter --version
flutter doctor -v
flutter build appbundle --release
```

Si el valor es menor que 36, actualiza Flutter y el Android SDK/Gradle compatibles y vuelve a ejecutar `flutter pub get`; no fuerces API 36 sobre un Flutter antiguo.

## Verificacion

```powershell
cd naye_fashion_store
flutter pub get
dart format .
flutter analyze
flutter test
flutter run
```

## Matriz de pruebas en dispositivo fisico

| Codigo | Condicion y pasos | Resultado esperado | Obtenido | Estado | Evidencia |
| --- | --- | --- | --- | --- | --- |
| CAM-01 | Permiso concedido; tomar foto; confirmar producto | Vista previa, envio multipart y producto visible | Registrar durante la prueba | Pendiente | Captura de permiso, vista previa y catalogo |
| CAM-02 | Denegar permiso; elegir imagen | El producto conserva la imagen de galeria y se registra | Registrar durante la prueba | Pendiente | Dialogo, selector y producto |
| CAM-03 | Bloquear permiso; pulsar Abrir ajustes | Se abren ajustes sin cerrar la app; galeria sigue disponible | Registrar durante la prueba | Pendiente | Dialogo y pantalla de ajustes |
| NET-04 | Activar modo avion; registrar; recuperar red; sincronizar | Producto local pendiente pasa a sincronizado | Registrar durante la prueba | Pendiente | Indicador pendiente y respuesta sincronizada |
| API-05 | Backend fuera de servicio; registrar | Producto se conserva pendiente y no se pierden campos | Registrar durante la prueba | Pendiente | Error, cola local y reintento |

## Limitaciones y recomendaciones

La cola usa `SharedPreferences`, adecuada para el taller pero no para miles de productos. La ruta local puede quedar invalida si el sistema elimina archivos temporales; una siguiente iteracion debe copiar la imagen al almacenamiento de la aplicacion y usar una base SQLite/Hive con estados `synced`, `pending` y `error`. Ejecuta la matriz en Android y iPhone, incluyendo modo avion, rechazo permanente y backend temporalmente caido, y adjunta las evidencias a la presentacion.
