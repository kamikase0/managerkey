import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manager_key/views/operador/reporte_diario_view.dart';
import 'package:manager_key/views/operador/salida_ruta_view.dart';
import 'package:manager_key/views/operador/llegada_ruta_view.dart';
import 'package:manager_key/views/operador/historial_reportes_diarios_view.dart';
import 'package:manager_key/views/tecnico/recepcion_view.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/reporte_sync_manager.dart'; // ✅ Cambiar a SyncManager más simple
import '../services/ubicacion_service.dart';
import '../widgets/sidebar.dart';
import '../utils/alert_helper.dart';
import 'login_page.dart';
import 'operador_view.dart';
import 'soporte_view.dart';
import 'coordinador_view.dart';

// ✅ Definir clases simples locales para evitar dependencias
enum SimpleSyncStatus {
  synced,
  syncing,
  pending,
  error,
}

class SimpleSyncState {
  final bool isSyncing;
  final bool offlineMode;
  final bool hasPendingSync;
  final int pendingReports;

  SimpleSyncState({
    required this.isSyncing,
    required this.offlineMode,
    required this.hasPendingSync,
    required this.pendingReports,
  });
}

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
  late AuthService _authService;
  late UbicacionService _ubicacionService;
  late ReporteSyncManager _syncManager;

  // Estado de sincronización simplificado
  SimpleSyncStatus _syncStatus = SimpleSyncStatus.synced;
  int _pendingReports = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _ubicacionService = UbicacionService();
    _syncManager = ReporteSyncManager();

    _loadUserData();
    _initializeServices();
  }

  /// ✅ SIMPLIFICADO: Inicializar servicios
  Future<void> _initializeServices() async {
    try {
      // Iniciar ubicación
      await _ubicacionService.registrarUbicacion();

      // Verificar estado de sincronización inicial
      await _updateSyncStatus();
    } catch (e) {
      print('❌ Error inicializando servicios: $e');
    }
  }

  /// ✅ SIMPLIFICADO: Cargar datos del usuario
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();

      if (user != null) {
        setState(() {
          _currentUser = user;
          _userGroup = user.primaryGroup;
          _tipoOperador = user.tipoOperador ?? 'Operador Urbano';
          _idOperador = user.idOperador;

          // Establecer vista inicial según grupo
          switch (_userGroup.toLowerCase()) {
            case 'operador':
              _activeView = 'operador';
              break;
            case 'coordinador':
              _activeView = 'coordinador';
              break;
            case 'tecnico':
              _activeView = 'recepcion';
              break;
            case 'soporte':
              _activeView = 'soporte';
              break;
            default:
              _activeView = 'operador';
          }
        });

        print('✅ Usuario cargado: ${user.username}');
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
    }
  }

  /// ✅ SIMPLIFICADO: Actualizar estado de sincronización
  Future<void> _updateSyncStatus() async {
    try {
      final tieneConexion = await _syncManager.tieneConexionInternet();
      final idOperador = await _authService.getIdOperador();

      if (idOperador != null) {
        final stats = await _syncManager.obtenerEstadisticas();
        setState(() {
          _pendingReports = stats['pendientes'] ?? 0;
          _syncStatus = tieneConexion
              ? (_pendingReports > 0 ? SimpleSyncStatus.pending : SimpleSyncStatus.synced)
              : SimpleSyncStatus.pending;
        });
      }
    } catch (e) {
      print('❌ Error actualizando estado de sincronización: $e');
    }
  }

  /// ✅ SIMPLIFICADO: Lógica de vistas
  Widget _getCurrentView() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Lógica para grupo "Operador"
    if (_userGroup.toLowerCase() == 'operador') {
      if (_currentUser!.isOperadorRural) {
        switch (_activeView) {
          case 'operador':
            return const OperadorView();
          case 'salida_ruta':
            return SalidaRutaView(idOperador: _idOperador ?? 0);
          case 'llegada_ruta':
            return LlegadaRutaView(idOperador: _idOperador ?? 0);
          case 'reporte_diario':
            return const ReporteDiarioView();
          case 'historial':
            return const HistorialReportesDiariosView();
          default:
            return const OperadorView();
        }
      } else if (_currentUser!.isOperadorUrbano) {
        switch (_activeView) {
          case 'operador':
            return const OperadorView();
          case 'llegada_ruta':
            return LlegadaRutaView(idOperador: _idOperador ?? 0);
          case 'reporte_diario':
            return const ReporteDiarioView();
          case 'historial':
            return const HistorialReportesDiariosView();
          default:
            return const OperadorView();
        }
      }
    }

    // Lógica para otros roles
    switch (_activeView) {
      case 'soporte':
        return const SoporteView();
      case 'recepcion':
        return const RecepcionView();
      case 'coordinador':
        return const CoordinadorView();
      default:
        return const Center(child: Text("Bienvenido"));
    }
  }

  /// ✅ SIMPLIFICADO: Sincronización manual
  Future<void> _sincronizarManualmente() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncStatus = SimpleSyncStatus.syncing;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Iniciando sincronización...'),
          duration: Duration(seconds: 2),
        ),
      );

      final resultado = await _syncManager.sincronizarReportesPendientes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['success'] == true
              ? '✅ Sincronización completada'
              : '❌ Error en sincronización'),
          backgroundColor: resultado['success'] == true ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      await _updateSyncStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  /// ✅ SIMPLIFICADO: Widget de indicador de sincronización
  Widget _buildSyncIndicator() {
    Color backgroundColor;
    IconData icon;
    String text;
    Color iconColor;

    switch (_syncStatus) {
      case SimpleSyncStatus.syncing:
        backgroundColor = Colors.blue.shade100;
        icon = Icons.sync;
        text = 'Sincronizando...';
        iconColor = Colors.blue.shade700;
        break;
      case SimpleSyncStatus.pending:
        backgroundColor = Colors.orange.shade100;
        icon = _pendingReports > 0 ? Icons.cloud_upload : Icons.cloud_off;
        text = _pendingReports > 0 ? '$_pendingReports' : 'Offline';
        iconColor = Colors.orange.shade700;
        break;
      case SimpleSyncStatus.error:
        backgroundColor = Colors.red.shade100;
        icon = Icons.error;
        text = 'Error';
        iconColor = Colors.red.shade700;
        break;
      case SimpleSyncStatus.synced:
      default:
        backgroundColor = Colors.green.shade100;
        icon = Icons.check_circle;
        text = 'Sincronizado';
        iconColor = Colors.green.shade700;
        break;
    }

    return GestureDetector(
      onTap: _syncStatus == SimpleSyncStatus.syncing ? null : _sincronizarManualmente,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: iconColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_syncStatus == SimpleSyncStatus.syncing)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            else
              Icon(icon, size: 16, color: iconColor),
            if (_pendingReports > 0 && _syncStatus == SimpleSyncStatus.pending) ...[
              const SizedBox(width: 4),
              Text(
                '$_pendingReports',
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ✅ SIMPLIFICADO: Widget de información del usuario
  Widget _buildUserInfo() {
    if (_currentUser == null || _currentUser!.groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _currentUser!.groups.join(', '),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_tipoOperador.isNotEmpty)
            Text(
              _tipoOperador,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  /// ✅ SIMPLIFICADO: Logout
  Future<void> _logout() async {
    final confirmarSalida = await AlertHelper.mostrarDialogoDeSalida(context);

    if (!confirmarSalida) return;

    try {
      // Detener servicios
      _ubicacionService.detenerCapturaAutomatica();

      // Hacer logout en AuthService
      await _authService.logout();

      // Navegar a LoginPage
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error en logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: _authService.getWelcomeMessage(),
          builder: (context, snapshot) {
            final welcomeMsg = snapshot.data ?? 'Sistema de Gestión';
            return Text(
              welcomeMsg.length > 20
                  ? '${welcomeMsg.substring(0, 20)}...'
                  : welcomeMsg,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        actions: [
          _buildSyncIndicator(),
          const SizedBox(width: 8),
          _buildUserInfo(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
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

  @override
  void dispose() {
    _ubicacionService.detenerCapturaAutomatica();
    super.dispose();
  }
}