// lib/views/operador/historial_reportes_diarios_view.dart - Versión completa corregida
import 'package:flutter/material.dart';
import '../../models/reporte_diario_historial.dart';
import '../../services/reporte_historial_service.dart';

class HistorialReportesDiariosView extends StatefulWidget {
  const HistorialReportesDiariosView({Key? key}) : super(key: key);

  @override
  State<HistorialReportesDiariosView> createState() => _HistorialReportesDiariosViewState();
}

class _HistorialReportesDiariosViewState extends State<HistorialReportesDiariosView> {
  late Future<List<ReporteDiarioHistorial>> _historialFuture;
  final ReporteHistorialService _historialService = ReporteHistorialService();

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  void _cargarHistorial() {
    setState(() {
      _historialFuture = _historialService.getHistorialReportes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Reportes'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHistorial,
            tooltip: 'Recargar historial',
          ),
        ],
      ),
      body: FutureBuilder<List<ReporteDiarioHistorial>>(
        future: _historialFuture,
        builder: (context, snapshot) {
          // --- Estado de Carga ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- Estado de Error ---
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          // --- Estado Sin Datos ---
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyWidget();
          }

          // --- Estado con Datos (Éxito) ---
          final reportes = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _cargarHistorial();
              await _historialFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: reportes.length,
              itemBuilder: (context, index) {
                final reporte = reportes[index];
                return _buildReporteCard(reporte);
              },
            ),
          );
        },
      ),
    );
  }

  // Widget para mostrar un reporte individual
  Widget _buildReporteCard(ReporteDiarioHistorial reporte) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: reporte.estadoSincronizacion.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Fecha y Estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _formatearFecha(reporte.fechaReporte),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      reporte.estadoSincronizacion.icon,
                      color: reporte.estadoSincronizacion.color,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      reporte.estadoSincronizacion.displayName,
                      style: TextStyle(
                        color: reporte.estadoSincronizacion.color,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Nombre de estación si está disponible
            if (reporte.nombreEstacion != null && reporte.nombreEstacion!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Estación: ${reporte.nombreEstacion}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],

            const Divider(height: 20),

            // Estadísticas de registros
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'Registros R',
                  reporte.registrosR.toString(),
                  Colors.blue,
                ),
                _buildStatColumn(
                  'Registros C',
                  reporte.registrosC.toString(),
                  Colors.orange,
                ),
              ],
            ),

            // Observaciones si las hay
            if (reporte.observaciones != null && reporte.observaciones!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Observaciones: ${reporte.observaciones}',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],

            // Fecha de sincronización si está disponible
            if (reporte.fechaSincronizacion != null &&
                reporte.estadoSincronizacion == EstadoSincronizacion.sincronizado) ...[
              const SizedBox(height: 8),
              Text(
                'Sincronizado: ${_formatearFechaHora(reporte.fechaSincronizacion!)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            const Text(
              'Ocurrió un error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cargarHistorial,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            color: Colors.grey.shade400,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron reportes',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los reportes aparecerán aquí una vez que los sincronices',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _cargarHistorial,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Actualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers para formatear fechas ---

  String _formatearFecha(String fechaStr) {
    if (fechaStr.isEmpty) return "Fecha no disponible";
    try {
      final fecha = DateTime.parse(fechaStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final ayer = today.subtract(const Duration(days: 1));

      if (fecha.year == today.year &&
          fecha.month == today.month &&
          fecha.day == today.day) {
        return "Hoy";
      } else if (fecha.year == ayer.year &&
          fecha.month == ayer.month &&
          fecha.day == ayer.day) {
        return "Ayer";
      } else {
        return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";
      }
    } catch (_) {
      return fechaStr.split('T').first;
    }
  }

  String _formatearFechaHora(DateTime fecha) {
    return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
  }
}