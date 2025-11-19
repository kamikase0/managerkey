// views/login_page.dart (VERSIÓN CORREGIDA)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Importar para SocketException
import '../main.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;

  void _quickLogin(String profile) {
    final userData = {
      'operador': {
        'email': 'j.quisbert.a',
        'username': 'j.quisbert.a',
        'group': 'Operador',
      },
      'soporte': {
        'email': 'soporte@test.com',
        'username': 'carlos_soporte',
        'group': 'soporte',
      },
      'coordinador': {
        'email': 'coordinador@test.com',
        'username': 'ana_coordinadora',
        'group': 'coordinador',
      },
    };

    final data = userData[profile]!;
    setState(() {
      _emailController.text = data['username']!;
      _passwordController.text = 'Bolivia2025';
    });
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Realizar login
      final authResponse = await AuthService().loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Guardar token en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', authResponse.access);

      // Navegar al home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePageWrapper()),
      );
    } catch (e) {
      if (!mounted) return;

      // MANEJO ESPECÍFICO DE ERRORES DE CONEXIÓN
      String errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    print('🔍 Error original: $error');

    // Verificar si es error de conexión
    if (error is SocketException) {
      return 'No se puede conectar al servidor. Verifica tu conexión a internet.';
    }

    // Verificar si es error de timeout
    if (error.toString().contains('timed out') ||
        error.toString().contains('timeout')) {
      return 'La conexión al servidor tardó demasiado. Verifica tu conexión a internet.';
    }

    // Verificar si es error de DNS o conexión
    if (error.toString().contains('Failed host lookup') ||
        error.toString().contains('Network is unreachable') ||
        error.toString().contains('Connection refused')) {
      return 'No se puede alcanzar el servidor. Verifica tu conexión a internet o contacta al administrador.';
    }

    // Verificar si es error de credenciales
    if (error.toString().contains('401') ||
        error.toString().contains('Unauthorized') ||
        error.toString().contains('invalid credentials')) {
      return 'Usuario o contraseña incorrectos.';
    }

    // Verificar si es error del servidor
    if (error.toString().contains('500') ||
        error.toString().contains('Internal Server Error')) {
      return 'Error interno del servidor. Por favor, intenta más tarde.';
    }

    // Verificar si el mensaje contiene la IP del servidor (lo que quieres evitar)
    final errorString = error.toString();
    if (errorString.contains('http://') || errorString.contains('https://')) {
      return 'Error de conexión con el servidor. Verifica tu conexión a internet.';
    }

    // Mensaje genérico para otros errores
    return 'Error al iniciar sesión. Verifica tus credenciales y conexión.';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error de conexión'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Sugerencias:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Verifica tu conexión a internet'),
            const Text('• Revisa la configuración de red'),
            const Text('• Contacta al administrador si el problema persiste'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // Método para verificar conexión antes de intentar login
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_tree,
                        size: 64,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sistema de Reportes Empadronamiento',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- Usuario ---
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Por favor ingresa tu usuario'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // --- Contraseña ---
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                        ),
                        obscureText: !_showPassword,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Por favor ingresa tu contraseña'
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // --- Botón login ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Text(
                            'Iniciar Sesión',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),

                      const Text(
                        'Acceso rápido (para testing):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _quickLogin('operador'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                              ),
                              child: const Text(
                                'Operador',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _quickLogin('soporte'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: const BorderSide(color: Colors.green),
                              ),
                              child: const Text(
                                'Soporte',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _quickLogin('coordinador'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                              ),
                              child: const Text(
                                'Coordinador',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}