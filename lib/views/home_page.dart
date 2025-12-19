

import 'package:flutter/material.dart';
import 'package:manager_key/views/operador/reporte_diario_view.dart';
import 'package:manager_key/views/operador/salida_ruta_view.dart';
import 'package:manager_key/views/operador/llegada_ruta_view.dart';
import 'package:manager_key/views/operador/historial_reportes_diarios_view.dart';
import 'package:manager_key/views/tecnico/recepcion_view.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/reporte_sync_manager.dart';
import '../services/ubicacion_service.dart';
import 'package:manager_key/widgets/sidebar.dart';
import '../utils/alert_helper.dart';
import 'login_page.dart';
import 'operador_view.dart';
import 'soporte_view.dart';
import 'coordinador_view.dart';
import '../views/logistico/bienvenida_view.dart';

enum SimpleSyncStatus {
  synced,
  syncing,
  pending,
  error,
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeView = 'bienvenida';
  String _userGroup = 'operador';
  String _tipoOperador = '';
  int? _idOperador;
  User? _currentUser;

  late AuthService _authService;
  late UbicacionService _ubicacionService;
  late ReporteSyncManager _syncManager;

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

  Future<void> _initializeServices() async {
    try {
      await _ubicacionService.registrarUbicacion();
      await _updateSyncStatus();
    } catch (e) {
      print('❌ Error inicializando servicios: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();

      if (user != null) {
        setState(() {
          _currentUser = user;
          _userGroup = user.groups.isNotEmpty ? user.groups.first : 'desconocido';
          _tipoOperador = user.operador?.tipoOperador ?? '';
          _idOperador = user.operador?.idOperador;
          _activeView = 'bienvenida';
        });

        print('✅ Usuario cargado: ${user.username}, Grupo: $_userGroup, Tipo: $_tipoOperador');
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
    }
  }

  Widget _getCurrentView() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_activeView) {
      case 'bienvenida':
        return BienvenidaView(
          username: _currentUser!.username,
          userRole: _tipoOperador.isNotEmpty ? _tipoOperador : _userGroup,
        );

      case 'llegada_ruta':
        return LlegadaRutaView(
          idOperador: _idOperador ?? 0,
          tipoOperador: _tipoOperador,
        );

      case 'operador_view':
        return const OperadorView();
      case 'salida_ruta':
        return SalidaRutaView(idOperador: _idOperador ?? 0);
      case 'reporte_diario':
        return const ReporteDiarioView();
      case 'historial':
        return const HistorialReportesDiariosView();

      case 'soporte':
        return const SoporteView();
      case 'recepcion':
        return const RecepcionView();
      case 'coordinador':
        return const CoordinadorView();

      default:
        return BienvenidaView(
          username: _currentUser!.username,
          userRole: _tipoOperador.isNotEmpty ? _tipoOperador : _userGroup,
        );
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
        isOperadorRural: _currentUser?.operador?.tipoOperador == 'Operador Rural',
      ),
      body: _getCurrentView(),
    );
  }

  /// ✅ CORREGIDO: Usar verificarConexion() en lugar de tieneConexionInternet()
  Future<void> _updateSyncStatus() async {
    try {
      // ✅ Cambio: verificarConexion() en lugar de tieneConexionInternet()
      final tieneConexion = await _syncManager.verificarConexion();
      final stats = await _syncManager.obtenerEstadisticas();

      setState(() {
        _pendingReports = stats['pendientes'] ?? 0;
        _syncStatus = tieneConexion
            ? (_pendingReports > 0 ? SimpleSyncStatus.pending : SimpleSyncStatus.synced)
            : SimpleSyncStatus.pending;
      });
    } catch (e) {
      print('❌ Error actualizando estado de sincronización: $e');
      setState(() {
        _syncStatus = SimpleSyncStatus.error;
      });
    }
  }

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado['success'] == true
                  ? '✅ ${resultado['sincronizados'] ?? 0} reporte(s) sincronizado(s)'
                  : '❌ ${resultado['message'] ?? 'Error en sincronización'}',
            ),
            backgroundColor: resultado['success'] == true ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await _updateSyncStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _syncStatus = SimpleSyncStatus.error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Widget _buildSyncIndicator() {
    Color backgroundColor;
    IconData icon;
    String tooltip;
    Color iconColor;

    switch (_syncStatus) {
      case SimpleSyncStatus.syncing:
        backgroundColor = Colors.blue.shade100;
        icon = Icons.sync;
        tooltip = 'Sincronizando...';
        iconColor = Colors.blue.shade700;
        break;
      case SimpleSyncStatus.pending:
        backgroundColor = Colors.orange.shade100;
        icon = _pendingReports > 0 ? Icons.cloud_upload : Icons.cloud_off;
        tooltip = _pendingReports > 0
            ? '$_pendingReports reporte(s) pendiente(s)'
            : 'Sin conexión';
        iconColor = Colors.orange.shade700;
        break;
      case SimpleSyncStatus.error:
        backgroundColor = Colors.red.shade100;
        icon = Icons.error;
        tooltip = 'Error de sincronización';
        iconColor = Colors.red.shade700;
        break;
      case SimpleSyncStatus.synced:
      default:
        backgroundColor = Colors.green.shade100;
        icon = Icons.check_circle;
        tooltip = 'Sincronizado';
        iconColor = Colors.green.shade700;
        break;
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
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
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_pendingReports',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
            _tipoOperador.isNotEmpty ? _tipoOperador : _currentUser!.groups.join(', '),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_tipoOperador.isNotEmpty)
            Text(
              _currentUser!.username,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmarSalida = await AlertHelper.mostrarDialogoDeSalida(context);

    if (confirmarSalida == null || !confirmarSalida) return;

    try {
      _ubicacionService.detenerCapturaAutomatica();
      await _authService.logout();

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
  void dispose() {
    _ubicacionService.detenerCapturaAutomatica();
    super.dispose();
  }
}