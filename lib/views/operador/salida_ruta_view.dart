import 'package:flutter/material.dart';
import '../../models/salida_ruta_model.dart';
import '../../models/user_model.dart';

import '../../services/api_service.dart';

import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class SalidaRutaView extends StatefulWidget {
  const SalidaRutaView({Key? key}) : super(key: key);

  @override
  _SalidaRutaViewState createState() => _SalidaRutaViewState();
}

class _SalidaRutaViewState extends State<SalidaRutaView> {
  final _formKey = GlobalKey<FormState>();
  // final _descripcionController = TextEditingController();

  final _observacionesController = TextEditingController();
  bool _switchValue = false;
  bool _isLoading = false;
  String _coordenadas = 'No capturadas';
  double? _latitud;
  double? _longitud;

  // Variables para datos del usuario
  String _userName = 'Cargando...';
  String _userRole = 'Cargando...';
  String _userEmail = 'Cargando...';
  String _welcomeMessage = 'Bienvenido/a';
  User? _currentUser;
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService(); //inicializa
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService().getCurrentUser();
    final welcomeMsg = await AuthService().getWelcomeMessage();

    if (user != null) {
      setState(() {
        _currentUser = user;
        _userName = user.username;
        _userRole = user.groups.join(', ');
        _userEmail = user.email;
        _welcomeMessage = welcomeMsg;
      });
    } else {
      setState(() {
        _userName = 'Usuario No Identificado';
        _userRole = 'Rol No Asignado';
        _userEmail = 'Email no disponible';
        _welcomeMessage = 'Bienvenido/a';
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mensaje de bienvenida
            //_buildWelcomeMessage(),
            //const SizedBox(height: 16),

            // Header con información del operador REAL
            // _buildUserHeader(),
            // const SizedBox(height: 24),

            // Switch de Despliegue
            _buildDespliegueSwitch(),
            const SizedBox(height: 24),

            // Observaciones
            _buildObservacionesField(),
            const SizedBox(height: 24),

            // Coordenadas
            _buildCoordenadasInfo(),
            const SizedBox(height: 24),

            // Botón Registrar Salida
            _buildRegistrarButton(),
          ],
        ),
      ),
    );
  }

  // Widget _buildWelcomeMessage() {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.green.shade50,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: Colors.green.shade200),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(Icons.waving_hand, color: Colors.green.shade700, size: 24),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 _welcomeMessage,
  //                 style: TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.green.shade800,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 'Hora: ${_getCurrentTime()}',
  //                 style: TextStyle(
  //                   fontSize: 12,
  //                   color: Colors.green.shade600,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildUserHeader() {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.blue.shade50,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.blue.shade200),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Información principal
  //         Row(
  //           children: [
  //             Icon(Icons.person, size: 20, color: Colors.blue.shade700),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     _userName,
  //                     style: TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.blue.shade900,
  //                     ),
  //                   ),
  //                   Text(
  //                     _userRole,
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       color: Colors.blue.shade700,
  //                       fontWeight: FontWeight.w500,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 12),
  //         Divider(height: 1, color: Colors.blue.shade200),
  //         const SizedBox(height: 12),
  //
  //         // Información de contacto
  //         Row(
  //           children: [
  //             Icon(Icons.email, size: 16, color: Colors.blue.shade600),
  //             const SizedBox(width: 8),
  //             Expanded(
  //               child: Text(
  //                 _userEmail,
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   color: Colors.blue.shade800,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         const SizedBox(height: 8),
  //
  //         Row(
  //           children: [
  //             Icon(Icons.assignment_ind, size: 16, color: Colors.blue.shade600),
  //             const SizedBox(width: 8),
  //             Text(
  //               'ID: ${_currentUser?.id ?? 'N/A'}',
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 color: Colors.blue.shade800,
  //               ),
  //             ),
  //           ],
  //         ),
  //
  //         if (_currentUser?.isStaff == true) ...[
  //           const SizedBox(height: 8),
  //           Row(
  //             children: [
  //               Icon(Icons.verified_user, size: 16, color: Colors.green.shade600),
  //               const SizedBox(width: 8),
  //               Text(
  //                 'Usuario Staff',
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   color: Colors.green.shade700,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

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
    setState(() {
      _isLoading = true;
    });

    try {
      // Capturar coordenadas
      final position = await LocationService().getCurrentLocation();
      if (position == null) {
        _mostrarError('No se pudo obtener la ubicación');
        return;
      }

      setState(() {
        _latitud = position.latitude;
        _longitud = position.longitude;
        _coordenadas = 'Lat: ${position.latitude.toStringAsFixed(6)}\n'
            'Long: ${position.longitude.toStringAsFixed(6)}';
      });

      // Guardar en SQLite local
      final salida = SalidaRuta(
        fechaHora: DateTime.now(),
        latitud: _latitud!,
        longitud: _longitud!,
        observaciones: _observacionesController.text,
      );

      await DatabaseService().insertSalidaRuta(salida);

      // GUARDAR EN FIRESTORE si el switch está activado
      if (_switchValue) {
        final guardado = await _firestoreService.guardarSalida(
          latitud: _latitud!,
          longitud: _longitud!,
          observaciones: _observacionesController.text,
        );

        if (guardado) {
          _mostrarExito('Salida guardada en servidor');
        } else {
          _mostrarError('Error al guardar en servidor');
        }
      } else {
        _mostrarExito('Salida guardada localmente');
      }

      _limpiarFormulario();
    } catch (e) {
      _mostrarError('Error al registrar salida: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<void> _registrarSalida() async {
  //   // if (_descripcionController.text.isEmpty) {
  //   //   _mostrarError('Por favor ingrese una descripción');
  //   //   return;
  //   // }
  //
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   try {
  //     // Capturar coordenadas
  //     final position = await LocationService().getCurrentLocation();
  //
  //     if (position == null) {
  //       _mostrarError('No se pudo obtener la ubicación');
  //       return;
  //     }
  //
  //     setState(() {
  //       _latitud = position.latitude;
  //       _longitud = position.longitude;
  //       _coordenadas = 'Lat: ${position.latitude.toStringAsFixed(6)}\n'
  //           'Long: ${position.longitude.toStringAsFixed(6)}';
  //     });
  //
  //     // Crear modelo de salida
  //     final salida = SalidaRuta(
  //       fechaHora: DateTime.now(),
  //       latitud: _latitud!,
  //       longitud: _longitud!,
  //       //descripcion: _descripcionController.text,
  //       observaciones: _observacionesController.text,
  //     );
  //
  //     // Guardar en SQLite
  //     final id = await DatabaseService().insertSalidaRuta(salida);
  //
  //     // Intentar enviar a API si hay conexión
  //     if (_switchValue) {
  //       final enviado = await ApiService().enviarSalidaRuta(salida);
  //       if (enviado) {
  //         await DatabaseService().updateSalidaEnviada(id);
  //         _mostrarExito('Salida registrada y enviada al servidor');
  //       } else {
  //         _mostrarExito('Salida registrada localmente (error al enviar)');
  //       }
  //     } else {
  //       _mostrarExito('Salida registrada localmente');
  //     }
  //
  //     _limpiarFormulario();
  //
  //   } catch (e) {
  //     _mostrarError('Error al registrar salida: $e');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  // Future<void> _registrarSalida() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   try {
  //     // Capturar coordenadas
  //     final position = await LocationService().getCurrentLocation();
  //     if (position == null) {
  //       _mostrarError('No se pudo obtener la ubicación');
  //       return;
  //     }
  //
  //     setState(() {
  //       _latitud = position.latitude;
  //       _longitud = position.longitude;
  //       _coordenadas = 'Lat: ${position.latitude.toStringAsFixed(6)}\n'
  //           'Long: ${position.longitude.toStringAsFixed(6)}';
  //     });
  //
  //     // Guardar en SQLite local
  //     final salida = SalidaRuta(
  //       fechaHora: DateTime.now(),
  //       latitud: _latitud!,
  //       longitud: _longitud!,
  //       observaciones: _observacionesController.text,
  //     );
  //
  //     await DatabaseService().insertSalidaRuta(salida);
  //
  //     // GUARDAR EN FIRESTORE si el switch está activado
  //     if (_switchValue) {
  //       final guardado = await _firestoreService.guardarSalida(
  //         latitud: _latitud!,
  //         longitud: _longitud!,
  //         observaciones: _observacionesController.text,
  //       );
  //
  //       if (guardado) {
  //         _mostrarExito('Salida guardada en servidor');
  //       } else {
  //         _mostrarError('Error al guardar en servidor');
  //       }
  //     } else {
  //       _mostrarExito('Salida guardada localmente');
  //     }
  //
  //     _limpiarFormulario();
  //   } catch (e) {
  //     _mostrarError('Error al registrar salida: $e');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

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
    // _descripcionController.clear();
    _observacionesController.clear();
    setState(() {
      _switchValue = false;
    });
    // No limpiamos las coordenadas para que el usuario pueda verlas
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // _descripcionController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }
}