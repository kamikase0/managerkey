// lib/views/operador/reporte_diario_view.dart (VERSIÓN COMPLETA MEJORADA)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/reporte_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';

class ReporteDiarioView extends StatefulWidget {
  const ReporteDiarioView({Key? key}) : super(key: key);

  @override
  State<ReporteDiarioView> createState() => _ReporteDiarioViewState();
}

class _ReporteDiarioViewState extends State<ReporteDiarioView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codigoEstacionController = TextEditingController();
  final TextEditingController _transmitidoController = TextEditingController();
  final TextEditingController _rInicialiController = TextEditingController();
  final TextEditingController _rFinalController = TextEditingController();
  final TextEditingController _rTotalController = TextEditingController();
  final TextEditingController _cInicialiController = TextEditingController();
  final TextEditingController _cFinalController = TextEditingController();
  final TextEditingController _cTotalController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _incidenciasController = TextEditingController();
  final TextEditingController _rTotal = TextEditingController();
  final TextEditingController _cTotal = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();

  late ReporteSyncService _syncService;
  late User? _userData;

  int diferenciaR = 0;
  int diferenciaC = 0;
  bool _isSubmitting = false;

  // Variables para geolocalización
  String? _latitud;
  String? _longitud;
  bool _locationCaptured = false;
  String _coordenadas = 'No capturadas';
  bool _gpsActivado = false;
  bool _ubicacionRequerida = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _syncService = context.read<ReporteSyncService>();
    _fechaController.text = DateTime.now().toString().split('.')[0];
    _verificarEstadoGPS();
    _iniciarMonitorGPS(); // ✅ Iniciar monitoreo inmediatamente
  }

  Future<void> _loadUserData() async {
    _userData = await AuthService().getCurrentUser();

    if (_userData != null && _userData!.operador != null) {
      setState(() {
        final operador = _userData!.operador!;
        _transmitidoController.text = operador.idOperador.toString();
        _codigoEstacionController.text = 'Estación: ${operador.nroEstacion ?? 'N/A'}';
      });
    }
  }

  // ✅ VERIFICAR SI EL GPS ESTÁ ACTIVADO
  Future<void> _verificarEstadoGPS() async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      setState(() {
        _gpsActivado = servicioHabilitado;
      });
      print('📍 Estado GPS: ${servicioHabilitado ? "ACTIVADO" : "DESACTIVADO"}');
    } catch (e) {
      print('❌ Error verificando estado GPS: $e');
      setState(() {
        _gpsActivado = false;
      });
    }
  }

  // ✅ CAPTURA SILENCIOSA - Solo cuando se presiona el botón
  Future<bool> _capturarGeolocalizacionAlEnviar() async {
    try {
      // ✅ VERIFICAR GPS ANTES DE CAPTURAR
      if (!_gpsActivado) {
        print('⚠️ GPS no activado, no se puede capturar ubicación');
        return false;
      }

      print('📍 Iniciando captura de geolocalización...');
      final position = await LocationService().getCurrentLocation();
      if (position != null) {
        setState(() {
          _latitud = position.latitude.toStringAsFixed(6);
          _longitud = position.longitude.toStringAsFixed(6);
          _coordenadas = 'Lat: ${_latitud}\nLong: ${_longitud}';
          _locationCaptured = true;
        });
        print('📍 Geolocalización capturada exactamente: $_coordenadas');
        return true;
      } else {
        setState(() {
          _locationCaptured = false;
          _coordenadas = 'Error al capturar ubicación';
        });
        print('⚠️ No se pudo capturar la ubicación');
        return false;
      }
    } catch (e) {
      setState(() {
        _locationCaptured = false;
        _coordenadas = 'Error: $e';
      });
      print('❌ Error capturando ubicación: $e');
      return false;
    }
  }

  void _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ VALIDACIÓN OBLIGATORIA DE GPS
    if (!_gpsActivado && _ubicacionRequerida) {
      _mostrarDialogoActivacionGPS();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_userData?.operador == null) {
        throw Exception('Datos de operador no disponibles');
      }

      // ✅ CAPTURAR GEOLOCALIZACIÓN SOLO SI EL GPS ESTÁ ACTIVADO
      bool ubicacionCapturada = false;
      if (_gpsActivado && _ubicacionRequerida) {
        ubicacionCapturada = await _capturarGeolocalizacionAlEnviar();
      }

      // Obtener fecha y hora actual en formato ISO
      final ahora = DateTime.now();
      final fechaHora = ahora.toIso8601String();

      final reporteData = {
        'fecha_reporte': _fechaController.text,
        'contador_inicial_c': _cInicialiController.text,
        'contador_final_c': _cFinalController.text,
        'registro_c': diferenciaC,
        'contador_inicial_r': _rInicialiController.text,
        'contador_final_r': _rFinalController.text,
        'registro_r': diferenciaR,
        'incidencias': _incidenciasController.text,
        'observaciones': _observacionesController.text,
        'operador': _userData!.operador!.idOperador,
        'estacion': _userData!.operador!.idEstacion,
        'estado': 'ENVIO REPORTE',
        'sincronizar': true,
      };

      // ✅ PREPARAR DATOS DE DESPLIEGUE (SE GUARDAN LOCALMENTE SI NO HAY INTERNET)
      final despliegueData = {
        'destino': 'REPORTE DIARIO - ${_userData!.operador!.nroEstacion ?? "Estación"}',
        'latitud': _latitud ?? (_ubicacionRequerida ? '0.0' : null),
        'longitud': _longitud ?? (_ubicacionRequerida ? '0.0' : null),
        'descripcion_reporte': null,
        'estado': 'REPORTE ENVIADO',
        'sincronizar': true,
        'observaciones': 'Reporte diario: ${_observacionesController.text.isNotEmpty ? _observacionesController.text : "Sin observaciones"}',
        'incidencias': _ubicacionRequerida
            ? (ubicacionCapturada ? 'Ubicación capturada correctamente' : 'No se pudo capturar ubicación')
            : 'Ubicación no requerida para este reporte',
        'fecha_hora': fechaHora,
        'operador': _userData!.operador!.idOperador,
        'sincronizado': false,
      };

      print('📤 Enviando reporte con datos:');
      print('📍 GPS Activado: $_gpsActivado');
      print('📍 Ubicación Requerida: $_ubicacionRequerida');
      print('📍 Coordenadas: $_coordenadas');
      print('🕐 Fecha/Hora: $fechaHora');

      // ✅ ENVÍO COMBINADO: Reporte diario + Geolocalización (SE GUARDA LOCAL SI NO HAY INTERNET)
      final result = await _syncService.saveReporteGeolocalizacion(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );

      if (!mounted) return;

      // Mostrar mensaje apropiado
      final mensaje = result['success']
          ? (result['saved_locally'] == true
          ? '📱 Reporte guardado localmente. Se sincronizará cuando haya internet.'
          : (_ubicacionRequerida
          ? (ubicacionCapturada
          ? '✅ Reporte enviado con geolocalización'
          : '⚠️ Reporte enviado sin geolocalización')
          : '✅ Reporte enviado sin ubicación'))
          : result['message'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: result['success']
              ? (result['saved_locally'] == true ? Colors.orange : Colors.green)
              : Colors.red,
          duration: Duration(seconds: 4),
        ),
      );

      if (result['success']) {
        _cleanFormulario();
        // Limpiar ubicación para el próximo reporte
        setState(() {
          _latitud = null;
          _longitud = null;
          _coordenadas = 'No capturadas';
          _locationCaptured = false;
          _ubicacionRequerida = true; // ✅ Resetear a requerido para próximo reporte
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ✅ DIALOGO PARA ACTIVAR GPS
  void _mostrarDialogoActivacionGPS() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('GPS Requerido', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text('Para enviar el reporte con ubicación, necesitas activar el GPS.'),
              SizedBox(height: 8),
              Text('¿Qué deseas hacer?', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Opción: Enviar sin ubicación
                setState(() {
                  _ubicacionRequerida = false;
                });
                _enviarReporte(); // Reintentar envío sin ubicación
              },
              child: Text('ENVIAR SIN UBICACIÓN', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _abrirConfiguracionGPS();
              },
              child: Text('ACTIVAR GPS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  // ✅ ABRIR CONFIGURACIÓN DE GPS
  Future<void> _abrirConfiguracionGPS() async {
    try {
      await Geolocator.openLocationSettings();
      // Verificar estado después de abrir configuración
      await Future.delayed(Duration(seconds: 2)); // Esperar un poco
      await _verificarEstadoGPS();
    } catch (e) {
      print('Error abriendo configuración GPS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir la configuración de GPS'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ ACTUALIZAR ESTADO GPS PERIÓDICAMENTE
  void _iniciarMonitorGPS() {
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        _verificarEstadoGPS();
        _iniciarMonitorGPS(); // Continuar monitoreo
      }
    });
  }

  void _cleanFormulario() {
    setState(() {
      _rInicialiController.clear();
      _rFinalController.clear();
      _cInicialiController.clear();
      _cFinalController.clear();
      _observacionesController.clear();
      _incidenciasController.clear();
      _cTotal.clear();
      _rTotal.clear();
      _fechaController.text = DateTime.now().toString().split('.')[0];
      diferenciaC = 0;
      diferenciaR = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulario limpiado'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _calcularDiferencia() {
    // Para R (recepción)
    final rInicial = int.tryParse(_rInicialiController.text);
    final rFinal = int.tryParse(_rFinalController.text);

    if (rInicial != null && rFinal != null) {
      if (rFinal >= rInicial) {
        setState(() {
          diferenciaR = (rFinal - rInicial) + 1;
          _rTotal.text = diferenciaR.toString();
        });
      } else {
        setState(() {
          _rTotal.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El valor final de R debe ser mayor o igual que el inicial'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    }

    // Para C (cantidad)
    final cInicial = int.tryParse(_cInicialiController.text);
    final cFinal = int.tryParse(_cFinalController.text);

    if (cInicial != null && cFinal != null) {
      if (cFinal >= cInicial) {
        setState(() {
          diferenciaC = (cFinal - cInicial) + 1;
          _cTotal.text = diferenciaC.toString();
        });
      } else {
        setState(() {
          _cTotal.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El valor final de C debe ser mayor o igual que el inicial'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Diario'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // ✅ INDICADOR DE ESTADO GPS EN APP BAR
          IconButton(
            icon: Icon(
              _gpsActivado ? Icons.location_on : Icons.location_off,
              color: _gpsActivado ? Colors.green : Colors.red,
            ),
            onPressed: _verificarEstadoGPS,
            tooltip: _gpsActivado ? 'GPS Activado' : 'GPS Desactivado - Toca para verificar',
          ),
        ],
      ),
      body: StreamBuilder<SyncStatus>(
        stream: _syncService.syncStatusStream,
        builder: (context, syncSnapshot) {
          final syncStatus = syncSnapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ INDICADOR DE ESTADO GPS
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _gpsActivado ? Colors.green.shade50 : Colors.orange.shade50,
                    border: Border.all(
                      color: _gpsActivado ? Colors.green : Colors.orange,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _gpsActivado ? Icons.location_on : Icons.location_off,
                        color: _gpsActivado ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _gpsActivado ? Colors.green : Colors.orange,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _gpsActivado
                                  ? 'Ubicación disponible para el reporte'
                                  : 'Active el GPS para capturar ubicación',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!_gpsActivado)
                        TextButton(
                          onPressed: _abrirConfiguracionGPS,
                          child: Text(
                            'ACTIVAR',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Indicador de estado de sincronización
                if (syncStatus != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: syncStatus.offlineMode
                          ? Colors.orange.shade100
                          : (syncStatus.success
                          ? Colors.green.shade100
                          : Colors.red.shade100),
                      border: Border.all(
                        color: syncStatus.offlineMode
                            ? Colors.orange
                            : (syncStatus.success ? Colors.green : Colors.red),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (syncStatus.isSyncing)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            syncStatus.success ? Icons.check_circle : Icons.info,
                            color: syncStatus.offlineMode
                                ? Colors.orange
                                : (syncStatus.success ? Colors.green : Colors.red),
                          ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            syncStatus.message,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ✅ INDICADOR DE CAPTURA DE UBICACIÓN DURANTE ENVÍO
                if (_isSubmitting && _ubicacionRequerida)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 20, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Capturando ubicación exacta...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _coordenadas,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Monospace',
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // FORMULARIO ORIGINAL
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha
                      TextFormField(
                        controller: _fechaController,
                        decoration: InputDecoration(
                          labelText: 'Fecha Reporte',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      // Código Estación (autocompletado)
                      TextFormField(
                        controller: _codigoEstacionController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Estación',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          helperText: 'Se carga del perfil automáticamente',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Número de Estación (oculto pero enviado)
                      TextFormField(
                        controller: _transmitidoController,
                        decoration: InputDecoration(
                          labelText: 'Número Estación',
                          hintText: '10638',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        enabled: false,
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 24),

                      // Sección R (Recepción)
                      const Text(
                        'Registros Recepción',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rInicialiController,
                              decoration: InputDecoration(
                                labelText: 'R Inicial',
                                hintText: '2',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              onChanged: (_) => _calcularDiferencia(),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _rFinalController,
                              decoration: InputDecoration(
                                labelText: 'R Final',
                                hintText: '32',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              onChanged: (_) => _calcularDiferencia(),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              controller: _rTotal,
                              decoration: InputDecoration(
                                labelText: 'Registros R',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sección C (Cantidad)
                      const Text(
                        'Registros Combustible',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cInicialiController,
                              decoration: InputDecoration(
                                labelText: 'C Inicial',
                                hintText: '4',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calcularDiferencia(),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cFinalController,
                              decoration: InputDecoration(
                                labelText: 'C Final',
                                hintText: '8',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calcularDiferencia(),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cTotal,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Registros C',
                                hintText: '10',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Observaciones
                      TextFormField(
                        controller: _observacionesController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Observaciones',
                          hintText: 'Ingrese sus observaciones aquí...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Botones
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _enviarReporte,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                                    : const Text(
                                  'Registrar Reporte',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _cleanFormulario,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Limpiar Campos',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _codigoEstacionController.dispose();
    _transmitidoController.dispose();
    _rInicialiController.dispose();
    _rFinalController.dispose();
    _cInicialiController.dispose();
    _cFinalController.dispose();
    _observacionesController.dispose();
    _incidenciasController.dispose();
    _rTotal.dispose();
    _cTotal.dispose();
    _fechaController.dispose();
    super.dispose();
  }
}