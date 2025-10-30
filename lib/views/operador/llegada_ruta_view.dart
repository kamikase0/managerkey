import 'package:flutter/material.dart';
import '../../models/salida_ruta_model.dart';

class LlegadaRutaView extends StatefulWidget {
  const LlegadaRutaView({Key? key}) : super(key:key);

  @override
  _LlegadaRutaViewState createState() => _LlegadaRutaViewState();
}

class _LlegadaRutaViewState extends State<LlegadaRutaView> {
  final _formKey = GlobalKey<FormState>();
  // final _descripcionController = TextEditingController();
  final _observacionesController = TextEditingController();

  double _latitud = 0.0;
  double _longitud = 0.0;
  DateTime _fechaHora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActual();
  }

  void _obtenerUbicacionActual() {
    // Aquí implementarías la obtención de la ubicación actual
    // Por ahora usamos valores de ejemplo
    setState(() {
      _latitud = -17.7833; // Ejemplo de coordenadas
      _longitud = -63.1821; // Ejemplo de coordenadas
      _fechaHora = DateTime.now();
    });
  }

  void _registrarLlegada() {
    if (_formKey.currentState!.validate()) {
      final llegada = SalidaRuta(
        fechaHora: _fechaHora,
        latitud: _latitud,
        longitud: _longitud,
        //descripcion: _descripcionController.text,
        observaciones: _observacionesController.text,
        enviado: false,
      );

      // Aquí guardarías en la base de datos local
      print('Llegada registrada: ${llegada.toMap()}');

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Llegada registrada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Limpiar formulario
      // _descripcionController.clear();
      _observacionesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de Llegada'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header informativo
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jose Luis Subia Paz',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Operador Rural',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Sección de Despliegue
              Text(
                'Despliegue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),

              SizedBox(height: 16),

              // Llegada a destino
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Llegó a destino',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // // Descripción
              // Text(
              //   'Descripción',
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     color: Colors.grey[700],
              //   ),
              // ),
              // SizedBox(height: 8),
              // TextFormField(
              //   controller: _descripcionController,
              //   maxLines: 3,
              //   decoration: InputDecoration(
              //     hintText: 'Ingrese la descripción de la llegada...',
              //     border: OutlineInputBorder(),
              //     contentPadding: EdgeInsets.all(12),
              //   ),
              //   validator: (value) {
              //     if (value == null || value.isEmpty) {
              //       return 'Por favor ingrese una descripción';
              //     }
              //     return null;
              //   },
              // ),
              //
              // SizedBox(height: 16),

              // Observaciones
              Text(
                'Observaciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _observacionesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ingrese observaciones adicionales...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),

              SizedBox(height: 24),

              // Información de ubicación y fecha
              Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información de registro:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Latitud: $_latitud'),
                      Text('Longitud: $_longitud'),
                      Text('Fecha: ${_fechaHora.toString()}'),
                    ],
                  ),
                ),
              ),

              Spacer(),

              // Botón de registrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _registrarLlegada,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Registrar Llegada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    //_descripcionController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }
}