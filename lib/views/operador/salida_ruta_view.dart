import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user_model.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/salida_llegada_service.dart';
import '../../services/punto_empadronamiento_service.dart'; // ✅ NUEVO
import '../../models/punto_empadronamiento_model.dart'; // ✅ NUEVO

class SalidaRutaView extends StatefulWidget {
  final int idOperador;

  const SalidaRutaView({Key? key, required this.idOperador}) : super(key: key);

  @override
  _SalidaRutaViewState createState() => _SalidaRutaViewState();
}

class _SalidaRutaViewState extends State<SalidaRutaView> {
  final _observacionesController = TextEditingController();
  //final _destino = TextEditingController();

  bool _sincronizarConServidor = true;
  bool _isLoading = false;
  String _coordenadas = 'No capturadas';

  String _userName = 'Cargando...';
  String _userRole = 'Cargando...';
  String _userEmail = 'Cargando...';
  User? _currentUser;
  late AuthService _authService;
  late DatabaseService _databaseService;
  late SalidaLlegadaService _salidaLlegadaService;

  int? _salidaLocalId; // Guardar ID de salida para usarlo en llegada

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
    _databaseService = DatabaseService();
    _salidaLlegadaService = SalidaLlegadaService();
    _loadUserData();
    _cargarDatosEmpadronamiento(); // ✅ NUEVO
    _verificarEstadoGPS(); // ✅ NUEVO
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

  // ✅ NUEVO: Método para cargar datos de empadronamiento
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

  // ✅ NUEVO: Método para cuando se selecciona una provincia
  void _onProvinciaSeleccionada(String? provincia) async {
    if (provincia == null) return;

    setState(() {
      _provinciaSeleccionada = provincia;
      _puntoEmpadronamientoSeleccionado = null;
      _puntosEmpadronamiento = [];
      _puntoEmpadronamientoId = null;
    });

    try {
      // Cargar puntos de empadronamiento para la provincia seleccionada
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

  // ✅ NUEVO: Método para cuando se selecciona un punto de empadronamiento
  void _onPuntoEmpadronamientoSeleccionado(String? punto) async {
    if (punto == null) return;

    setState(() {
      _puntoEmpadronamientoSeleccionado = punto;
    });

    try {
      // Obtener el ID del punto seleccionado
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

  // ✅ NUEVO: Método para capturar geolocalización
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

  // ✅ NUEVO: Verificar estado GPS
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

  // ✅ MODIFICADO: Método registrar salida con empadronamiento y geolocalización
  Future<void> _registrarSalida() async {
    // if (_destino.text.isEmpty) {
    //   _mostrarError('El destino es requerido');
    //   return;
    // }

    if (_provinciaSeleccionada == null || _puntoEmpadronamientoId == null) {
      _mostrarError('Debe seleccionar provincia y punto de empadronamiento');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Capturar geolocalización si el GPS está activado
      bool ubicacionCapturada = false;
      if (_gpsActivado) {
        ubicacionCapturada = await _capturarGeolocalizacion();
      }

      // ✅ CORREGIDO: Sin el parámetro datosDespliegue que causaba el error
      final resultado = await _salidaLlegadaService.registrarSalidaConEmpadronamiento(
        //destino: _destino.text,
        observaciones: _observacionesController.text,
        idOperador: widget.idOperador,
        sincronizarConServidor: _sincronizarConServidor,
        puntoEmpadronamientoId: _puntoEmpadronamientoId!,
        latitud: _latitud,
        longitud: _longitud,
      );

      if (resultado['exitoso']) {
        _salidaLocalId = resultado['localId'];
        _mostrarExito(resultado['mensaje']);
        _limpiarFormulario();

        // Mostrar opción de ir a registrar llegada después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ///_mostrarOpcionIrALlegada();
          }
        });
      } else {
        _mostrarError(resultado['mensaje']);
      }
    } catch (e) {
      print('❌ Error al registrar salida: $e');
      _mostrarError('Error al registrar salida: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // void _mostrarOpcionIrALlegada() {
  //   if (!mounted) return;
  //
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('Salida Registrada'),
  //       content: const Text('¿Deseas registrar la llegada ahora?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx),
  //           child: const Text('Más tarde'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(ctx);
  //             // Navegar a llegada con el ID de salida
  //             Navigator.pushNamed(
  //               context,
  //               '/llegada_ruta',
  //               arguments: {
  //                 'idOperador': widget.idOperador,
  //                 'salidaLocalId': _salidaLocalId,
  //                 'puntoEmpadronamientoId': _puntoEmpadronamientoId,
  //               },
  //             );
  //           },
  //           child: const Text('Ir a Llegada'),
  //         ),
  //       ],
  //     ),
  //   );
  // }



  Widget _buildProvinciaAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _provincias;
        }
        return _provincias.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _provinciaSeleccionada = selection;
        });
        _onProvinciaSeleccionada(selection);
      },
      fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
          ) {
        // Sincronizar el controlador con el valor seleccionado
        if (_provinciaSeleccionada != null && textEditingController.text.isEmpty) {
          textEditingController.text = _provinciaSeleccionada!;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Provincia/Municipio *',
            hintText: 'Escriba para buscar...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: _provinciaSeleccionada != null
                ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                textEditingController.clear();
                setState(() {
                  _provinciaSeleccionada = null;
                  _puntoEmpadronamientoSeleccionado = null;
                  _puntosEmpadronamiento = [];
                });
              },
            )
                : null,
          ),
        );
      },
      optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
          ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPuntoEmpadronamientoAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _puntosEmpadronamiento;
        }
        return _puntosEmpadronamiento.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _puntoEmpadronamientoSeleccionado = selection;
        });
        _onPuntoEmpadronamientoSeleccionado(selection);
      },
      fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
          ) {
        // Sincronizar el controlador con el valor seleccionado
        if (_puntoEmpadronamientoSeleccionado != null && textEditingController.text.isEmpty) {
          textEditingController.text = _puntoEmpadronamientoSeleccionado!;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: _provinciaSeleccionada != null,
          decoration: InputDecoration(
            labelText: 'Punto de Empadronamiento *',
            hintText: _provinciaSeleccionada != null
                ? 'Escriba para buscar...'
                : 'Primero seleccione una provincia',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: _puntoEmpadronamientoSeleccionado != null
                ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                textEditingController.clear();
                setState(() {
                  _puntoEmpadronamientoSeleccionado = null;
                  _puntoEmpadronamientoId = null;
                });
              },
            )
                : null,
          ),
        );
      },
      optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
          ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ NUEVO: Widget para información de GPS
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

              // ✅ NUEVO: Campos de empadronamiento
              _buildCamposEmpadronamiento(),

              const SizedBox(height: 24),
              // _buildDestinoField(),
              // const SizedBox(height: 24),
              _buildObservacionesField(),
              const SizedBox(height: 24),

              // ✅ MODIFICADO: Información de coordenadas con GPS
              _buildGPSInfo(),

              const SizedBox(height: 24),
              _buildSincronizacionSwitch(),
              const SizedBox(height: 32),
              _buildRegistrarButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Los métodos existentes se mantienen igual...
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
          const Text('Información del Operador',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Usuario: $_userName', style: const TextStyle(fontSize: 13)),
          Text('ID Operador: ${widget.idOperador}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text('Email: $_userEmail', style: const TextStyle(fontSize: 13)),
          Text('Rol: $_userRole', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // Widget _buildDestinoField() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Destino *',
  //           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //       const SizedBox(height: 8),
  //       TextField(
  //         controller: _destino,
  //         decoration: InputDecoration(
  //           labelText: 'Ingrese el destino',
  //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  //           contentPadding:
  //           const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Observaciones',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _observacionesController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Ingrese observaciones adicionales...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSincronizacionSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sincronizar con Servidor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _sincronizarConServidor
                      ? '📤 Enviar inmediatamente'
                      : '💾 Solo guardar localmente',
                  style: TextStyle(
                      fontSize: 12,
                      color: _sincronizarConServidor
                          ? Colors.green.shade700
                          : Colors.orange.shade700),
                ),
              ],
            ),
          ),
          Switch(
            value: _sincronizarConServidor,
            onChanged: (value) => setState(() => _sincronizarConServidor = value),
            activeColor: Colors.blue,
          ),
        ],
      ),
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
        ),
        icon: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        )
            : const Icon(Icons.save, size: 20),
        label: Text(
          _isLoading ? 'Procesando...' : 'Registrar Despliegue',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _limpiarFormulario() {
    _observacionesController.clear();
    //_destino.clear();
    setState(() {
      _sincronizarConServidor = true;
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
    //_destino.dispose();
    super.dispose();
  }

  // ✅ CAMBIADO: De Autocomplete a Dropdown simple para Punto de Empadronamiento
  // ✅ ACTUALIZADO: Usar Dropdown en lugar de Autocomplete
  // ✅ ACTUALIZADO: Usar Dropdown en lugar de Autocomplete
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

            // ✅ CAMBIADO: Provincia con Dropdown
            _buildProvinciaDropdown(),

            const SizedBox(height: 12),

            // ✅ CAMBIADO: Punto de Empadronamiento con Dropdown
            _buildPuntoEmpadronamientoDropdown(),
          ],
        ),
      ),
    );
  }
