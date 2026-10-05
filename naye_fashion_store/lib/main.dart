import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

const urlApi = String.fromEnvironment(
  'URL_API',
  defaultValue: 'https://backend-production-0f02.up.railway.app',
);

void main() => runApp(const AplicacionNaye());

class ProductSyncService {
  static const String _pendingProductsKey = 'pending_products';
  static const int maxImageBytes = 5 * 1024 * 1024;

  static Map<String, dynamic> buildProductPayload({
    required int idCategoria,
    required String nombre,
    required String descripcion,
    required String talla,
    required String color,
    required double precio,
    required int stock,
    String? fotoUrl,
  }) {
    final payload = <String, dynamic>{
      'idCategoria': idCategoria,
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'talla': talla.trim(),
      'color': color.trim(),
      'precio': precio,
      'stock': stock,
    };

    if (fotoUrl != null && fotoUrl.trim().isNotEmpty) {
      payload['fotoUrl'] = fotoUrl.trim();
    }

    return payload;
  }

  static bool isOnlineResult(String result) => result != 'none';

  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  static Future<void> savePendingProducts(
    List<Map<String, dynamic>> products,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = products.map((product) => jsonEncode(product)).toList();
    await prefs.setStringList(_pendingProductsKey, serialized);
  }

  static Future<void> savePendingProduct(Map<String, dynamic> product) async {
    final pending = await loadPendingProducts();
    pending.add(product);
    await savePendingProducts(pending);
  }

  static Future<List<Map<String, dynamic>>> loadPendingProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingProductsKey) ?? const [];
    return pending
        .map(
          (item) => Map<String, dynamic>.from(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> clearPendingProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingProductsKey);
  }

  static Future<void> syncPendingProducts({
    required String token,
    required String apiUrl,
    required Future<void> Function(Map<String, dynamic>) onSend,
  }) async {
    final pending = await loadPendingProducts();
    if (pending.isEmpty || !await isOnline()) {
      return;
    }

    final remaining = <Map<String, dynamic>>[];
    for (final product in pending) {
      try {
        await onSend(product);
      } catch (_) {
        remaining.add(product);
      }
    }

    if (remaining.isEmpty) {
      await clearPendingProducts();
    } else {
      await savePendingProducts(remaining);
    }
  }

  static Future<void> sendProduct({
    required String token,
    required String apiUrl,
    required Map<String, dynamic> product,
  }) async {
    final imagePath = product['fotoPath'] as String?;
    final fields = Map<String, dynamic>.from(product)
      ..remove('fotoPath')
      ..remove('syncStatus');

    if (imagePath != null && imagePath.isNotEmpty) {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('La imagen local ya no está disponible.');
      }
      if (await imageFile.length() > maxImageBytes) {
        throw Exception('La imagen supera el tamaño máximo de 5 MB.');
      }

      final request =
          http.MultipartRequest('POST', Uri.parse('$apiUrl/api/productos'))
            ..headers['Authorization'] = 'Bearer $token'
            ..fields.addAll(
              fields.map((key, value) => MapEntry(key, value.toString())),
            )
            ..files.add(await http.MultipartFile.fromPath('foto', imagePath));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_responseMessage(response.statusCode, body));
      }
      return;
    }

    final response = await http.post(
      Uri.parse('$apiUrl/api/productos'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(fields),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_responseMessage(response.statusCode, response.body));
    }
  }

  static String _responseMessage(int statusCode, String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['mensaje'] ??
              data['error'] ??
              'La operación no pudo completarse')
          .toString();
    } catch (_) {
      return 'La operación no pudo completarse ($statusCode)';
    }
  }
}

class AplicacionNaye extends StatelessWidget {
  const AplicacionNaye({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naye Fashion Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AutenticacionPagina(),
    );
  }
}

class MyApp extends AplicacionNaye {
  const MyApp({super.key});
}

class AutenticacionPagina extends StatefulWidget {
  const AutenticacionPagina({super.key});

