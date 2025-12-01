import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../config/enviroment.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/punto_empadronamiento_service.dart';
import '../../models/registro_despliegue_model.dart';
import '../../models/punto_empadronamiento_model.dart';
import '../../utils/alert_helper.dart';

class LlegadaRutaView extends StatefulWidget {
  final int idOperador;

  const LlegadaRutaView({Key? key, required this.idOperador}) : super(key: key);

  @override
  State<LlegadaRutaView> createState() => _LlegadaRutaViewState();
}

class _LlegadaRutaViewState extends State<LlegadaRutaView> {
  bool _isLoading = false;
  bool _sincronizarConServidor = true;
  final TextEditingController _observacionesController = TextEditingController();

  // --- Estado del formulario y geolocalización ---
  String _coordenadas = 'No capturadas';
  String? _latitud;
  String? _longitud;
  bool _locationCaptured = false;
  bool _gpsActivado = false;
  bool _locationLoading = false;

  // --- Estado de los dropdowns de empadronamiento ---
  String? _provinciaSeleccionada;
  String? _puntoEmpadronamientoSeleccionado;
  List<String> _provincias = [];
  List<String> _puntosEmpadronamiento = [];
  bool _cargadoProvincias = false;
  int? _puntoEmpadronamientoIdSeleccionado;

  // --- Servicios ---
  late final AuthService _authService;
  late final DatabaseService _databaseService;
  final PuntoEmpadronamientoService _puntoService = PuntoEmpadronamientoService();

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _databaseService = DatabaseService();