// ✅ CAMBIADO: De Autocomplete a Dropdown simple para Provincia
  Widget _buildProvinciaDropdown() {
    return DropdownButtonFormField<String>(
      value: _provinciaSeleccionada,
      decoration: InputDecoration(
        labelText: 'Provincia/Municipio *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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


  // ✅ CORREGIDO: Sin el parámetro 'enabled'
  Widget _buildPuntoEmpadronamientoDropdown() {
    return DropdownButtonFormField<String>(
      value: _puntoEmpadronamientoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Punto de Empadronamiento *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintText: _provinciaSeleccionada != null
            ? (_puntosEmpadronamiento.isEmpty ? 'Cargando puntos...' : 'Seleccione un punto')
            : 'Primero seleccione una provincia',
      ),
      isExpanded: true,
      // ❌ ELIMINADO: enabled: _provinciaSeleccionada != null && _puntosEmpadronamiento.isNotEmpty,
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
      // ✅ CORREGIDO: Controlar habilitación mediante onChanged
      onChanged: (_provinciaSeleccionada != null && _puntosEmpadronamiento.isNotEmpty)
          ? (String? nuevoPunto) {
        setState(() {
          _puntoEmpadronamientoSeleccionado = nuevoPunto;
        });
        _onPuntoEmpadronamientoSeleccionado(nuevoPunto);
      }
          : null, // Si es null, el dropdown se deshabilita automáticamente
      validator: (value) {
        if (_provinciaSeleccionada != null && (value == null || value.isEmpty)) {
          return 'Seleccione un punto de empadronamiento';
        }
        return null;
      },
    );
  }

}