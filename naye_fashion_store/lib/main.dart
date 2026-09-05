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
          datos['mensaje'] ?? datos['error'] ?? 'No se pudo completar la solicitud',
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
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
                    Text('NAYE', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) return 'Escribe tu correo';
                        if (!valor.contains('@')) return 'Escribe un correo válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _ocultarContrasena = !_ocultarContrasena), icon: Icon(_ocultarContrasena ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                      validator: (valor) => valor == null || valor.length < 6 ? 'Usa al menos 6 caracteres' : null,
                    ),
                    if (_esRegistro) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmacionController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_reset_outlined)),
                        validator: (valor) => valor != _contrasenaController.text ? 'Las contraseñas no coinciden' : null,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _enviarFormulario,
                      child: _cargando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_esRegistro ? 'Registrarme' : 'Iniciar sesión'),
                    ),
                    TextButton(
                      onPressed: _cargando ? null : () => setState(() { _esRegistro = !_esRegistro; _error = null; }),
                      child: Text(_esRegistro ? 'Ya tengo una cuenta' : 'Crear una cuenta'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
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
          return ListView.builder(
            itemCount: datos.length,
            itemBuilder: (context, indice) {
              final producto = datos[indice];
              return ListTile(
                title: Text(producto['nombre'] as String),
                subtitle: Text('${producto['talla']} | ${producto['color']}'),
                trailing: Text('\$${producto['precio']}'),
              );
            },
          );
        },
      ),
    );
  }
}
