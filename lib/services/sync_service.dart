import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/registro_despliegue_model.dart';

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

      for (var registro in registrosPendientes) {
        try {
          final enviado = await ApiService().enviarRegistroDespliegue(registro);
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

  /// Obtener última fecha de intento de sincronización
  DateTime? getLastSyncAttempt() => _lastSyncAttempt;

  /// Verificar si está sincronizando
  bool isSyncing() => _isSyncing;
}