import 'package:flutter/material.dart';
import '../../models/registro_despliegue_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class SalidaRutaView extends StatefulWidget {
  const SalidaRutaView({Key? key}) : super(key: key);

  @override
  _SalidaRutaViewState createState() => _SalidaRutaViewState();
}

class _SalidaRutaViewState extends State<SalidaRutaView> {
  final _observacionesController = TextEditingController();
  bool _switchValue = false;
  bool _isLoading = false;
  String _coordenadas = 'No capturadas';

  String _userName = 'Cargando...';
  String _userRole = 'Cargando...';
  String _userEmail = 'Cargando...';
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService().getCurrentUser();

    if (user != null) {
      setState(() {
        _currentUser = user;
        _userName = user.username;
        _userRole = user.groups.join(', ');
        _userEmail = user.email;
      });
    } else {
      setState(() {
        _userName = 'Usuario No Identificado';
        _userRole = 'Rol No Asignado';
        _userEmail = 'Email no disponible';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida de Ruta'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDespliegueSwitch(),
              const SizedBox(height: 24),
              _buildObservacionesField(),
              const SizedBox(height: 24),
              _buildCoordenadasInfo(),
              const SizedBox(height: 24),
              _buildRegistrarButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDespliegueSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Despliegue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _switchValue ? 'Enviar a servidor' : 'Solo guardar local',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Switch(
            value: _switchValue,
            onChanged: (value) {
              setState(() {
                _switchValue = value;
              });
            },
            activeColor: Colors.blue,
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
          'Observaciones',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _observacionesController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Ingrese observaciones adicionales...',
            labelText: 'Observaciones',
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
              Icon(Icons.location_on, size: 18, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text(
                'Coordenadas Capturadas:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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

  Widget _buildRegistrarButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registrarSalida,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.save, size: 20),
            SizedBox(width: 8),
            Text(
              'Registrar Salida',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrarSalida() async {
    setState(() => _isLoading = true);

    try {
      // Obtener ubicación actual
      final position = await LocationService().getCurrentLocation();
      if (position == null) {
        _mostrarError('No se pudo obtener la ubicación');
        return;
      }

      // Actualizar coordenadas en UI
      setState(() {
        _coordenadas = 'Lat: ${position.latitude.toStringAsFixed(6)}\n'
            'Long: ${position.longitude.toStringAsFixed(6)}';
      });

      // Crear registro de despliegue
      final registro = RegistroDespliegue(
        destino: "Laja",
        latitudDespliegue: position.latitude.toString(),
        longitudDespliegue: position.longitude.toString(),
        fueDesplegado: true,
        llegoDestino: false,
        fechaHoraSalida: DateTime.now().toIso8601String(),
        operadorId: _currentUser?.id ?? 100,
        estado: "TRANSMITIDO",
        observaciones: _observacionesController.text,
        sincronizar: !_switchValue, // true si NO sincroniza, false si SÍ sincroniza
      );

      // Guardar en base de datos local
      final db = DatabaseService();
      final localId = await db.insertRegistroDespliegue(registro);

      // Intentar enviar al servidor si el switch está activado
      if (_switchValue) {
        final apiService = ApiService();
        final enviado = await apiService.enviarRegistroDespliegue(registro);
        if (enviado) {
          await db.marcarComoSincronizado(localId);
          _mostrarExito('Despliegue enviado al servidor');
        } else {
          _mostrarError('Error al enviar. Guardado localmente.');
        }
      } else {
        _mostrarExito('Despliegue guardado localmente');
      }

      _limpiarFormulario();
    } catch (e) {
      _mostrarError('Error al registrar salida: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _limpiarFormulario() {
    _observacionesController.clear();
    setState(() {
      _switchValue = false;
    });
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }
}