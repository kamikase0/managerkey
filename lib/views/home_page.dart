import 'package:flutter/material.dart';
import 'package:manager_key/views/operador/reporte_view.dart';
import 'package:manager_key/views/operador/salida_ruta_view.dart';
import 'package:manager_key/views/operador/llegada_ruta_view.dart';
import 'package:manager_key/views/tecnico/recepcion_view.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/sidebar.dart';
import 'operador_view.dart';
import 'soporte_view.dart';
import 'coordinador_view.dart';

class HomePage extends StatefulWidget {
  final Function() onLogout;

  const HomePage({Key? key, required this.onLogout}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeView = 'operador';
  String _userGroup = 'operador';
  String _tipoOperador = 'Operador Urbano';
  int? _idOperador;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService().getCurrentUser();

      if (user != null) {
        setState(() {
          _currentUser = user;
          _userGroup = user.primaryGroup;
          _tipoOperador = user.tipoOperador ?? 'Operador Urbano';
          _idOperador = user.idOperador;
          // Establecer vista inicial según tipo de operador
          _activeView = user.isOperadorRural ? 'operador' : 'reporte_diario';
        });

        print('✅ Usuario cargado: ${user.username}');
        print('📍 Tipo Operador: $_tipoOperador');
        print('🔑 ID Operador: $_idOperador');
      } else {
        _setDefaultValues();
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
      _setDefaultValues();
    }
  }

  void _setDefaultValues() {
    setState(() {
      _userGroup = 'operador';
      _tipoOperador = 'Operador Urbano';
      _activeView = 'reporte_diario';
      _idOperador = null;
    });
  }

  Widget _getCurrentView() {
    switch (_activeView) {
    // Vistas comunes
      case 'operador':
        return const OperadorView();
      case 'reporte_diario':
        return const ReporteDiarioView();

    // Vistas solo para Operador Rural
      case 'salida_ruta':
        return SalidaRutaView(idOperador: _idOperador ?? 0);
      case 'llegada_ruta':
        return LlegadaRutaView(idOperador: _idOperador ?? 0);

    // Vistas de otros roles
      case 'soporte':
        return const SoporteView();
      case 'recepcion':
        return const RecepcionView();
      case 'coordinador':
        return const CoordinadorView();

      default:
        return const OperadorView();
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: AuthService().getWelcomeMessage(),
          builder: (context, snapshot) {
            final welcomeMsg = snapshot.data ?? 'Sistema de Gestión';
            return Text(
              welcomeMsg.length > 10
                  ? '${welcomeMsg.substring(0, 10)}...'
                  : welcomeMsg,
            );
          },
        ),
        actions: [
          // Mostrar información del usuario en el AppBar
          FutureBuilder<User?>(
            future: AuthService().getCurrentUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null && user.groups.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.groups.join(', '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (user.tipoOperador != null)
                          Text(
                            user.tipoOperador!,
                            style: const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      drawer: Sidebar(
        activeView: _activeView,
        onViewChanged: (view) {
          setState(() {
            _activeView = view;
          });
          Navigator.of(context).pop();
        },
        userGroup: _userGroup,
        tipoOperador: _tipoOperador,
        isOperadorRural: _currentUser?.isOperadorRural ?? false,
      ),
      body: _getCurrentView(),
    );
  }
}