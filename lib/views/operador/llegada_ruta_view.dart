import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../config/enviroment.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/punto_empadronamiento_service.dart'; // ✅ NUEVO
import '../../models/registro_despliegue_model.dart';
import '../../models/user_model.dart';
import '../../models/punto_empadronamiento_model.dart'; // ✅ NUEVO
import 'package:sqflite/sqflite.dart';

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
  String _coordenadas = 'No capturadas';
  RegistroDespliegue? _registroActivo;
  User? _currentUser;
  late AuthService _authService;
  late DatabaseService _databaseService;

  // Variables para centro de empadronamiento
  int? _centroEmpadronamientoId;
  String? _puntoEmpadronamientoNombre;

  // Variables para mostrar provincia y municipio
  String? _provincia;
  String? _municipio;

  // ✅ NUEVAS VARIABLES PARA EMPADRONAMIENTO
  String? _provinciaSeleccionada;
  String? _puntoEmpadronamientoSeleccionado;
  List<String> _provincias = [];
  List<String> _puntosEmpadronamiento = [];
  bool _cargadoProvincias = false;
  int? _puntoEmpadronamientoIdSeleccionado;
  final PuntoEmpadronamientoService _puntoService = PuntoEmpadronamientoService();

  // ✅ NUEVAS VARIABLES PARA GEOLOCALIZACION
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
    //_cargarUsuarioYRegistro();
    _cargarDatosEmpadronamiento(); // ✅ NUEVO
    _verificarEstadoGPS(); // ✅ NUEVO
  }

  /// Cargar usuario actual y luego el registro activo
  Future<void> _cargarUsuarioYRegistro() async {
    try {
      final user = await _authService.getCurrentUser();
      // if (user != null) {
      //   setState(() {
      //     _currentUser = user;
      //   });
      //   print('✅ Usuario cargado: ${user.username}');
      //   print('🔍 ID Operador: ${widget.idOperador}');
      //
      //   // Cargar registros del operador usando idOperador
      //   await _cargarUltimoRegistroActivo();
      // } else {
      //   _mostrarSnack('No hay usuario autenticado', error: true);
      // }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
      _mostrarSnack('Error al cargar usuario: $e', error: true);
    }
  }

  /// Cargar el último registro de despliegue activo para el operador
  Future<void> _cargarUltimoRegistroActivo() async {
    try {
      print('📋 INICIANDO BÚSQUEDA DE REGISTRO ACTIVO...');
      print('🔍 ID Operador: ${widget.idOperador}');

      // ✅ PRIMERO: Verificar si hay registro en servidor (si hay internet)
      final tieneInternet = await SyncService().verificarConexion();
      print('🌐 ¿Tiene internet?: $tieneInternet');

      if (tieneInternet) {
        final accessToken = await _authService.getAccessToken();
        print('🔑 ¿Tiene accessToken?: ${accessToken != null && accessToken.isNotEmpty}');

        if (accessToken != null && accessToken.isNotEmpty) {
          final apiService = ApiService(accessToken: accessToken);
          print('📡 Buscando registro en servidor...');

          final registroServidor = await apiService.obtenerUltimoRegistroDespliegue(widget.idOperador);
          print('📊 Resultado búsqueda servidor: ${registroServidor != null ? "ENCONTRADO" : "NO ENCONTRADO"}');

          if (registroServidor != null) {
            print('📋 Datos registro servidor:');
            print('   - Estado: ${registroServidor.estado}');
            print('   - Fecha: ${registroServidor.fechaHora}');
            print('   - Centro Empadronamiento: ${registroServidor.centroEmpadronamiento}');
            print('   - Operador ID: ${registroServidor.operadorId}');

            if (registroServidor.estado == 'DESPLIEGUE') {
              print('✅ Registro activo encontrado en servidor - Centro: ${registroServidor.centroEmpadronamiento}');

              // ✅ Cargar información del centro para mostrar
              await _cargarInformacionCentroEmpadronamiento(registroServidor.centroEmpadronamiento);

              setState(() {
                _registroActivo = registroServidor;
                _centroEmpadronamientoId = registroServidor.centroEmpadronamiento;
              });
              return;
            } else {
              print('⚠️ Registro encontrado pero con estado: ${registroServidor.estado} (se esperaba DESPLIEGUE)');
            }
          } else {
            print('🔭 No se encontró registro en servidor para operador ${widget.idOperador}');
          }
        }
      } else {
        print('📡 Sin conexión a internet, buscando localmente...');
      }

      // ✅ SEGUNDO: Si no hay en servidor o no hay internet, buscar localmente
      print('💾 Buscando registros locales...');
      final todosRegistros = await _databaseService.obtenerTodosRegistros();
      print('📊 Total registros locales: ${todosRegistros.length}');

      // Filtrar por operador y estado DESPLIEGUE
      final registrosDelOperador = todosRegistros
          .where((r) {
        final coincideOperador = r.operadorId == widget.idOperador;
        final coincideEstado = r.estado == 'DESPLIEGUE';
        print('   - Registro ID: ${r.id}, Operador: ${r.operadorId}, Estado: ${r.estado}, Coincide: ${coincideOperador && coincideEstado}');
        return coincideOperador && coincideEstado;
      })
          .toList();

      print('🎯 Registros del operador ${widget.idOperador} con estado DESPLIEGUE: ${registrosDelOperador.length}');

      if (registrosDelOperador.isNotEmpty) {
        // Ordenar por fecha más reciente y tomar el último
        registrosDelOperador.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

        final registroMasReciente = registrosDelOperador.first;
        print('📅 Registro más reciente encontrado:');
        print('   - ID: ${registroMasReciente.id}');
        print('   - Fecha: ${registroMasReciente.fechaHora}');
        print('   - Centro Empadronamiento: ${registroMasReciente.centroEmpadronamiento}');

        // ✅ Cargar información del centro para mostrar
        await _cargarInformacionCentroEmpadronamiento(registroMasReciente.centroEmpadronamiento);

        setState(() {
          _registroActivo = registroMasReciente;
          _centroEmpadronamientoId = _registroActivo!.centroEmpadronamiento;
        });

        print('✅ Registro activo local encontrado - Centro: ${_registroActivo?.centroEmpadronamiento}');
        print('🏢 Centro empadronamiento ID: $_centroEmpadronamientoId');
      } else {
        print('❌ No hay registros activos para este operador');
        print('   - Se buscó operador ID: ${widget.idOperador}');
        print('   - Se buscó estado: DESPLIEGUE');
        _mostrarSnack('No hay registro de despliegue activo', error: true);
      }
    } catch (e) {
      print('❌ Error al cargar registro: $e');
      print('🔍 Stack trace: ${e.toString()}');
      _mostrarSnack('Error al cargar registro: $e', error: true);
    }
  }

  /// Cargar información completa del centro de empadronamiento desde SQLite local
  Future<void> _cargarInformacionCentroEmpadronamiento(int? centroId) async {
    if (centroId == null) return;

    try {
      print('📋 Buscando información del centro: $centroId');

      // Obtener desde la base de datos local (empadronamiento.db)
      final Database db = await openDatabase('empadronamiento.db');

      final List<Map<String, dynamic>> maps = await db.query(
        'puntos_empadronamiento',
        where: 'id = ?',
        whereArgs: [centroId],
      );

      await db.close();

      if (maps.isNotEmpty) {
        final centroEncontrado = maps.first;
        print('✅ Centro encontrado: $centroEncontrado');

        setState(() {
          _provincia = centroEncontrado['provincia'] ?? 'No disponible';
          _municipio = centroEncontrado['punto_de_empadronamiento'] ?? 'No disponible';
          _puntoEmpadronamientoNombre = centroEncontrado['punto_de_empadronamiento'] ?? 'No disponible';
        });

        print('📍 Información del centro cargada: $_municipio, $_provincia');
      } else {
        print('⚠️ Centro no encontrado en BD local, usando valores por defecto');
        // Si no se encuentra en local, usar valores por defecto
        setState(() {
          _provincia = 'No disponible';
          _municipio = 'No disponible';
          _puntoEmpadronamientoNombre = 'No disponible';
        });
      }
    } catch (e) {
      print('❌ Error al cargar información del centro: $e');
      // Valores por defecto en caso de error
      setState(() {
        _provincia = 'No disponible';
        _municipio = 'No disponible';
        _puntoEmpadronamientoNombre = 'No disponible';
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
      _puntoEmpadronamientoIdSeleccionado = null;
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
          _puntoEmpadronamientoIdSeleccionado = puntoSeleccionado.id;
        });
        print('✅ Punto de empadronamiento seleccionado: ID ${_puntoEmpadronamientoIdSeleccionado} - $punto');
      }
    } catch (e) {
      print('❌ Error obteniendo ID del punto de empadronamiento: $e');
    }
  }

  // ✅ NUEVO: Verificar estado GPS
  Future<void> _verificarEstadoGPS() async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      setState(() {
        _gpsActivado = servicioHabilitado;
      });
      print('🔍 Estado GPS: ${servicioHabilitado ? "ACTIVADO" : "DESACTIVADO"}');
    } catch (e) {
      print('❌ Error verificando estado GPS: $e');
      setState(() {
        _gpsActivado = false;
      });
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

      print('🔍 Iniciando captura de geolocalización...');
      final position = await LocationService().getCurrentLocation();
      if (position != null) {
        setState(() {
          _latitud = position.latitude.toStringAsFixed(6);
          _longitud = position.longitude.toStringAsFixed(6);
          _coordenadas = 'Lat: ${_latitud}\nLong: ${_longitud}';
          _locationCaptured = true;
        });
        print('🔍 Geolocalización capturada: $_coordenadas');
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

  void _mostrarSnack(String mensaje, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 3 : 2),
      ),
    );
  }



  /// ✅ NUEVO MÉTODO: Sincronizar registros locales pendientes
  Future<void> _sincronizarRegistrosPendientes() async {
    try {
      print('🔄 Iniciando sincronización de registros pendientes...');

      // Obtener todos los registros no sincronizados
      final pendientes =
      await _databaseService.obtenerRegistrosDespliegueNoSincronizados();

      if (pendientes.isEmpty) {
        print('✅ No hay registros pendientes de sincronizar');
        return;
      }

      print('📊 Encontrados ${pendientes.length} registros pendientes');

      // Verificar conectividad
      final tieneInternet = await SyncService().verificarConexion();
      if (!tieneInternet) {
        print('📡 Sin internet. Sincronización pospuesta');
        return;
      }

      // Obtener token
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        print('❌ No se pudo obtener token de autenticación');
        return;
      }

      int sincronizados = 0;
      int fallidos = 0;

      // Procesar cada registro
      for (var registro in pendientes) {
        // Preparar JSON con los nombres correctos
        final jsonData = {
          'centro_empadronamiento': registro.centroEmpadronamiento,
          'latitud': double.tryParse(registro.latitud) ?? 0,
          'longitud': double.tryParse(registro.longitud) ?? 0,
          'descripcion_reporte': registro.descripcionReporte,
          'estado': registro.estado,
          'sincronizar': registro.sincronizar,
          'observaciones': registro.observaciones ?? '',
          'incidencias': registro.incidencias ?? '',
          'fecha_hora': registro.fechaHora,
          'operador': registro.operadorId,
        };

        final enviado = await _enviarRegistroAlServidor(jsonData, accessToken);

        if (enviado && registro.id != null) {
          // Eliminar del local
          await _databaseService.eliminarRegistroDespliegue(registro.id!);
          print('✅ Registro ${registro.id} sincronizado y eliminado');
          sincronizados++;
        } else {
          print('⚠️ Fallo al sincronizar registro ${registro.id}');
          fallidos++;
        }
      }

      print(
          '📊 Sincronización completada: $sincronizados exitosos, $fallidos fallidos');
    } catch (e) {
      print('❌ Error en sincronización: $e');
    }
  }


  /// Widget para mostrar información del centro de empadronamiento
  Widget _buildCentroEmpadronamientoInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Centro de Empadronamiento',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _puntoEmpadronamientoNombre ?? 'No disponible',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          if (_provincia != null && _municipio != null) ...[
            Text(
              'Provincia: $_provincia',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Municipio: $_municipio',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          Text(
            'ID: ${_centroEmpadronamientoId ?? "No disponible"}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
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

  // ✅ NUEVO: Widget para combobox de provincia
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

  // ✅ NUEVO: Widget para combobox de punto de empadronamiento
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

  // ✅ NUEVO: Widget para campos de empadronamiento
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Llegada'),
        backgroundColor: Colors.green.shade700,
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
      body: _buildConRegistroView(),
    );
  }

  Widget _buildSinRegistroView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No hay registro de despliegue activo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Operador: ${_currentUser?.username ?? "Cargando..."} (ID: ${widget.idOperador})',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarUltimoRegistroActivo,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  Widget _buildConRegistroView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCentroEmpadronamientoInfo(),
            const SizedBox(height: 16),
            _buildCamposEmpadronamiento(),
            const SizedBox(height: 16),
            _buildRegistroOriginalInfo(),
            const SizedBox(height: 16),
            _buildObservacionesField(),
            const SizedBox(height: 16),
            _buildGPSInfo(),
            const SizedBox(height: 16),
            _buildSincronizacionSwitch(),
            const SizedBox(height: 24),
            _buildRegistrarButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistroOriginalInfo() {
    final fechaOriginal = _registroActivo?.fechaHora != null
        ? DateTime.parse(_registroActivo!.fechaHora)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.grey.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Despliegue registrado el:',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  fechaOriginal != null
                      ? '${fechaOriginal.day}/${fechaOriginal.month}/${fechaOriginal.year} ${fechaOriginal.hour}:${fechaOriginal.minute.toString().padLeft(2, '0')}'
                      : 'Fecha no disponible',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observaciones de Llegada',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _observacionesController,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Ingrese observaciones de llegada...',
            contentPadding: const EdgeInsets.all(12),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 4),
        Text(
          'Observaciones originales: ${_registroActivo?.observaciones ?? "Ninguna"}',
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildSincronizacionSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sincronizar con Servidor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _sincronizarConServidor
                      ? '📤 Enviar inmediatamente'
                      : '💾 Solo guardar localmente',
                  style: TextStyle(
                    fontSize: 12,
                    color: _sincronizarConServidor
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _sincronizarConServidor,
            onChanged: (value) => setState(() => _sincronizarConServidor = value),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

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
        icon: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.flag, size: 20),
        label: Text(
          _isLoading ? 'Procesando...' : 'Registrar Llegada',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  // âœ… SECCIÓN CORREGIDA: MÃ©todo _registrarLlegada - LÍNEA ~531
  Future<void> _registrarLlegada() async {
    // âœ… VERIFICAR: Centro de empadronamiento seleccionado
    if (_puntoEmpadronamientoIdSeleccionado == null ||
        _puntoEmpadronamientoIdSeleccionado == 0) {
      _mostrarSnack('Error: Debe seleccionar un punto de empadronamiento',
          error: true);
      return;
    }

    // âœ… VERIFICAR: Provincia seleccionada
    if (_provinciaSeleccionada == null || _provinciaSeleccionada!.isEmpty) {
      _mostrarSnack('Error: Debe seleccionar una provincia', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Obtener ubicaciÃ³n actual (si GPS estÃ¡ activado)
      String? latitudFinal = _latitud;
      String? longitudFinal = _longitud;

      if (_gpsActivado && !_locationCaptured) {
        final location = await LocationService().getCurrentLocation();
        if (location != null) {
          latitudFinal = location.latitude.toString();
          longitudFinal = location.longitude.toString();
          setState(() {
            _coordenadas =
            'Lat: ${location.latitude.toStringAsFixed(6)}\nLong: ${location.longitude.toStringAsFixed(6)}';
          });
        }
      }

      final ahora = DateTime.now().toLocal();

      final fechaFormato = ahora.toIso8601String();
      final fechaSinZ = fechaFormato.replaceAll('Z', '');

      print('â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•');
      print(' REGISTRO DE LLEGADA PARA ENVIAR:');
      print('â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•');
      print('Centro Empadronamiento ID: $_puntoEmpadronamientoIdSeleccionado');
      print('Provincia Seleccionada: $_provinciaSeleccionada');
      print(' Punto Empadronamiento: $_puntoEmpadronamientoSeleccionado');
      print(' Operador ID: ${widget.idOperador}');
      print('Fecha/Hora: ${ahora.toIso8601String()}');
      print('Observaciones: ${_observacionesController.text}');
      print('Latitud: $latitudFinal');
      print('Longitud: $longitudFinal');
      print('â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•');

      // âœ… CREAR OBJETO RegistroDespliegue PARA BD LOCAL
      // âš ï¸ IMPORTANTE: Asegurar que TODOS los campos sean válidos
      final nuevoRegistroLlegada = RegistroDespliegue(
        id: null,  // âœ… SQLite genera el ID automáticamente
        latitud: latitudFinal ?? '0',
        longitud: longitudFinal ?? '0',
        descripcionReporte: null,  // âœ… DEBE SER null O STRING, no vacío si es nullable
        estado: 'LLEGADA',
        sincronizar: _sincronizarConServidor,
        observaciones: _observacionesController.text.isNotEmpty
            ? _observacionesController.text
            : 'Sin observaciones',
        incidencias: '',
        fechaHora: fechaSinZ,
        operadorId: widget.idOperador,
        sincronizado: false,
        centroEmpadronamiento: _puntoEmpadronamientoIdSeleccionado,
        fechaSincronizacion: null,  // âœ… Agregar este campo
      );

      print(' Objeto RegistroDespliegue creado correctamente');

      // âœ… PREPARAR JSON PARA API
      final Map<String, dynamic> jsonParaAPI = {
        'centro_empadronamiento': _puntoEmpadronamientoIdSeleccionado,
        'latitud': double.tryParse(latitudFinal ?? '0') ?? 0,
        'longitud': double.tryParse(longitudFinal ?? '0') ?? 0,
        'descripcion_reporte': null,
        'estado': 'LLEGADA',
        'sincronizar': true,
        'observaciones': _observacionesController.text.isNotEmpty
            ? _observacionesController.text
            : '',
        'incidencias': '',
        'fecha_hora': fechaSinZ,
        'operador': widget.idOperador,
      };

      print(' JSON para API: $jsonParaAPI');

      // âœ… GUARDAR LOCALMENTE PRIMERO (siempre)
      final nuevoId =
      await _databaseService.insertRegistroDespliegue(nuevoRegistroLlegada);
      print('âœ… Nuevo registro de llegada guardado localmente con ID: $nuevoId');

      // âœ… VERIFICAR CONECTIVIDAD Y SINCRONIZAR
      final tieneInternet = await SyncService().verificarConexion();
      print('Â¿Tiene internet?: $tieneInternet');

      if (tieneInternet && _sincronizarConServidor) {
        // âœ… CASO 1: CON INTERNET - ENVIAR INMEDIATAMENTE AL SERVIDOR
        print(' Intentando enviar al servidor...');

        final accessToken = await _authService.getAccessToken();
        if (accessToken == null || accessToken.isEmpty) {
          _mostrarSnack('No se pudo obtener el token de autenticaciÃ³n',
              error: true);
          setState(() => _isLoading = false);
          return;
        }

        final enviado =
        await _enviarRegistroAlServidor(jsonParaAPI, accessToken);

        if (enviado) {
          // âœ… Eliminar del local despuÃ©s de sincronizar exitosamente
          await _databaseService.eliminarRegistroDespliegue(nuevoId);
          print(
              'ï¸ Registro eliminado localmente despuÃ©s de sincronizaciÃ³n exitosa');
              _mostrarSnack('âœ… Llegada registrada y sincronizada correctamente');
        } else {
          print(
              'âš ï¸ Error al enviar. Registro se mantiene localmente para sincronizar despuÃ©s');
          _mostrarSnack(
              'âš ï¸ Error al enviar. Se guardÃ³ localmente y se sincronizarÃ¡ despuÃ©s');
        }
      } else if (!tieneInternet) {
        // âœ… CASO 2: SIN INTERNET - GUARDAR SOLO LOCALMENTE
        print(' Sin conexiÃ³n. Registro guardado localmente para sincronizar despuÃ©s');
        _mostrarSnack(
            ' Sin conexiÃ³n. Se guardÃ³ localmente y se sincronizarÃ¡ cuando haya internet');
      } else {
        // âœ… CASO 3: USUARIO NO QUIERE SINCRONIZAR INMEDIATAMENTE
        print('ð¾ SincronizaciÃ³n manual desactivada. Registro guardado localmente');
            _mostrarSnack('âœ… Llegada registrada localmente');
      }

      _observacionesController.clear();

      // Recargar despuÃ©s de completar
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _cargarUltimoRegistroActivo();
        }
      });
    } catch (e) {
      print('âŒ Error al registrar llegada: $e');
      print('Stack trace: ${StackTrace.current}');
      _mostrarSnack('Error al registrar llegada: ${e.toString()}', error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// âœ… NUEVO MÃ‰TODO: Enviar registro al servidor con POST
  Future<bool> _enviarRegistroAlServidor(
      Map<String, dynamic> jsonData, String accessToken) async {
    try {
      const url = '${Enviroment.apiUrlDev}/registrosdespliegue/';

      print(' URL: $url');
      print(' Token: ${accessToken.substring(0, 20)}...');
      print(' Datos: $jsonData');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(jsonData),
      ).timeout(const Duration(seconds: 30));

      print(' Status Code: ${response.statusCode}');
      print(' Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('âœ… Registro enviado exitosamente al servidor');
        return true;
      } else {
        print('âŒ Error del servidor: ${response.statusCode}');
        print(' Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('âŒ Error de conexiÃ³n al enviar: $e');
      return false;
    }
  }
}