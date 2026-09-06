import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const urlApi = String.fromEnvironment(
  'URL_API',
  defaultValue: 'https://backend-production-0f02.up.railway.app',
);

void main() => runApp(const AplicacionNaye());

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

  Future<void> _crearProducto() async {
    final datos = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const NuevoProductoPagina()),
    );
    if (datos == null) return;
    try {
      final respuesta = await http.post(
        Uri.parse('$urlApi/api/productos'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(datos),
      );
      if (respuesta.statusCode != 201 && respuesta.statusCode != 200) {
        throw Exception(_mensajeRespuesta(respuesta));
      }
      setState(() => productos = cargarProductos());
      _mostrarMensaje('Producto agregado correctamente');
    } catch (error) {
      _mostrarMensaje(error.toString().replaceFirst('Exception: ', ''));
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

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'idCategoria': int.parse(_categoria.text),
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'talla': _talla.text.trim(),
      'color': _color.text.trim(),
      'precio': double.parse(_precio.text.replaceAll(',', '.')),
      'stock': int.parse(_stock.text),
    });
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