  @override
  State<AutenticacionPagina> createState() => _AutenticacionPaginaState();
}

class _AutenticacionPaginaState extends State<AutenticacionPagina> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmacionController = TextEditingController();
  bool _esRegistro = false;
  bool _cargando = false;
  bool _ocultarContrasena = true;
  String? _error;

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    final ruta = _esRegistro
        ? '/api/autenticacion/registrarse'
        : '/api/autenticacion/iniciar-sesion';
    try {
      final respuesta = await http.post(
        Uri.parse('$urlApi$ruta'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': _correoController.text.trim(),
          'contrasena': _contrasenaController.text,
        }),
      );
      final datos = respuesta.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(respuesta.body) as Map<String, dynamic>;

      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        throw Exception(
          datos['mensaje'] ??
              datos['error'] ??
              'No se pudo completar la solicitud',
        );
      }

      if (_esRegistro && datos['token'] == null) {
        setState(() {
          _esRegistro = false;
          _cargando = false;
        });
        _mostrarMensaje('Cuenta creada. Ahora puedes iniciar sesión.');
        return;
      }

      final token = datos['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('La respuesta no contiene un token válido');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProductosPagina(token: token)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && _cargando) setState(() => _cargando = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esRegistro ? 'Crea tu cuenta' : 'Bienvenida de nuevo';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'NAYE',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Escribe tu correo';
                        }
                        if (!valor.contains('@')) {
                          return 'Escribe un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _ocultarContrasena = !_ocultarContrasena,
                          ),
                          icon: Icon(
                            _ocultarContrasena
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (valor) => valor == null || valor.length < 6
                          ? 'Usa al menos 6 caracteres'
                          : null,
                    ),
                    if (_esRegistro) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmacionController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (valor) =>
                            valor != _contrasenaController.text
                            ? 'Las contraseñas no coinciden'
                            : null,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _enviarFormulario,
                      child: _cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _esRegistro ? 'Registrarme' : 'Iniciar sesión',
                            ),
                    ),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => setState(() {
                              _esRegistro = !_esRegistro;
                              _error = null;
                            }),
                      child: Text(
                        _esRegistro
                            ? 'Ya tengo una cuenta'
                            : 'Crear una cuenta',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductosPagina extends StatefulWidget {
  const ProductosPagina({required this.token, super.key});

  final String token;

  @override
  State<ProductosPagina> createState() => _ProductosPaginaState();
}

class _ProductosPaginaState extends State<ProductosPagina> {
  late Future<List<Map<String, dynamic>>> productos;
  final Map<int, int> carrito = {};

  @override
  void initState() {
    super.initState();
    productos = cargarProductos();
    _sincronizarProductosPendientes();
  }

  Future<List<Map<String, dynamic>>> cargarProductos() async {
    final respuesta = await http.get(
      Uri.parse('$urlApi/api/productos'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (respuesta.statusCode != 200) {
      throw Exception('No se pudieron cargar los productos');
    }
    final contenido = jsonDecode(respuesta.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(
      (contenido['datos'] as List).map(
        (producto) => Map<String, dynamic>.from(producto as Map),
      ),
    );
  }

  Future<void> _sincronizarProductosPendientes() async {
    if (!mounted) return;
    if (!await ProductSyncService.isOnline()) {
      return;
    }

    await ProductSyncService.syncPendingProducts(
      token: widget.token,
      apiUrl: urlApi,
      onSend: (producto) async {
        await ProductSyncService.sendProduct(
          token: widget.token,
          apiUrl: urlApi,
          product: producto,
        );
      },
    );

    if (mounted) {
      setState(() => productos = cargarProductos());
    }
  }

  Future<void> _crearProducto() async {
    final datos = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const NuevoProductoPagina()),
    );
    if (datos == null) return;

    final payload = ProductSyncService.buildProductPayload(
      idCategoria: datos['idCategoria'] as int,
      nombre: datos['nombre'] as String,
      descripcion: datos['descripcion'] as String? ?? '',
      talla: datos['talla'] as String,
      color: datos['color'] as String,
      precio: (datos['precio'] as num).toDouble(),
      stock: datos['stock'] as int,
      fotoUrl: datos['fotoUrl'] as String?,
    );
    final fotoPath = datos['fotoPath'] as String?;
    if (fotoPath != null && fotoPath.isNotEmpty) {
      payload['fotoPath'] = fotoPath;
      payload['syncStatus'] = 'pending';
    }

    try {
      final online = await ProductSyncService.isOnline();
      if (!online) {
        await ProductSyncService.savePendingProduct(payload);
        _mostrarMensaje(
          'Sin conexión. El producto se guardó en la cola local y se sincronizará cuando haya red.',
        );
        return;
      }

      await ProductSyncService.sendProduct(
        token: widget.token,
        apiUrl: urlApi,
        product: payload,
      );
      setState(() => productos = cargarProductos());
      _mostrarMensaje('Producto agregado correctamente');
    } catch (error) {
      await ProductSyncService.savePendingProduct(payload);
      _mostrarMensaje(error.toString().replaceFirst('Exception: ', ''));
      _mostrarMensaje(
        'El producto quedó pendiente y se reintentará al sincronizar.',
      );
    }
  }

  Future<void> _registrarVenta(List<Map<String, dynamic>> datos) async {
    try {
      final respuesta = await http.post(
        Uri.parse('$urlApi/api/ventas'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'detalles': datos
              .map(
                (producto) => {
                  'idProducto': producto['idProducto'],
                  'cantidad': carrito[producto['idProducto']] ?? 0,
                },
              )
              .toList(),
        }),
      );
      if (respuesta.statusCode != 201 && respuesta.statusCode != 200) {
        throw Exception(_mensajeRespuesta(respuesta));
      }
      setState(() {
        carrito.clear();
        productos = cargarProductos();
      });
      _mostrarMensaje('Venta registrada correctamente');
    } catch (error) {
      _mostrarMensaje(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _mensajeRespuesta(http.Response respuesta) {
    try {
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return (datos['mensaje'] ??
              datos['error'] ??
              'La operación no pudo completarse')
          .toString();
    } catch (_) {
      return 'La operación no pudo completarse (${respuesta.statusCode})';
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _cerrarSesion() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AutenticacionPagina()),
      (ruta) => false,
    );
  }

  void _abrirCarrito(List<Map<String, dynamic>> datos) {
    final seleccionados = datos.where((producto) {
      final id = producto['idProducto'] as int;
      return (carrito[id] ?? 0) > 0;
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => CarritoPanel(
        productos: seleccionados,
        cantidades: carrito,
        onCambiarCantidad: (id, cantidad) => setState(() {
          if (cantidad <= 0) {
            carrito.remove(id);
          } else {
            carrito[id] = cantidad;
          }
        }),
        onVender: () {
          Navigator.pop(context);
          _registrarVenta(seleccionados);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naye Ventas'),
        actions: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: productos,
            builder: (context, estado) => IconButton(
              tooltip: 'Carrito',
              onPressed: estado.hasData
                  ? () => _abrirCarrito(estado.data!)
                  : null,
              icon: Badge(
                label: Text(
                  '${carrito.values.fold<int>(0, (total, cantidad) => total + cantidad)}',
                ),
                isLabelVisible: carrito.isNotEmpty,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sincronizar pendientes',
            onPressed: _sincronizarProductosPendientes,
            icon: FutureBuilder<List<Map<String, dynamic>>>(
              future: ProductSyncService.loadPendingProducts(),
              builder: (context, estado) {
                final cantidad = estado.data?.length ?? 0;
                return Badge(
                  isLabelVisible: cantidad > 0,
                  label: Text('$cantidad'),
                  child: const Icon(Icons.sync),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: productos,
        builder: (context, estado) {
          if (estado.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (estado.hasError) {
            return Center(child: Text(estado.error.toString()));
          }
          final datos = estado.data ?? [];
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => productos = cargarProductos()),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: datos.length,
              itemBuilder: (context, indice) {
                final producto = datos[indice];
                final id = producto['idProducto'] as int;
                final cantidad = carrito[id] ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(producto['nombre'] as String),
                    subtitle: Text(
                      '${producto['talla']} | ${producto['color']} | Stock: ${producto['stock']}',
                    ),
                    trailing: SizedBox(
                      width: 140,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('\$${producto['precio']}'),
                          IconButton(
                            tooltip: 'Agregar a venta',
                            onPressed: (producto['stock'] as int) > cantidad
                                ? () =>
                                      setState(() => carrito[id] = cantidad + 1)
                                : null,
                            icon: const Icon(Icons.add_shopping_cart_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearProducto,
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
    );
  }
}

class CarritoPanel extends StatelessWidget {
  const CarritoPanel({
    required this.productos,
    required this.cantidades,
    required this.onCambiarCantidad,
    required this.onVender,
    super.key,
  });

  final List<Map<String, dynamic>> productos;
  final Map<int, int> cantidades;
  final void Function(int id, int cantidad) onCambiarCantidad;
  final VoidCallback onVender;

  @override
  Widget build(BuildContext context) {
    final total = productos.fold<double>(0, (suma, producto) {
      final precio = (producto['precio'] as num).toDouble();
      return suma + precio * (cantidades[producto['idProducto'] as int] ?? 0);
    });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Venta actual', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (productos.isEmpty)
              const Text('Agrega productos para comenzar una venta.'),
            ...productos.map((producto) {
              final id = producto['idProducto'] as int;
              final cantidad = cantidades[id] ?? 0;
              return Row(
                children: [
                  Expanded(child: Text(producto['nombre'] as String)),
                  IconButton(
                    onPressed: () => onCambiarCantidad(id, cantidad - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$cantidad'),
                  IconButton(
                    onPressed: () => onCambiarCantidad(id, cantidad + 1),
                    icon: const Icon(Icons.add),
                  ),
                  Text(
                    '\$${((producto['precio'] as num) * cantidad).toStringAsFixed(2)}',
                  ),
                ],
              );
            }),
            const Divider(),
            Text(
              'Total: \$${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: productos.isEmpty ? null : onVender,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Registrar venta'),
            ),
          ],
        ),
      ),
    );
  }
}

class NuevoProductoPagina extends StatefulWidget {
  const NuevoProductoPagina({super.key});

  @override
  State<NuevoProductoPagina> createState() => _NuevoProductoPaginaState();
}

class _NuevoProductoPaginaState extends State<NuevoProductoPagina> {
  final _formKey = GlobalKey<FormState>();
  final _categoria = TextEditingController(text: '1');
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _talla = TextEditingController();
  final _color = TextEditingController();
  final _precio = TextEditingController();
  final _stock = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _fotoPath;

  @override
  void dispose() {
    for (final controller in [
      _categoria,
      _nombre,
      _descripcion,
      _talla,
      _color,
      _precio,
      _stock,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _tomarFoto() async {
    final status = await permission_handler.Permission.camera.status;

    if (status.isDenied) {
      final shouldAsk = await showPermissionExplanation();
      if (!shouldAsk) return;
      final request = await requestCameraPermission();

      if (request.isGranted) {
        await takeProductPhoto();
        return;
      }

      if (request.isPermanentlyDenied) {
        await _mostrarPermisoBloqueado();
        return;
      }

      _mostrarMensaje(
        'Permiso de cámara denegado. Puedes elegir una imagen existente.',
      );
      return;
    }

    if (status.isPermanentlyDenied) {
      await _mostrarPermisoBloqueado();
      return;
    }

    if (status.isRestricted || status.isLimited) {
      _mostrarMensaje(
        'La cámara está restringida o no está disponible. Puedes elegir una imagen existente.',
      );
      return;
    }

    await takeProductPhoto();
  }

  Future<permission_handler.PermissionStatus> requestCameraPermission() {
    return permission_handler.Permission.camera.request();
  }

  Future<bool> showPermissionExplanation() async {
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso para usar la cámara'),
        content: const Text(
          'Necesitamos acceder a la cámara para tomar una fotografía del producto y añadirla al catálogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return aceptar ?? false;
  }

  Future<void> _mostrarPermisoBloqueado() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de cámara bloqueado'),
        content: const Text(
          'El permiso fue bloqueado en los ajustes del sistema. Puedes habilitarlo allí o elegir una imagen existente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Future<void> takeProductPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) {
        _mostrarMensaje('No se seleccionó ninguna foto.');
        return;
      }

      await _setSelectedImage(picked);
    } catch (_) {
      _mostrarMensaje('La cámara no está disponible en este momento.');
    }
  }

  Future<void> pickProductImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _setSelectedImage(picked);
    } catch (_) {
      _mostrarMensaje(
        'No se pudo seleccionar la imagen. Puedes continuar sin fotografía.',
      );
    }
  }

  Future<void> _setSelectedImage(XFile picked) async {
    final file = File(picked.path);
    if (!await file.exists()) {
      _mostrarMensaje('El archivo de imagen no está disponible.');
      return;
    }
    if (await file.length() > ProductSyncService.maxImageBytes) {
      _mostrarMensaje('La imagen supera el tamaño máximo de 5 MB.');
      return;
    }
    setState(() => _fotoPath = picked.path);
  }

  Future<void> openAppSettings() async {
    await permission_handler.openAppSettings();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final precio = double.tryParse(_precio.text.replaceAll(',', '.'));
    final stock = int.tryParse(_stock.text);
    final categoria = int.tryParse(_categoria.text);
    if (precio == null ||
        precio < 0 ||
        stock == null ||
        stock < 0 ||
        categoria == null) {
      _mostrarMensaje('Revisa categoría, precio y stock.');
      return;
    }
    Navigator.pop(context, {
      'idCategoria': categoria,
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'talla': _talla.text.trim(),
      'color': _color.text.trim(),
      'precio': precio,
      'stock': stock,
      if (_fotoPath != null && _fotoPath!.isNotEmpty) 'fotoUrl': _fotoPath,
      if (_fotoPath != null && _fotoPath!.isNotEmpty) 'fotoPath': _fotoPath,
    });
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  String? _requerido(String? valor) =>
      valor == null || valor.trim().isEmpty ? 'Campo requerido' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar producto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _categoria,
              decoration: const InputDecoration(labelText: 'ID de categoría'),
              keyboardType: TextInputType.number,
              validator: _requerido,
            ),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _requerido,
            ),
            TextFormField(
              controller: _descripcion,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            TextFormField(
              controller: _talla,
              decoration: const InputDecoration(labelText: 'Talla'),
              validator: _requerido,
            ),
            TextFormField(
              controller: _color,
              decoration: const InputDecoration(labelText: 'Color'),
              validator: _requerido,
            ),
            TextFormField(
              controller: _precio,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _requerido,
            ),
            TextFormField(
              controller: _stock,
              decoration: const InputDecoration(labelText: 'Stock'),
              keyboardType: TextInputType.number,
              validator: _requerido,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_camera_outlined),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Foto del producto')),
                        TextButton.icon(
                          onPressed: _tomarFoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Tomar foto'),
                        ),
                        TextButton.icon(
                          onPressed: pickProductImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Elegir imagen'),
                        ),
                      ],
                    ),
                    if (_fotoPath != null && _fotoPath!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_fotoPath!),
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Puedes guardar el producto sin fotografía y añadirla después.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar producto'),
            ),
          ],
        ),
      ),
    );
  }
}
