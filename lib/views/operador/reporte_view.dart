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
  final TextEditingController _rTotal = TextEditingController();
  final TextEditingController _cTotal = TextEditingController();

  double diferenciaR = 0;
  double diferenciaC = 0;

  @override
  void dispose() {
    _codigoEstacionController.dispose();
    _transmitidoController.dispose();
    _rInicialiController.dispose();
    _rFinalController.dispose();
    _cInicialiController.dispose();
    _cFinalController.dispose();
    _observacionesController.dispose();
    _rTotal.dispose();
    _cTotal.dispose();
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
        // if (mounted) {
        //   _codigoEstacionController.clear();
        //   _transmitidoController.clear();
        //   _transmitidoController.clear();
        //   _rInicialiController.clear();
        //   _rFinalController.clear();
        //   _cInicialiController.clear();
        //   _cFinalController.clear();
        //   _observacionesController.clear();
        //   _cTotal.clear();
        //   _rTotal.clear();
        // }
        // }
      });
    }
  }

  void _cleanFormulario(){
    setState(() {
      _codigoEstacionController.clear();
      _transmitidoController.clear();
      _rInicialiController.clear();
      _rFinalController.clear();
      _cInicialiController.clear();
      _cFinalController.clear();
      _observacionesController.clear();
      _cTotal.clear();
      _rTotal.clear();
      // diferenciaC = null;
      // diferenciaR = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulario limpiado'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      )
    );
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
                  hintText: '12345',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El codigo de transmision es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Sección R (Recepción)
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rInicialiController,
                      decoration: InputDecoration(
                        labelText: 'R Inicial',
                        hintText: '2',
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
                      onChanged: (_) => _calcularDiferencia(),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rFinalController,
                      decoration: InputDecoration(
                        labelText: 'R Final',
                        hintText: '32',
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
                      onChanged: (_) => _calcularDiferencia(),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      controller: _rTotal,
                      decoration: InputDecoration(
                        labelText: 'Registros R',
                        hintText: diferenciaR!.toString() ?? '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (_) => null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sección C (Cantidad)
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cInicialiController,
                      decoration: InputDecoration(
                        labelText: 'C Inicial',
                        hintText: '4',
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
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calcularDiferencia(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cFinalController,
                      decoration: InputDecoration(
                        labelText: 'C Final',
                        hintText: '8',
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
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calcularDiferencia(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cTotal,
                      decoration: InputDecoration(
                        labelText: 'registros C',
                        hintText: '10',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (value) => null,
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
                child: Column(
                  children: [
                    ElevatedButton(
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
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _cleanFormulario,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Limpiar Campos',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


    // final TextEditingController _inicialController = TextEditingController();
    // final TextEditingController _finalController = TextEditingController();

    String _mensajeError = '';
    double? _diferencia;

    void _calcularDiferencia() {
      // --- Para R (recepción) ---
      final rInicial = int.tryParse(_rInicialiController.text);
      final rFinal = int.tryParse(_rFinalController.text);

      if (rInicial != null && rFinal != null) {
        if (rFinal >= rInicial) {
          setState(() {
            diferenciaR = (rFinal - rInicial) + 1;
            _rTotal.text = diferenciaR!.toString();
          });
        } else {
          // si final < inicial, limpia y muestra error
          setState(() {
            _rTotal.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El valor final de R debe ser mayor o igual que el inicial'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          });
        }
      }

      // --- Para C (cantidad) ---
      final cInicial = int.tryParse(_cInicialiController.text);
      final cFinal = int.tryParse(_cFinalController.text);

      if (cInicial != null && cFinal != null) {
        if (cFinal >= cInicial) {
          setState(() {
            diferenciaC = (cFinal - cInicial) + 1;
            _cTotal.text = diferenciaC!.toString();
          });
        } else {
          setState(() {
            _cTotal.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El valor final de C debe ser mayor o igual que el inicial'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
      }
    }

}