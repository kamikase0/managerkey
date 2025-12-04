import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manager_key/views/operador/reporte_diario_view.dart';
import 'package:manager_key/views/operador/salida_ruta_view.dart';
import 'package:manager_key/views/operador/llegada_ruta_view.dart';
// ✅ PASO 1: AÑADIR LA IMPORTACIÓN PARA LA VISTA DE HISTORIAL
import 'package:manager_key/views/operador/historial_reportes_diarios_view.dart';
import 'package:manager_key/views/tecnico/recepcion_view.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/reporte_sync_service.dart';
import '../services/api_service.dart';
import '../services/ubicacion_service.dart';
import '../widgets/sidebar.dart';
import '../utils/alert_helper.dart';
import 'login_page.dart';
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
  late AuthService _authService;
  late UbicacionService _ubicacionService;
  late ApiService? _apiService;

  // ✅ CORREGIDO: Stream único que no se recrea
  Stream<SyncStatus>? _syncStream;

  @override
  void initState() {
    super.initState();
    _syncService = Provider.of<ReporteSyncService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    _ubicacionService = Provider.of<UbicacionService>(context, listen: false);

    _loadUserData();
    _initializeSyncService();
    _initializeUbicacionService();
  }

  /// ✅ NUEVO: Inicializar servicio de ubicaciones
  Future<void> _initializeUbicacionService() async {
    try {
      print('🌍 Inicializando servicio de ubicaciones...');

      // Registrar ubicación inmediatamente
      await _ubicacionService.registrarUbicacion();

      // Iniciar captura automática cada 2 minutos
      _ubicacionService.iniciarCapturaAutomatica(
        intervalo: const Duration(minutes: 2),
      );

      print('✅ Servicio de ubicaciones inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando servicio de ubicaciones: $e');
    }
  }

  /// ✅ CORREGIDO: Inicializar el stream una sola vez
  void _initializeSyncStream() {
    if (_syncStream == null) {
      _syncStream = _syncService.syncStatusStream.asBroadcastStream();
      print("Stream  de sincronizacion inicializado");
    }
  }

  /// ✅ CORREGIDO: Inicializar el servicio de sincronización con token
  Future<void> _initializeSyncService() async {
    try {
      print('🔧 Inicializando servicio de sincronización...');

      final token = await _authService.getAccessToken();

      if (token != null && token.isNotEmpty) {
        // ✅ Inicializar ReporteSyncService con el token
        await _syncService.initialize(accessToken: token);

        _initializeSyncStream();

        print('✅ Servicio de sincronización inicializado con token');

        // Iniciar sincronización manual después de 2 segundos
        await Future.delayed(const Duration(seconds: 2));
        await _syncService.syncNow();
      } else {
        print('⚠️ No hay token disponible para inicializar sincronización');
      }
    } catch (e) {
      print('❌ Error inicializando sincronización: $e');
    }
  }

  /// ✅ CORREGIDO Y AJUSTADO: Cargar datos del usuario y establecer vista inicial
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();

      if (user != null) {
        setState(() {
          _currentUser = user;
          _userGroup = user.primaryGroup;
          _tipoOperador = user.tipoOperador ?? 'Operador Urbano';
          _idOperador = user.idOperador;

          // --- AJUSTE CLAVE AQUÍ ---
          // Establecer la vista inicial basada en el grupo del usuario.
          switch (_userGroup.toLowerCase()) { // Usar toLowerCase para ser robusto
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
            // Vista por defecto segura si el grupo no se reconoce.
              _activeView = 'operador';
          }
        });

        print('✅ Usuario cargado: ${user.username}');
        print('🔧 Grupo: $_userGroup');
        print('🔧 Tipo Operador: $_tipoOperador');
        print('📍 ID Operador: $_idOperador');
        print('👀 Vista Inicial: $_activeView');
      } else {
        _setDefaultValues();
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
      _setDefaultValues();
    }
  }


  /// Establecer valores por defecto
  void _setDefaultValues() {
    setState(() {
      _userGroup = 'operador';
      _tipoOperador = 'Operador Urbano';
      _activeView = 'operador';
      _idOperador = null;
    });
  }

  /// ✅ AJUSTE FINAL: Lógica de vistas separada por tipo de operador.
  /// ✅ AJUSTE FINAL: Lógica de vistas separada por tipo de operador.
  Widget _getCurrentView() {
    // Si el usuario no está cargado, muestra un indicador de carga.
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- Lógica para el grupo "Operador" ---
    if (_userGroup.toLowerCase() == 'operador') {
      // Menú para OPERADOR RURAL
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
            return const OperadorView(); // Vista por defecto para Rural
        }
      }
      // Menú para OPERADOR URBANO
      else if (_currentUser!.isOperadorUrbano) {
        switch (_activeView) {
          case 'operador':
            return const OperadorView();
        // 'salida_ruta' no está disponible para Urbano

        // ✅ VISTA AÑADIDA PARA OPERADOR URBANO
          case 'llegada_ruta':
            return LlegadaRutaView(idOperador: _idOperador ?? 0);
          case 'reporte_diario':
            return const ReporteDiarioView();
          case 'historial':
            return const HistorialReportesDiariosView();
          default:
          // Vista por defecto para Operador Urbano si el estado es inválido
            return const OperadorView();
        }
      }
    }

    // --- Lógica para otros roles (Coordinador, Soporte, etc.) ---
    switch (_activeView) {
      case 'soporte':
        return const SoporteView();
      case 'recepcion':
        return const RecepcionView();
      case 'coordinador':
        return const CoordinadorView();
      default:
      // Si se llega aquí, es un rol no-operador con una vista inválida.
      // Se le redirige a una vista segura.
        return const Center(child: Text("Bienvenido"));
    }
  }



  /// ✅ NUEVO: Sincronizar ubicaciones pendientes manualmente
  Future<void> _sincronizarUbicacionesManualmente() async {
    if (!mounted) {
      print('⚠️ Widget desmontado, cancelando sincronización');
      return;
    }

    try {
      print('📍 Sincronizando ubicaciones pendientes...');
      await _ubicacionService.sincronizarUbicacionesPendientes();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ubicaciones sincronizadas correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// ✅ CORREGIDO: Sincronización manual de reportes
  Future<void> _manualSync() async {
    if (!mounted) {
      print('⚠️ Widget desmontado, cancelando sincronización manual');
      return;
    }

    final result = await _syncService.syncNow();

    if (!mounted) {
      print('⚠️ Widget desmontado, no se puede mostrar snackbar');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),
      ),
    );
  }

  /// ✅ CORREGIDO: Construir indicador de sincronización
  Widget _buildSyncIndicator() {
    if (_syncStream == null) {
      return _buildSyncButton();
    }

    return StreamBuilder<SyncStatus>(
      stream: _syncStream,
      builder: (context, snapshot) {
        final status = snapshot.data;

        if (status == null || status == SyncStatus.synced) {
          return _buildSyncButton();
        }

        if (status == SyncStatus.syncing) {
          return _buildSyncingIndicator();
        }

        if (status == SyncStatus.pending) {
          return _buildOfflineIndicator();
        }

        if (status == SyncStatus.error) {
          return _buildErrorIndicator();
        }

        return _buildSyncButton();
      },
    );
  }

  /// Widget: Botón de sincronización normal
  Widget _buildSyncButton() {
    return FutureBuilder<SyncState>(
      future: _syncService.getSyncState(),
      builder: (context, snapshot) {
        final state = snapshot.data;
        final hasPending = state?.hasPendingSync == true;
        final pendingCount = (state?.pendingReports ?? 0) +
            (state?.pendingDeployments ?? 0);

        return GestureDetector(
          onTap: _manualSync,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasPending ? Colors.orange.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasPending ? Colors.orange : Colors.grey,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync,
                  size: 16,
                  color: hasPending ? Colors.orange : Colors.grey,
                ),
                if (hasPending && pendingCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$pendingCount',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Widget: Indicador sincronizando
  Widget _buildSyncingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Sincronizando...',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget: Indicador offline
  Widget _buildOfflineIndicator() {
    return GestureDetector(
      onTap: _manualSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text(
              'Offline',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget: Indicador de error
  Widget _buildErrorIndicator() {
    return GestureDetector(
      onTap: _manualSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 16, color: Colors.red.shade700),
            const SizedBox(width: 6),
            Text(
              'Error',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget: Información del usuario
  Widget _buildUserInfo() {
    return FutureBuilder<User?>(
      future: _authService.getCurrentUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null && user.groups.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user.groups.join(', '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (user.tipoOperador != null)
                  Text(
                    user.tipoOperador!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// ✅ CORREGIDO: Widget para el banner de estado
  Widget _buildSyncStatusBanner() {
    if (_syncStream == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16,
      right: 16,
      left: 16,
      child: StreamBuilder<SyncStatus>(
        stream: _syncStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == SyncStatus.synced) {
            return const SizedBox.shrink();
          }

          final status = snapshot.data!;
          Color backgroundColor;
          IconData icon;
          String text;

          switch (status) {
            case SyncStatus.syncing:
              backgroundColor = Colors.blue.shade600;
              icon = Icons.sync;
              text = 'Sincronizando datos...';
              break;
            case SyncStatus.pending:
              backgroundColor = Colors.orange.shade600;
              icon = Icons.cloud_off;
              text = 'Modo offline - Los datos se guardarán localmente';
              break;
            case SyncStatus.error:
              backgroundColor = Colors.red.shade600;
              icon = Icons.error;
              text = 'Error de sincronización';
              break;
            case SyncStatus.synced:
              backgroundColor = Colors.green.shade600;
              icon = Icons.cloud_done;
              text = 'Sincronizado';
              break;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
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
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (status == SyncStatus.pending)
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white, size: 18),
                    onPressed: _manualSync,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          );
        },
      ),
    );
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
            onPressed: () async {
              final bool confirmarSalida =
              await AlertHelper.mostrarDialogoDeSalida(context);
              if (confirmarSalida) {
                await _logout();
              }
            },
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
      body: Stack(
        children: [
          _getCurrentView(),
          _buildSyncStatusBanner(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print('🧹 Limpiando HomePage...');
    _ubicacionService.detenerCapturaAutomatica();
    _syncService.dispose();
    super.dispose();
  }

  /// ✅ MÉTODO LOGOUT FINAL Y CORRECTO (reemplaza el actual en home_page.dart)
  Future<void> _logout() async {
    print('🔄 ========== INICIANDO LOGOUT ==========');

    try {
      // ✅ PASO 1: Detener geolocalización
      print('🌍 PASO 1: Deteniendo geolocalización...');
      try {
        _ubicacionService.detenerCapturaAutomatica();
        print('✅ Geolocalización detenida');
      } catch (e) {
        print('⚠️ Error deteniendo geolocalización: $e');
      }

      // ✅ PASO 2: Detener sincronización de reportes
      print('📊 PASO 2: Deteniendo sincronización...');
      try {
        _syncService.stopSync(); // Detener el timer
        print('✅ Sincronización detenida');
      } catch (e) {
        print('⚠️ Error deteniendo sincronización: $e');
      }

      // ✅ PASO 3: Dispose de servicios
      print('🧹 PASO 3: Limpiando servicios...');
      try {
        _syncService.dispose(); // Limpiar todo
        print('✅ Servicios limpios');
      } catch (e) {
        print('⚠️ Error limpiando servicios: $e');
      }

      // ✅ PASO 4: Logout en AuthService
      print('🔐 PASO 4: Logout en AuthService...');
      try {
        await _authService.logout();
        print('✅ Logout completado en AuthService');
      } catch (e) {
        print('⚠️ Error en logout de AuthService: $e');
      }

      // ✅ PASO 5: Diagnosticar estado post-logout
      print('🔍 PASO 5: Diagnosticando estado post-logout...');
      try {
        final diagnostic = await _authService.diagnosticarLogout();
        print('🔍 Diagnóstico: $diagnostic');

        if (diagnostic['hasAccessToken'] == true || diagnostic['hasUserData'] == true) {
          print('⚠️ ADVERTENCIA: Aún hay datos residuales!');
          print('   - Access Token: ${diagnostic['hasAccessToken']}');
          print('   - User Data: ${diagnostic['hasUserData']}');
        } else {
          print('✅ Todos los datos fueron eliminados correctamente');
        }
      } catch (e) {
        print('⚠️ Error diagnosticando: $e');
      }

      // ✅ PASO 6: Esperar limpieza
      print('⏳ PASO 6: Esperando limpieza de datos...');
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ PASO 7: Navegar a Login
      print('🚀 PASO 7: Navegando a LoginPage...');
      if (!mounted) {
        print('⚠️ Widget no está montado, cancelando navegación');
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false, // Elimina todo el stack de navegación
      );

      print('✅ ========== LOGOUT COMPLETADO ==========');
    } catch (e) {
      print('❌ ERROR CRÍTICO EN LOGOUT: $e');

      // Nuclear option: forzar logout incluso si hay error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en logout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Intentar navegar de todos modos
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
            );
          }
        });
      }
    }
  }

  /// ✅ MÉTODO PARA MOSTRAR CONFIRMACIÓN DE LOGOUT
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando afuera
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text(
            '¿Estás seguro de que deseas cerrar sesión? Se limpiarán todos los datos locales.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('❌ Usuario canceló logout');
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                print('✅ Usuario confirmó logout');
                Navigator.of(dialogContext).pop();
                _logout(); // Ejecutar logout después de cerrar el diálogo
              },
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
