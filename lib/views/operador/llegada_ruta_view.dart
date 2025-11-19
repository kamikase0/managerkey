import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';
import '../../models/registro_despliegue_model.dart';
import '../../models/user_model.dart';


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

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _databaseService = DatabaseService();
    _cargarUsuarioYRegistro();
  }

  /// Cargar usuario actual y luego el registro activo
  Future<void> _cargarUsuarioYRegistro() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        print('✅ Usuario cargado: ${user.username}');
        print('🔑 ID Operador: ${widget.idOperador}');

        // Cargar registros del operador usando idOperador
        await _cargarUltimoRegistroActivo();
      } else {
        _mostrarSnack('No hay usuario autenticado', error: true);
      }
    } catch (e) {
      print('❌ Error al cargar usuario: $e');
      _mostrarSnack('Error al cargar usuario: $e', error: true);
    }
  }

  /// Cargar el último registro de despliegue activo para el operador
  Future<void> _cargarUltimoRegistroActivo() async {
    try {
      // Obtener todos los registros de despliegue
      final todosRegistros = await _databaseService.obtenerTodosRegistros();

      // Filtrar por operador y estado DESPLIEGUE
      final registrosDelOperador = todosRegistros
          .where((r) => r.operadorId == widget.idOperador && r.estado == 'DESPLIEGUE')
          .toList();

      print('📊 Registros del operador ${widget.idOperador}: ${registrosDelOperador.length}');

      if (registrosDelOperador.isNotEmpty) {
        // Ordenar por fecha más reciente y tomar el último
        registrosDelOperador.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

        setState(() {
          _registroActivo = registrosDelOperador.first;
        });
        print('✅ Registro activo encontrado: ${_registroActivo?.destino} - ${_registroActivo?.fechaHora}');
      } else {
        print('❌ No hay registros activos para este operador');
        _mostrarSnack('No hay registro de despliegue activo', error: true);
      }
    } catch (e) {
      print('❌ Error al cargar registro: $e');
      _mostrarSnack('Error al cargar registro: $e', error: true);
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

  Future<void> _registrarLlegada() async {
    if (_registroActivo == null) {
      _mostrarSnack('No hay registro de despliegue activo', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Obtener ubicación actual
      final location = await LocationService().getCurrentLocation();
      if (location == null) {
        _mostrarSnack('No se pudo obtener la ubicación actual', error: true);
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _coordenadas = 'Lat: ${location.latitude.toStringAsFixed(6)}\nLong: ${location.longitude.toStringAsFixed(6)}';
      });

      final ahora = DateTime.now();

      // Crear nuevo registro de llegada
      final nuevoRegistroLlegada = RegistroDespliegue(
        destino: _registroActivo!.destino,
        latitud: location.latitude.toString(),
        longitud: location.longitude.toString(),
        descripcionReporte: _registroActivo!.descripcionReporte,
        estado: "LLEGADA",
        sincronizar: _sincronizarConServidor,
        observaciones: _observacionesController.text.isNotEmpty
            ? _observacionesController.text
            : _registroActivo!.observaciones,
        incidencias: _registroActivo!.incidencias,
        fechaHora: ahora.toIso8601String(),
        operadorId: widget.idOperador,
        sincronizado: false,
      );

      // Guardar en base de datos local
      final nuevoId = await _databaseService.insertRegistroDespliegue(nuevoRegistroLlegada);
      print('✅ Nuevo registro de llegada creado con ID local: $nuevoId');

      // Si se solicita sincronización inmediata
      if (_sincronizarConServidor) {
        final tieneInternet = await SyncService().verificarConexion();
        if (tieneInternet) {
          final accessToken = await _authService.getAccessToken();

          if (accessToken == null || accessToken.isEmpty) {
            _mostrarSnack('No se pudo obtener el token de autenticación', error: true);
            setState(() => _isLoading = false);
            return;
          }

          final apiService = ApiService(accessToken: accessToken);
          final registroMap = nuevoRegistroLlegada.toApiMap();

          print('📤 Enviando registro de llegada al servidor...');
          final enviado = await apiService.enviarRegistroDespliegue(registroMap);

          if (enviado) {
            // ✅ CORREGIDO: Eliminar registro local después de sincronizar exitosamente
            await _databaseService.eliminarRegistroDespliegue(nuevoId);
            _mostrarSnack('✅ Llegada registrada y sincronizada correctamente');
          } else {
            _mostrarSnack('⚠️ Error al enviar. Se guardó localmente y se sincronizará después');
          }
        } else {
          _mostrarSnack('📡 Sin conexión. Se guardó localmente y se sincronizará cuando haya internet');
        }
      } else {
        _mostrarSnack('✅ Llegada registrada localmente');
      }

      _observacionesController.clear();

      // Recargar para ver si hay más registros activos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _cargarUltimoRegistroActivo();
        }
      });
    } catch (e) {
      print('❌ Error al registrar llegada: $e');
      _mostrarSnack('Error al registrar llegada: ${e.toString()}', error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Llegada'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _registroActivo == null
          ? _buildSinRegistroView()
          : _buildConRegistroView(),
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
            _buildDestinoInfo(),
            const SizedBox(height: 16),
            _buildRegistroOriginalInfo(),
            const SizedBox(height: 16),
            _buildObservacionesField(),
            const SizedBox(height: 16),
            _buildCoordenadasInfo(),
            const SizedBox(height: 16),
            _buildSincronizacionSwitch(),
            const SizedBox(height: 24),
            _buildRegistrarButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinoInfo() {
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
            'Destino del Despliegue',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _registroActivo?.destino ?? 'N/A',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
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

  Widget _buildCoordenadasInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text(
                'Coordenadas de Llegada:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _coordenadas,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
}