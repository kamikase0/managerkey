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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final group = await AuthService().getUserGroup();
    setState(() {
      _userGroup = group ?? 'operador';
      _activeView = _userGroup;
    });
  }

  Widget _getCurrentView() {
    switch (_activeView) {
      case 'operador':
        return const OperadorView();
      case 'salida_ruta':
        return const SalidaRutaView();
      case 'llegada_ruta':
        return const LlegadaRutaView();
      case 'reporte_diario':
        return const ReporteDiarioView();
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
          // Mostrar email del usuario en el AppBar
          FutureBuilder<User?>(
            future: AuthService().getCurrentUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null && user.groups.length>0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: Text(
                      user.groups.join(', '),
                      style: const TextStyle(fontSize: 12),
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
          Navigator.of(context).pop(); // Cerrar el drawer
        },
        userGroup: _userGroup,
      ),
      body: _getCurrentView(),
    );
  }
}