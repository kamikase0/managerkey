// lib/views/operador/historial_reportes_diarios_view.dart - VERSIÓN CON ORDEN DESCENDENTE
import 'package:flutter/material.dart';
import '../../models/reporte_diario_historial.dart';
import '../../services/reporte_historial_service.dart';
import '../../services/auth_service.dart';

class HistorialReportesDiariosView extends StatefulWidget {
  const HistorialReportesDiariosView({Key? key}) : super(key: key);

  @override
  State<HistorialReportesDiariosView> createState() => _HistorialReportesDiariosViewState();
}

class _HistorialReportesDiariosViewState extends State<HistorialReportesDiariosView> {
  late Future<List<ReporteDiarioHistorial>> _historialFuture;
  final ReporteHistorialService _historialService = ReporteHistorialService();
  final AuthService _authService = AuthService();

  String? _nroEstacion;

  @override
  void initState() {
    super.initState();
    _cargarDatosOperador();
    _cargarHistorial();
  }

  Future<void> _cargarDatosOperador() async {
    try {
      final datosOperador = await _authService.getDatosOperador();
      if (datosOperador != null) {
        _nroEstacion = datosOperador['nro_estacion']?.toString() ?? 'N/A';
      }
    } catch (e) {
      print('Error cargando datos del operador: $e');
    }
  }

  void _cargarHistorial() {
    setState(() {
      _historialFuture = _historialService.getHistorialReportes();
    });
  }

  // Método para ordenar los reportes de forma descendente por fecha
  List<ReporteDiarioHistorial> _ordenarReportesDescendente(List<ReporteDiarioHistorial> reportes) {
    return reportes..sort((a, b) {
      try {
        // Parsear las fechas
        final fechaA = DateTime.parse(a.fechaReporte);
        final fechaB = DateTime.parse(b.fechaReporte);

        // Ordenar descendente (más reciente primero)
        return fechaB.compareTo(fechaA);
      } catch (e) {
        // Si hay error al parsear, mantener el orden original
        return 0;
      }
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyWidget();
          }

          // Ordenar los reportes de forma descendente
          final reportesOrdenados = _ordenarReportesDescendente(snapshot.data!);

          return RefreshIndicator(
            onRefresh: () async {
              _cargarHistorial();
              await _historialFuture;
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: reportesOrdenados.length,
              itemBuilder: (context, index) {
                final reporte = reportesOrdenados[index];
                return _buildReporteCard(reporte, index);
              },
            ),
          );
        },
      ),
    );
  }

  // Widget para mostrar un reporte individual
  Widget _buildReporteCard(ReporteDiarioHistorial reporte, int index) {
    // Usamos el número de estación del operador
    final codigoMateria = "BIOM-030"; // Fijo como en la imagen

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
            // Fila superior: Número de Reporte y Estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Reporte ${reporte.id ?? index + 1}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF333333),
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

            // Código de materia
            const SizedBox(height: 4),
            Text(
              codigoMateria,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),

            // Nombre de estación si está disponible
            if (_nroEstacion != null) ...[
              const SizedBox(height: 2),
              Text(
                'Estación: $_nroEstacion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const Divider(height: 20, thickness: 1),

            // Transacción
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Trans. ${_nroEstacion ?? 'N/A'}",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF444444),
                  fontSize: 13,
                ),
              ),
            ),

            // Fecha específica como en la imagen
            Text(
              _formatearFechaEspecifica(reporte.fechaReporte),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontFamily: 'Monospace',
              ),
            ),

            const SizedBox(height: 16),

            // SECCIÓN REGISTROS R - CON FORMATO ESPECÍFICO
            _buildSeccionRegistrosFormateada(
              tipo: 'R',
              inicial: reporte.contadorInicialR,
              final_: reporte.contadorFinalR,
              saltos: reporte.saltosenR.toString(),
              total: reporte.contadorR,
              color: Colors.blue,
            ),

            const SizedBox(height: 16),

            // SECCIÓN REGISTROS C - CON FORMATO ESPECÍFICO
            _buildSeccionRegistrosFormateada(
              tipo: 'C',
              inicial: reporte.contadorInicialC,
              final_: reporte.contadorFinalC,
              saltos: reporte.saltosenC.toString(),
              total: reporte.contadorC,
              color: Colors.orange,
            ),

            // Observaciones e incidencias
            if ((reporte.observaciones?.isNotEmpty ?? false) ||
                (reporte.incidencias?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reporte.observaciones?.isNotEmpty ?? false) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.note,
                            color: Colors.grey.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Observaciones: ${reporte.observaciones}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (reporte.incidencias?.isNotEmpty ?? false)
                        const SizedBox(height: 8),
                    ],
                    if (reporte.incidencias?.isNotEmpty ?? false) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Incidencias: ${reporte.incidencias}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Fecha de registro
            const SizedBox(height: 12),
            Text(
              'Registro: ${_formatearFechaHoraString(reporte.fechaCreacion?.toIso8601String() ?? '')}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),

            // Fecha de sincronización si está disponible
            if (reporte.fechaSincronizacion != null &&
                reporte.estadoSincronizacion == EstadoSincronizacion.sincronizado) ...[
              const SizedBox(height: 4),
              Text(
                'Sincronizado: ${_formatearFechaHora(reporte.fechaSincronizacion!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget para sección de registros con formato específico (como en la imagen)
  Widget _buildSeccionRegistrosFormateada({
    required String tipo,
    required String inicial,
    required String final_,
    required String saltos,
    required String total,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la sección (Ri o Ci)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '$tipo i :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ),

          // Línea de valores iniciales y finales
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    'Inicial :',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    inicial,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12,
                      fontFamily: 'Monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Línea de valores finales
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    'Final:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    final_,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12,
                      fontFamily: 'Monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Fila: Saltos y Total
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Saltos:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      saltos,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      total,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Formatea fecha específica como "24-10-2025 14:21'12"
  String _formatearFechaEspecifica(String fechaStr) {
    if (fechaStr.isEmpty) return "Fecha no disponible";

    try {
      final fecha = DateTime.parse(fechaStr).toLocal();
      final day = fecha.day.toString().padLeft(2, '0');
      final month = fecha.month.toString().padLeft(2, '0');
      final year = fecha.year.toString();
      final hour = fecha.hour.toString().padLeft(2, '0');
      final minute = fecha.minute.toString().padLeft(2, '0');
      final second = fecha.second.toString().padLeft(2, '0');

      return 'Fecha: $day-$month-$year $hour:$minute\'$second';
    } catch (_) {
      return 'Fecha: ${fechaStr.split('T').first}';
    }
  }

  // Formatea fecha y hora desde string
  String _formatearFechaHoraString(String fechaStr) {
    if (fechaStr.isEmpty) return "Fecha no disponible";
    try {
      final fecha = DateTime.parse(fechaStr).toLocal();
      return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return fechaStr.split('T').first;
    }
  }

  String _formatearFechaHora(DateTime fecha) {
    return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
  }

  // Resto de métodos auxiliares
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
            Icons.history_toggle_off,
            color: Colors.grey.shade400,
            size: 70,
          ),
          const SizedBox(height: 20),
          Text(
            'No hay historial de reportes',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
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
}