    // ✅ SIMPLIFICADO: Solo cargamos lo necesario para el formulario
    _cargarDatosEmpadronamiento();
    _verificarEstadoGPS();
  }

  // Carga las provincias desde la base de datos local
  Future<void> _cargarDatosEmpadronamiento() async {
    try {
      setState(() => _cargadoProvincias = false);
      final provincias = await _puntoService.getProvinciasFromLocalDatabase();
      if (mounted) {
        setState(() {
          _provincias = provincias;
          _cargadoProvincias = true;
        });
      }
      print('✅ Provincias cargadas: ${_provincias.length}');
    } catch (e) {
      print('❌ Error cargando provincias: $e');
      if (mounted) {
        setState(() => _cargadoProvincias = false);
        AlertHelper.showError(
            context: context, text: 'Error al cargar las provincias.');
      }
    }
  }

  // Carga los puntos de empadronamiento cuando se selecciona una provincia
  void _onProvinciaSeleccionada(String? provincia) async {
    if (provincia == null) return;

    setState(() {
      _provinciaSeleccionada = provincia;
      _puntoEmpadronamientoSeleccionado = null;
      _puntosEmpadronamiento = [];
      _puntoEmpadronamientoIdSeleccionado = null;
    });

    try {
      final puntos = await _puntoService.getPuntosByProvincia(provincia);
      final nombresPuntos = puntos.map((p) => p.puntoEmpadronamiento).toList();
      if (mounted) {
        setState(() => _puntosEmpadronamiento = nombresPuntos);
      }
    } catch (e) {
      print('❌ Error cargando puntos de empadronamiento: $e');
      if (mounted) {
        AlertHelper.showError(
            context: context, text: 'Error al cargar los puntos.');
      }
    }
  }

  // Obtiene el ID del punto cuando se selecciona uno
  void _onPuntoEmpadronamientoSeleccionado(String? punto) async {
    if (punto == null) return;

    setState(() => _puntoEmpadronamientoSeleccionado = punto);

    try {
      final puntos =
      await _puntoService.getPuntosByProvincia(_provinciaSeleccionada!);
      final puntoSeleccionado = puntos.firstWhere(
            (p) => p.puntoEmpadronamiento == punto,
        orElse: () =>
            PuntoEmpadronamiento(id: 0, provincia: '', puntoEmpadronamiento: ''),
      );

      if (puntoSeleccionado.id != 0) {
        setState(() => _puntoEmpadronamientoIdSeleccionado = puntoSeleccionado.id);
        print('✅ Punto de empadronamiento seleccionado: ID ${puntoSeleccionado.id}');
      }
    } catch (e) {
      print('❌ Error obteniendo ID del punto: $e');
    }
  }

  // Verifica el estado del GPS
  Future<void> _verificarEstadoGPS() async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() => _gpsActivado = servicioHabilitado);
      }
    } catch (e) {
      print('❌ Error verificando estado GPS: $e');
      if (mounted) {
        setState(() => _gpsActivado = false);
      }
    }
  }

  // Captura la geolocalización actual
  Future<bool> _capturarGeolocalizacion() async {
    setState(() => _locationLoading = true);
    try {
      if (!_gpsActivado) return false;
      final position = await LocationService().getCurrentLocation();
      if (position != null) {
        if (mounted) {
          setState(() {
            _latitud = position.latitude.toStringAsFixed(6);
            _longitud = position.longitude.toStringAsFixed(6);
            _coordenadas = 'Lat: $_latitud\nLong: $_longitud';
            _locationCaptured = true;
          });
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
    }
  }

  void _limpiarFormulario() {
    _observacionesController.clear();
    setState(() {
      _provinciaSeleccionada = null;
      _puntoEmpadronamientoSeleccionado = null;
      _puntosEmpadronamiento = [];
      _puntoEmpadronamientoIdSeleccionado = null;
      _coordenadas = 'No capturadas';
      _latitud = null;
      _longitud = null;
      _locationCaptured = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Llegada'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_gpsActivado ? Icons.location_on : Icons.location_off, color: _gpsActivado ? Colors.lightGreenAccent : Colors.red),
            onPressed: _verificarEstadoGPS,
            tooltip: _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCamposEmpadronamiento(),
              const SizedBox(height: 16),
              _buildObservacionesField(),
              const SizedBox(height: 16),
              _buildGPSInfo(),
              const SizedBox(height: 16),
              //_buildSincronizacionSwitch(),
              //const SizedBox(height: 24),
              _buildRegistrarButton(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE LA INTERFAZ ---

  Widget _buildCamposEmpadronamiento() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UBICACIÓN DE LLEGADA *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
            ),
            const SizedBox(height: 16),
            _buildProvinciaDropdown(),
            const SizedBox(height: 12),
            _buildPuntoEmpadronamientoDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildProvinciaDropdown() {
    return DropdownButtonFormField<String>(
      value: _provinciaSeleccionada,
      decoration: InputDecoration(
        labelText: 'Provincia/Municipio *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      isExpanded: true,
      items: _provincias.map((String provincia) => DropdownMenuItem<String>(value: provincia, child: Text(provincia, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (String? nuevaProvincia) => _onProvinciaSeleccionada(nuevaProvincia),
      validator: (value) => (value == null || value.isEmpty) ? 'Seleccione una provincia' : null,
    );
  }

  Widget _buildPuntoEmpadronamientoDropdown() {
    return DropdownButtonFormField<String>(
      value: _puntoEmpadronamientoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Punto de Empadronamiento *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: _provinciaSeleccionada != null ? (_puntosEmpadronamiento.isEmpty ? 'Cargando...' : 'Seleccione un punto') : 'Primero seleccione una provincia',
      ),
      isExpanded: true,
      items: _puntosEmpadronamiento.map((String punto) => DropdownMenuItem<String>(value: punto, child: Text(punto, overflow: TextOverflow.ellipsis, maxLines: 2))).toList(),
      onChanged: (_provinciaSeleccionada != null && _puntosEmpadronamiento.isNotEmpty) ? (String? nuevoPunto) => _onPuntoEmpadronamientoSeleccionado(nuevoPunto) : null,
      validator: (value) => (_provinciaSeleccionada != null && (value == null || value.isEmpty)) ? 'Seleccione un punto' : null,
    );
  }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Observaciones (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _observacionesController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Ingrese observaciones de la llegada...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildGPSInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gpsActivado ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gpsActivado ? Colors.green : Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_gpsActivado ? Icons.location_on : Icons.location_off, color: _gpsActivado ? Colors.green : Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(_gpsActivado ? 'GPS Activado' : 'GPS Desactivado', style: TextStyle(fontWeight: FontWeight.bold, color: _gpsActivado ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_coordenadas),
          if (_locationLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Capturando ubicación...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildSincronizacionSwitch() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.green.shade50,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.green.shade200),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         const Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text('Sincronizar con Servidor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //               SizedBox(height: 4),
  //               Text('Enviar inmediatamente si hay conexión', style: TextStyle(fontSize: 12)),
  //             ],
  //           ),
  //         ),
  //         Switch(
  //           value: _sincronizarConServidor,
  //           onChanged: (value) => setState(() => _sincronizarConServidor = value),
  //           activeColor: Colors.green,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildRegistrarButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _registrarLlegada,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.flag, size: 20),
        label: Text(_isLoading ? 'Procesando...' : 'Registrar Llegada', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Reemplaza el método _registrarLlegada existente con esta versión corregida

  // Método principal para registrar la llegada
  Future<void> _registrarLlegada() async {
    // --- 1. Validaciones iniciales del formulario ---
    if (_puntoEmpadronamientoIdSeleccionado == null || _puntoEmpadronamientoIdSeleccionado == 0) {
      AlertHelper.showError(context: context, title: 'Dato Requerido', text: 'Debe seleccionar un punto de empadronamiento.');
      return;
    }

    if (_provinciaSeleccionada == null || _provinciaSeleccionada!.isEmpty) {
      AlertHelper.showError(context: context, title: 'Dato Requerido', text: 'Debe seleccionar una provincia.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- 2. Captura de geolocalización si es necesario ---
      if (_gpsActivado && !_locationCaptured) {
        final capturada = await _capturarGeolocalizacion();
        if (!capturada && _gpsActivado) {
          AlertHelper.showWarning(context: context, title: 'Ubicación no Capturada', text: 'No se pudo obtener la ubicación. El registro se guardará con coordenadas 0,0.');
        }
      }

      // --- 3. Construcción del objeto de registro ---
      final ahora = DateTime.now().toLocal();
      final fechaSinZ = ahora.toIso8601String().replaceAll('Z', '');

      final nuevoRegistro = RegistroDespliegue(
        id: null, // El ID se asigna automáticamente en la BD local
        latitud: _latitud ?? '0.0', // Usar 0.0 como valor por defecto
        longitud: _longitud ?? '0.0',
        descripcionReporte: null,
        estado: 'LLEGADA',
        sincronizar: _sincronizarConServidor,
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : 'Sin observaciones',
        incidencias: '',
        fechaHora: fechaSinZ,
        operadorId: widget.idOperador,
        sincronizado: false,
        centroEmpadronamiento: _puntoEmpadronamientoIdSeleccionado,
        fechaSincronizacion: null,
      );

      // --- 4. Lógica de envío según la conexión a internet ---
      final tieneInternet = await SyncService().verificarConexion();

      if (tieneInternet && _sincronizarConServidor) {
        // ✅ CASO 1: HAY INTERNET -> Intentar enviar directamente al servidor
        print('🌐 Conexión detectada. Intentando envío directo al servidor.');

        final accessToken = await _authService.getAccessToken();
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('No se pudo obtener el token de autenticación.');
        }

        final enviado = await _enviarRegistroAlServidor(nuevoRegistro.toJsonForApi(), accessToken);

        if (enviado) {
          // Si se envía con éxito, solo mostramos el mensaje y limpiamos. No se guarda nada localmente.
          AlertHelper.showSuccess(context: context, title: '¡Llegada Registrada!', text: 'La llegada se ha sincronizado correctamente.');
        } else {
          // Si falla el envío (ej. error 500 del servidor), lo guardamos localmente como respaldo.
          print('⚠️ El envío al servidor falló. Guardando registro localmente como respaldo.');
          await _databaseService.insertRegistroDespliegue(nuevoRegistro);
          AlertHelper.showWarning(context: context, title: 'Sincronización Fallida', text: 'El registro se guardó localmente para un intento posterior.');
        }

      } else {
        // ❌ CASO 2: NO HAY INTERNET -> Guardar directamente en la base de datos local
        print('🔌 Sin conexión. Guardando registro directamente en la base de datos local.');
        await _databaseService.insertRegistroDespliegue(nuevoRegistro);
        if (!tieneInternet) {
          AlertHelper.showInfo(context: context, title: 'Registro Guardado Localmente', text: 'No hay conexión. El registro se sincronizará automáticamente más tarde.');
        } else {
          AlertHelper.showSuccess(context: context, title: 'Llegada Registrada Localmente', text: 'La llegada se guardó en el dispositivo.');
        }
      }

      // --- 5. Limpieza del formulario ---
      _limpiarFormulario();

    } catch (e) {
      print('❌ Error al registrar llegada: $e');
      AlertHelper.showError(context: context, title: 'Error Inesperado', text: 'Ocurrió un error al registrar la llegada: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// Reemplaza también el método _enviarRegistroAlServidor para corregir la URL

  // Envía un registro al servidor
  Future<bool> _enviarRegistroAlServidor(Map<String, dynamic> jsonData, String accessToken) async {
    try {
      // ✅ CORRECCIÓN: Se elimina la barra final para evitar duplicados
      const url = '${Enviroment.apiUrlDev}registrosdespliegue/';
      print('📤 Enviando registro de llegada a: $url');
      print('📦 Datos: ${jsonEncode(jsonData)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(jsonData),
      ).timeout(const Duration(seconds: 30));

      print('📥 Respuesta del servidor - Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Registro enviado exitosamente al servidor');
        return true;
      } else {
        print('❌ Error del servidor: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error de conexión al enviar registro de llegada: $e');
      return false;
    }
  }


  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }
}
