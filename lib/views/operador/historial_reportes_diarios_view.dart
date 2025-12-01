// // lib/views/operador/historial_reportes_diarios_view.dart
//
// import 'package:flutter/material.dart';
// import '../../models/reporte_diario_historial.dart';
// import '../../services/reporte_historial_service.dart';
// import '../../utils/alert_helper.dart';
//
// class HistorialReportesDiariosView extends StatefulWidget {
//   const HistorialReportesDiariosView({Key? key}) : super(key: key);
//
//   @override
//   State<HistorialReportesDiariosView> createState() => _HistorialReportesDiariosViewState();
// }
//
// class _HistorialReportesDiariosViewState extends State<HistorialReportesDiariosView> {
//   late Future<List<ReporteDiarioHistorial>> _historialFuture;
//   final ReporteHistorialService _historialService = ReporteHistorialService();
//
//   @override
//   void initState() {
//     super.initState();
//     _cargarHistorial();
//   }
//
//   void _cargarHistorial() {
//     setState(() {
//       _historialFuture = _historialService.getHistorialReportes();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Historial de Reportes Diarios'),
//         backgroundColor: Colors.blue.shade700,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _cargarHistorial,
//             tooltip: 'Recargar historial',
//           ),
//         ],
//       ),
//       body: FutureBuilder<List<ReporteDiarioHistorial>>(
//         future: _historialFuture,
//         builder: (context, snapshot) {
//           // --- Estado de Carga ---
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           // --- Estado de Error ---
//           if (snapshot.hasError) {
//             return _buildErrorWidget(snapshot.error.toString());
//           }
//
//           // --- Estado Sin Datos ---
//           if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return _buildEmptyWidget();
//           }
//
//           // --- Estado con Datos (Éxito) ---
//           final reportes = snapshot.data!;
//           return RefreshIndicator(
//             onRefresh: () async => _cargarHistorial(),
//             child: ListView.builder(
//               padding: const EdgeInsets.symmetric(vertical: 8.0),
//               itemCount: reportes.length,
//               itemBuilder: (context, index) {
//                 final reporte = reportes[index];
//                 return _buildReporteCard(reporte);
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   // Widget para mostrar un reporte individual
//   Widget _buildReporteCard(ReporteDiarioHistorial reporte) {
//     final Icon estadoIcon = _getIconoEstado(reporte.estadoSincronizacion);
//     final String estadoTexto = _getTextoEstado(reporte.estadoSincronizacion);
//     final Color estadoColor = _getColorEstado(reporte.estadoSincronizacion);
//
//     final String estacion = reporte.nombreEstacion ?? 'N/A';
//     final String fechaFormateada = _formatearFecha(reporte.fechaReporte);
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       elevation: 3,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(10),
//         side: BorderSide(color: estadoColor.withOpacity(0.5), width: 1),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Fila superior: Estación y Estado
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Expanded(
//                   child: Text(
//                     "Estación: $estacion",
//                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     estadoIcon,
//                     const SizedBox(width: 6),
//                     Text(estadoTexto, style: TextStyle(color: estadoColor, fontWeight: FontWeight.w500)),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 4),
//
//             // Fecha formateada
//             Text(
//               fechaFormateada,
//               style: const TextStyle(color: Colors.grey, fontSize: 12),
//             ),
//             const Divider(height: 24),
//
//             // Fila de estadísticas: Registros R y C
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildStatColumn('Registros R', reporte.registrosR.toString(), Colors.blue),
//                 _buildStatColumn('Registros C', reporte.registrosC.toString(), Colors.orange),
//               ],
//             ),
//
//             // Observaciones si las hay
//             if (reporte.observaciones != null && reporte.observaciones!.isNotEmpty) ...[
//               const SizedBox(height: 12),
//               Text(
//                 'Observaciones: ${reporte.observaciones}',
//                 style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   // --- Widgets Auxiliares ---
//
//   Widget _buildStatColumn(String label, String value, Color color) {
//     return Column(
//       children: [
//         Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
//         Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
//       ],
//     );
//   }
//
//   Widget _buildErrorWidget(String error) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, color: Colors.red, size: 50),
//             const SizedBox(height: 16),
//             const Text('Ocurrió un error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             Text(error, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
//             const SizedBox(height: 20),
//             ElevatedButton(onPressed: _cargarHistorial, child: const Text('Reintentar')),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyWidget() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 60),
//           const SizedBox(height: 16),
//           const Text('No se encontraron reportes', style: TextStyle(fontSize: 18, color: Colors.grey)),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: _cargarHistorial,
//             icon: const Icon(Icons.refresh, size: 18),
//             label: const Text('Intentar de nuevo'),
//           )
//         ],
//       ),
//     );
//   }
//
//   // --- Helpers de Estilo para el Estado de Sincronización ---
//
//   Icon _getIconoEstado(EstadoSincronizacion estado) {
//     switch (estado) {
//       case EstadoSincronizacion.sincronizado:
//         return const Icon(Icons.cloud_done, color: Colors.green, size: 18);
//       case EstadoSincronizacion.pendiente:
//         return const Icon(Icons.cloud_upload, color: Colors.orange, size: 18);
//       case EstadoSincronizacion.fallido:
//         return const Icon(Icons.cloud_off, color: Colors.red, size: 18);
//     }
//   }
//
//   String _getTextoEstado(EstadoSincronizacion estado) {
//     switch (estado) {
//       case EstadoSincronizacion.sincronizado:
//         return 'Sincronizado';
//       case EstadoSincronizacion.pendiente:
//         return 'Pendiente';
//       case EstadoSincronizacion.fallido:
//         return 'Fallido';
//     }
//   }
//
//   Color _getColorEstado(EstadoSincronizacion estado) {
//     switch (estado) {
//       case EstadoSincronizacion.sincronizado:
//         return Colors.green;
//       case EstadoSincronizacion.pendiente:
//         return Colors.orange;
//       case EstadoSincronizacion.fallido:
//         return Colors.red;
//     }
//   }
//
//   // --- Helper para formatear fecha ---
//   String _formatearFecha(String fechaStr) {
//     if (fechaStr.isEmpty) return "Fecha no disponible";
//     try {
//       final f = DateTime.parse(fechaStr).toLocal();
//       return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
//     } catch (_) {
//       return fechaStr;
//     }
//   }
// }

// lib/views/operador/historial_reportes_diarios_view.dart

import 'package:flutter/material.dart';
import '../../models/reporte_diario_historial.dart';
//import '../../models/reporte_diario_historial_model.dart';
import '../../services/reporte_historial_service.dart';
import '../../utils/alert_helper.dart';

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
          return ListView.builder(
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              final reporte = reportes[index];
              return _buildReporteCard(reporte);
            },
          );
        },
      ),
    );
  }

  // Widget para mostrar un reporte individual
  Widget _buildReporteCard(ReporteDiarioHistorial reporte) {
    final Icon estadoIcon = _getIconoEstado(reporte.estadoSincronizacion);
    final String estadoTexto = _getTextoEstado(reporte.estadoSincronizacion);
    final Color estadoColor = _getColorEstado(reporte.estadoSincronizacion);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: estadoColor.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reporte.fechaReporte.split('T').first, // Mostrar solo la fecha
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    estadoIcon,
                    const SizedBox(width: 4),
                    Text(estadoTexto, style: TextStyle(color: estadoColor, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Registros R', reporte.registrosR.toString(), Colors.blue),
                _buildStatColumn('Registros C', reporte.registrosC.toString(), Colors.orange),
              ],
            ),
            if (reporte.observaciones != null && reporte.observaciones!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Observaciones: ${reporte.observaciones}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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
            const Text('Ocurrió un error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _cargarHistorial, child: const Text('Reintentar')),
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
          Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 60),
          const SizedBox(height: 16),
          const Text('No se encontraron reportes', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- Helpers de Estilo para el Estado de Sincronización ---

  Icon _getIconoEstado(EstadoSincronizacion estado) {
    switch (estado) {
      case EstadoSincronizacion.sincronizado:
        return const Icon(Icons.cloud_done, color: Colors.green, size: 18);
      case EstadoSincronizacion.pendiente:
        return const Icon(Icons.cloud_upload, color: Colors.orange, size: 18);
      case EstadoSincronizacion.fallido:
        return const Icon(Icons.cloud_off, color: Colors.red, size: 18);
    }
  }

  String _getTextoEstado(EstadoSincronizacion estado) {
    switch (estado) {
      case EstadoSincronizacion.sincronizado:
        return 'Sincronizado';
      case EstadoSincronizacion.pendiente:
        return 'Pendiente';
      case EstadoSincronizacion.fallido:
        return 'Fallido';
    }
  }

  Color _getColorEstado(EstadoSincronizacion estado) {
    switch (estado) {
      case EstadoSincronizacion.sincronizado:
        return Colors.green;
      case EstadoSincronizacion.pendiente:
        return Colors.orange;
      case EstadoSincronizacion.fallido:
        return Colors.red;
    }
  }
}
