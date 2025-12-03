import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
//import '../../services/salida_llegada_service.dart';
import '../../services/salida_llegada_service_corregido.dart';
import '../../services/punto_empadronamiento_service.dart';
import '../../services/salida_llegada_service_corregido.dart' as SalidaServiceCorregido;
import '../../models/punto_empadronamiento_model.dart';
import '../../utils/alert_helper.dart';
import '../../widgets/sync_monitor_widget.dart'; // ✅ NUEVO: Importar widget de sincronización

class SalidaRutaView extends StatefulWidget {
  final int idOperador;

  const SalidaRutaView({Key? key, required this.idOperador}) : super(key: key);

  @override
  _SalidaRutaViewState createState() => _SalidaRutaViewState();
}

class _SalidaRutaViewState extends State<SalidaRutaView> {
  final _observacionesController = TextEditingController();
  bool _isLoading = false;
  String _coordenadas = 'No capturadas';

  String _userName = 'Cargando...';
  String _userRole = 'Cargando...';
  String _userEmail = 'Cargando...';
  User? _currentUser;
  late AuthService _authService;
  // late SalidaLlegadaService _salidaLlegadaService;
  late SalidaServiceCorregido.SalidaLlegadaService _salidaLlegadaService;

  // ✅ NUEVAS VARIABLES PARA EMPADRONAMIENTO
  String? _provinciaSeleccionada;
  String? _puntoEmpadronamientoSeleccionado;
  List<String> _provincias = [];
  List<String> _puntosEmpadronamiento = [];
  bool _cargadoProvincias = false;
  int? _puntoEmpadronamientoId;
  final PuntoEmpadronamientoService _puntoService = PuntoEmpadronamientoService();

  // ✅ NUEVAS VARIABLES PARA GEOLOCALIZACIÓN
  String? _latitud;
  String? _longitud;
  bool _locationCaptured = false;
  bool _gpsActivado = false;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _salidaLlegadaService = SalidaServiceCorregido.SalidaLlegadaService();

