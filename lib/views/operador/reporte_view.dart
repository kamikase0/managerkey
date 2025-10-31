import 'package:flutter/material.dart';

class ReporteDiarioView extends StatefulWidget {
  const ReporteDiarioView({Key? key}) : super(key: key);

  @override
  State<ReporteDiarioView> createState() => _ReporteDiarioViewState();
}

class _ReporteDiarioViewState extends State<ReporteDiarioView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _codigoEstacionController = TextEditingController();
  final TextEditingController _transmitidoController = TextEditingController();
  final TextEditingController _rInicialiController = TextEditingController();
  final TextEditingController _rFinalController = TextEditingController();
  final TextEditingController _cInicialiController = TextEditingController();
  final TextEditingController _cFinalController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  @override
  void dispose() {
    _codigoEstacionController.dispose();
    _transmitidoController.dispose();
    _rInicialiController.dispose();
    _rFinalController.dispose();
    _cInicialiController.dispose();
    _cFinalController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _mostrarMensajeExito(Map<String, String> datos) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reporte Registrado Exitosamente',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Código: ${datos['codigo']}'),
            Text('Transmitido: ${datos['transmitido']}'),
            Text('R Inicial: ${datos['rInicial']} - Final: ${datos['rFinal']}'),
            Text('C Inicial: ${datos['cInicial']} - Final: ${datos['cFinal']}'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _enviarReporte() {
    if (_formKey.currentState!.validate()) {
      final datos = {
        'codigo': _codigoEstacionController.text,
        'transmitido': _transmitidoController.text,
        'rInicial': _rInicialiController.text,
        'rFinal': _rFinalController.text,
        'cInicial': _cInicialiController.text,
        'cFinal': _cFinalController.text,
        'observaciones': _observacionesController.text,
      };

      _mostrarMensajeExito(datos);

      // Aquí puedes agregar la lógica para enviar los datos al servidor
      print('Datos enviados: $datos');

      // Limpiar formulario después de 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _codigoEstacionController.clear();
          _transmitidoController.clear();
          _rInicialiController.clear();
          _rFinalController.clear();
          _cInicialiController.clear();
          _cFinalController.clear();
          _observacionesController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Diario'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Código Estación
              TextFormField(
                controller: _codigoEstacionController,
                decoration: InputDecoration(
                  labelText: 'Código Estación',
                  hintText: 'BIOM-030',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El código es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Transmitido
              TextFormField(
                controller: _transmitidoController,
                decoration: InputDecoration(
                  labelText: 'TRANSMITIDO',
                  hintText: '12:34',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El horario es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Sección R (Recepción)
              const Text(
                'R:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rInicialiController,
                      decoration: InputDecoration(
                        labelText: 'Inicial',
                        hintText: '02',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rFinalController,
                      decoration: InputDecoration(
                        labelText: 'Final',
                        hintText: '03',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sección C (Cantidad)
              const Text(
                'C:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cInicialiController,
                      decoration: InputDecoration(
                        labelText: 'Inicial',
                        hintText: '04',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cFinalController,
                      decoration: InputDecoration(
                        labelText: 'Final',
                        hintText: '05',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requerido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Observaciones
              const Text(
                'Observaciones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _observacionesController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Ingrese sus observaciones aquí...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 32),

              // Botón Registrar
              Center(
                child: ElevatedButton(
                  onPressed: _enviarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Registrar Llegada',
                    style: TextStyle(
                      color: Colors.white,
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
}