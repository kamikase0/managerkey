// lib/views/operador/historial_reportes_diarios_view.dart
import 'package:flutter/material.dart';
import 'package:manager_key/services/reporte_sync_manager.dart';
import '../../models/reporte_diario_historial.dart';
import '../../models/reporte_diario_local.dart';

class HistorialReportesDiariosView extends StatefulWidget {
  const HistorialReportesDiariosView({Key? key}) : super(key: key);

  @override
  State<HistorialReportesDiariosView> createState() => _HistorialReportesDiariosViewState();
}

class _HistorialReportesDiariosViewState extends State<HistorialReportesDiariosView> {
  late Future<List<ReporteDiarioLocal>> _reportesFuture;
  final ReporteSyncManager _syncManager = ReporteSyncManager();
  bool _isSyncing = false;
  Map<String, dynamic> _estadisticas = {};

  @override
  void initState() {
    super.initState();
    _cargarReportes();
    _cargarEstadisticas();
  }

  void _cargarReportes() {
    setState(() {
      _reportesFuture = _syncManager.obtenerReportes();
    });
  }

  Future<void> _cargarEstadisticas() async {
    final stats = await _syncManager.obtenerEstadisticas();
    setState(() {
      _estadisticas = stats;
    });
  }

  Future<void> _sincronizarManualmente() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final resultado = await _syncManager.sincronizarReportesPendientes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? 'Sincronización completada'),
          backgroundColor: resultado['success'] == true ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      // Recargar datos
      _cargarReportes();
      _cargarEstadisticas();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error en la sincronización'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
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
          // Indicador de reportes pendientes
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

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportes,
            tooltip: 'Recargar historial',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de estado
          if ((_estadisticas['pendientes'] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_upload,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
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
            ),

          // Contenido principal
          Expanded(
            child: FutureBuilder<List<ReporteDiarioLocal>>(
              future: _reportesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _cargarReportes,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off,
                            color: Colors.grey.shade400, size: 70),
                        const SizedBox(height: 20),
                        const Text(
                          'No hay reportes diarios',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final reportes = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: () async {
                    _cargarReportes();
                    await _reportesFuture;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: reportes.length,
                    itemBuilder: (context, index) {
                      final reporte = reportes[index];
                      return _buildReporteCard(reporte);
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

  Widget _buildReporteCard(ReporteDiarioLocal reporte) {
    final isPendiente = reporte.estado == 'pendiente';
    final isSincronizado = reporte.estado == 'sincronizado';
    final isFallido = reporte.estado == 'fallido';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con ID y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reporte ${reporte.idServer ?? reporte.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPendiente ? Colors.orange.shade100
                        : isSincronizado ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPendiente ? Colors.orange
                          : isSincronizado ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPendiente ? Icons.cloud_upload
                            : isSincronizado ? Icons.cloud_done
                            : Icons.cloud_off,
                        size: 14,
                        color: isPendiente ? Colors.orange
                            : isSincronizado ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPendiente ? 'Pendiente'
                            : isSincronizado ? 'Sincronizado'
                            : 'Fallido',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPendiente ? Colors.orange
                              : isSincronizado ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Fecha del reporte
            Text(
              'Fecha: ${reporte.fechaReporte}',
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 16),

            // Datos de registros R
            _buildSeccionRegistro(
              titulo: 'Registros R',
              inicial: reporte.contadorInicialR,
              final_: reporte.contadorFinalR,
              total: reporte.contadorR,
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            // Datos de registros C
            _buildSeccionRegistro(
              titulo: 'Registros C',
              inicial: reporte.contadorInicialC,
              final_: reporte.contadorFinalC,
              total: reporte.contadorC,
              color: Colors.orange,
            ),

            // Observaciones
            if (reporte.observaciones?.isNotEmpty ?? false)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Observaciones: ${reporte.observaciones}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),

            // Fecha de sincronización
            if (reporte.fechaSincronizacion != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sincronizado: ${_formatearFecha(reporte.fechaSincronizacion!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionRegistro({
    required String titulo,
    required String inicial,
    required String final_,
    required String total,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Inicial: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  inicial,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Monospace'),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Final: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Text(
                  final_,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Total: $total',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return "${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}";
  }
}