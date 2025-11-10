import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../models/registro_despliegue_model.dart';
import '../../utils/network_utils.dart';

class LlegadaRutaView extends StatefulWidget {
  const LlegadaRutaView({super.key});

  @override
  State<LlegadaRutaView> createState() => _LlegadaRutaViewState();
}

class _LlegadaRutaViewState extends State<LlegadaRutaView> {
  bool _isLoading = false;
  bool _switchValue = true;
  final TextEditingController _observacionesController = TextEditingController();
  String _coordenadas = 'No capturadas';

  void _mostrarSnack(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _registrarLlegada() async {
    setState(() => _isLoading = true);

    try {
      // Obtener ubicación actual
      final location = await LocationService().getCurrentLocation();
      if (location == null) {
        _mostrarSnack("No se pudo obtener la ubicación actual", error: true);
        return;
      }

      // Actualizar coordenadas en UI
      setState(() {
        _coordenadas = 'Lat: ${location.latitude.toStringAsFixed(6)}\n'
            'Long: ${location.longitude.toStringAsFixed(6)}';
      });

      final db = DatabaseService();

      // Buscar el registro activo (último desplegado sin llegada)
      final registros = await db.obtenerNoSincronizados();

      if (registros.isEmpty) {
        _mostrarSnack(
          "No hay registro de salida activo",
          error: true,
        );
        return;
      }

      // Buscar el último registro que fue desplegado pero no llegó
      RegistroDespliegue? registroActivo;
      for (var r in registros.reversed) {
        if (r.fueDesplegado && !r.llegoDestino) {
          registroActivo = r;
          break;
        }
      }

      if (registroActivo == null) {
        _mostrarSnack(
          "No hay registro de salida activo",
          error: true,
        );
        return;
      }

      // Actualizar el registro con datos de llegada
      final actualizado = registroActivo.copyWith(
        llegoDestino: true,
        latitudLlegada: location.latitude.toString(),
        longitudLlegada: location.longitude.toString(),
        estado: "COMPLETADO",
        fechaHoraLlegada: DateTime.now().toIso8601String(),
        observaciones: _observacionesController.text,
        sincronizar: !_switchValue, // true si NO sincroniza, false si SÍ sincroniza
      );

      // Actualizar en base de datos local
      await db.actualizarRegistroDespliegue(actualizado);

      // Intentar enviar al servidor si el switch está activado
      if (_switchValue) {
        bool tieneInternet = await NetworkUtils.verificarConexion();
        if (tieneInternet) {
          final enviado = await ApiService().enviarRegistroDespliegue(actualizado);
          if (enviado) {
            await db.marcarComoSincronizado(actualizado.id!);
            _mostrarSnack("Llegada registrada y sincronizada correctamente.");
          } else {
            _mostrarSnack(
              "Error al enviar al servidor. Guardado localmente.",
              error: true,
            );
          }
        } else {
          _mostrarSnack(
            "Sin conexión a internet. Guardado localmente.",
            error: true,
          );
        }
      } else {
        _mostrarSnack("Llegada registrada localmente.");
      }

      _observacionesController.clear();
    } catch (e) {
      _mostrarSnack("Error al registrar llegada: $e", error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Llegada"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de sección
              const Text(
                'Despliegue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              // Indicador de llegada
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Llegó a destino',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Campo de observaciones
              const Text(
                'Observaciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Ingrese observaciones adicionales...",
                  contentPadding: EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Información de coordenadas
              Container(
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
                            size: 18, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Información de registro:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
              ),
              const SizedBox(height: 24),

              // Switch de sincronización
              Container(
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
                          'Sincronizar con servidor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _switchValue ? 'Enviar ahora' : 'Guardar localmente',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _switchValue,
                      onChanged: (value) =>
                          setState(() => _switchValue = value),
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botón de registrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _registrarLlegada,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.flag),
                  label: Text(
                    _isLoading ? 'Procesando...' : 'Registrar llegada',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
    _observacionesController.dispose();
    super.dispose();
  }
}