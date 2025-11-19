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
    setState(() => _isLoading = true);

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

      // ============================================
      // 2. OBTENER REPORTES (EN PARALELO PARA MÁS VELOCIDAD)
      // ============================================
      final results = await Future.wait([
        _fetchRemoteReportes(operadorId),
        _fetchLocalReportes(operadorId),
      ]);

      final remotos = results[0];
      final locales = results[1];

      // ================================
      // 3. COMBINAR Y ELIMINAR DUPLICADOS
      // ================================
      final Map<String, Map<String, dynamic>> reportesUnicos = {};

      // Primero agregamos los reportes remotos
      for (final reporte in remotos) {
        final key = _generateReportKey(reporte);
        reportesUnicos[key] = {...reporte, "synced": true};
      }

      // Agregamos los reportes locales si no existen
      for (final reporte in locales) {
        final key = _generateReportKey(reporte);
        if (!reportesUnicos.containsKey(key)) {
          reportesUnicos[key] = {...reporte, "synced": false};
        }
      }

      // ================================
      // 4. ORDENAR Y ACTUALIZAR LA UI
      // ================================
      final merged = reportesUnicos.values.toList();

      merged.sort((a, b) {
        final fa = DateTime.tryParse(a["fecha_reporte"] ?? "") ?? DateTime(1970);
        final fb = DateTime.tryParse(b["fecha_reporte"] ?? "") ?? DateTime(1970);
        return fb.compareTo(fa);
      });

      if (mounted) {
        setState(() {
          _reportes = merged;
        });
      }

      // Limpiar reportes locales ya sincronizados
      await _syncService.clearSyncedLocalReportes(operadorId);

    } catch (e, stacktrace) {
      print("ERROR en _loadData: $e");
      print(stacktrace);
      _showError("Ocurrió un error al cargar los reportes: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // MÉTODO PARA GENERAR UNA CLAVE ÚNICA PARA UN REPORTE
  String _generateReportKey(Map<String, dynamic> reporte) {
    final fechaBase = DateTime.tryParse(reporte['fecha_reporte'] ?? '') ?? DateTime(1970);
    final fechaTruncada = fechaBase.toIso8601String().substring(0, 16);
    final estacion = reporte['estacion']?.toString() ?? 'unknown';
    final operador = reporte['operador']?.toString() ?? 'unknown';
    return '${fechaTruncada}_${estacion}_$operador';
  }

  // ✅ CORREGIDO: Método simplificado sin verificación compleja
  Future<List<Map<String, dynamic>>> _fetchRemoteReportes(int operadorId) async {
    try {
      // ✅ INTENTAR DIRECTAMENTE - si falla, capturamos la excepción
      final remotos = await _apiService.obtenerReportesDiarios();

      // Filtrar y preparar los datos
      return remotos
          .where((r) => r["operador"] == operadorId)
          .map((r) => {...r})
          .toList();
    } catch (e) {
      print("❌ Error obteniendo reportes remotos: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLocalReportes(int operadorId) async {
    try {
      final locales = await _syncService.getReportes();
      return locales
          .where((r) => r["operador"] == operadorId && (r["synced"] == 0 || r["synced"] == false))
          .map((r) => {...r})
          .toList();
    } catch (e) {
      print("❌ Error obteniendo reportes locales: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HISTÓRICO DE REPORTES"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Cargando reportes...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _loadData,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            "No hay reportes",
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            "Los reportes aparecerán aquí cuando los generes",
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
                  child: Text(
                    sincronizado ? "ENVIADO" : "LOCAL",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Información del reporte
            _buildInfoRow("Estación", estacion),
            _buildInfoRow("Contador R", "Inicial: $contadorInicialR | Final: $contadorFinalR"),
            _buildInfoRow("Contador C", "Inicial: $contadorInicialC | Final: $contadorFinalC"),
            const SizedBox(height: 8),

            // Fecha
            Text(
              "Fecha: ${_formatearFecha(fecha)}",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
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
            width: 80,
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