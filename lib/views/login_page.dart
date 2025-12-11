import 'package:flutter/material.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../utils/alert_helper.dart';
import 'home_page.dart';
import 'package:provider/provider.dart';
import 'package:manager_key/services/ubicacion_service.dart';
import 'package:manager_key/models/user_model.dart';

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
        'username': 'test_coordinador',
        'group': 'coordinador',
      },
      'logistico': {
        'email': 'logistico@test.com',
        'username': 'abril.gutierrez.a',
        'group': 'logistico',
      },
    };

    final data = userData[profile]!;
    setState(() {
      _emailController.text = data['username']!;
      _passwordController.text = 'Bolivia2030';
    });

    AlertHelper.showInfo(
      context: context,
      title: 'Perfil Cargado',
      text: 'Perfil de ${data['group']} cargado. Presiona "Iniciar Sesión"',
      autoCloseSeconds: 2,
    );
  }

  Future<void> _startGeolocationService() async {
    if (!mounted) return;

    try {
      print('🌍 Iniciando servicio de geolocalización...');
      final ubicacionService = context.read<UbicacionService>();
      await ubicacionService.registrarUbicacion();
      ubicacionService.iniciarCapturaAutomatica(
        intervalo: const Duration(minutes: 2),
      );
      print('✅ Servicio de geolocalización iniciado correctamente');
    } catch (e) {
      print('❌ Error al iniciar el servicio de geolocalización: $e');
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _showSuccessAndNavigate() {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: '¡Bienvenido!',
      text: 'Sesión iniciada correctamente',
      autoCloseDuration: const Duration(seconds: 2),
      barrierDismissible: false,
      showConfirmBtn: false,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _navigateToHome();
      }
    });
  }

  void _navigateToHome() {
    print('🚀 Navegando al Home...');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePage(
          onLogout: () {
            print('🔄 Usuario cerró sesión desde HomePage');
          },
        ),
      ),
          (route) => false,
    );
  }

  void _handleLoginError(String message) {
    AlertHelper.showError(
      context: context,
      title: 'Error de Inicio de Sesión',
      text: message,
    );
  }

  Future<void> _submitLoginWithConnectionCheck() async {
    if (!_formKey.currentState!.validate()) return;

    bool hasConnection = await _checkInternetConnection();
    if (!hasConnection) {
      AlertHelper.showError(
        context: context,
        title: 'Sin Conexión',
        text: 'No hay conexión a internet. Verifica tu conexión e intenta nuevamente.',
      );
      return;
    }

    await _submitLogin();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    AlertHelper.showLoading(
      context: context,
      title: 'Iniciando Sesión',
      text: 'Verificando credenciales...',
    );

    try {
      final authService = context.read<AuthService>();
      final result = await authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      AlertHelper.closeLoading(context);

      if (result['success'] == true) {
        print('✅ Flujo de login completado en la UI');
        await _startGeolocationService();
        _showSuccessAndNavigate();
      } else {
        _handleLoginError(result['message'] ?? 'Ocurrió un error desconocido.');
      }
    } catch (e) {
      if (!mounted) return;
      AlertHelper.closeLoading(context);
      _handleLoginError('Error de conexión. Intente de nuevo.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                      _buildLogo(),
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

                      // Campo Usuario
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

                      // Campo Contraseña
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

                      // Botón de Inicio de Sesión
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : _submitLoginWithConnectionCheck,
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

                      // ✨ NUEVA SECCIÓN: Botones de Acceso Rápido
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),

                      Text(
                        'Acceso Rápido (Desarrollo)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botones de perfiles en fila
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickAccessButton(
                            label: 'Operador',
                            icon: Icons.work_outline,
                            color: Colors.blue,
                            onTap: () => _quickLogin('operador'),
                          ),
                          _buildQuickAccessButton(
                            label: 'Soporte',
                            icon: Icons.support_agent,
                            color: Colors.orange,
                            onTap: () => _quickLogin('soporte'),
                          ),
                          _buildQuickAccessButton(
                            label: 'Coordinador',
                            icon: Icons.admin_panel_settings,
                            color: Colors.green,
                            onTap: () => _quickLogin('coordinador'),
                          ),
                          _buildQuickAccessButton(
                            label: 'Logistico',
                            icon: Icons.admin_panel_settings,
                            color: Colors.purple,
                            onTap: () => _quickLogin('logistico'),
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

  // Widget para botones de acceso rápido
  Widget _buildQuickAccessButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/icono_sereci.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('⚠️ Error al cargar logo: $error');
            return Container(
              color: Colors.blue[50],
              child: const Icon(
                Icons.account_tree,
                size: 50,
                color: Colors.blue,
              ),
            );
          },
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

// import 'package:flutter/material.dart';
// import 'package:quickalert/models/quickalert_type.dart';
// import 'package:quickalert/widgets/quickalert_dialog.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';
// import '../services/auth_service.dart';
// import '../utils/alert_helper.dart';
// import 'home_page.dart';
// import 'package:provider/provider.dart';
// import 'package:manager_key/services/ubicacion_service.dart';
// import 'package:manager_key/models/user_model.dart';
//
// class LoginPage extends StatefulWidget {
//   const LoginPage({Key? key}) : super(key: key);
//
//   @override
//   _LoginPageState createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _isLoading = false;
//   bool _showPassword = false;
//
//   void _quickLogin(String profile) {
//     final userData = {
//       'operador': {
//         'email': 'j.quisbert.a',
//         'username': 'javier.quisbert',
//         'group': 'Operador',
//       },
//       'soporte': {
//         'email': 'soporte@test.com',
//         'username': 'carlos_soporte',
//         'group': 'soporte',
//       },
//       'coordinador': {
//         'email': 'coordinador@test.com',
//         'username': 'test_coordinador',
//         'group': 'coordinador',
//       },
//     };
//
//     final data = userData[profile]!;
//     setState(() {
//       _emailController.text = data['username']!;
//       _passwordController.text = 'Bolivia2025';
//     });
//
//     // Mostrar confirmación del perfil cargado
//     AlertHelper.showInfo(
//       context: context,
//       title: 'Perfil Cargado',
//       text: 'Perfil de ${data['group']} cargado. Presiona "Iniciar Sesión"',
//       autoCloseSeconds: 2,
//     );
//   }
//
//   /// ✅ CORREGIDO: Método para iniciar el servicio de geolocalización
//   Future<void> _startGeolocationService() async {
//     if (!mounted) return;
//
//     try {
//       print('🌍 Iniciando servicio de geolocalización...');
//
//       final ubicacionService = context.read<UbicacionService>();
//
//       await ubicacionService.registrarUbicacion();
//
//       ubicacionService.iniciarCapturaAutomatica(
//         intervalo: const Duration(minutes: 2),
//       );
//
//       print('✅ Servicio de geolocalización iniciado correctamente');
//     } catch (e) {
//       print('❌ Error al iniciar el servicio de geolocalización: $e');
//     }
//   }
//
//   /// ✅ CORREGIDO: Método para verificar conexión a internet
//   Future<bool> _checkInternetConnection() async {
//     try {
//       final result = await InternetAddress.lookup('google.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
//
//   /// ✅ CORREGIDO: Mostrar éxito y navegar
//   void _showSuccessAndNavigate() {
//     QuickAlert.show(
//       context: context,
//       type: QuickAlertType.success,
//       title: '¡Bienvenido!',
//       text: 'Sesión iniciada correctamente',
//       autoCloseDuration: const Duration(seconds: 2),
//       barrierDismissible: false,
//       showConfirmBtn: false,
//     );
//
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) {
//         _navigateToHome();
//       }
//     });
//   }
//
//   /// ✅ CORRECCIÓN: Navegar al Home
//   void _navigateToHome() {
//     print('🚀 Navegando al Home...');
//
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(
//         builder: (context) => HomePage(
//           onLogout: () {
//             print('🔄 Usuario cerró sesión desde HomePage');
//           },
//         ),
//       ),
//           (route) => false,
//     );
//   }
//
//   /// ✅ CORREGIDO: Manejar errores de login
//   void _handleLoginError(String message) {
//     AlertHelper.showError(
//       context: context,
//       title: 'Error de Inicio de Sesión',
//       text: message,
//     );
//   }
//
//   /// ✅ CORREGIDO: Método principal de login con verificación
//   Future<void> _submitLoginWithConnectionCheck() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     bool hasConnection = await _checkInternetConnection();
//     if (!hasConnection) {
//       AlertHelper.showError(
//         context: context,
//         title: 'Sin Conexión',
//         text: 'No hay conexión a internet. Verifica tu conexión e intenta nuevamente.',
//       );
//       return;
//     }
//
//     await _submitLogin();
//   }
//
//   // ✅✅✅ CORRECCIÓN PRINCIPAL APLICADA AQUÍ ✅✅✅
//   /// Método _submitLogin actualizado para usar el nuevo `authService.login`
//   Future<void> _submitLogin() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() {
//       _isLoading = true;
//     });
//
//     AlertHelper.showLoading(
//       context: context,
//       title: 'Iniciando Sesión',
//       text: 'Verificando credenciales...',
//     );
//
//     try {
//       // Usamos context.read<AuthService>() que ya está disponible gracias al Provider
//       final authService = context.read<AuthService>();
//       final result = await authService.login(
//         _emailController.text.trim(),
//         _passwordController.text.trim(),
//       );
//
//       if (!mounted) return;
//
//       AlertHelper.closeLoading(context);
//
//       if (result['success'] == true) {
//         // El login fue exitoso, la sincronización de puntos ya se hizo dentro del método
//         print('✅ Flujo de login completado en la UI');
//         await _startGeolocationService();
//         _showSuccessAndNavigate();
//       } else {
//         // El login falló, mostramos el mensaje de error que viene del servicio
//         _handleLoginError(result['message'] ?? 'Ocurrió un error desconocido.');
//       }
//     } catch (e) {
//       if (!mounted) return;
//       AlertHelper.closeLoading(context);
//       _handleLoginError('Error de conexión. Intente de nuevo.');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       resizeToAvoidBottomInset: true,
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Container(
//             width: 400,
//             child: Card(
//               elevation: 4,
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // ✅ LOGO DE ASSETS - VERSIÓN MEJORADA
//                       _buildLogo(),
//
//                       const SizedBox(height: 16),
//
//                       const Text(
//                         'Iniciar Sesión',
//                         style: TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//
//                       const SizedBox(height: 8),
//
//                       Text(
//                         'Sistema de Reportes Empadronamiento',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//
//                       const SizedBox(height: 32),
//
//                       // --- Campo Usuario ---
//                       TextFormField(
//                         controller: _emailController,
//                         decoration: const InputDecoration(
//                           labelText: 'Usuario',
//                           prefixIcon: Icon(Icons.person),
//                           border: OutlineInputBorder(),
//                         ),
//                         validator: (value) => value == null || value.isEmpty
//                             ? 'Por favor ingresa tu usuario'
//                             : null,
//                       ),
//
//                       const SizedBox(height: 16),
//
//                       // --- Campo Contraseña ---
//                       TextFormField(
//                         controller: _passwordController,
//                         decoration: InputDecoration(
//                           labelText: 'Contraseña',
//                           prefixIcon: const Icon(Icons.lock),
//                           border: const OutlineInputBorder(),
//                           suffixIcon: IconButton(
//                             icon: Icon(
//                               _showPassword
//                                   ? Icons.visibility
//                                   : Icons.visibility_off,
//                               color: Colors.grey,
//                             ),
//                             onPressed: () {
//                               setState(() => _showPassword = !_showPassword);
//                             },
//                           ),
//                         ),
//                         obscureText: !_showPassword,
//                         validator: (value) => value == null || value.isEmpty
//                             ? 'Por favor ingresa tu contraseña'
//                             : null,
//                       ),
//
//                       const SizedBox(height: 24),
//
//                       // --- Botón de Inicio de Sesión ---
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: _isLoading
//                               ? null
//                               : _submitLoginWithConnectionCheck,
//                           style: ElevatedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 16),
//                             backgroundColor: Colors.blue,
//                             foregroundColor: Colors.white,
//                           ),
//                           child: _isLoading
//                               ? const SizedBox(
//                             height: 20,
//                             width: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(
//                                 Colors.white,
//                               ),
//                             ),
//                           )
//                               : const Text(
//                             'Iniciar Sesión',
//                             style: TextStyle(fontSize: 16),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildLogo() {
//     return Container(
//       height: 100,
//       width: 100,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 8,
//             spreadRadius: 2,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: ClipOval(
//         child: Image.asset(
//           'assets/icon/icono_sereci.png',
//           fit: BoxFit.cover,
//           errorBuilder: (context, error, stackTrace) {
//             print('⚠️ Error al cargar logo: $error');
//             return Container(
//               color: Colors.blue[50],
//               child: const Icon(
//                 Icons.account_tree,
//                 size: 50,
//                 color: Colors.blue,
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
// }
