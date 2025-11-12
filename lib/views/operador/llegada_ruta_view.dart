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
  final TextEditingController _observacionesController =
  TextEditingController();
  String _coordenadas = 'No capturadas';
  RegistroDespliegue? _registroActivo;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _cargarUsuarioYRegistro();
  }

  /// Cargar usuario actual y luego el registro activo
  Future<void> _cargarUsuarioYRegistro() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        print('✅ Usuario cargado: ${user.username} (ID: ${user.id})');
        print('🔑 ID Operador: ${widget.idOperador}');

        // Cargar registros del operador usando idOperador
        await _cargarUltimoRegistroActivo();
      } else {
        _mostrarSnack('No hay usuario autenticado', error: true);
      }
    } catch (e) {
      _mostrarSnack('Error al cargar usuario: $e', error: true);
    }
  }

  /// Cargar el último registro de despliegue activo para el operador
  Future<void> _cargarUltimoRegistroActivo() async {
    try {
      final db = DatabaseService();

      // Obtener todos los registros de despliegue
      final todosRegistros = await db.obtenerTodosRegistros();

      // Filtrar por operador (usando idOperador) y estado DESPLIEGUE
      final registrosDelOperador = todosRegistros
          .where((r) =>
      r.operadorId == widget.idOperador &&
          r.estado == 'DESPLIEGUE')
          .toList();

      print('📊 Registros del operador ${widget.idOperador}: ${registrosDelOperador.length}');

      if (registrosDelOperador.isNotEmpty) {
        setState(() {
          _registroActivo = registrosDelOperador.last;
        });
        print('✅ Registro activo encontrado: ${_registroActivo?.destino}');
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
        _mostrarSnack(
            'No se pudo obtener la ubicación actual',
            error: true);
        return;
      }

      setState(() {
        _coordenadas =
        'Lat: ${location.latitude.toStringAsFixed(6)}\nLong: ${location.longitude.toStringAsFixed(6)}';
      });

      final ahora = DateTime.now();

      /// 📌 CREAR UN NUEVO REGISTRO DE LLEGADA
      final nuevoRegistroLlegada = RegistroDespliegue(
        destino: _registroActivo!.destino,
        latitud: location.latitude.toString(),
        longitud: location.longitude.toString(),
        descripcionReporte: _registroActivo!.descripcionReporte,
        estado: "LLEGADA",
        sincronizar: _sincronizarConServidor,
        observaciones: _observacionesController.text.isEmpty
            ? _registroActivo!.observaciones
            : _observacionesController.text,
        incidencias: _registroActivo!.incidencias,
        fechaHora: ahora.toIso8601String(),
        operadorId: widget.idOperador, // 🎯 Usar idOperador
        sincronizado: false,
      );

      final db = DatabaseService();

      /// 💾 GUARDAR COMO UN NUEVO REGISTRO
      final nuevoId = await db.insertRegistroDespliegue(nuevoRegistroLlegada);
      print('✅ Nuevo registro de llegada creado con ID: $nuevoId');

      // Intentar enviar al servidor si está marcado
      if (_sincronizarConServidor) {
        final tieneInternet = await SyncService().verificarConexion();

        if (tieneInternet) {
          final apiService = ApiService();
          final enviado =
          await apiService.enviarRegistroDespliegue(nuevoRegistroLlegada);

          if (enviado) {
            await db.marcarComoSincronizado(nuevoId);
            _mostrarSnack(
                '✅ Llegada registrada y sincronizada correctamente.');
          } else {
            _mostrarSnack(
                '⚠️ Error al enviar. Guardado para sincronizar después.',
                error: true);
          }
        } else {
          _mostrarSnack(
              '📡 Sin conexión. Se sincronizará cuando haya internet.',
              error: true);
        }
      } else {
        _mostrarSnack('✅ Llegada registrada localmente.');
      }

      _observacionesController.clear();

      // Recargar el siguiente registro activo
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _cargarUltimoRegistroActivo();
        }
      });
    } catch (e) {
      print('❌ Error al registrar llegada: $e');
      _mostrarSnack('Error al registrar llegada: $e', error: true);
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
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay registro de despliegue activo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Operador: ${_currentUser?.username ?? "Cargando..."} (ID: ${widget.idOperador})',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarUltimoRegistroActivo,
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDestinoInfo(),
              const SizedBox(height: 24),
              _buildEstadoInfo(),
              const SizedBox(height: 24),
              _buildObservacionesField(),
              const SizedBox(height: 24),
              _buildCoordenadasInfo(),
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
          const Text('Destino del Despliegue',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_registroActivo?.destino ?? 'N/A',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEstadoInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Creando Nuevo Registro',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Estado: LLEGADA',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObservacionesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Observaciones de Llegada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              Icon(Icons.location_on,
                  size: 18,
                  color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Coordenadas de Llegada:',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_coordenadas,
              style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Monospace',
                  fontWeight: FontWeight.w500)),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sincronizar con Servidor',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
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
          Switch(
            value: _sincronizarConServidor,
            onChanged: (value) =>
                setState(() => _sincronizarConServidor = value),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
              AlwaysStoppedAnimation<Color>(Colors.white)),
        )
            : const Icon(Icons.flag),
        label: Text(
          _isLoading ? 'Procesando...' : 'Registrar Llegada',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
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