import 'package:flutter/material.dart';
import 'package:manager_key/config/enviroment.dart';
import '../../models/registro_despliegue_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';

class SalidaRutaView extends StatefulWidget {
  final int idOperador;

  const SalidaRutaView({Key? key, required this.idOperador}) : super(key: key);

  @override
  _SalidaRutaViewState createState() => _SalidaRutaViewState();
}

class _SalidaRutaViewState extends State<SalidaRutaView> {
  final _observacionesController = TextEditingController();
  final _destino = TextEditingController();

  bool _sincronizarConServidor = false;
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
      print('✅ Usuario cargado: ${user.username}');
      print('🔑 ID Operador a usar: ${widget.idOperador}');
    } else {
      setState(() {
        _userName = 'Usuario No Identificado';
        _userRole = 'Rol No Asignado';
        _userEmail = 'Email no disponible';
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
      final position = await LocationService().getCurrentLocation();
      if (position == null) {
        _mostrarError('No se pudo obtener la ubicación');
        return;
      }

      setState(() {
        _coordenadas =
        'Lat: ${position.latitude.toStringAsFixed(6)}\nLong: ${position.longitude.toStringAsFixed(6)}';
      });

      final ahora = DateTime.now();

      final registro = RegistroDespliegue(
        destino: _destino.text,
        latitud: position.latitude.toString(),
        longitud: position.longitude.toString(),
        descripcionReporte: null,
        estado: "DESPLIEGUE",
        sincronizar: _sincronizarConServidor,
        observaciones: _observacionesController.text,
        incidencias: "",
        fechaHora: ahora.toIso8601String(),
        operadorId: widget.idOperador,
        sincronizado: false,
      );

      final db = DatabaseService();
      final localId = await db.insertRegistroDespliegue(registro);
      print('✅ Registro de salida creado con ID: $localId');

      if (_sincronizarConServidor) {
        final tieneInternet = await SyncService().verificarConexion();
        if (tieneInternet) {
          // ✅ CORREGIDO: Obtener token desde AuthService
          final authService = AuthService();
          final accessToken = await authService.getAccessToken();

          if (accessToken == null || accessToken.isEmpty) {
            _mostrarError('No se pudo obtener el token de autenticación');
            return;
          }

          final apiService = ApiService(accessToken: accessToken);
          final registroMap = registro.toJson();
          final enviado = await apiService.enviarRegistroDespliegue(registroMap);

          if (enviado) {
            await db.marcarComoSincronizado(localId);
            _mostrarExito('✅ Despliegue enviado al servidor');
          } else {
            _mostrarError('⚠️ Error al enviar. Guardado para sincronizar después.');
          }
        } else {
          _mostrarError('📡 Sin conexión. Se sincronizará cuando haya internet.');
        }
      } else {
        _mostrarExito('✅ Despliegue guardado localmente'); // ✅ Agregar este mensaje
      }

      _limpiarFormulario();
    } catch (e) {
      print('❌ Error al registrar salida: $e');
      _mostrarError('Error al registrar salida: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Future<void> _registrarSalida() async {
  //   if (_destino.text.isEmpty) {
  //     _mostrarError('El destino es requerido');
  //     return;
  //   }
  //
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     final position = await LocationService().getCurrentLocation();
  //     if (position == null) {
  //       _mostrarError('No se pudo obtener la ubicación');
  //       return;
  //     }
  //
  //     setState(() {
  //       _coordenadas =
  //       'Lat: ${position.latitude.toStringAsFixed(6)}\nLong: ${position.longitude.toStringAsFixed(6)}';
  //     });
  //
  //     final ahora = DateTime.now();
  //
  //     final registro = RegistroDespliegue(
  //       destino: _destino.text,
  //       latitud: position.latitude.toString(),
  //       longitud: position.longitude.toString(),
  //       descripcionReporte: null,
  //       estado: "DESPLIEGUE",
  //       sincronizar: _sincronizarConServidor,
  //       observaciones: _observacionesController.text,
  //       incidencias: "",
  //       fechaHora: ahora.toIso8601String(),
  //       operadorId: widget.idOperador,
  //       sincronizado: false,
  //     );
  //
  //     final db = DatabaseService();
  //     final localId = await db.insertRegistroDespliegue(registro);
  //     print('✅ Registro de salida creado con ID: $localId');
  //
  //     if (_sincronizarConServidor) {
  //       final tieneInternet = await SyncService().verificarConexion();
  //       if (tieneInternet) {
  //         final token = _currentUser?.accessToken ?? ''; // Obtener el token del usuario
  //         final apiService = ApiService(accessToken: token); // Pasar el token
  //         final registroMap = registro.toJson();
  //         final enviado = await apiService.enviarRegistroDespliegue(registroMap);
  //
  //         if (enviado) {
  //           await db.marcarComoSincronizado(localId);
  //           _mostrarExito('✅ Despliegue enviado al servidor');
  //         } else {
  //           _mostrarError('⚠️ Error al enviar. Guardado para sincronizar después.');
  //         }
  //       } else {
  //         _mostrarError('📡 Sin conexión. Se sincronizará cuando haya internet.');
  //       }
  //     }
  //
  //     _limpiarFormulario();
  //   } catch (e) {
  //     print('❌ Error al registrar salida: $e');
  //     _mostrarError('Error al registrar salida: $e');
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  // Future<void> _registrarSalida() async {
  //   if (_destino.text.isEmpty) {
  //     _mostrarError('El destino es requerido');
  //     return;
  //   }
  //
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     final position = await LocationService().getCurrentLocation();
  //     if (position == null) {
  //       _mostrarError('No se pudo obtener la ubicación');
  //       return;
  //     }
  //
  //     setState(() {
  //       _coordenadas =
  //       'Lat: ${position.latitude.toStringAsFixed(6)}\nLong: ${position.longitude.toStringAsFixed(6)}';
  //     });
  //
  //     final ahora = DateTime.now();
  //
  //     // ✅ Usar widget.idOperador en lugar de user.id
  //     final registro = RegistroDespliegue(
  //       destino: _destino.text,
  //       latitud: position.latitude.toString(),
  //       longitud: position.longitude.toString(),
  //       descripcionReporte: null,
  //       estado: "DESPLIEGUE",
  //       sincronizar: _sincronizarConServidor,
  //       observaciones: _observacionesController.text,
  //       incidencias: "",
  //       fechaHora: ahora.toIso8601String(),
  //       operadorId: widget.idOperador, // 🎯 Usar idOperador del parámetro
  //       sincronizado: false,
  //     );
  //
  //     final db = DatabaseService();
  //     final localId = await db.insertRegistroDespliegue(registro);
  //     print('✅ Registro de salida creado con ID: $localId');
  //
  //     if (_sincronizarConServidor) {
  //       final tieneInternet = await SyncService().verificarConexion();
  //       if (tieneInternet) {
  //         final token = AuthService().getAccessToken();
  //         final apiService = ApiService(accessToken: token);
  //
  //         final String _baseUrl = Enviroment.apiUrl;
  //         final String _registrosEndpoint = 'registrosdespliegue/';
  //         String apiService = '$_baseUrl$_registrosEndpoint';
  //
  //         final registroMap = registro.toJson();
  //         final estado = await apiService.enviarRegistroDespliegue(registroMap);
  //         //final enviado = await apiService.enviarRegistroDespliegue(registro);
  //
  //         if (estado) {
  //           await db.marcarComoSincronizado(localId);
  //           _mostrarExito('✅ Despliegue enviado al servidor');
  //         } else {
  //           _mostrarError('⚠️ Error al enviar. Guardado para sincronizar después.');
  //         }
  //       } else {
  //         _mostrarError('📡 Sin conexión. Se sincronizará cuando haya internet.');
  //       }
  //     } else {
  //       _mostrarExito('✅ Despliegue guardado localmente');
  //     }
  //
  //     _limpiarFormulario();
  //   } catch (e) {
  //     print('❌ Error al registrar salida: $e');
  //     _mostrarError('Error al registrar salida: $e');
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

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
                  fontSize: 13, fontFamily: 'Monospace', fontWeight: FontWeight.w500)),
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
          Column(
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _limpiarFormulario() {
    _observacionesController.clear();
    _destino.clear();
    setState(() {
      _sincronizarConServidor = false;
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