    _loadUserData();
    _cargarDatosEmpadronamiento();
    _verificarEstadoGPS();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          _userName = user.username;
          _userRole = user.groups.isNotEmpty ? user.groups.join(', ') : 'Sin rol asignado';
          _userEmail = user.email;
        });
        print('✅ Usuario cargado: ${user.username}');
        print('🔑 ID Operador a usar: ${widget.idOperador}');
      } else {
        setState(() {
          _userName = 'Usuario No Identificado';
          _userRole = 'Rol No Asignado';
          _userEmail = 'Email no disponible';
        });
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
      setState(() {
        _userName = 'Error al cargar';
        _userRole = 'Error';
        _userEmail = 'Error';
      });
    }
  }

  Future<void> _cargarDatosEmpadronamiento() async {
    try {
      setState(() {
        _cargadoProvincias = false;
      });
      final provincias = await _puntoService.getProvinciasFromLocalDatabase();

      setState(() {
        _provincias = provincias;
        _cargadoProvincias = true;
      });

      print('✅ Provincias cargadas: ${_provincias.length}');
    } catch (e) {
      print('❌ Error cargando provincias: $e');
      setState(() {
        _cargadoProvincias = false;
      });
    }
  }

  void _onProvinciaSeleccionada(String? provincia) async {
    if (provincia == null) return;

    setState(() {
      _provinciaSeleccionada = provincia;
      _puntoEmpadronamientoSeleccionado = null;
      _puntosEmpadronamiento = [];
      _puntoEmpadronamientoId = null;
    });

    try {
      final puntos = await _puntoService.getPuntosByProvincia(provincia);
      final nombresPuntos = puntos.map((p) => p.puntoEmpadronamiento).toList();

      setState(() {
        _puntosEmpadronamiento = nombresPuntos;
      });

      print('✅ Puntos de empadronamiento cargados: ${puntos.length} para $provincia');
    } catch (e) {
      print('❌ Error cargando puntos de empadronamiento: $e');
    }
  }

  void _onPuntoEmpadronamientoSeleccionado(String? punto) async {
    if (punto == null) return;

    setState(() {
      _puntoEmpadronamientoSeleccionado = punto;
    });

    try {
      final puntos = await _puntoService.getPuntosByProvincia(_provinciaSeleccionada!);
      final puntoSeleccionado = puntos.firstWhere(
            (p) => p.puntoEmpadronamiento == punto,
        orElse: () => PuntoEmpadronamiento(
          id: 0,
          provincia: '',
          puntoEmpadronamiento: '',
        ),
      );

      if (puntoSeleccionado.id != 0) {
        setState(() {
          _puntoEmpadronamientoId = puntoSeleccionado.id;
        });
        print('✅ Punto de empadronamiento seleccionado: ID ${_puntoEmpadronamientoId} - $punto');
      }
    } catch (e) {
      print('❌ Error obteniendo ID del punto de empadronamiento: $e');
    }
  }

  Future<bool> _capturarGeolocalizacion() async {
    setState(() => _locationLoading = true);
    try {
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
        print('📍 Geolocalización capturada: $_coordenadas');
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
    } finally {
      setState(() => _locationLoading = false);
    }
  }

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

  // ✅ ACTUALIZADO: Método registrar salida con manejo mejorado de offline
  // ✅ CORREGIDO: Método registrar salida con manejo mejorado de offline
  Future<void> _registrarSalida() async {

    if (_provinciaSeleccionada == null || _puntoEmpadronamientoId == null) {
      AlertHelper.showError(
        context: context,
        title: 'Datos Incompletos',
        text: 'Debe seleccionar una provincia y un punto de empadronamiento.',
      );
      return;
    }

    setState(() => _isLoading = true);
    AlertHelper.showLoading(context: context, text: 'Registrando despliegue...');

    try {
      bool ubicacionCapturada = false;
      if (_gpsActivado) {
        ubicacionCapturada = await _capturarGeolocalizacion();
      }

      // ✅ USAR EL SERVICIO ACTUALIZADO
      final resultado = await _salidaLlegadaService.registrarSalidaConEmpadronamiento(
        observaciones: _observacionesController.text,
        idOperador: widget.idOperador,
        sincronizarConServidor: true, // Siempre intentar sincronizar
        puntoEmpadronamientoId: _puntoEmpadronamientoId!,
        latitud: _latitud,
        longitud: _longitud,
      );

      if (mounted) AlertHelper.closeLoading(context);

      if (resultado['exitoso']) {
        // ✅ MOSTRAR MENSAJE DIFERENTE SEGÚN SI SE SINCRONIZÓ O NO
        if (resultado['sincronizado'] == true) {
          AlertHelper.showSuccess(
            context: context,
            title: '✅ ¡Despliegue Registrado!',
            text: '${resultado['mensaje']}\n\nLos datos se han guardado en registros_despliegue y sincronizado con el servidor.',
          );
        } else {
          AlertHelper.showInfo(
            context: context,
            title: '📱 ¡Despliegue Guardado!',
            text: '${resultado["mensaje"]}\n\nLos datos se guardaron en registros_despliegue y se sincronizarán automáticamente cuando haya conexión.',
          );
        }

        _limpiarFormulario();

      } else {
        AlertHelper.showError(
          context: context,
          title: 'Registro Fallido',
          text: resultado['mensaje'],
        );
      }
    } catch (e) {
      if (mounted) AlertHelper.closeLoading(context);

      print('❌ Error al registrar salida: $e');
      AlertHelper.showError(
        context: context,
        title: 'Error Inesperado',
        text: 'Ocurrió un error al registrar el despliegue: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ NUEVO: Método para sincronización manual desde la vista
  Future<void> _sincronizarManual() async {
    AlertHelper.showLoading(context: context, text: 'Sincronizando registros...');

    try {
      final resultado = await _salidaLlegadaService.sincronizarRegistrosPendientes();

      if (mounted) AlertHelper.closeLoading(context);

      if (resultado['success']) {
        AlertHelper.showSuccess(
          context: context,
          title: '✅ Sincronización',
          text: resultado['message'],
        );
      } else {
        AlertHelper.showError(
          context: context,
          title: '❌ Sincronización',
          text: resultado['message'],
        );
      }
    } catch (e) {
      if (mounted) AlertHelper.closeLoading(context);
      AlertHelper.showError(
        context: context,
        title: 'Error',
        text: 'Error en sincronización: ${e.toString()}',
      );
    }
  }

  Widget _buildGPSInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gpsActivado ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _gpsActivado ? Colors.green : Colors.orange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _gpsActivado ? Icons.location_on : Icons.location_off,
                color: _gpsActivado ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _gpsActivado ? Colors.green : Colors.orange,
                ),
              ),
              const Spacer(),
              if (!_gpsActivado)
                TextButton.icon(
                  onPressed: _verificarEstadoGPS,
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('Verificar'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_coordenadas),
          if (_locationLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Capturando ubicación...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          if (!_locationCaptured && _gpsActivado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: _capturarGeolocalizacion,
                icon: Icon(Icons.location_on, size: 16),
                label: Text('Capturar ubicación'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 36),
                  backgroundColor: Colors.blue.shade100,
                  foregroundColor: Colors.blue.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida de Ruta - Despliegue'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _gpsActivado ? Icons.location_on : Icons.location_off,
              color: _gpsActivado ? Colors.green : Colors.red,
            ),
            onPressed: _verificarEstadoGPS,
            tooltip: _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
          ),
          // ✅ NUEVO: Botón de sincronización manual
          IconButton(
            icon: Icon(Icons.sync, color: Colors.white),
            onPressed: _sincronizarManual,
            tooltip: 'Sincronizar registros pendientes',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfoCard(),
              const SizedBox(height: 24),

              // ✅ NUEVO: Monitor de sincronización
              _buildSyncMonitor(),

              const SizedBox(height: 24),

              // Campos de empadronamiento
              _buildCamposEmpadronamiento(),

              const SizedBox(height: 24),

              // Observaciones
              _buildObservacionesField(),

              const SizedBox(height: 24),

              // Información de GPS
              _buildGPSInfo(),

              const SizedBox(height: 24),

              // Botón de registro
              _buildRegistrarButton(),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NUEVO: Widget para monitor de sincronización
  Widget _buildSyncMonitor() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Estado de Sincronización',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, dynamic>>(
              future: _salidaLlegadaService.obtenerEstadisticasSincronizacion(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(strokeWidth: 2));
                }

                if (snapshot.hasError) {
                  return Text(
                    'Error cargando estadísticas',
                    style: TextStyle(color: Colors.red),
                  );
                }

                final stats = snapshot.data ?? {};
                final pendientes = stats['pendientes'] ?? 0;
                final total = stats['total'] ?? 0;
                final sincronizados = stats['sincronizados'] ?? 0;
                final porcentaje = stats['porcentaje'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          label: 'Total',
                          value: total.toString(),
                          icon: Icons.list,
                          color: Colors.blue,
                        ),
                        _buildStatItem(
                          label: 'Sincronizados',
                          value: sincronizados.toString(),
                          icon: Icons.check_circle,
                          color: Colors.green,
                        ),
                        _buildStatItem(
                          label: 'Pendientes',
                          value: pendientes.toString(),
                          icon: Icons.pending,
                          color: pendientes > 0 ? Colors.orange : Colors.grey,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (pendientes > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progreso: $porcentaje%',
                                style: TextStyle(fontSize: 12),
                              ),
                              if (pendientes > 0)
                                TextButton(
                                  onPressed: _sincronizarManual,
                                  child: Text(
                                    'Sincronizar ahora',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: porcentaje / 100,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              porcentaje == 100 ? Colors.green : Colors.blue,
                            ),
                          ),
                        ],
                      ),

                    if (pendientes == 0 && total > 0)
                      Text(
                        '✅ Todo sincronizado',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    if (total == 0)
                      Text(
                        '📊 No hay registros de despliegue',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información del Operador',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Usuario: $_userName', style: const TextStyle(fontSize: 13)),
          Text(
            'ID Operador: ${widget.idOperador}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text('Email: $_userEmail', style: const TextStyle(fontSize: 13)),
          Text('Rol: $_userRole', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _observacionesController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Ingrese observaciones adicionales...',
            labelText: 'Observaciones (opcional)',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildRegistrarButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _registrarSalida,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        icon: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.save, size: 20),
        label: Text(
          _isLoading ? 'Procesando...' : 'Registrar Despliegue',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _limpiarFormulario() {
    _observacionesController.clear();
    setState(() {
      _coordenadas = 'No capturadas';
      _provinciaSeleccionada = null;
      _puntoEmpadronamientoSeleccionado = null;
      _puntoEmpadronamientoId = null;
      _latitud = null;
      _longitud = null;
      _locationCaptured = false;
    });
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Widget _buildCamposEmpadronamiento() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UBICACIÓN DE EMPADRONAMIENTO *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.purple,
              ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: _provinciaSeleccionada != null
            ? IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: () {
            setState(() {
              _provinciaSeleccionada = null;
              _puntoEmpadronamientoSeleccionado = null;
              _puntosEmpadronamiento = [];
              _puntoEmpadronamientoId = null;
            });
          },
        )
            : null,
      ),
      isExpanded: true,
      items: _provincias.map((String provincia) {
        return DropdownMenuItem<String>(
          value: provincia,
          child: Text(
            provincia,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (String? nuevaProvincia) {
        setState(() {
          _provinciaSeleccionada = nuevaProvincia;
        });
        _onProvinciaSeleccionada(nuevaProvincia);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Seleccione una provincia';
        }
        return null;
      },
    );
  }

  Widget _buildPuntoEmpadronamientoDropdown() {
    return DropdownButtonFormField<String>(
      value: _puntoEmpadronamientoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Punto de Empadronamiento *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintText: _provinciaSeleccionada != null
            ? (_puntosEmpadronamiento.isEmpty ? 'Cargando puntos...' : 'Seleccione un punto')
            : 'Primero seleccione una provincia',
        suffixIcon: _puntoEmpadronamientoSeleccionado != null
            ? IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: () {
            setState(() {
              _puntoEmpadronamientoSeleccionado = null;
              _puntoEmpadronamientoId = null;
            });
          },
        )
            : null,
      ),
      isExpanded: true,
      items: _puntosEmpadronamiento.map((String punto) {
        return DropdownMenuItem<String>(
          value: punto,
          child: Text(
            punto,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );
      }).toList(),
      onChanged: (_provinciaSeleccionada != null && _puntosEmpadronamiento.isNotEmpty)
          ? (String? nuevoPunto) {
        setState(() {
          _puntoEmpadronamientoSeleccionado = nuevoPunto;
        });
        _onPuntoEmpadronamientoSeleccionado(nuevoPunto);
      }
          : null,
      validator: (value) {
        if (_provinciaSeleccionada != null && (value == null || value.isEmpty)) {
          return 'Seleccione un punto de empadronamiento';
        }
        return null;
      },
    );
  }

}
