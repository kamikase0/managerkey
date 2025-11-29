import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../services/auth_service.dart';
import '../../services/reporte_sync_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';

class ReporteHistorialView extends StatefulWidget {
  const ReporteHistorialView({Key? key}) : super(key: key);

  @override
  State<ReporteHistorialView> createState() => _ReporteHistorialViewState();
}

class _ReporteHistorialViewState extends State<ReporteHistorialView> {
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = false;
  bool _hasInternet = true;
  String _loadingMessage = "Cargando reportes...";
  bool _usingCachedData = false;

  late AuthService _authService;
  late ApiService _apiService;
  late ReporteSyncService _syncService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = Provider.of<AuthService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    _syncService = Provider.of<ReporteSyncService>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    // ✅ PRIMERO: Intentar cargar desde cache del login
    final cachedReportes = await _tryLoadFromCache();
    if (cachedReportes.isNotEmpty) {
      if (mounted) {
        setState(() {
          _reportes = cachedReportes;
          _usingCachedData = true;
        });
      }
      print("✅ Usando reportes cargados durante el login: ${cachedReportes.length}");
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = "Actualizando reportes...";
    });

    try {
      // ================================
      // 1. OBTENER DATOS DE AUTENTICACIÓN
      // ================================
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        _showError("Usuario no autenticado.");
        return;
      }

      final operadorId = currentUser.operador?.idOperador;
      if (operadorId == null) {
        _showError("ID de Operador no encontrado.");
        return;
      }

      // ================================
      // 2. VERIFICAR CONEXIÓN A INTERNET
      // ================================
      setState(() => _loadingMessage = "Verificando conexión a internet...");
      bool hasConnection = await _checkInternetConnection();
      setState(() => _hasInternet = hasConnection);

      // ================================
      // 3. CARGAR REPORTES ACTUALIZADOS
      // ================================
      List<Map<String, dynamic>> reportesActualizados = [];

      if (hasConnection) {
        // ✅ CON INTERNET: Cargar datos actualizados del servidor
        setState(() => _loadingMessage = "Actualizando reportes del servidor...");
        reportesActualizados = await _loadWithInternet(operadorId);
        _usingCachedData = false;
      } else {
        // ❌ SIN INTERNET: Usar cache o cargar locales
        if (_reportes.isEmpty) {
          setState(() => _loadingMessage = "Cargando reportes locales...");
          reportesActualizados = await _loadWithoutInternet(operadorId);
        } else {
          // Ya tenemos datos del cache, no necesitamos recargar
          reportesActualizados = _reportes;
        }
      }

      // ================================
      // 4. ORDENAR Y ACTUALIZAR LA UI
      // ================================
      reportesActualizados.sort((a, b) {
        final fa = DateTime.tryParse(a["fecha_reporte"] ?? "") ?? DateTime(1970);
        final fb = DateTime.tryParse(b["fecha_reporte"] ?? "") ?? DateTime(1970);
        return fb.compareTo(fa);
      });

      if (mounted) {
        setState(() {
          _reportes = reportesActualizados;
        });
      }

      print("✅ Carga completada: ${reportesActualizados.length} reportes");

    } catch (e, stacktrace) {
      print("ERROR en _loadData: $e");
      print(stacktrace);
      if (_reportes.isEmpty) {
        _showError("Ocurrió un error al cargar los reportes: ${e.toString()}");
      } else {
        _showWarning("Usando datos en cache. Error al actualizar: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ CORREGIDO: Obtener reportes del cache
  Future<List<Map<String, dynamic>>> _tryLoadFromCache() async {
    try {
      return await _authService.getReportesFromCache();
    } catch (e) {
      print("❌ Error cargando desde cache: $e");
      return [];
    }
  }

  /// ✅ CORREGIDO: Verificar conexión
  Future<bool> _checkInternetConnection() async {
    try {
      setState(() => _loadingMessage = "Verificando conexión con el servidor...");
      final result = await _apiService.checkConnection();
      print("🔗 Estado de conexión: $result");
      return result;
    } catch (e) {
      print("❌ Sin conexión a internet: $e");
      return false;
    }
  }

  /// ✅ CORREGIDO: Cargar con conexión a internet
  Future<List<Map<String, dynamic>>> _loadWithInternet(int operadorId) async {
    List<Map<String, dynamic>> reportesCombinados = [];

    try {
      // ✅ Cargar reportes actualizados del servidor
      setState(() => _loadingMessage = "Obteniendo reportes actualizados...");
      final reportesRemotos = await _fetchRemoteReportes(operadorId);
      print("📡 Reportes remotos obtenidos: ${reportesRemotos.length}");

      for (var i = 0; i < reportesRemotos.length; i++) {
        print("📍 Remoto $i: ${reportesRemotos[i]['fecha_reporte']} - Operador: ${reportesRemotos[i]['operador']}");
      }

      reportesCombinados.addAll(reportesRemotos.map((r) => {...r, "synced": true}));

      // ✅ Cargar reportes locales no sincronizados
      setState(() => _loadingMessage = "Buscando reportes locales pendientes...");
      final reportesLocalesNoSync = await _fetchLocalUnsyncedReportes(operadorId);
      print("📱 Reportes locales no sincronizados: ${reportesLocalesNoSync.length}");

      for (var i = 0; i < reportesLocalesNoSync.length; i++) {
        print("📱 Local $i: ${reportesLocalesNoSync[i]['fecha_reporte']} - Synced: ${reportesLocalesNoSync[i]['synced']}");
      }

      reportesCombinados.addAll(reportesLocalesNoSync);

      // ✅ Guardar reportes en cache
      await _authService.guardarReportesEnCache(reportesCombinados);

      // ✅ CORREGIDO: Sincronizar pendientes en segundo plano
      _syncPendingReportesInBackground(operadorId);

      print("✅ TOTAL combinados: ${reportesCombinados.length} reportes");

    } catch (e) {
      print("❌ Error en carga con internet: $e");
      // En caso de error, mantener los datos existentes o cargar locales
      if (reportesCombinados.isEmpty) {
        setState(() => _loadingMessage = "Cargando reportes locales...");
        reportesCombinados = await _fetchAllLocalReportes(operadorId);
      }
    }

    return reportesCombinados;
  }

  /// ✅ CORREGIDO: Sincronizar reportes pendientes en segundo plano
  Future<void> _syncPendingReportesInBackground(int operadorId) async {
    try {
      print("🔄 Sincronizando reportes pendientes en segundo plano...");

      // ✅ NUEVO: Obtener el token de autenticación
      final accessToken = await _authService.getAccessToken();
      if (accessToken != null) {
        final apiService = ApiService(accessToken: accessToken);

        // ✅ CORREGIDO: Usar sincronizarReportes en lugar de syncPendingReportes
        await _syncService.sincronizarReportes(apiService: apiService);
        print("✅ Sincronización en segundo plano completada");
      } else {
        print("⚠️ No hay token de autenticación disponible para sincronizar");
      }
    } catch (e) {
      print("❌ Error en sincronización en segundo plano: $e");
    }
  }

  /// ✅ Cargar sin conexión
  Future<List<Map<String, dynamic>>> _loadWithoutInternet(int operadorId) async {
    final reportesLocales = await _fetchAllLocalReportes(operadorId);
    print("📱 Cargados ${reportesLocales.length} reportes locales (sin internet)");
    return reportesLocales;
  }

  /// ✅ Obtener reportes remotos
  Future<List<Map<String, dynamic>>> _fetchRemoteReportes(int operadorId) async {
    try {
      final remotos = await _apiService.obtenerReportesPorOperador(operadorId);
      print("📡 Reportes remotos obtenidos: ${remotos.length}");
      return remotos;
    } catch (e) {
      print("❌ Error obteniendo reportes remotos: $e");
      return [];
    }
  }

  /// ✅ Obtener reportes locales no sincronizados
  Future<List<Map<String, dynamic>>> _fetchLocalUnsyncedReportes(int operadorId) async {
    try {
      final locales = await _syncService.getReportes();
      print("📋 Total de reportes locales en BD: ${locales.length}");

      final unsynced = locales.where((r) {
        final esMismoOperador = r["operador"] == operadorId;
        final noSincronizado = (r["sincronizado"] == 0 || r["sincronizado"] == false);
        final resultado = esMismoOperador && noSincronizado;

        if (resultado) {
          print("🎯 Reporte local no sincronizado encontrado:");
          print("   - Fecha: ${r['fecha_reporte']}");
          print("   - Operador: ${r['operador']}");
          print("   - Sincronizado: ${r['sincronizado']}");
        }

        return resultado;
      }).map((r) {
        final reporteLimpio = Map<String, dynamic>.from(r);
        reporteLimpio['synced'] = false;
        return reporteLimpio;
      }).toList();

      print("📱 Reportes locales no sincronizados filtrados: ${unsynced.length}");
      return unsynced;
    } catch (e) {
      print("❌ Error obteniendo reportes locales no sincronizados: $e");
      return [];
    }
  }

  /// ✅ Obtener todos los reportes locales
  Future<List<Map<String, dynamic>>> _fetchAllLocalReportes(int operadorId) async {
    try {
      final locales = await _syncService.getReportes();
      print("📋 Total de reportes locales en BD: ${locales.length}");

      final allLocal = locales.where((r) {
        final esMismoOperador = r["operador"] == operadorId;
        if (esMismoOperador) {
          print("📱 Reporte local encontrado:");
          print("   - Fecha: ${r['fecha_reporte']}");
          print("   - Operador: ${r['operador']}");
          print("   - Sincronizado: ${r['sincronizado']}");
        }
        return esMismoOperador;
      }).map((r) {
        final reporteLimpio = Map<String, dynamic>.from(r);
        reporteLimpio['synced'] = (r["sincronizado"] == 1 || r["sincronizado"] == true);
        return reporteLimpio;
      }).toList();

      print("📱 Todos los reportes locales filtrados: ${allLocal.length}");
      return allLocal;
    } catch (e) {
      print("❌ Error obteniendo todos los reportes locales: $e");
      return [];
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showWarning(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HISTÓRICO DE REPORTES"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _hasInternet ? Icons.wifi : Icons.wifi_off,
              color: _hasInternet ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de estado de conexión
          if (!_hasInternet)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    "Modo sin conexión - Mostrando reportes locales",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Banner de datos en cache
          if (_usingCachedData && _hasInternet)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cached, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    "Mostrando datos cargados durante el login",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _reportes.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _reportes.length,
                itemBuilder: (context, index) {
                  return _buildReporteCard(
                    reporte: _reportes[index],
                    index: index + 1,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _loadData,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _loadingMessage,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (!_hasInternet)
            Text(
              "Sin conexión a internet",
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasInternet ? Icons.assignment_outlined : Icons.assignment_late_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _hasInternet ? "No hay reportes" : "No hay reportes locales",
            style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _hasInternet
                ? "Los reportes aparecerán aquí cuando los generes"
                : "Conectate a internet para ver todos los reportes",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Recargar"),
          ),
        ],
      ),
    );
  }

  Widget _buildReporteCard({
    required Map<String, dynamic> reporte,
    required int index,
  }) {
    final sincronizado = reporte["synced"] == true;
    final fecha = reporte['fecha_reporte']?.toString() ?? '';
    final estacion = reporte['estacion']?.toString() ?? 'N/A';
    final contadorInicialR = reporte['contador_inicial_r']?.toString() ?? '0';
    final contadorFinalR = reporte['contador_final_r']?.toString() ?? '0';
    final contadorInicialC = reporte['contador_inicial_c']?.toString() ?? '0';
    final contadorFinalC = reporte['contador_final_c']?.toString() ?? '0';
    final registroR = reporte['registro_r']?.toString() ?? '0';
    final registroC = reporte['registro_c']?.toString() ?? '0';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con número de reporte y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Reporte #$index",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sincronizado ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        sincronizado ? Icons.cloud_done : Icons.phone_iphone,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sincronizado ? "ENVIADO" : "LOCAL",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Información del reporte
            _buildInfoRow("Estación", estacion),
            _buildInfoRow("Registros R", "$registroR (Inicial: $contadorInicialR | Final: $contadorFinalR)"),
            _buildInfoRow("Registros C", "$registroC (Inicial: $contadorInicialC | Final: $contadorFinalC)"),
            const SizedBox(height: 8),

            // Fecha y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Fecha: ${_formatearFecha(fecha)}",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (!sincronizado && _hasInternet)
                  Text(
                    "Pendiente de envío",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(String fechaStr) {
    try {
      final f = DateTime.parse(fechaStr);
      return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "Fecha no disponible";
    }
  }
}