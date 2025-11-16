import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manager_key/views/operador/reporte_diario_view.dart';
import 'package:manager_key/views/operador/salida_ruta_view.dart';
import 'package:manager_key/views/operador/llegada_ruta_view.dart';
import 'package:manager_key/views/tecnico/recepcion_view.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/reporte_sync_service.dart';
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
  late ReporteSyncService _syncService;

  @override
  void initState() {
    super.initState();
    // Usar context.read es seguro dentro de initState
    _syncService = context.read<ReporteSyncService>();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Es mejor usar el provider si ya está disponible
      final authService = context.read<AuthService>();
      final user = await authService.getCurrentUser();

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
        print('🔧 Tipo Operador: $_tipoOperador');
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

  // =======================================================
  // >> NUEVA FUNCIÓN: DIÁLOGO DE CONFIRMACIÓN <<
  // =======================================================
  Future<bool> _mostrarDialogoDeSalida() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // El usuario debe presionar un botón
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirmar Salida'),
          content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('NO', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('SÍ, SALIR', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    // Si el usuario cierra el diálogo de otra forma, asumimos 'false'
    return resultado ?? false;
  }
  // =======================================================

  Future<void> _logout() async {
    // Usamos el provider para una única fuente de verdad
    final authService = context.read<AuthService>();
    await authService.logout();
    //_syncService.dispose();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos una sola vez el provider de AuthService para evitar múltiples llamadas
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: authService.getWelcomeMessage(),
          builder: (context, snapshot) {
            final welcomeMsg = snapshot.data ?? 'Sistema de Gestión';
            return Text(
              welcomeMsg.length > 20
                  ? '${welcomeMsg.substring(0, 20)}...'
                  : welcomeMsg,
            );
          },
        ),
        actions: [
          // Indicador de estado de sincronización
          StreamBuilder<SyncStatus>(
            stream: _syncService.syncStatusStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final status = snapshot.data!;
              final icon = status.isSyncing
                  ? Icons.cloud_upload
                  : (status.success
                  ? Icons.cloud_done
                  : (status.offlineMode ? Icons.cloud_off : Icons.error));

              final color = status.isSyncing
                  ? Colors.amber
                  : (status.success
                  ? Colors.green
                  : (status.offlineMode ? Colors.orange : Colors.red));

              return Tooltip(
                message: status.message,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Icon(icon, color: color),
                  ),
                ),
              );
            },
          ),

          // Mostrar información del usuario en el AppBar
          FutureBuilder<User?>(
            future: authService.getCurrentUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null && user.groups.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          user.groups.join(', '),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
            // =======================================================
            // >> CAMBIO PRINCIPAL: LÓGICA DE onP ressed <<
            // =======================================================
            onPressed: () async {
              // 1. Mostrar el diálogo y esperar la respuesta
              final bool confirmarSalida = await _mostrarDialogoDeSalida();

              // 2. Si el usuario confirma, entonces ejecutar el logout
              if (confirmarSalida) {
                await _logout();
              }
              // Si no, no hacer nada.
            },
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
      body: Stack(
        children: [
          _getCurrentView(),
          // Indicador flotante de sincronización (opcional, para modo offline)
          Positioned(
            bottom: 16,
            right: 16,
            child: StreamBuilder<SyncStatus>(
              stream: _syncService.syncStatusStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.offlineMode) {
                  return const SizedBox.shrink();
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Modo offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
