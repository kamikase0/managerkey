import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  //ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    // Es mejor inicializar los servicios aquí para acceder al context de forma segura
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

      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        _showError("Sesión expirada. Por favor, inicie sesión de nuevo.");
        return;
      }

      _apiService = ApiService(accessToken: accessToken);

      // ============================================
      // 2. OBTENER REPORTES (EN PARALELO PARA MÁS VELOCIDAD)
      // ============================================
      final results = await Future.wait([
        _fetchRemoteReportes(accessToken, operadorId),
        _fetchLocalReportes(operadorId),
      ]);

      final remotos = results[0];
      final locales = results[1];

      // ================================
      // 3. COMBINAR Y ELIMINAR DUPLICADOS
      // ================================

      // Usamos un mapa para detectar duplicados de manera eficiente.
      // La clave será única para cada reporte (basada en sus datos).
      final Map<String, Map<String, dynamic>> reportesUnicos = {};

      // Primero agregamos los reportes remotos (son la "verdad" principal)
      for (final reporte in remotos) {
        // Usamos una clave robusta para identificar un reporte único.
        final key = _generateReportKey(reporte);
        reportesUnicos[key] = reporte;
      }

      // Ahora agregamos los reportes locales, SOLO si no existen ya en el mapa.
      for (final reporte in locales) {
        final key = _generateReportKey(reporte);
        if (!reportesUnicos.containsKey(key)) {
          // Este es un reporte local que no está en el servidor.
          reportesUnicos[key] = reporte;
        }
      }

      // ================================
      // 4. ORDENAR Y ACTUALIZAR LA UI
      // ================================
      final merged = reportesUnicos.values.toList();

      merged.sort((a, b) {
        final fa = DateTime.tryParse(a["fecha_reporte"] ?? "") ?? DateTime(1970);
        final fb = DateTime.tryParse(b["fecha_reporte"] ?? "") ?? DateTime(1970);
        return fb.compareTo(fa); // Orden descendente (más nuevo primero)
      });

      if (mounted) {
        setState(() {
          _reportes = merged;
        });
      }

      // Opcional: Limpiar la base de datos local de reportes que ya se sincronizaron
      await _syncService.clearSyncedLocalReportes(operadorId);

    } catch (e, stacktrace) {
      print("ERROR FATAL en _loadData: $e");
      print(stacktrace);
      _showError("Ocurrió un error al cargar los reportes.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // MÉTODO PARA GENERAR UNA CLAVE ÚNICA PARA UN REPORTE
  String _generateReportKey(Map<String, dynamic> reporte) {
    // Tomamos la fecha y la truncamos a minutos para evitar diferencias por segundos/milisegundos
    final fechaBase = DateTime.tryParse(reporte['fecha_reporte'] ?? '') ?? DateTime(1970);
    final fechaTruncada = fechaBase.toIso8601String().substring(0, 16); // 'YYYY-MM-DDTHH:mm'
    return '${fechaTruncada}_${reporte['estacion']}_${reporte['operador']}';
  }

  // MÉTODOS AUXILIARES PARA OBTENER DATOS
  Future<List<Map<String, dynamic>>> _fetchRemoteReportes(String accessToken, int operadorId) async {
    try {
      // ✅ CORREGIDO: Usar _apiService ya inicializado
      // if (_apiService == null) {
      //   throw Exception("ApiService no inicializado");
      // }

      final remotos = await _apiService.obtenerReportesDiarios();

      // Filtrar y preparar los datos
      return remotos
          .where((r) => r["operador"] == operadorId)
          .map((r) => {...r, "synced": true})
          .toList();
    } catch (e) {
      print("No se pudieron obtener reportes remotos: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLocalReportes(int operadorId) async {
    final locales = await _syncService.getReportes();
    // ¡¡CORRECCIÓN IMPORTANTE!! Filtrar locales por el operador actual.
    return locales
        .where((r) => r["operador"] == operadorId && r["synced"] == 0)
        .map((r) => {...r, "synced": false}) // Marcar como no sincronizados
        .toList();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // ===================================
  // WIDGETS (sin cambios, ya están bien)
  // ===================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HISTÓRICO DE REPORTES"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No hay reportes",
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.grey[300],
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _loadData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child:
          const Text("REFRESCAR", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildReporteCard({
    required Map<String, dynamic> reporte,
    required int index,
  }) {
    final sincronizado = reporte["synced"] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(index, sincronizado),
          const SizedBox(height: 10),
          Text("Estación: ${reporte['estacion'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 11)),
          Text(
              "Ri: ${reporte['contador_inicial_r']} | Rf: ${reporte['contador_final_r']}",
              style: const TextStyle(fontSize: 11)),
          Text(
              "Ci: ${reporte['contador_inicial_c']} | Cf: ${reporte['contador_final_c']}",
              style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            "Fecha: ${_formatearFecha(reporte['fecha_reporte'] ?? '')}",
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int index, bool sincronizado) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Reporte $index",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        Container(
          width: 55,
          height: 26,
          decoration: BoxDecoration(
            color: sincronizado ? Colors.green : Colors.orange, // Cambiado a naranja
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Text(
            sincronizado ? "ENVIADO" : "LOCAL", // Cambiado a LOCAL
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _formatearFecha(String fechaStr) {
    try {
      final f = DateTime.parse(fechaStr);
      return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "N/A";
    }
  }
}