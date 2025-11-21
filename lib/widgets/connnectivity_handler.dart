// widgets/connectivity_handler.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../views/general/no_internet_screen.dart';

class ConnectivityHandler extends StatefulWidget {
  final Widget child;
  final String? customMessage;

  const ConnectivityHandler({
    Key? key,
    required this.child,
    this.customMessage,
  }) : super(key: key);

  @override
  State<ConnectivityHandler> createState() => _ConnectivityHandlerState();
}

class _ConnectivityHandlerState extends State<ConnectivityHandler> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    print('🚀 ConnectivityHandler iniciado');
    _checkConnection();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    print('📡 Configurando listener de conectividad');
    _connectivityService.connectivityStream.listen((result) {
      print('🔄 Cambio en conectividad: $result');
      if (result == ConnectivityResult.none) {
        print('📵 Sin conexión detectada por listener');
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isChecking = false;
          });
        }
      } else {
        print('📶 Posible reconexión, verificando...');
        _checkConnection();
      }
    });
  }

  Future<void> _checkConnection() async {
    print('🔍 Iniciando verificación de conexión...');
    if (mounted) {
      setState(() => _isChecking = true);
    }

    final hasConnection = await _connectivityService.hasInternetConnection();

    print('🎯 Resultado de verificación: $hasConnection');
    if (mounted) {
      setState(() {
        _isConnected = hasConnection;
        _isChecking = false;
      });
    }
  }

  void _handleRetry() async {
    print('🔄 Reintentando conexión...');
    await _checkConnection();
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Build ConnectivityHandler - Conectado: $_isConnected, Checking: $_isChecking');

    // Mostrar loading mientras verificamos
    if (_isChecking) {
      print('⏳ Mostrando loading de verificación...');
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verificando conexión...'),
            ],
          ),
        ),
      );
    }

    // Mostrar pantalla de sin internet si no hay conexión
    // if (!_isConnected) {
    //   print('🚫 Mostrando pantalla de sin internet');
    //   return NoInternetScreen(
    //     onRetry: _handleRetry,
    //     customMessage: widget.customMessage,
    //   );
    // }

    // Si hay conexión, mostrar el contenido normal
    print('✅ Conexión establecida, mostrando contenido normal');
    return widget.child;
  }
}