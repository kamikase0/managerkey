import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/registro_despliegue_model.dart';
import 'auth_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  static bool _isSyncing = false;
  static DateTime? _lastSyncAttempt;

  // Instancia de Connectivity
  final Connectivity _connectivity = Connectivity();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  /// Verificar si hay conexión a internet
  /// Compatible con connectivity_plus 5.0.0+
  Future<bool> verificarConexion() async {
    try {
      final result = await _connectivity.checkConnectivity();

      // Para connectivity_plus 5.0.0+ que devuelve List<ConnectivityResult>
      if (result is List<ConnectivityResult>) {
        return result==(ConnectivityResult.mobile) ||
            result==(ConnectivityResult.wifi);
      }

      // Manejo para versiones anteriores (por compatibilidad)
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  /// Sincronizar registros pendientes
  Future<void> sincronizarRegistrosPendientes() async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso...');
      return;
    }

    _isSyncing = true;
    try {
      final tieneInternet = await verificarConexion();
      if (!tieneInternet) {
        print('❌ Sin conexión a internet');
        return;
      }

      final db = DatabaseService();
      final registrosPendientes = await db.obtenerNoSincronizados();

      if (registrosPendientes.isEmpty) {
        print('✅ No hay registros pendientes');
        return;
      }

      print('📤 Sincronizando ${registrosPendientes.length} registros...');

      // Obtener el token una sola vez
      final accessToken = await _obtenerAccessToken();
      if (accessToken.isEmpty) {
        print('❌ No se pudo obtener access token');
        return;
      }

      final apiService = ApiService(accessToken: accessToken);

      for (var registro in registrosPendientes) {
        try {
          final registroMap = registro.toApiMap();

          // ✅ CORREGIDO: Usar el método que retorna bool directamente
          final enviado = await apiService.enviarRegistroDespliegue(registroMap);

          if (enviado) {
            await db.marcarComoSincronizado(registro.id!);
            print('✅ Registro ${registro.id} sincronizado');
          } else {
            print('⚠️ Error al enviar registro ${registro.id}');
          }
        } catch (e) {
          print('❌ Error en registro ${registro.id}: $e');
        }
      }

      _lastSyncAttempt = DateTime.now();
    } finally {
      _isSyncing = false;
    }
  }

  /// ✅ Obtener accessToken desde AuthService
  Future<String> _obtenerAccessToken() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();

      if (user != null) {
        // Dependiendo de cómo tengas implementado AuthService
        // Podrías necesitar obtener el token de otra manera
        final token = await authService.getAccessToken();
        return token ?? '';
      }
      return '';
    } catch (e) {
      print('Error obteniendo access token: $e');
      return '';
    }
  }

  /// Obtener última fecha de intento de sincronización
  DateTime? getLastSyncAttempt() => _lastSyncAttempt;

  /// Verificar si está sincronizando
  bool isSyncing() => _isSyncing;
}