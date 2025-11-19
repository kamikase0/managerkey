import 'package:flutter/material.dart';
import 'package:manager_key/config/enviroment.dart';
import '../../models/registro_despliegue_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/salida_llegada_service.dart';

class SalidaRutaView extends StatefulWidget {
  final int idOperador;

  const SalidaRutaView({Key? key, required this.idOperador}) : super(key: key);

  @override
  _SalidaRutaViewState createState() => _SalidaRutaViewState();
}

class _SalidaRutaViewState extends State<SalidaRutaView> {
  final _observacionesController = TextEditingController();
  final _destino = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _databaseService = DatabaseService();
    _salidaLlegadaService = SalidaLlegadaService();
    _loadUserData();
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

  Future<void> _registrarSalida() async {
    if (_destino.text.isEmpty) {
      _mostrarError('El destino es requerido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Usar el servicio integrado de salida-llegada
      final resultado = await _salidaLlegadaService.registrarSalida(
        destino: _destino.text,
        observaciones: _observacionesController.text,
        idOperador: widget.idOperador,
        sincronizarConServidor: _sincronizarConServidor,
      );

      if (resultado['exitoso']) {
        // Guardar ID local de salida para usar en llegada
        _salidaLocalId = resultado['localId'];

        _mostrarExito(resultado['mensaje']);
        _limpiarFormulario();

        // Mostrar opción de ir a registrar llegada después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _mostrarOpcionIrALlegada();
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

  void _mostrarOpcionIrALlegada() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salida Registrada'),
        content: const Text('¿Deseas registrar la llegada ahora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Más tarde'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navegar a llegada con el ID de salida
              Navigator.pushNamed(
                context,
                '/llegada_ruta',
                arguments: {
                  'idOperador': widget.idOperador,
                  'salidaLocalId': _salidaLocalId,
                },
              );
            },
            child: const Text('Ir a Llegada'),
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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfoCard(),
              const SizedBox(height: 24),
              _buildDestinoField(),
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

  Widget _buildDestinoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Destino *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _destino,
          decoration: InputDecoration(
            labelText: 'Ingrese el destino',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

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
              Icon(Icons.location_on, size: 18, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Coordenadas de Salida:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _limpiarFormulario() {
    _observacionesController.clear();
    _destino.clear();
    setState(() {
      _sincronizarConServidor = true;
      _coordenadas = 'No capturadas';
    });
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    _destino.dispose();
    super.dispose();
  }
}