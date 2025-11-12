import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Administrador de LLaves',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  late StreamSubscription<dynamic> _connectivitySubscription;
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _initializeConnectivityListener();
  }

  /// =============================
  /// 📱 Verificar autenticación
  /// =============================
  Future<void> _checkAuth() async {
    final authenticated = await AuthService().isAuthenticated();
    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  /// =============================
  /// 📡 Listener de Conectividad
  /// =============================
  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((result) async {
      print('📡 Estado de conectividad: $result');

      bool tieneConexion = false;

      // Manejar si es una lista
      if (result is List<ConnectivityResult>) {
        tieneConexion = result == (ConnectivityResult.mobile) ||
            result == (ConnectivityResult.wifi);
      }
      // Manejar si es un único valor
      else if (result is ConnectivityResult) {
        tieneConexion = result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi;
      } else {
        // Fallback para otros tipos
        tieneConexion = false;
      }

      if (tieneConexion) {
        print('✅ Conexión detectada, iniciando sincronización...');
        await _syncService.sincronizarRegistrosPendientes();
      } else {
        print('❌ Sin conexión a internet');
      }
    });

    // Verificar conexión inicial al iniciar la app
    _verificarConexionInicial();
  }

  /// =============================
  /// 🔍 Verificar conexión inicial
  /// =============================
  Future<void> _verificarConexionInicial() async {
    final tieneInternet = await _syncService.verificarConexion();
    if (tieneInternet) {
      print('📤 App iniciada con conexión, sincronizando registros pendientes...');
      await _syncService.sincronizarRegistrosPendientes();
    }
  }

  /// =============================
  /// ✅ Manejo de login exitoso
  /// =============================
  void _handleLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
    // Intentar sincronizar después de login
    _verificarConexionInicial();
  }

  /// =============================
  /// ❌ Manejo de logout
  /// =============================
  void _handleLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated
        ? HomePage(onLogout: _handleLogout)
        : LoginPage(onLoginSuccess: _handleLoginSuccess);
  }
}