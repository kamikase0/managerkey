// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// // No se necesita 'dart:convert' aquí directamente
//
// import '../../services/auth_service.dart';
// import '../../services/reporte_sync_service.dart';
// import '../../services/api_service.dart';
// // No se necesita user_model.dart si solo usas el ID
//
// class ReporteHistorialView extends StatefulWidget {
//   const ReporteHistorialView({Key? key}) : super(key: key);
//
//   @override
//   State<ReporteHistorialView> createState() => _ReporteHistorialViewState();
// }
//
// class _ReporteHistorialViewState extends State<ReporteHistorialView> {
//   List<Map<String, dynamic>> _reportes = [];
//   bool _isLoading = true; // Inicia en true para mostrar carga inicial
//   bool _hasInternet = true;
//   String _loadingMessage = "Cargando reportes...";
//   bool _usingCachedData = false;
//
//   late AuthService _authService;
//   late ApiService _apiService;
//   late ReporteSyncService _syncService;
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Iniciar servicios desde Provider
//     _authService = Provider.of<AuthService>(context, listen: false);
//     _apiService = Provider.of<ApiService>(context, listen: false);
//     _syncService = Provider.of<ReporteSyncService>(context, listen: false);
//     _loadData();
//   }
//
//   Future<void> _loadData() async {
//     if (!mounted) return;
//
//     // Si ya hay datos, mostramos un indicador de actualización
//     if (_reportes.isNotEmpty) {
//       setState(() {
//         _isLoading = true;
//         _loadingMessage = "Actualizando reportes...";
//       });
//     } else {
//       // Carga inicial
//       setState(() {
//         _isLoading = true;
//         _loadingMessage = "Cargando reportes...";
//       });
//     }
//
//     // Intentar cargar desde caché del login para una UI más rápida
//     if (_reportes.isEmpty) {
//       final cachedReportes = await _tryLoadFromCache();
//       if (mounted && cachedReportes.isNotEmpty) {
//         setState(() {
//           _reportes = cachedReportes;
//           _usingCachedData = true;
//         });
//         print("✅ Usando reportes cargados durante el login: ${cachedReportes.length}");
//       }
//     }
//
//     try {
//       final currentUser = await _authService.getCurrentUser();
//       if (currentUser?.operador?.idOperador == null) {
//         _showError("Usuario no autenticado o ID de Operador no encontrado.");
//         if (mounted) setState(() => _isLoading = false);
//         return;
//       }
//       final operadorId = currentUser!.operador!.idOperador;
//
//       bool hasConnection = await _checkInternetConnection();
//       if (mounted) setState(() => _hasInternet = hasConnection);
//
//       List<Map<String, dynamic>> reportesActualizados;
//
//       if (hasConnection) {
//         reportesActualizados = await _loadWithInternet(operadorId);
//         if (mounted) _usingCachedData = false;
//       } else {
//         reportesActualizados = _reportes.isNotEmpty ? _reportes : await _loadWithoutInternet(operadorId);
//       }
//
//       // Ordenar por fecha, más reciente primero
//       reportesActualizados.sort((a, b) {
//         final fa = DateTime.tryParse(a["fecha_reporte"] ?? "") ?? DateTime(1970);
//         final fb = DateTime.tryParse(b["fecha_reporte"] ?? "") ?? DateTime(1970);
//         return fb.compareTo(fa);
//       });
//
//       if (mounted) {
//         setState(() {
//           _reportes = reportesActualizados;
//         });
//       }
//
//       print("✅ Carga completada: ${reportesActualizados.length} reportes");
//
//     } catch (e, stacktrace) {
//       print("ERROR en _loadData: $e\n$stacktrace");
//       if (_reportes.isEmpty) {
//         _showError("Ocurrió un error al cargar los reportes: ${e.toString()}");
//       } else {
//         _showWarning("No se pudo actualizar. Usando datos locales.");
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> _tryLoadFromCache() async {
//     try {
//       return await _authService.getReportesFromCache();
//     } catch (e) {
//       print("❌ Error cargando desde cache: $e");
//       return [];
//     }
//   }
//
//   /// ✅ CORREGIDO: Verificar conexión
//   Future<bool> _checkInternetConnection() async {
//     try {
//       return await _apiService.checkConnection();
//     } catch (e) {
//       return false;
//     }
//   }
//
//   /// ✅ CORREGIDO: Cargar con conexión a internet
//   Future<List<Map<String, dynamic>>> _loadWithInternet(int operadorId) async {
//     setState(() => _loadingMessage = "Sincronizando con el servidor...");
//
//     // Ejecutar en paralelo la carga remota y la sincronización local
//     final results = await Future.wait([
//       _fetchRemoteReportes(operadorId),
//       _syncPendingReportesInBackground(operadorId)
//     ]);
//
//     final reportesRemotos = results[0] as List<Map<String, dynamic>>;
//     final reportesLocalesNoSync = await _fetchLocalUnsyncedReportes(operadorId);
//
//     // Combinar listas (remotos ya están marcados como 'synced')
//     final reportesCombinados = [
//       ...reportesRemotos,
//       ...reportesLocalesNoSync,
//     ];
//
//     // Eliminar duplicados si los hubiera (basado en un identificador único si lo tienes)
//     // Por ahora, asumimos que no hay duplicados entre remotos y locales no sincronizados.
//
//     await _authService.guardarReportesEnCache(reportesCombinados);
//     return reportesCombinados;
//   }
//
//   Future<void> _syncPendingReportesInBackground(int operadorId) async {
//     try {
//       print("🔄 Sincronizando reportes pendientes en segundo plano...");
//       await _syncService.syncPendingReportes();
//       print("✅ Sincronización en segundo plano completada");
//     } catch (e) {
//       print("❌ Error en sincronización en segundo plano: $e");
//     }
//   }
//
//   /// ✅ Cargar sin conexión
//   Future<List<Map<String, dynamic>>> _loadWithoutInternet(int operadorId) async {
//     setState(() => _loadingMessage = "Cargando reportes locales...");
//     return await _fetchAllLocalReportes(operadorId);
//   }
//
//   /// ✅ Obtener reportes remotos
//   Future<List<Map<String, dynamic>>> _fetchRemoteReportes(int operadorId) async {
//     try {
//       final remotos = await _apiService.obtenerReportesPorOperador(operadorId);
//       // Asegurarse que los remotos siempre tengan 'synced: true'
//       return remotos.map((r) => {...r, "synced": true}).toList();
//     } catch (e) {
//       print("❌ Error obteniendo reportes remotos: $e");
//       return []; // Devolver vacío en caso de error de red
//     }
//   }
//
//   /// ✅ Obtener reportes locales no sincronizados
//   Future<List<Map<String, dynamic>>> _fetchLocalUnsyncedReportes(int operadorId) async {
//     final locales = await _syncService.getReportes();
//     return locales.where((r) =>
//     r["operador"] == operadorId && (r["synced"] == 0 || r["synced"] == false)
//     ).map((r) => {...r, "synced": false}).toList(); // Asegurar 'synced: false'
//   }
//
//   /// ✅ Obtener todos los reportes locales
//   Future<List<Map<String, dynamic>>> _fetchAllLocalReportes(int operadorId) async {
//     final locales = await _syncService.getReportes();
//     return locales.where((r) => r["operador"] == operadorId).map((r) {
//       return {...r, "synced": r["synced"] == 1 || r["synced"] == true};
//     }).toList();
//   }
//
//   void _showError(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
//     }
//   }
//
//   void _showWarning(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("HISTORIAL DE REPORTES"),
//         backgroundColor: Colors.blue.shade700,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: Icon(
//               _hasInternet ? Icons.cloud_queue_rounded : Icons.cloud_off_rounded,
//               color: _hasInternet ? Colors.white : Colors.orange,
//             ),
//             onPressed: _loadData,
//             tooltip: _hasInternet ? 'Conectado' : 'Sin conexión',
//           ),
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _isLoading ? null : _loadData,
//             tooltip: 'Recargar historial',
//           ),
//         ],
//       ),
//       body: _isLoading && _reportes.isEmpty
//           ? _buildLoadingState()
//           : _reportes.isEmpty
//           ? _buildEmptyState()
//           : RefreshIndicator(
//         onRefresh: _loadData,
//         child: ListView.builder(
//           padding: const EdgeInsets.symmetric(vertical: 8.0),
//           itemCount: _reportes.length,
//           itemBuilder: (context, index) {
//             return _buildReporteCard(_reportes[index]);
//           },
//         ),
//       ),
//     );
//   }
//
//   // --- WIDGETS DE LA INTERFAZ (Fusionados y Mejorados) ---
//
//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const CircularProgressIndicator(),
//           const SizedBox(height: 16),
//           Text(_loadingMessage, style: const TextStyle(color: Colors.grey)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.inbox_outlined, color: Colors.grey.shade400, size: 60),
//           const SizedBox(height: 16),
//           const Text('No se encontraron reportes', style: TextStyle(fontSize: 18, color: Colors.grey)),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: _loadData,
//             icon: const Icon(Icons.refresh, size: 18),
//             label: const Text('Intentar de nuevo'),
//           )
//         ],
//       ),
//     );
//   }
//
//   Widget _buildReporteCard(Map<String, dynamic> reporte) {
//     final bool sincronizado = reporte["synced"] == true;
//     final String fecha = reporte['fecha_reporte']?.toString() ?? '';
//     final String estacion = reporte['estacion']?.toString() ?? 'N/A';
//     final String registroR = reporte['registro_r']?.toString() ?? '0';
//     final String registroC = reporte['registro_c']?.toString() ?? '0';
//     final String observaciones = reporte['observaciones'] ?? '';
//
//     final Color estadoColor = sincronizado ? Colors.green : Colors.orange;
//     final IconData estadoIconData = sincronizado ? Icons.cloud_done : Icons.cloud_upload;
//     final String estadoTexto = sincronizado ? 'Sincronizado' : 'Pendiente';
//
//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(10),
//         side: BorderSide(color: estadoColor.withOpacity(0.5), width: 1),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
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
//                     Icon(estadoIconData, color: estadoColor, size: 18),
//                     const SizedBox(width: 6),
//                     Text(estadoTexto, style: TextStyle(color: estadoColor, fontWeight: FontWeight.w500)),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 4),
//             Text(
//               _formatearFecha(fecha), // Usar el formateador de fecha
//               style: const TextStyle(color: Colors.grey, fontSize: 12),
//             ),
//             const Divider(height: 24),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildStatColumn('Registros R', registroR, Colors.blue),
//                 _buildStatColumn('Registros C', registroC, Colors.orange),
//               ],
//             ),
//             if (observaciones.isNotEmpty) ...[
//               const SizedBox(height: 12),
//               Text(
//                 'Observaciones: $observaciones',
//                 style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
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
//   String _formatearFecha(String fechaStr) {
//     if (fechaStr.isEmpty) return "Fecha no disponible";
//     try {
//       final f = DateTime.parse(fechaStr).toLocal(); // Convertir a hora local
//       return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
//     } catch (_) {
//       return fechaStr; // Si falla, mostrar el string original
//     }
//   }
// }
//
//
//
// //  import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import 'dart:convert';
// //
// // import '../../services/auth_service.dart';
// // import '../../services/reporte_sync_service.dart';
// // import '../../services/api_service.dart';
// // import '../../models/user_model.dart';
// //
// // class ReporteHistorialView extends StatefulWidget {
// //   const ReporteHistorialView({Key? key}) : super(key: key);
// //
// //   @override
// //   State<ReporteHistorialView> createState() => _ReporteHistorialViewState();
// // }
// //
// // class _ReporteHistorialViewState extends State<ReporteHistorialView> {
// //   List<Map<String, dynamic>> _reportes = [];
// //   bool _isLoading = false;
// //   bool _hasInternet = true;
// //   String _loadingMessage = "Cargando reportes...";
// //   bool _usingCachedData = false;
// //
// //   late AuthService _authService;
// //   late ApiService _apiService;
// //   late ReporteSyncService _syncService;
// //
// //   @override
// //   void didChangeDependencies() {
// //     super.didChangeDependencies();
// //     _authService = Provider.of<AuthService>(context, listen: false);
// //     _apiService = Provider.of<ApiService>(context, listen: false);
// //     _syncService = Provider.of<ReporteSyncService>(context, listen: false);
// //     _loadData();
// //   }
// //
// //   Future<void> _loadData() async {
// //     if (!mounted) return;
// //
// //     // ✅ PRIMERO: Intentar cargar desde cache del login
// //     final cachedReportes = await _tryLoadFromCache();
// //     if (cachedReportes.isNotEmpty) {
// //       if (mounted) {
// //         setState(() {
// //           _reportes = cachedReportes;
// //           _usingCachedData = true;
// //         });
// //       }
// //       print("✅ Usando reportes cargados durante el login: ${cachedReportes.length}");
// //     }
// //
// //     setState(() {
// //       _isLoading = true;
// //       _loadingMessage = "Actualizando reportes...";
// //     });
// //
// //     try {
// //       // ================================
// //       // 1. OBTENER DATOS DE AUTENTICACIÓN
// //       // ================================
// //       final currentUser = await _authService.getCurrentUser();
// //       if (currentUser == null) {
// //         _showError("Usuario no autenticado.");
// //         return;
// //       }
// //
// //       final operadorId = currentUser.operador?.idOperador;
// //       if (operadorId == null) {
// //         _showError("ID de Operador no encontrado.");
// //         return;
// //       }
// //
// //       // ================================
// //       // 2. VERIFICAR CONEXIÓN A INTERNET
// //       // ================================
// //       setState(() => _loadingMessage = "Verificando conexión a internet...");
// //       bool hasConnection = await _checkInternetConnection();
// //       setState(() => _hasInternet = hasConnection);
// //
// //       // ================================
// //       // 3. CARGAR REPORTES ACTUALIZADOS
// //       // ================================
// //       List<Map<String, dynamic>> reportesActualizados = [];
// //
// //       if (hasConnection) {
// //         // ✅ CON INTERNET: Cargar datos actualizados del servidor
// //         setState(() => _loadingMessage = "Actualizando reportes del servidor...");
// //         reportesActualizados = await _loadWithInternet(operadorId);
// //         _usingCachedData = false;
// //       } else {
// //         // ❌ SIN INTERNET: Usar cache o cargar locales
// //         if (_reportes.isEmpty) {
// //           setState(() => _loadingMessage = "Cargando reportes locales...");
// //           reportesActualizados = await _loadWithoutInternet(operadorId);
// //         } else {
// //           // Ya tenemos datos del cache, no necesitamos recargar
// //           reportesActualizados = _reportes;
// //         }
// //       }
// //
// //       // ================================
// //       // 4. ORDENAR Y ACTUALIZAR LA UI
// //       // ================================
// //       reportesActualizados.sort((a, b) {
// //         final fa = DateTime.tryParse(a["fecha_reporte"] ?? "") ?? DateTime(1970);
// //         final fb = DateTime.tryParse(b["fecha_reporte"] ?? "") ?? DateTime(1970);
// //         return fb.compareTo(fa);
// //       });
// //
// //       if (mounted) {
// //         setState(() {
// //           _reportes = reportesActualizados;
// //         });
// //       }
// //
// //       print("✅ Carga completada: ${reportesActualizados.length} reportes");
// //
// //     } catch (e, stacktrace) {
// //       print("ERROR en _loadData: $e");
// //       print(stacktrace);
// //       if (_reportes.isEmpty) {
// //         _showError("Ocurrió un error al cargar los reportes: ${e.toString()}");
// //       } else {
// //         // Tenemos datos del cache, mostramos advertencia pero no error
// //         _showWarning("Usando datos en cache. Error al actualizar: ${e.toString()}");
// //       }
// //     } finally {
// //       if (mounted) setState(() => _isLoading = false);
// //     }
// //   }
// //
// //   // ✅ CORREGIDO: Usar el método público correcto
// //   Future<List<Map<String, dynamic>>> _tryLoadFromCache() async {
// //     try {
// //       return await _authService.getReportesFromCache();
// //     } catch (e) {
// //       print("❌ Error cargando desde cache: $e");
// //       return [];
// //     }
// //   }
// //
// //   Future<bool> _checkInternetConnection() async {
// //     try {
// //       setState(() => _loadingMessage = "Verificando conexión con el servidor...");
// //       final result = await _apiService.checkConnection();
// //       print("🔗 Estado de conexión: $result");
// //       return result;
// //     } catch (e) {
// //       print("❌ Sin conexión a internet: $e");
// //       return false;
// //     }
// //   }
// //
// //   Future<List<Map<String, dynamic>>> _loadWithInternet(int operadorId) async {
// //     List<Map<String, dynamic>> reportesCombinados = [];
// //
// //     try {
// //       // ✅ Cargar reportes actualizados del servidor
// //       setState(() => _loadingMessage = "Obteniendo reportes actualizados...");
// //       final reportesRemotos = await _fetchRemoteReportes(operadorId);
// //       print("📡 Reportes remotos obtenidos: ${reportesRemotos.length}");
// //
// //       for (var i = 0; i < reportesRemotos.length; i++) {
// //         print("📍 Remoto $i: ${reportesRemotos[i]['fecha_reporte']} - Operador: ${reportesRemotos[i]['operador']}");
// //       }
// //
// //       reportesCombinados.addAll(reportesRemotos.map((r) => {...r, "synced": true}));
// //
// //       // ✅ Cargar reportes locales no sincronizados
// //       setState(() => _loadingMessage = "Buscando reportes locales pendientes...");
// //       final reportesLocalesNoSync = await _fetchLocalUnsyncedReportes(operadorId);
// //       print("📱 Reportes locales no sincronizados: ${reportesLocalesNoSync.length}");
// //
// //       for (var i = 0; i < reportesLocalesNoSync.length; i++) {
// //         print("📱 Local $i: ${reportesLocalesNoSync[i]['fecha_reporte']} - Synced: ${reportesLocalesNoSync[i]['synced']}");
// //       }
// //
// //       reportesCombinados.addAll(reportesLocalesNoSync);
// //
// //       // ✅ CORREGIDO: Usar el método público correcto
// //       await _authService.guardarReportesEnCache(reportesCombinados);
// //
// //       // ✅ CORREGIDO: Usar el método público correcto
// //       _syncPendingReportesInBackground(operadorId);
// //
// //       print("✅ TOTAL combinados: ${reportesCombinados.length} reportes");
// //
// //     } catch (e) {
// //       print("❌ Error en carga con internet: $e");
// //       // En caso de error, mantener los datos existentes o cargar locales
// //       if (reportesCombinados.isEmpty) {
// //         setState(() => _loadingMessage = "Cargando reportes locales...");
// //         reportesCombinados = await _fetchAllLocalReportes(operadorId);
// //       }
// //     }
// //
// //     return reportesCombinados;
// //   }
// //
// //   // ✅ CORREGIDO: Usar el método público correcto
// //   Future<void> _syncPendingReportesInBackground(int operadorId) async {
// //     try {
// //       print("🔄 Sincronizando reportes pendientes en segundo plano...");
// //       await _syncService.syncPendingReportes(); // ✅ Ahora este método existe
// //       print("✅ Sincronización en segundo plano completada");
// //     } catch (e) {
// //       print("❌ Error en sincronización en segundo plano: $e");
// //     }
// //   }
// //
// //   Future<List<Map<String, dynamic>>> _loadWithoutInternet(int operadorId) async {
// //     // ❌ Solo cargar reportes locales
// //     final reportesLocales = await _fetchAllLocalReportes(operadorId);
// //     print("📱 Cargados ${reportesLocales.length} reportes locales (sin internet)");
// //     return reportesLocales;
// //   }
// //
// //   Future<List<Map<String, dynamic>>> _fetchRemoteReportes(int operadorId) async {
// //     try {
// //       final remotos = await _apiService.obtenerReportesPorOperador(operadorId);
// //       print("📡 Reportes remotos obtenidos: ${remotos.length}");
// //       return remotos;
// //     } catch (e) {
// //       print("❌ Error obteniendo reportes remotos: $e");
// //       return [];
// //     }
// //   }
// //
// //   Future<List<Map<String, dynamic>>> _fetchLocalUnsyncedReportes(int operadorId) async {
// //     try {
// //       final locales = await _syncService.getReportes();
// //       print("📋 Total de reportes locales en BD: ${locales.length}");
// //
// //       // Filtrar por operador y estado de sincronización
// //       final unsynced = locales.where((r) {
// //         final esMismoOperador = r["operador"] == operadorId;
// //         final noSincronizado = (r["synced"] == 0 || r["synced"] == false);
// //         final resultado = esMismoOperador && noSincronizado;
// //
// //         if (resultado) {
// //           print("🎯 Reporte local no sincronizado encontrado:");
// //           print("   - Fecha: ${r['fecha_reporte']}");
// //           print("   - Operador: ${r['operador']}");
// //           print("   - Synced: ${r['synced']}");
// //         }
// //
// //         return resultado;
// //       }).map((r) {
// //         // Crear una copia limpia del reporte
// //         final reporteLimpio = Map<String, dynamic>.from(r);
// //         // Asegurar que tenga el campo 'synced' como false
// //         reporteLimpio['synced'] = false;
// //         return reporteLimpio;
// //       }).toList();
// //
// //       print("📱 Reportes locales no sincronizados filtrados: ${unsynced.length}");
// //       return unsynced;
// //     } catch (e) {
// //       print("❌ Error obteniendo reportes locales no sincronizados: $e");
// //       return [];
// //     }
// //   }
// //
// //   Future<List<Map<String, dynamic>>> _fetchAllLocalReportes(int operadorId) async {
// //     try {
// //       final locales = await _syncService.getReportes();
// //       print("📋 Total de reportes locales en BD: ${locales.length}");
// //
// //       final allLocal = locales.where((r) {
// //         final esMismoOperador = r["operador"] == operadorId;
// //         if (esMismoOperador) {
// //           print("📱 Reporte local encontrado:");
// //           print("   - Fecha: ${r['fecha_reporte']}");
// //           print("   - Operador: ${r['operador']}");
// //           print("   - Synced: ${r['synced']}");
// //         }
// //         return esMismoOperador;
// //       }).map((r) {
// //         // Crear una copia limpia
// //         final reporteLimpio = Map<String, dynamic>.from(r);
// //         // Normalizar el campo synced
// //         reporteLimpio['synced'] = (r["synced"] == 1 || r["synced"] == true);
// //         return reporteLimpio;
// //       }).toList();
// //
// //       print("📱 Todos los reportes locales filtrados: ${allLocal.length}");
// //       return allLocal;
// //     } catch (e) {
// //       print("❌ Error obteniendo todos los reportes locales: $e");
// //       return [];
// //     }
// //   }
// //
// //   void _showError(String message) {
// //     if (mounted) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(message),
// //           backgroundColor: Colors.red,
// //           duration: const Duration(seconds: 4),
// //         ),
// //       );
// //     }
// //   }
// //
// //   void _showWarning(String message) {
// //     if (mounted) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(message),
// //           backgroundColor: Colors.orange,
// //           duration: const Duration(seconds: 4),
// //         ),
// //       );
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("HISTÓRICO DE REPORTES"),
// //         centerTitle: true,
// //         backgroundColor: Colors.blue.shade700,
// //         foregroundColor: Colors.white,
// //         elevation: 2,
// //         actions: [
// //           // Indicador de estado de conexión
// //           Padding(
// //             padding: const EdgeInsets.only(right: 16),
// //             child: Icon(
// //               _hasInternet ? Icons.wifi : Icons.wifi_off,
// //               color: _hasInternet ? Colors.green : Colors.orange,
// //             ),
// //           ),
// //         ],
// //       ),
// //       body: Column(
// //         children: [
// //           // Banner de estado de conexión
// //           if (!_hasInternet)
// //             Container(
// //               width: double.infinity,
// //               padding: const EdgeInsets.all(12),
// //               color: Colors.orange.shade50,
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
// //                   const SizedBox(width: 8),
// //                   Text(
// //                     "Modo sin conexión - Mostrando reportes locales",
// //                     style: TextStyle(
// //                       color: Colors.orange.shade700,
// //                       fontSize: 12,
// //                       fontWeight: FontWeight.w500,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           // Banner de datos en cache
// //           if (_usingCachedData && _hasInternet)
// //             Container(
// //               width: double.infinity,
// //               padding: const EdgeInsets.all(12),
// //               color: Colors.blue.shade50,
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   Icon(Icons.cached, size: 16, color: Colors.blue.shade700),
// //                   const SizedBox(width: 8),
// //                   Text(
// //                     "Mostrando datos cargados durante el login",
// //                     style: TextStyle(
// //                       color: Colors.blue.shade700,
// //                       fontSize: 12,
// //                       fontWeight: FontWeight.w500,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           Expanded(
// //             child: _isLoading
// //                 ? _buildLoadingState()
// //                 : _reportes.isEmpty
// //                 ? _buildEmptyState()
// //                 : RefreshIndicator(
// //               onRefresh: _loadData,
// //               child: ListView.builder(
// //                 padding: const EdgeInsets.all(12),
// //                 itemCount: _reportes.length,
// //                 itemBuilder: (context, index) {
// //                   return _buildReporteCard(
// //                     reporte: _reportes[index],
// //                     index: index + 1,
// //                   );
// //                 },
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: _isLoading ? null : _loadData,
// //         backgroundColor: Colors.blue.shade700,
// //         foregroundColor: Colors.white,
// //         child: const Icon(Icons.refresh),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildLoadingState() {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           const CircularProgressIndicator(),
// //           const SizedBox(height: 16),
// //           Text(
// //             _loadingMessage,
// //             style: const TextStyle(color: Colors.grey),
// //             textAlign: TextAlign.center,
// //           ),
// //           const SizedBox(height: 8),
// //           if (!_hasInternet)
// //             Text(
// //               "Sin conexión a internet",
// //               style: TextStyle(
// //                 color: Colors.orange.shade700,
// //                 fontSize: 12,
// //               ),
// //             ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildEmptyState() {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           Icon(
// //             _hasInternet ? Icons.assignment_outlined : Icons.assignment_late_outlined,
// //             size: 80,
// //             color: Colors.grey.shade400,
// //           ),
// //           const SizedBox(height: 16),
// //           Text(
// //             _hasInternet ? "No hay reportes" : "No hay reportes locales",
// //             style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
// //           ),
// //           const SizedBox(height: 8),
// //           Text(
// //             _hasInternet
// //                 ? "Los reportes aparecerán aquí cuando los generes"
// //                 : "Conectate a internet para ver todos los reportes",
// //             style: const TextStyle(fontSize: 14, color: Colors.grey),
// //             textAlign: TextAlign.center,
// //           ),
// //           const SizedBox(height: 20),
// //           ElevatedButton.icon(
// //             onPressed: _loadData,
// //             icon: const Icon(Icons.refresh, size: 18),
// //             label: const Text("Recargar"),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildReporteCard({
// //     required Map<String, dynamic> reporte,
// //     required int index,
// //   }) {
// //     final sincronizado = reporte["synced"] == true;
// //     final fecha = reporte['fecha_reporte']?.toString() ?? '';
// //     final estacion = reporte['estacion']?.toString() ?? 'N/A';
// //     final contadorInicialR = reporte['contador_inicial_r']?.toString() ?? '0';
// //     final contadorFinalR = reporte['contador_final_r']?.toString() ?? '0';
// //     final contadorInicialC = reporte['contador_inicial_c']?.toString() ?? '0';
// //     final contadorFinalC = reporte['contador_final_c']?.toString() ?? '0';
// //     final registroR = reporte['registro_r']?.toString() ?? '0';
// //     final registroC = reporte['registro_c']?.toString() ?? '0';
// //
// //     return Card(
// //       elevation: 2,
// //       margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
// //       child: Padding(
// //         padding: const EdgeInsets.all(16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // Header con número de reporte y estado
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //               children: [
// //                 Text(
// //                   "Reporte #$index",
// //                   style: const TextStyle(
// //                     fontWeight: FontWeight.bold,
// //                     fontSize: 16,
// //                   ),
// //                 ),
// //                 Container(
// //                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
// //                   decoration: BoxDecoration(
// //                     color: sincronizado ? Colors.green : Colors.orange,
// //                     borderRadius: BorderRadius.circular(12),
// //                   ),
// //                   child: Row(
// //                     mainAxisSize: MainAxisSize.min,
// //                     children: [
// //                       Icon(
// //                         sincronizado ? Icons.cloud_done : Icons.phone_iphone,
// //                         size: 14,
// //                         color: Colors.white,
// //                       ),
// //                       const SizedBox(width: 4),
// //                       Text(
// //                         sincronizado ? "ENVIADO" : "LOCAL",
// //                         style: const TextStyle(
// //                           color: Colors.white,
// //                           fontSize: 12,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ],
// //             ),
// //             const SizedBox(height: 12),
// //
// //             // Información del reporte
// //             _buildInfoRow("Estación", estacion),
// //             _buildInfoRow("Registros R", "$registroR (Inicial: $contadorInicialR | Final: $contadorFinalR)"),
// //             _buildInfoRow("Registros C", "$registroC (Inicial: $contadorInicialC | Final: $contadorFinalC)"),
// //             const SizedBox(height: 8),
// //
// //             // Fecha y estado
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //               children: [
// //                 Text(
// //                   "Fecha: ${_formatearFecha(fecha)}",
// //                   style: TextStyle(
// //                     color: Colors.grey.shade600,
// //                     fontSize: 12,
// //                     fontStyle: FontStyle.italic,
// //                   ),
// //                 ),
// //                 if (!sincronizado && _hasInternet)
// //                   Text(
// //                     "Pendiente de envío",
// //                     style: TextStyle(
// //                       color: Colors.orange.shade700,
// //                       fontSize: 11,
// //                       fontWeight: FontWeight.w500,
// //                     ),
// //                   ),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildInfoRow(String label, String value) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 2),
// //       child: Row(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           SizedBox(
// //             width: 100,
// //             child: Text(
// //               "$label:",
// //               style: const TextStyle(
// //                 fontSize: 14,
// //                 fontWeight: FontWeight.w500,
// //               ),
// //             ),
// //           ),
// //           Expanded(
// //             child: Text(
// //               value,
// //               style: const TextStyle(fontSize: 14),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   String _formatearFecha(String fechaStr) {
// //     try {
// //       final f = DateTime.parse(fechaStr);
// //       return "${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}";
// //     } catch (_) {
// //       return "Fecha no disponible";
// //     }
// //   }
// // }