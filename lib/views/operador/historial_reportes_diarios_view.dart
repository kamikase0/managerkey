// lib/views/operador/historial_reportes_diarios_view.dart
import 'package:flutter/material.dart';
import 'package:manager_key/services/reporte_sync_manager.dart';
import '../../models/reporte_diario_local.dart';

class HistorialReportesDiariosView extends StatefulWidget {
  const HistorialReportesDiariosView({Key? key}) : super(key: key);

  @override
  State<HistorialReportesDiariosView> createState() =>
      _HistorialReportesDiariosViewState();
}

class _HistorialReportesDiariosViewState
    extends State<HistorialReportesDiariosView> {
  final ReporteSyncManager _syncManager = ReporteSyncManager();

  late Future<List<ReporteDiarioLocal>> _reportesFuture;
  Map<String, dynamic> _estadisticas = {};

  bool _isSyncing = false;
  bool _isLoadingFromApi = false;

  @override
  void initState() {
    super.initState();
    _actualizarDatosCompletos();
  }

  /// Actualiza datos desde API y BD local
  Future<void> _actualizarDatosCompletos() async {
    if (_isLoadingFromApi) return;

    setState(() => _isLoadingFromApi = true);

    try {
      // 1. Descargar reportes desde API
      await _syncManager.descargarYGuardarReportesDesdeApi();

      // 2. Cargar desde BD local
      _cargarReportes();
      await _cargarEstadisticas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Historial actualizado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error actualizando datos: $e');

      // Aún así cargar datos locales
      _cargarReportes();
      await _cargarEstadisticas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error conectando al servidor. Mostrando datos locales.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFromApi = false);
      }
    }
  }

  /// Cargar reportes desde BD local
  void _cargarReportes() {
    if (mounted) {
      setState(() {
        _reportesFuture = _syncManager.obtenerReportes();
      });
    }
  }

  /// Cargar estadísticas
  Future<void> _cargarEstadisticas() async {
    final stats = await _syncManager.obtenerEstadisticas();
    if (mounted) {
      setState(() => _estadisticas = stats);
    }
  }

  /// Sincronizar reportes pendientes manualmente
  Future<void> _sincronizarManualmente() async {
    setState(() => _isSyncing = true);

    try {
      final resultado = await _syncManager.sincronizarReportesPendientes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Sincronización completada'),
            backgroundColor: resultado['success'] == true ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Recargar datos después de sincronizar
      await _actualizarDatosCompletos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error en la sincronización'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Reportes'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Badge de reportes pendientes
          if ((_estadisticas['pendientes'] ?? 0) > 0)
            IconButton(
              icon: Stack(
                children: [
                  Icon(
                    _isSyncing ? Icons.sync : Icons.cloud_upload,
                    color: _isSyncing ? Colors.orange : Colors.yellow,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_estadisticas['pendientes']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: _isSyncing ? null : _sincronizarManualmente,
              tooltip: 'Sincronizar reportes pendientes',
            ),

          // Botón de refresh
          IconButton(
            icon: _isLoadingFromApi
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.refresh),
            onPressed: _isLoadingFromApi ? null : _actualizarDatosCompletos,
            tooltip: 'Actualizar desde servidor',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de reportes pendientes
          if ((_estadisticas['pendientes'] ?? 0) > 0)
            _buildBannerPendientes(),

          // Card de estadísticas
          _buildCardEstadisticas(),

          // Lista de reportes
          Expanded(
            child: _isLoadingFromApi
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Descargando historial del servidor...'),
                ],
              ),
            )
                : FutureBuilder<List<ReporteDiarioLocal>>(
              future: _reportesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorWidget(snapshot.error.toString());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyWidget();
                }

                final reportes = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _actualizarDatosCompletos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: reportes.length,
                    itemBuilder: (context, index) {
                      return _buildReporteCard(reportes[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // WIDGETS AUXILIARES
  // ===================================================================

  Widget _buildBannerPendientes() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.cloud_upload, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_estadisticas['pendientes']} reporte(s) pendiente(s) de sincronizar',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSyncing ? null : _sincronizarManualmente,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _isSyncing
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.orange),
              ),
            )
                : Text(
              'SINCRONIZAR',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardEstadisticas() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildEstadisticaItem(
              'Total',
              _estadisticas['total'] ?? 0,
              Colors.blue,
              Icons.assignment,
            ),
            _buildEstadisticaItem(
              'Sincronizados',
              _estadisticas['sincronizados'] ?? 0,
              Colors.green,
              Icons.cloud_done,
            ),
            _buildEstadisticaItem(
              'Pendientes',
              _estadisticas['pendientes'] ?? 0,
              Colors.orange,
              Icons.cloud_upload,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticaItem(String label, int value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          Text(
            'Error al cargar reportes',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _cargarReportes,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            color: Colors.grey.shade400,
            size: 70,
          ),
          const SizedBox(height: 20),
          const Text(
            'No hay reportes diarios',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text(
            'Los reportes que envíes aparecerán aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _actualizarDatosCompletos,
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar en servidor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReporteCard(ReporteDiarioLocal reporte) {
    final isPendiente = reporte.estado == 'pendiente';
    final isSincronizado = reporte.estado == 'sincronizado';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporte ${reporte.idServer ?? reporte.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${reporte.fechaReporte}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildEstadoChip(isPendiente, isSincronizado),
              ],
            ),

            const Divider(height: 24),

            // Datos de registros
            _buildSeccionRegistro(
              titulo: 'Registros Nuevos (R)',
              inicial: reporte.contadorInicialR,
              final_: reporte.contadorFinalR,
              total: reporte.contadorR,
              saltos: reporte.saltosenR,
              observaciones: reporte.observacionR,
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            _buildSeccionRegistro(
              titulo: 'Registros Cambio Domicilio (C)',
              inicial: reporte.contadorInicialC,
              final_: reporte.contadorFinalC,
              total: reporte.contadorC,
              saltos: reporte.saltosenC,
              observaciones: reporte.observacionC,
              color: Colors.orange,
            ),

            // Incidencias
            if (reporte.incidencias?.isNotEmpty ?? false)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Incidencias: ${reporte.incidencias}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Fecha de sincronización
            if (reporte.fechaSincronizacion != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Sincronizado: ${_formatearFecha(reporte.fechaSincronizacion!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoChip(bool isPendiente, bool isSincronizado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPendiente
            ? Colors.orange.shade100
            : isSincronizado
            ? Colors.green.shade100
            : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPendiente
              ? Colors.orange
              : isSincronizado
              ? Colors.green
              : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPendiente
                ? Icons.cloud_upload
                : isSincronizado
                ? Icons.cloud_done
                : Icons.cloud_off,
            size: 14,
            color: isPendiente
                ? Colors.orange
                : isSincronizado
                ? Colors.green
                : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            isPendiente
                ? 'Pendiente'
                : isSincronizado
                ? 'Sincronizado'
                : 'Fallido',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPendiente
                  ? Colors.orange
                  : isSincronizado
                  ? Colors.green
                  : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionRegistro({
    required String titulo,
    required String inicial,
    required String final_,
    required String total,
    required int saltos,
    String? observaciones,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                titulo.contains('R') ? Icons.receipt : Icons.home_work,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rango
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inicial', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    Text(inicial, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade400),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Final', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    Text(final_, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Total y saltos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (saltos > 0)
                Text(
                  'Saltos: $saltos',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),

          // Observaciones
          if (observaciones?.isNotEmpty ?? false)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Obs: $observaciones',
                style: const TextStyle(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} "
        "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
  }
}