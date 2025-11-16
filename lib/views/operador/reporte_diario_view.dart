// lib/views/operador/reporte_diario_view.dart (ACTUALIZADO)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/reporte_sync_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

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
  final TextEditingController _rTotalController = TextEditingController();
  final TextEditingController _cInicialiController = TextEditingController();
  final TextEditingController _cFinalController = TextEditingController();
  final TextEditingController _cTotalController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _incidenciasController = TextEditingController();
  final TextEditingController _rTotal = TextEditingController();
  final TextEditingController _cTotal = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();

  late ReporteSyncService _syncService;
  late User? _userData;
  late String _accessToken;

  int diferenciaR = 0;
  int diferenciaC = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _syncService = context.read<ReporteSyncService>();
    _fechaController.text = DateTime.now().toString().split('.')[0];
  }

  Future<void> _loadUserData() async {
    _userData = await AuthService().getCurrentUser();

    if (_userData != null && _userData!.operador != null) {
      setState(() {
        // Usar los nombres correctos del modelo
        final operador = _userData!.operador!;
        _transmitidoController.text = operador.idOperador.toString() ?? '';
        _codigoEstacionController.text = 'Estación: ${operador.nroEstacion ?? 'N/A'}';
      });
    }
  }

  @override
  void dispose() {
    _codigoEstacionController.dispose();
    _transmitidoController.dispose();
    _rInicialiController.dispose();
    _rFinalController.dispose();
    _cInicialiController.dispose();
    _cFinalController.dispose();
    _observacionesController.dispose();
    _incidenciasController.dispose();
    _rTotal.dispose();
    _cTotal.dispose();
    _fechaController.dispose();
    super.dispose();
  }

  void _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (_userData?.operador == null) {
        throw Exception('Datos de operador no disponibles');
      }

      final reporteData = {
        'fecha_reporte': _fechaController.text,
        'contador_inicial_c': _cInicialiController.text,
        'contador_final_c': _cFinalController.text,
        'registro_c': diferenciaC,
        'contador_inicial_r': _rInicialiController.text,
        'contador_final_r': _rFinalController.text,
        'registro_r': diferenciaR,
        'incidencias': _incidenciasController.text,
        'observaciones': _observacionesController.text,
        'operador': _userData!.operador!.idOperador,
        'estacion': _userData!.operador!.idEstacion,
        'estado': 'TRANSMITIDO',
        'sincronizar': true,
      };

      final result = await _syncService.saveReporte(reporteData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      if (result['success']) {
        _cleanFormulario();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _cleanFormulario() {
    setState(() {
      _rInicialiController.clear();
      _rFinalController.clear();
      _cInicialiController.clear();
      _cFinalController.clear();
      _observacionesController.clear();
      _incidenciasController.clear();
      _cTotal.clear();
      _rTotal.clear();
      _fechaController.text = DateTime.now().toString().split('.')[0];
      diferenciaC = 0;
      diferenciaR = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulario limpiado'),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _calcularDiferencia() {
    // Para R (recepción)
    final rInicial = int.tryParse(_rInicialiController.text);
    final rFinal = int.tryParse(_rFinalController.text);

    if (rInicial != null && rFinal != null) {
      if (rFinal >= rInicial) {
        setState(() {
          diferenciaR = (rFinal - rInicial) + 1;
          _rTotal.text = diferenciaR.toString();
        });
      } else {
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

    // Para C (cantidad)
    final cInicial = int.tryParse(_cInicialiController.text);
    final cFinal = int.tryParse(_cFinalController.text);

    if (cInicial != null && cFinal != null) {
      if (cFinal >= cInicial) {
        setState(() {
          diferenciaC = (cFinal - cInicial) + 1;
          _cTotal.text = diferenciaC.toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Diario'),
        backgroundColor: Colors.blue[700],
      ),
      body: StreamBuilder<SyncStatus>(
        stream: _syncService.syncStatusStream,
        builder: (context, syncSnapshot) {
          final syncStatus = syncSnapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de estado de sincronización
                if (syncStatus != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: syncStatus.offlineMode
                          ? Colors.orange.shade100
                          : (syncStatus.success
                          ? Colors.green.shade100
                          : Colors.red.shade100),
                      border: Border.all(
                        color: syncStatus.offlineMode
                            ? Colors.orange
                            : (syncStatus.success ? Colors.green : Colors.red),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (syncStatus.isSyncing)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            syncStatus.success ? Icons.check_circle : Icons.info,
                            color: syncStatus.offlineMode
                                ? Colors.orange
                                : (syncStatus.success ? Colors.green : Colors.red),
                          ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            syncStatus.message,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha
                      TextFormField(
                        controller: _fechaController,
                        decoration: InputDecoration(
                          labelText: 'Fecha Reporte',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      // Código Estación (autocompletado)
                      TextFormField(
                        controller: _codigoEstacionController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Estación',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          helperText: 'Se carga del perfil automáticamente',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Número de Estación (oculto pero enviado)
                      TextFormField(
                        controller: _transmitidoController,
                        decoration: InputDecoration(
                          labelText: 'Número Estación',
                          hintText: '10638',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        enabled: false,
                        validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 24),

                      // Sección R (Recepción)
                      const Text(
                        'Registros Recepción',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              onChanged: (_) => _calcularDiferencia(),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              onChanged: (_) => _calcularDiferencia(),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              controller: _rTotal,
                              decoration: InputDecoration(
                                labelText: 'Registros R',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sección C (Cantidad)
                      const Text(
                        'Registros Combustible',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calcularDiferencia(),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4)
                              ],
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              validator: (value) =>
                              value?.isEmpty ?? true ? 'Requerido' : null,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => _calcularDiferencia(),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4)
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cTotal,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Registros C',
                                hintText: '10',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // // Incidencias
                      // TextFormField(
                      //   controller: _incidenciasController,
                      //   maxLines: 3,
                      //   decoration: InputDecoration(
                      //     labelText: 'Incidencias',
                      //     hintText: 'Ingrese incidencias si las hay...',
                      //     border: OutlineInputBorder(
                      //       borderRadius: BorderRadius.circular(8),
                      //     ),
                      //     contentPadding: const EdgeInsets.all(12),
                      //   ),
                      // ),
                      // const SizedBox(height: 16),

                      // Observaciones
                      TextFormField(
                        controller: _observacionesController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Observaciones',
                          hintText: 'Ingrese sus observaciones aquí...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Botones
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _enviarReporte,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                                    : const Text(
                                  'Registrar Reporte',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _cleanFormulario,
                                style: OutlinedButton.styleFrom(
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}