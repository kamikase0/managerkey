import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:manager_key/services/punto_empadronamiento_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../../models/punto_empadronamiento_model.dart';
import '../../services/api_service.dart';
import '../../services/reporte_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';
import '../../utils/alert_helper.dart';

class ReporteDiarioView extends StatefulWidget {
  const ReporteDiarioView({Key? key}) : super(key: key);

  @override
  State<ReporteDiarioView> createState() => _ReporteDiarioViewState();
}

class _ReporteDiarioViewState extends State<ReporteDiarioView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _codigoEstacionController =
      TextEditingController();
  final TextEditingController _transmitidoController = TextEditingController();
  final TextEditingController _rInicialiController = TextEditingController();
  final TextEditingController _rFinalController = TextEditingController();
  final TextEditingController _rTotalController = TextEditingController();
  final TextEditingController _rObservacionesController =
      TextEditingController();
  final TextEditingController _rSaltosController = TextEditingController();

  final TextEditingController _cInicialiController = TextEditingController();
  final TextEditingController _cFinalController = TextEditingController();
  final TextEditingController _cTotalController = TextEditingController();
  final TextEditingController _cObservacionesController =
      TextEditingController();
  final TextEditingController _cSaltosController = TextEditingController();

  final TextEditingController _observacionesController =
      TextEditingController();
  final TextEditingController _incidenciasController = TextEditingController();
  final TextEditingController _rTotal = TextEditingController();
  final TextEditingController _cTotal = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();

  // Controladores para los dígitos finales (el último número del formato)
  final TextEditingController _rInicialDigitoFinalController =
      TextEditingController();
  final TextEditingController _rFinalDigitoFinalController =
      TextEditingController();
  final TextEditingController _cInicialDigitoFinalController =
      TextEditingController();
  final TextEditingController _cFinalDigitoFinalController =
      TextEditingController();

  late ReporteSyncService _syncService;
  late User? _userData;
  String _equipoId = '00000';

  int diferenciaR = 0;
  int diferenciaC = 0;
  bool _isSubmitting = false;

  // Variables para geolocalización
  String? _latitud;
  String? _longitud;
  bool _locationCaptured = false;
  String _coordenadas = 'No capturadas';
  bool _gpsActivado = false;
  bool _ubicacionRequerida = true;
  bool _locationLoading = false;

  //variables para registro de municio Punto de empadronamiento
  String? _provinciaSeleccionada;
  String? _puntoEmpadronamientoSeleccionado;
  List<String> _provincias = [];
  List<String> _puntosEmpadronamiento = [];
  bool _cargadoProvincias = false;
  int? _puntoEmpadronamientoId;
  final PuntoEmpadronamientoService _puntoService =
      PuntoEmpadronamientoService();

  //Habilitacion o deshababilitacion de campos
  bool _camposR = false;
  bool _camposC = false;

  @override
  void initState() {
    super.initState();
    _syncService = context.read<ReporteSyncService>();
    _fechaController.text = DateTime.now().toString().split('.')[0];

    // Inicializar dígitos finales con valor por defecto
    _rInicialDigitoFinalController.text = '';
    _rFinalDigitoFinalController.text = '';
    _cInicialDigitoFinalController.text = '';
    _cFinalDigitoFinalController.text = '';

    _initializeApp();
    _cargarDatosEmpadronamiento();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadUserData();
      await _verificarEstadoGPS();
      _iniciarMonitorGPS();
    } catch (e) {
      print('❌ Error en inicialización: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      _userData = await AuthService().getCurrentUser();

      if (_userData != null && _userData!.operador != null) {
        setState(() {
          final operador = _userData!.operador!;
          _transmitidoController.text = operador.idOperador.toString();
          _codigoEstacionController.text =
              'Estación: ${operador.nroEstacion ?? 'N/A'}';

          // ✅ CORREGIDO: Usar nro_estacion en lugar de id_operador
          _equipoId = (operador.nroEstacion ?? '0').toString().padLeft(5, '0');
          print('📱 Número de Estación configurado: $_equipoId');
        });
      }
    } catch (e) {
      print('❌ Error cargando datos de usuario: $e');
    }
  }

  String _buildFormatoR(String cuatroDigitos, String digitoFinal) {
    return 'R-$_equipoId-${cuatroDigitos.padLeft(4, '0')}-$digitoFinal';
  }

  String _buildFormatoC(String cuatroDigitos, String digitoFinal) {
    return 'C-$_equipoId-${cuatroDigitos.padLeft(4, '0')}-$digitoFinal';
  }

  void _validarRegistroR(
    String valor,
    TextEditingController controller,
    TextEditingController digitoFinalController,
    bool esInicial,
  ) {
    String limpio = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (limpio.length > 4) {
      limpio = limpio.substring(0, 4);
    }

    if (limpio != valor) {
      controller.text = limpio;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: limpio.length),
      );
    }

    final formatoCompleto = _buildFormatoR(limpio, digitoFinalController.text);
    print(
      '📝 R ${esInicial ? 'Inicial' : 'Final'} formateado: $formatoCompleto',
    );

    _calcularDiferencia();
  }

  void _validarRegistroC(
    String valor,
    TextEditingController controller,
    TextEditingController digitoFinalController,
    bool esInicial,
  ) {
    String limpio = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (limpio.length > 4) {
      limpio = limpio.substring(0, 4);
    }

    if (limpio != valor) {
      controller.text = limpio;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: limpio.length),
      );
    }

    final formatoCompleto = _buildFormatoC(limpio, digitoFinalController.text);
    print(
      '📝 C ${esInicial ? 'Inicial' : 'Final'} formateado: $formatoCompleto',
    );

    _calcularDiferencia();
  }

  void _validarDigitoFinal(
    String valor,
    TextEditingController controller,
    TextEditingController cuatroDigitosController,
    bool esR,
    bool esInicial,
  ) {
    String limpio = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (limpio.length > 1) {
      limpio = limpio.substring(0, 1);
    }

    if (limpio != valor) {
      controller.text = limpio;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: limpio.length),
      );
    }

    if (esR) {
      _validarRegistroR(
        cuatroDigitosController.text,
        cuatroDigitosController,
        controller,
        esInicial,
      );
    } else {
      _validarRegistroC(
        cuatroDigitosController.text,
        cuatroDigitosController,
        controller,
        esInicial,
      );
    }
  }

  void _calcularDiferencia() {
    // 1. Obtener los textos de los controladores iniciales y finales
    final rInicialStr = _rInicialiController.text;
    final rFinalStr = _rFinalController.text;
    final cInicialStr = _cInicialiController.text;
    final cFinalStr = _cFinalController.text;

    // --- VALIDACIÓN Y CÁLCULO PARA 'R' (Recepción) ---
    if (rInicialStr.isNotEmpty && rFinalStr.isNotEmpty) {
      final rInicial = int.tryParse(rInicialStr) ?? 0;
      final rFinal = int.tryParse(rFinalStr) ?? 0;

      if (rFinal >= rInicial) {
        final rSaltos = _rSaltosController.text;
        final rsaltosValor = int.tryParse(rSaltos) ?? 0;

        setState(() {
          diferenciaR = ((rFinal - rInicial) - rsaltosValor) + 1;
          _rTotal.text = diferenciaR.toString();
        });
      } else {
        setState(() {
          _rTotal.clear();
        });
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(
        //       content: Text(
        //         'El valor final de R debe ser mayor o igual que el inicial',
        //       ),
        //       backgroundColor: Colors.red,
        //       duration: Duration(seconds: 3),
        //     ),
        //   );
        // }
      }
    } else {
      setState(() {
        _rTotal.clear();
      });
    }

    // --- VALIDACIÓN Y CÁLCULO PARA 'C' (Combustible) ---
    if (cInicialStr.isNotEmpty && cFinalStr.isNotEmpty) {
      final cInicial = int.tryParse(cInicialStr) ?? 0;
      final cFinal = int.tryParse(cFinalStr) ?? 0;

      if (cFinal >= cInicial) {
        final cSaltos = _cSaltosController.text;
        final csaltosValor = int.tryParse(cSaltos) ?? 0;

        setState(() {
          diferenciaC = ((cFinal - cInicial) - csaltosValor + 1);
          _cTotal.text = diferenciaC.toString();
        });
      } else {
        setState(() {
          _cTotal.clear();
        });
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(
        //       content: Text(
        //         'El valor final de C debe ser mayor o igual que el inicial',
        //       ),
        //       backgroundColor: Colors.red,
        //       duration: Duration(seconds: 4),
        //     ),
        //   );
        // }
      }
    } else {
      setState(() {
        _cTotal.clear();
      });
    }
  }

  // void _enviarReporte() async {
  //   if (!_formKey.currentState!.validate()) return;
  //
  //   if (!_gpsActivado && _ubicacionRequerida) {
  //     _mostrarDialogoActivacionGPS();
  //     return;
  //   }
  //
  //   // ✅ NUEVA VALIDACIÓN: Validar rangos de R y C antes de enviar
  //   if (_camposR) {
  //     final rInicial = int.tryParse(_rInicialiController.text) ?? 0;
  //     final rFinal = int.tryParse(_rFinalController.text) ?? 0;
  //     if (rFinal < rInicial) {
  //       await _mostrarAlertaError(
  //           'El valor final de R no puede ser menor que el valor inicial.');
  //       return;
  //     }
  //   }
  //
  //   if (_camposC) {
  //     final cInicial = int.tryParse(_cInicialiController.text) ?? 0;
  //     final cFinal = int.tryParse(_cFinalController.text) ?? 0;
  //     if (cFinal < cInicial) {
  //       await _mostrarAlertaError(
  //           'El valor final de C no puede ser menor que el valor inicial.');
  //       return;
  //     }
  //   }
  //
  //   setState(() => _isSubmitting = true);
  //
  //   try {
  //     if (_userData?.operador == null) {
  //       throw Exception('Datos de operador no disponibles');
  //     }
  //
  //     bool ubicacionCapturada = false;
  //     if (_gpsActivado && _ubicacionRequerida) {
  //       ubicacionCapturada = await _capturarGeolocalizacionAlEnviar();
  //     }
  //
  //     final ahora = DateTime.now();
  //     final fechaHora = ahora.toIso8601String();
  //
  //     // --- Lógica condicional para 'R' ---
  //     String rInicialCompleto;
  //     String rFinalCompleto;
  //     int registroR;
  //
  //     if (!_camposR) {
  //       print('ℹ️ Campos R deshabilitados. Enviando valores en cero.');
  //       rInicialCompleto = _buildFormatoR('0000', '0');
  //       rFinalCompleto = _buildFormatoR('0000', '0');
  //       registroR = 0;
  //     } else {
  //       rInicialCompleto = _buildFormatoR(
  //         _rInicialiController.text.padLeft(4, '0'),
  //         _rInicialDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _rInicialDigitoFinalController.text,
  //       );
  //
  //       rFinalCompleto = _buildFormatoR(
  //         _rFinalController.text.padLeft(4, '0'),
  //         _rFinalDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _rFinalDigitoFinalController.text,
  //       );
  //       registroR = diferenciaR;
  //     }
  //
  //     // --- Lógica condicional para 'C' ---
  //     String cInicialCompleto;
  //     String cFinalCompleto;
  //     int registroC;
  //
  //     if (!_camposC) {
  //       print('ℹ️ Campos C deshabilitados. Enviando valores en cero.');
  //       cInicialCompleto = _buildFormatoC('0000', '0');
  //       cFinalCompleto = _buildFormatoC('0000', '0');
  //       registroC = 0;
  //     } else {
  //       cInicialCompleto = _buildFormatoC(
  //         _cInicialiController.text.padLeft(4, '0'),
  //         _cInicialDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _cInicialDigitoFinalController.text,
  //       );
  //       cFinalCompleto = _buildFormatoC(
  //         _cFinalController.text.padLeft(4, '0'),
  //         _cFinalDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _cFinalDigitoFinalController.text,
  //       );
  //       registroC = diferenciaC;
  //     }
  //
  //     final reporteData = {
  //       'fecha_reporte': _fechaController.text,
  //       'contador_inicial_c': cInicialCompleto,
  //       'contador_final_c': cFinalCompleto,
  //       'registro_c': registroC,
  //       'contador_inicial_r': rInicialCompleto,
  //       'contador_final_r': rFinalCompleto,
  //       'registro_r': registroR,
  //       'incidencias': _incidenciasController.text,
  //       'observaciones': _observacionesController.text,
  //       'operador': _userData!.operador!.idOperador,
  //       'estacion': _userData!.operador!.idEstacion,
  //       'centro_empadronamiento': _puntoEmpadronamientoId,
  //       'estado': 'ENVIO REPORTE',
  //       'sincronizar': true,
  //
  //       // ✅ CORREGIDO: Usar nombres consistentes
  //       'observacionC': _cObservacionesController.text,
  //       'observacionR': _rObservacionesController.text,
  //       'saltosenC': int.tryParse(_cSaltosController.text) ?? 0,
  //       'saltosenR': int.tryParse(_rSaltosController.text) ??
  //           0, // ✅ CORREGIDO: usar _rSaltosController
  //     };
  //
  //     final despliegueData = {
  //       'destino':
  //       'REPORTE DIARIO - ${_userData!.operador!.nroEstacion ?? "Estación"}',
  //       'latitud': _latitud ?? (_ubicacionRequerida ? '0.0' : null),
  //       'longitud': _longitud ?? (_ubicacionRequerida ? '0.0' : null),
  //       'descripcion_reporte': null,
  //       'estado': 'REPORTE ENVIADO',
  //       'sincronizar': true,
  //       'observaciones':
  //       'Reporte diario: ${_observacionesController.text.isNotEmpty ? _observacionesController.text : "Sin observaciones"}',
  //       'incidencias': _ubicacionRequerida
  //           ? (ubicacionCapturada
  //           ? 'Ubicación capturada correctamente'
  //           : 'No se pudo capturar ubicación')
  //           : 'Ubicación no requerida para este reporte',
  //       'fecha_hora': fechaHora,
  //       'operador': _userData!.operador!.idOperador,
  //       'sincronizado': false,
  //     };
  //
  //     print('📤 Enviando reporte con formatos:');
  //     print('📍 R Inicial: $rInicialCompleto');
  //     print('📍 R Final: $rFinalCompleto');
  //     print('📍 Registro R: $registroR');
  //     print('📍 C Inicial: $cInicialCompleto');
  //     print('📍 C Final: $cFinalCompleto');
  //     print('📍 Registro C: $registroC');
  //     print('📍 Punto Empadronamiento ID: $_puntoEmpadronamientoId');
  //
  //     final result = await _syncService.saveReporteGeolocalizacion(
  //       reporteData: reporteData,
  //       despliegueData: despliegueData,
  //     );
  //
  //     if (!mounted) return;
  //
  //     // ✅ NUEVO: Mostrar alerta de confirmación
  //     await _mostrarAlertaResultado(
  //       exito: result['success'],
  //       guardadoLocal: result['saved_locally'] == true,
  //       ubicacionCapturada: ubicacionCapturada,
  //       ubicacionRequerida: _ubicacionRequerida,
  //       mensaje: result['message'],
  //     );
  //
  //     if (result['success']) {
  //       _cleanFormulario();
  //       setState(() {
  //         _latitud = null;
  //         _longitud = null;
  //         _coordenadas = 'No capturadas';
  //         _locationCaptured = false;
  //         _ubicacionRequerida = true;
  //         _camposR = false;
  //         _camposC = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //
  //     // ✅ NUEVO: Mostrar alerta de error
  //     await _mostrarAlertaError('Error al enviar reporte: $e');
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isSubmitting = false);
  //     }
  //   }
  // }

  Widget _buildCamposEmpadronamiento() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UBICACIÓN DE EMPADRONAMIENTO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 16),
            _buildProvinciaDropdown(),
            const SizedBox(height: 12),
            _buildPuntoEmpadronamientoDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoConFormatoCompleto({
    required String label,
    required TextEditingController controller4Digitos,
    required TextEditingController controllerDigitoFinal,
    required bool esR,
    required bool esInicial,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  '${esR ? 'R' : 'C'}-$_equipoId-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller4Digitos,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '0000',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  onChanged: (valor) => esR
                      ? _validarRegistroR(
                          valor,
                          controller4Digitos,
                          controllerDigitoFinal,
                          esInicial,
                        )
                      : _validarRegistroC(
                          valor,
                          controller4Digitos,
                          controllerDigitoFinal,
                          esInicial,
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: const Text('-', style: TextStyle(fontSize: 14)),
              ),
              SizedBox(
                width: 60,
                child: TextFormField(
                  controller: controllerDigitoFinal,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  onChanged: (valor) {
                    _validarDigitoFinal(
                      valor,
                      controllerDigitoFinal,
                      controller4Digitos,
                      esR,
                      esInicial,
                    );
                    final formatoCompleto = esR
                        ? _buildFormatoR(
                            controller4Digitos.text.padLeft(4, '0'),
                            valor.isEmpty ? '0' : valor,
                          )
                        : _buildFormatoC(
                            controller4Digitos.text.padLeft(4, '0'),
                            valor.isEmpty ? '0' : valor,
                          );
                    print(
                      '🎯 ${esR ? 'R' : 'C'} ${esInicial ? 'Inicial' : 'Final'}: $formatoCompleto',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Formato: ${esR ? 'R' : 'C'}-$_equipoId-xxxx-N',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Diario'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _gpsActivado ? Icons.location_on : Icons.location_off,
              color: _gpsActivado ? Colors.green : Colors.red,
            ),
            onPressed: _verificarEstadoGPS,
            tooltip: _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
          ),
        ],
      ),
      body: StreamBuilder<SyncStatus>(
        stream: _syncService.syncStatusStream,
        builder: (context, syncSnapshot) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner de estado GPS
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _gpsActivado
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    border: Border.all(
                      color: _gpsActivado ? Colors.green : Colors.orange,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _gpsActivado ? Icons.location_on : Icons.location_off,
                        color: _gpsActivado ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _gpsActivado
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _gpsActivado
                                  ? 'Ubicación disponible para el reporte'
                                  : 'Active el GPS para capturar ubicación',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!_gpsActivado)
                        TextButton(
                          onPressed: _abrirConfiguracionGPS,
                          child: Text(
                            'ACTIVAR',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
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
                      // INFORMACIÓN GENERAL
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'INFORMACIÓN GENERAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _fechaController,
                                decoration: InputDecoration(
                                  labelText: 'Fecha Reporte',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                validator: (value) => value?.isEmpty ?? true
                                    ? 'Campo requerido'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _codigoEstacionController,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Estación',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _transmitidoController,
                                decoration: InputDecoration(
                                  labelText: 'ID Operador',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                enabled: false,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // CAMPOS DE EMPADRONAMIENTO
                      _buildCamposEmpadronamiento(),

                      const SizedBox(height: 20),

                      // ✅ SECCIÓN REGISTROS NUEVOS (R)
                      ExpansionTile(
                        key: Key('panel_r_${_camposR.toString()}'),
                        maintainState: true,
                        title: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!_camposR) {
                              AlertHelper.showConfirmRegistrarR(
                                context: context,
                                onConfirm: () {
                                  setState(() {
                                    _camposR = true;
                                  });
                                },
                              );
                            } else {
                              // ✅ MEJORA: Mostrar confirmación al desactivar también
                              _mostrarConfirmacionDesactivarR();
                            }
                          },
                          child: Text(
                            'REGISTROS NUEVOS (R) ${_camposR ? '(Activado)' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _camposR
                                  ? Colors.blue
                                  : Colors.blue.withOpacity(0.7),
                            ),
                          ),
                        ),
                        leading: Icon(
                          Icons.receipt,
                          color: _camposR
                              ? Colors.blue
                              : Colors.blue.withOpacity(0.7),
                        ),
                        initiallyExpanded: _camposR,
                        onExpansionChanged: (bool isExpanding) {
                          if (isExpanding && !_camposR) {
                            // Si intenta expandir sin haber activado, mostrar confirmación
                            AlertHelper.showConfirmRegistrarR(
                              context: context,
                              onConfirm: () {
                                setState(() {
                                  _camposR = true;
                                });
                              },
                            );
                          } else if (!isExpanding && _camposR) {
                            // Si intenta colapsar estando activado, mostrar confirmación
                            _mostrarConfirmacionDesactivarR();
                          }
                        },
                        collapsedBackgroundColor: _camposR
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        backgroundColor: _camposR
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCampoConFormatoCompleto(
                                  label: 'R Inicial',
                                  controller4Digitos: _rInicialiController,
                                  controllerDigitoFinal:
                                      _rInicialDigitoFinalController,
                                  esR: true,
                                  esInicial: true,
                                ),
                                const SizedBox(height: 12),
                                _buildCampoConFormatoCompleto(
                                  label: 'R Final',
                                  controller4Digitos: _rFinalController,
                                  controllerDigitoFinal:
                                      _rFinalDigitoFinalController,
                                  esR: true,
                                  esInicial: false,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _rSaltosController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Saltos en registro R (Opcional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (valor) {
                                    _calcularDiferencia();
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  readOnly: true,
                                  controller: _rTotal,
                                  decoration: InputDecoration(
                                    labelText: 'TOTAL REGISTROS R',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Colors.blue.shade50,
                                    prefixIcon: const Icon(
                                      Icons.house,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _rObservacionesController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Observacion R (Opcional)',
                                    hintText:
                                        'Ingrese observaciones de registro R...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ✅ SECCIÓN REGISTROS CAMBIO DE DOMICILIO (C) - CORREGIDO
                      ExpansionTile(
                        key: Key('panel_c_${_camposC.toString()}'),
                        maintainState: true,
                        title: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!_camposC) {
                              AlertHelper.showConfirmRegistrarC(
                                context: context,
                                onConfirm: () {
                                  setState(() {
                                    _camposC = true;
                                  });
                                },
                              );
                            } else {
                              // ✅ MEJORA: Mostrar confirmación al desactivar también
                              _mostrarConfirmacionDesactivarC();
                            }
                          },
                          child: Text(
                            'REGISTROS CAMBIO DE DOMICILIO (C) ${_camposC ? '(Activado)' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _camposC
                                  ? Colors.orange
                                  : Colors.orange.withOpacity(0.7),
                            ),
                          ),
                        ),
                        leading: Icon(
                          Icons.home_work,
                          color: _camposC
                              ? Colors.orange
                              : Colors.orange.withOpacity(0.7),
                        ),
                        initiallyExpanded: _camposC,
                        onExpansionChanged: (bool isExpanding) {
                          if (isExpanding && !_camposC) {
                            // Si intenta expandir sin haber activado, mostrar confirmación
                            AlertHelper.showConfirmRegistrarC(
                              context: context,
                              onConfirm: () {
                                setState(() {
                                  _camposC = true;
                                });
                              },
                            );
                          } else if (!isExpanding && _camposC) {
                            // Si intenta colapsar estando activado, mostrar confirmación
                            _mostrarConfirmacionDesactivarC();
                          }
                        },
                        collapsedBackgroundColor: _camposC
                            ? Colors.orange.shade50
                            : Colors.grey.shade100,
                        backgroundColor: _camposC
                            ? Colors.orange.shade50
                            : Colors.grey.shade100,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCampoConFormatoCompleto(
                                  label: 'C Inicial',
                                  controller4Digitos: _cInicialiController,
                                  controllerDigitoFinal:
                                      _cInicialDigitoFinalController,
                                  esR: false,
                                  esInicial: true,
                                ),
                                const SizedBox(height: 12),
                                _buildCampoConFormatoCompleto(
                                  label: 'C Final',
                                  controller4Digitos: _cFinalController,
                                  controllerDigitoFinal:
                                      _cFinalDigitoFinalController,
                                  esR: false,
                                  esInicial: false,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _cSaltosController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Saltos en registro C (Opcional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (valor) {
                                    _calcularDiferencia();
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  readOnly: true,
                                  controller: _cTotal,
                                  decoration: InputDecoration(
                                    labelText: 'TOTAL REGISTROS C',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Colors.orange.shade50,
                                    prefixIcon: const Icon(
                                      Icons.swap_horiz,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _cObservacionesController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'Observacion C (Opcional)',
                                    hintText:
                                        'Ingrese observaciones de registro C...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // OBSERVACIONES
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'INCIDENCIAS ADICIONALES',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _incidenciasController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Incidencias de Reporte Diario',
                                  hintText: 'Ingrese sus incidente aquí...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // BOTONES DE ACCIÓN
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _enviarReporte,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'ENVIAR REPORTE',
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
                            height: 45,
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _cleanFormulario,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'LIMPIAR FORMULARIO',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 50),
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

  @override
  void dispose() {
    // Dispose de todos los controladores
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
    _cSaltosController.dispose(); // ✅ Añadido dispose faltante
    _rSaltosController.dispose(); // ✅ Añadido dispose faltante
    _rObservacionesController.dispose(); // ✅ Añadido dispose faltante
    _cObservacionesController.dispose(); // ✅ Añadido dispose faltante
    _rTotalController.dispose(); // ✅ Añadido dispose faltante
    _cTotalController.dispose(); // ✅ Añadido dispose faltante

    // Dispose de los nuevos controladores de dígitos finales
    _rInicialDigitoFinalController.dispose();
    _rFinalDigitoFinalController.dispose();
    _cInicialDigitoFinalController.dispose();
    _cFinalDigitoFinalController.dispose();

    super.dispose();
  }

  void _mostrarConfirmacionDesactivarR() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Desactivar Registros R',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          content: const Text(
            '¿Estás seguro de que quieres desactivar los Registros Nuevos (R)?\n\n'
            'Los datos ingresados se perderán.',
            style: TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _camposR = false;
                  _registroRenCero(); // Limpiar campos R
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'DESACTIVAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarConfirmacionDesactivarC() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Desactivar Registros C',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          content: const Text(
            '¿Estás seguro de que quieres desactivar los Registros de Cambio de Domicilio (C)?\n\n'
            'Los datos ingresados se perderán.',
            style: TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.orange.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _camposC = false;
                  _registroCenCero(); // Limpiar campos C
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'DESACTIVAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- MÉTODOS DE GEOLOCALIZACIÓN Y DIÁLOGOS ---
  Future<void> _verificarEstadoGPS() async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _gpsActivado = servicioHabilitado;
        });
      }
      print(
        '📍 Estado GPS: ${servicioHabilitado ? "ACTIVADO" : "DESACTIVADO"}',
      );
    } catch (e) {
      print('❌ Error verificando estado GPS: $e');
      if (mounted) {
        setState(() {
          _gpsActivado = false;
        });
      }
    }
  }

  void _iniciarMonitorGPS() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _verificarEstadoGPS();
        _iniciarMonitorGPS();
      }
    });
  }

  Future<void> _abrirConfiguracionGPS() async {
    try {
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 2));
      await _verificarEstadoGPS();
    } catch (e) {
      print('Error abriendo configuración GPS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la configuración de GPS'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _capturarGeolocalizacionAlEnviar() async {
    setState(() => _locationLoading = true);
    try {
      if (!_gpsActivado) {
        print('⚠️ GPS no activado, no se puede capturar ubicación');
        return false;
      }

      print('📍 Iniciando captura de geolocalización...');
      final position = await LocationService().getCurrentLocation();
      if (position != null) {
        if (mounted) {
          setState(() {
            _latitud = position.latitude.toStringAsFixed(6);
            _longitud = position.longitude.toStringAsFixed(6);
            _coordenadas = 'Lat: $_latitud\nLong: $_longitud';
            _locationCaptured = true;
          });
        }
        print('📍 Geolocalización capturada: $_coordenadas');
        return true;
      } else {
        if (mounted) {
          setState(() {
            _locationCaptured = false;
            _coordenadas = 'Error al capturar ubicación';
          });
        }
        print('⚠️ No se pudo capturar la ubicación');
        return false;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationCaptured = false;
          _coordenadas = 'Error: $e';
        });
      }
      print('❌ Error capturando ubicación: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
    }
  }

  void _mostrarDialogoActivacionGPS() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'GPS Requerido',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Para enviar el reporte con ubicación, necesitas activar el GPS.',
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Qué deseas hacer?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _ubicacionRequerida = false;
                });
                _enviarReporte();
              },
              child: const Text(
                'ENVIAR SIN UBICACIÓN',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _abrirConfiguracionGPS();
              },
              child: const Text(
                'ACTIVAR GPS',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  // --- MÉTODOS DE EMPADRONAMIENTO ---
  Widget _buildProvinciaDropdown() {
    return DropdownButtonFormField<String>(
      value: _provinciaSeleccionada,
      decoration: InputDecoration(
        labelText: 'Provincia/Municipio *',
        hintText: 'Seleccione una provincia',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        prefixIcon: const Icon(Icons.location_city),
      ),
      isExpanded: true,
      items: _provincias.map((String provincia) {
        return DropdownMenuItem<String>(
          value: provincia,
          child: Text(provincia, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (String? nuevaProvincia) {
        _onProvinciaSeleccionada(nuevaProvincia);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Seleccione una provincia';
        }
        return null;
      },
    );
  }

  Widget _buildPuntoEmpadronamientoDropdown() {
    return DropdownButtonFormField<String>(
      value: _puntoEmpadronamientoSeleccionado,
      decoration: InputDecoration(
        labelText: 'Punto de Empadronamiento *',
        hintText: _provinciaSeleccionada != null
            ? (_puntosEmpadronamiento.isEmpty
                  ? 'Cargando puntos...'
                  : 'Seleccione un punto')
            : 'Primero seleccione una provincia',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        prefixIcon: const Icon(Icons.place),
      ),
      isExpanded: true,
      items: _puntosEmpadronamiento.map((String punto) {
        return DropdownMenuItem<String>(
          value: punto,
          child: Text(punto, overflow: TextOverflow.ellipsis, maxLines: 2),
        );
      }).toList(),
      onChanged:
          (_provinciaSeleccionada != null && _puntosEmpadronamiento.isNotEmpty)
          ? (String? nuevoPunto) {
              _onPuntoEmpadronamientoSeleccionado(nuevoPunto);
            }
          : null,
      validator: (value) {
        if (_provinciaSeleccionada != null &&
            (value == null || value.isEmpty)) {
          return 'Seleccione un punto de empadronamiento';
        }
        return null;
      },
    );
  }

  void _onProvinciaSeleccionada(String? provincia) async {
    if (provincia == null) return;

    setState(() {
      _provinciaSeleccionada = provincia;
      _puntoEmpadronamientoSeleccionado = null;
      _puntosEmpadronamiento = [];
      _puntoEmpadronamientoId = null;
    });

    try {
      print('📍 Cargando puntos para provincia: $provincia');
      final puntos = await _puntoService.getPuntosByProvincia(provincia);
      final nombresPuntos = puntos.map((p) => p.puntoEmpadronamiento).toList();
      if (mounted) {
        setState(() {
          _puntosEmpadronamiento = nombresPuntos;
        });
      }
      print('✅ Puntos de empadronamiento cargados: ${puntos.length}');
      print('📌 Puntos: $nombresPuntos');
    } catch (e) {
      print('❌ Error cargando puntos de empadronamiento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar puntos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onPuntoEmpadronamientoSeleccionado(String? punto) async {
    if (punto == null) return;

    setState(() {
      _puntoEmpadronamientoSeleccionado = punto;
    });

    try {
      print('📍 Buscando ID para punto: $punto');
      final puntos = await _puntoService.getPuntosByProvincia(
        _provinciaSeleccionada!,
      );
      final puntoSeleccionado = puntos.firstWhere(
        (p) => p.puntoEmpadronamiento == punto,
        orElse: () => PuntoEmpadronamiento(
          id: 0,
          provincia: '',
          puntoEmpadronamiento: '',
        ),
      );

      if (puntoSeleccionado.id != 0) {
        if (mounted) {
          setState(() {
            _puntoEmpadronamientoId = puntoSeleccionado.id;
          });
        }
        print('✅ Punto de empadronamiento seleccionado:');
        print('   - ID: $_puntoEmpadronamientoId');
        print('   - Nombre: $punto');
      } else {
        print('❌ No se encontró el ID para el punto: $punto');
      }
    } catch (e) {
      print('❌ Error obteniendo ID del punto de empadronamiento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar punto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarDatosEmpadronamiento() async {
    try {
      if (mounted) {
        setState(() {
          _cargadoProvincias = false;
        });
      }
      print('📍 Cargando provincias...');
      final provincias = await _puntoService.getProvinciasFromLocalDatabase();
      if (mounted) {
        setState(() {
          _provincias = provincias;
          _cargadoProvincias = true;
        });
      }
      print('✅ Provincias cargadas: ${_provincias.length}');
      print('📌 Provincias: $_provincias');
    } catch (e) {
      print('❌ Error cargando provincias: $e');
      if (mounted) {
        setState(() {
          _cargadoProvincias = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar provincias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cleanFormulario() {
    _formKey.currentState?.reset();
    setState(() {
      _rInicialiController.clear();
      _rFinalController.clear();
      _cInicialiController.clear();
      _cFinalController.clear();
      _observacionesController.clear();
      _incidenciasController.clear();
      _cTotal.clear();
      _rTotal.clear();
      _cSaltosController.clear();
      _rSaltosController.clear();
      _rObservacionesController.clear();
      _cObservacionesController.clear();

      _rInicialDigitoFinalController.text = '';
      _rFinalDigitoFinalController.text = '';
      _cInicialDigitoFinalController.text = '';
      _cFinalDigitoFinalController.text = '';

      _provinciaSeleccionada = null;
      _puntoEmpadronamientoSeleccionado = null;
      _puntoEmpadronamientoId = null;
      _puntosEmpadronamiento = [];

      _fechaController.text = DateTime.now().toString().split('.')[0];
      diferenciaC = 0;
      diferenciaR = 0;

      _camposR = false;
      _camposC = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formulario limpiado'),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _registroRenCero() {
    setState(() {
      _rInicialiController.clear();
      _rFinalController.clear();
      _rInicialDigitoFinalController.clear();
      _rFinalDigitoFinalController.clear();
      _rSaltosController.clear();
      _rTotal.clear();
      _rObservacionesController.clear();
    });
  }

  void _registroCenCero() {
    setState(() {
      _cInicialiController.clear();
      _cFinalController.clear();
      _cSaltosController.clear();
      _cInicialDigitoFinalController.clear();
      _cFinalDigitoFinalController.clear();
      _cTotal.clear();
      _cObservacionesController.clear();
    });
  }

  // ✅ NUEVO: Función para mostrar alerta de resultado
  // Future<void> _mostrarAlertaResultado({
  //   required bool exito,
  //   required bool guardadoLocal,
  //   required bool ubicacionCapturada,
  //   required bool ubicacionRequerida,
  //   String? mensaje,
  // }) async {
  //   String titulo;
  //   String contenido;
  //   Color colorFondo;
  //   IconData icono;
  //
  //   if (exito) {
  //     if (guardadoLocal) {
  //       titulo = '📱 Reporte Guardado Localmente';
  //       contenido = 'El reporte se ha guardado en el dispositivo. '
  //           'Se sincronizará automáticamente cuando se detecte conexión a internet.';
  //       colorFondo = Colors.orange.shade50;
  //       icono = Icons.signal_wifi_off;
  //     } else {
  //       if (ubicacionRequerida) {
  //         if (ubicacionCapturada) {
  //           titulo = 'Reporte Enviado con Éxito';
  //           contenido = 'El reporte ha sido enviado correctamente.';
  //           colorFondo = Colors.green.shade50;
  //           icono = Icons.check_circle;
  //         } else {
  //           //titulo = '⚠️ Reporte Enviado sin Ubicación';
  //           titulo = '⚠️ Reporte Enviado ';
  //           contenido = 'El reporte ha sido enviado.';
  //           colorFondo = Colors.orange.shade50;
  //           icono = Icons.location_off;
  //         }
  //       } else {
  //         titulo = '✅ Reporte Enviado';
  //         contenido = 'El reporte ha sido enviado correctamente '
  //             'sin requerir ubicación.';
  //         colorFondo = Colors.green.shade50;
  //         icono = Icons.check_circle;
  //       }
  //     }
  //   } else {
  //     titulo = '❌ Error al Enviar';
  //     contenido =
  //         mensaje ?? 'Ha ocurrido un error al intentar enviar el reporte.';
  //     colorFondo = Colors.red.shade50;
  //     icono = Icons.error;
  //   }
  //
  //   await showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         backgroundColor: colorFondo,
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         title: Row(
  //           children: [
  //             Icon(icono,
  //                 size: 28, color: _getColorIcono(exito, guardadoLocal)),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: Text(
  //                 titulo,
  //                 style: TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   color: _getColorTexto(exito, guardadoLocal),
  //                   fontSize: 18,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         content: Text(
  //           contenido,
  //           style: const TextStyle(
  //             fontSize: 14,
  //             height: 1.4,
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             style: TextButton.styleFrom(
  //               foregroundColor: _getColorBoton(exito, guardadoLocal),
  //             ),
  //             child: Text(
  //               exito ? 'ACEPTAR' : 'REINTENTAR',
  //               style: const TextStyle(
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // ✅ NUEVO: Función para mostrar alerta de error
  Future<void> _mostrarAlertaError(String mensaje) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error, size: 28, color: Colors.red.shade700),
              const SizedBox(width: 12),
              const Text(
                '❌ Error de Validación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text(
                'CORREGIR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ NUEVO: Funciones auxiliares para colores
  Color _getColorIcono(bool exito, bool guardadoLocal) {
    if (!exito) return Colors.red.shade700;
    if (guardadoLocal) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Color _getColorTexto(bool exito, bool guardadoLocal) {
    if (!exito) return Colors.red.shade700;
    if (guardadoLocal) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Color _getColorBoton(bool exito, bool guardadoLocal) {
    if (!exito) return Colors.red.shade700;
    if (guardadoLocal) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  // 🔄 CAMBIOS EN _enviarReporte() - PARTE 1: Detectar conexión

  // void _enviarReporte() async {
  //   if (!_formKey.currentState!.validate()) return;
  //
  //   // ✅ NUEVA VALIDACIÓN: Verificar si campos R están deshabilitados PERO tienen valores
  //   if (!_camposR) {
  //     final rInicialTieneValor = _rInicialiController.text.isNotEmpty;
  //     final rFinalTieneValor = _rFinalController.text.isNotEmpty;
  //
  //     if (rInicialTieneValor || rFinalTieneValor) {
  //       // Hay valores en R pero la sección está deshabilitada
  //       print('⚠️ ADVERTENCIA: Campos R tienen valores pero la sección está deshabilitada');
  //       print('   R Inicial ingresado: ${_rInicialiController.text}');
  //       print('   R Final ingresado: ${_rFinalController.text}');
  //
  //       await _mostrarDialogoConfirmacionR();
  //       return;
  //     }
  //   }
  //
  //   // ✅ NUEVA VALIDACIÓN: Verificar si campos C están deshabilitados PERO tienen valores
  //   if (!_camposC) {
  //     final cInicialTieneValor = _cInicialiController.text.isNotEmpty;
  //     final cFinalTieneValor = _cFinalController.text.isNotEmpty;
  //
  //     if (cInicialTieneValor || cFinalTieneValor) {
  //       // Hay valores en C pero la sección está deshabilitada
  //       print('⚠️ ADVERTENCIA: Campos C tienen valores pero la sección está deshabilitada');
  //       print('   C Inicial ingresado: ${_cInicialiController.text}');
  //       print('   C Final ingresado: ${_cFinalController.text}');
  //
  //       await _mostrarDialogoConfirmacionC();
  //       return;
  //     }
  //   }
  //
  //   // 1. Validar GPS si es requerido
  //   if (!_gpsActivado && _ubicacionRequerida) {
  //     _mostrarDialogoActivacionGPS();
  //     return;
  //   }
  //
  //   setState(() => _isSubmitting = true);
  //
  //   try {
  //     if (_userData?.operador == null) {
  //       throw Exception('Datos de operador no disponibles');
  //     }
  //
  //     // 2. Verificar conexión a internet
  //     final tieneInternet = await _verificarConexionInternet();
  //
  //     // 3. Capturar ubicación si es necesario
  //     bool ubicacionCapturada = false;
  //     if (_gpsActivado && _ubicacionRequerida) {
  //       ubicacionCapturada = await _capturarGeolocalizacionAlEnviar();
  //     }
  //
  //     final ahora = DateTime.now();
  //     final fechaHora = ahora.toIso8601String();
  //
  //     // ⛔️ INICIO DEL BLOQUE FALTANTE ⛔️
  //     // --- Lógica condicional para 'R' ---
  //     String rInicialCompleto;
  //     String rFinalCompleto;
  //     int registroR;
  //
  //     if (!_camposR) {
  //       print('ℹ️ Campos R deshabilitados. Enviando valores en cero.');
  //       rInicialCompleto = _buildFormatoR('0000', '0');
  //       rFinalCompleto = _buildFormatoR('0000', '0');
  //       registroR = 0;
  //     } else {
  //       rInicialCompleto = _buildFormatoR(
  //         _rInicialiController.text.padLeft(4, '0'),
  //         _rInicialDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _rInicialDigitoFinalController.text,
  //       );
  //
  //       rFinalCompleto = _buildFormatoR(
  //         _rFinalController.text.padLeft(4, '0'),
  //         _rFinalDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _rFinalDigitoFinalController.text,
  //       );
  //       registroR = diferenciaR;
  //     }
  //
  //     // --- Lógica condicional para 'C' ---
  //     String cInicialCompleto;
  //     String cFinalCompleto;
  //     int registroC;
  //
  //     if (!_camposC) {
  //       print('ℹ️ Campos C deshabilitados. Enviando valores en cero.');
  //       cInicialCompleto = _buildFormatoC('0000', '0');
  //       cFinalCompleto = _buildFormatoC('0000', '0');
  //       registroC = 0;
  //     } else {
  //       cInicialCompleto = _buildFormatoC(
  //         _cInicialiController.text.padLeft(4, '0'),
  //         _cInicialDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _cInicialDigitoFinalController.text,
  //       );
  //       cFinalCompleto = _buildFormatoC(
  //         _cFinalController.text.padLeft(4, '0'),
  //         _cFinalDigitoFinalController.text.isEmpty
  //             ? '0'
  //             : _cFinalDigitoFinalController.text,
  //       );
  //       registroC = diferenciaC;
  //     }
  //     // ⛔️ FIN DEL BLOQUE FALTANTE ⛔️
  //
  //     // 4. Construir mapa de datos para el reporte
  //     final reporteData = {
  //       'fecha_reporte': _fechaController.text,
  //       'contador_inicial_c': cInicialCompleto,
  //       'contador_final_c': cFinalCompleto,
  //       'registro_c': registroC,
  //       'contador_inicial_r': rInicialCompleto,
  //       'contador_final_r': rFinalCompleto,
  //       'registro_r': registroR,
  //       'incidencias': _incidenciasController.text,
  //       'observaciones': _observacionesController.text,
  //       'operador': _userData!.operador!.idOperador,
  //       'estacion': _userData!.operador!.idEstacion,
  //       'centro_empadronamiento': _puntoEmpadronamientoId,
  //       'estado': 'ENVIO REPORTE',
  //       'sincronizar': true,
  //       'observacionC': _cObservacionesController.text,
  //       'observacionR': _rObservacionesController.text,
  //       'saltosenC': int.tryParse(_cSaltosController.text) ?? 0,
  //       'saltosenR': int.tryParse(_rSaltosController.text) ?? 0,
  //     };
  //
  //     // 5. Construir mapa de datos para el despliegue/geolocalización
  //     final despliegueData = {
  //       'destino':
  //       'REPORTE DIARIO - ${_userData!.operador!.nroEstacion ?? "Estación"}',
  //       'latitud': _latitud ?? (_ubicacionRequerida ? '0.0' : null),
  //       'longitud': _longitud ?? (_ubicacionRequerida ? '0.0' : null),
  //       'descripcion_reporte': null,
  //       'estado': 'REPORTE ENVIADO',
  //       'sincronizar': true,
  //       'observaciones':
  //       'Reporte diario: ${_observacionesController.text.isNotEmpty ? _observacionesController.text : "Sin observaciones"}',
  //       'incidencias': _ubicacionRequerida
  //           ? (ubicacionCapturada
  //           ? 'Ubicación capturada correctamente'
  //           : 'No se pudo capturar ubicación')
  //           : 'Ubicación no requerida para este reporte',
  //       'fecha_hora': fechaHora,
  //       'operador': _userData!.operador!.idOperador,
  //       'sincronizado': false,
  //     };
  //
  //     print('📤 Enviando reporte con formatos:');
  //     print('📍 R Inicial: $rInicialCompleto');
  //     print('📍 R Final: $rFinalCompleto');
  //     print('📍 C Inicial: $cInicialCompleto');
  //     print('📍 C Final: $cFinalCompleto');
  //
  //     // 6. Preparar ApiService si hay conexión
  //     final authService = AuthService();
  //     final accessToken = await authService.getAccessToken();
  //     ApiService? apiService;
  //     if (tieneInternet && accessToken != null) {
  //       apiService = ApiService(accessToken: accessToken);
  //     }
  //
  //     // 7. Guardar los datos localmente
  //     final result = await _syncService.saveReporteGeolocalizacion(
  //       reporteData: reporteData,
  //       despliegueData: despliegueData,
  //     );
  //
  //     // 8. Si hay conexión, intentar sincronizar inmediatamente
  //     if (tieneInternet && apiService != null) {
  //       print('🌐 Conexión disponible - sincronizando inmediatamente');
  //       await _syncService.sincronizarReportes(apiService: apiService);
  //     }
  //
  //     if (!mounted) return;
  //
  //     // 9. Mostrar resultado al usuario
  //     await _mostrarAlertaResultado(
  //       exito: result['success'],
  //       guardadoLocal: result['saved_locally'] == true,
  //       ubicacionCapturada: ubicacionCapturada,
  //       ubicacionRequerida: _ubicacionRequerida,
  //       mensaje: result['message'],
  //       tieneInternet: tieneInternet,
  //     );
  //
  //     // 10. Limpiar formulario si todo fue exitoso
  //     if (result['success']) {
  //       _cleanFormulario();
  //       setState(() {
  //         _latitud = null;
  //         _longitud = null;
  //         _coordenadas = 'No capturadas';
  //         _locationCaptured = false;
  //         _ubicacionRequerida = true;
  //         _camposR = false;
  //         _camposC = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     await _mostrarAlertaError('Error al enviar reporte: $e');
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isSubmitting = false);
  //     }
  //   }
  // }

  void _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Validar campos R/C deshabilitados pero con valores
    await _validarCamposDeshabilitadosConValores();

    // 2. Continuar con el envío
    await _continuarEnvioReporte();
  }

  Future<void> _validarCamposDeshabilitadosConValores() async {
    // Validar R
    if (!_camposR && _tienenValoresR()) {
      final confirmar = await _mostrarConfirmacionActivarR();
      if (confirmar == true) {
        setState(() => _camposR = true);
        _calcularDiferencia();
      } else if (confirmar == false) {
        _registroRenCero();
      } else {
        // Usuario canceló
        throw Exception('Envío cancelado por usuario');
      }
    }

    // Validar C
    if (!_camposC && _tienenValoresC()) {
      final confirmar = await _mostrarConfirmacionActivarC();
      if (confirmar == true) {
        setState(() => _camposC = true);
        _calcularDiferencia();
      } else if (confirmar == false) {
        _registroCenCero();
      } else {
        // Usuario canceló
        throw Exception('Envío cancelado por usuario');
      }
    }
  }

  bool _tienenValoresR() {
    return _rInicialiController.text.isNotEmpty ||
        _rFinalController.text.isNotEmpty ||
        _rInicialDigitoFinalController.text.isNotEmpty ||
        _rFinalDigitoFinalController.text.isNotEmpty;
  }

  bool _tienenValoresC() {
    return _cInicialiController.text.isNotEmpty ||
        _cFinalController.text.isNotEmpty ||
        _cInicialDigitoFinalController.text.isNotEmpty ||
        _cFinalDigitoFinalController.text.isNotEmpty;
  }

  Future<bool?> _mostrarConfirmacionActivarR() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Valores R detectados'),
          content: const Text(
            'Has ingresado valores en los campos R. '
            '¿Quieres activar la sección de Registros Nuevos (R) '
            'o limpiar los valores?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ACTIVAR R'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('LIMPIAR VALORES'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  // ✅ NUEVO: Método para verificar conexión
  Future<bool> _verificarConexionInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('⚠️ Error verificando conexión: $e');
      return false;
    }
  }

  // ✅ ACTUALIZAR: _mostrarAlertaResultado con parámetro tieneInternet
  Future<void> _mostrarAlertaResultado({
    required bool exito,
    required bool guardadoLocal,
    required bool ubicacionCapturada,
    required bool ubicacionRequerida,
    required bool tieneInternet,
    String? mensaje,
  }) async {
    String titulo;
    String contenido;
    Color colorFondo;
    IconData icono;

    if (exito) {
      if (!tieneInternet) {
        titulo = '📱 Reporte Guardado Localmente';
        contenido =
            'El reporte se guardó en el dispositivo.\n\n'
            'Se sincronizará automáticamente cuando haya conexión a internet.';
        colorFondo = Colors.orange.shade50;
        icono = Icons.save;
      } else if (guardadoLocal) {
        titulo = '⏳ Procesando Sincronización';
        contenido =
            'El reporte se está sincronizando con el servidor.\n\n'
            'Por favor, espera...';
        colorFondo = Colors.blue.shade50;
        icono = Icons.cloud_sync;
      } else {
        titulo = '✅ Reporte Enviado';
        contenido = 'El reporte ha sido enviado correctamente al servidor.';
        colorFondo = Colors.green.shade50;
        icono = Icons.check_circle;
      }
    } else {
      titulo = '❌ Error al Enviar';
      contenido =
          mensaje ?? 'Ha ocurrido un error al intentar enviar el reporte.';
      colorFondo = Colors.red.shade50;
      icono = Icons.error;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorFondo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                icono,
                size: 28,
                color: _getColorIcono(exito, guardadoLocal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getColorTexto(exito, guardadoLocal),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            contenido,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: _getColorBoton(exito, guardadoLocal),
              ),
              child: const Text(
                'ACEPTAR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarDialogoConfirmacionR() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '⚠️ Valores R Ingresados',
            style: TextStyle(color: Colors.orange),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Has ingresado valores en los campos R, '
                'pero la sección de Registros Nuevos está deshabilitada.',
              ),
              const SizedBox(height: 12),
              Text(
                '• R Inicial: ${_rInicialiController.text}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '• R Final: ${_rFinalController.text}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Qué deseas hacer?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Opción 1: Activar sección R y usar los valores
                setState(() {
                  _camposR = true;
                });
                // Recalcular diferencia
                _calcularDiferencia();
                // Continuar con el envío
                _continuarEnvioReporte();
              },
              child: const Text(
                'ACTIVAR SECCIÓN R',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Opción 2: Limpiar valores R y enviar ceros
                _registroRenCero();
                // Continuar con el envío
                _continuarEnvioReporte();
              },
              child: const Text(
                'LIMPIAR VALORES R',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _continuarEnvioReporte() async {
    // Agregar async
    if (!_gpsActivado && _ubicacionRequerida) {
      _mostrarDialogoActivacionGPS();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_userData?.operador == null) {
        throw Exception('Datos de operador no disponibles');
      }

      // 2. Verificar conexión a internet
      final tieneInternet = await _verificarConexionInternet();

      // 3. Capturar ubicación si es necesario
      bool ubicacionCapturada = false;
      if (_gpsActivado && _ubicacionRequerida) {
        ubicacionCapturada = await _capturarGeolocalizacionAlEnviar();
      }

      final ahora = DateTime.now();
      final fechaHora = ahora.toIso8601String();

      // ⚠️ DEBUG: Verificar estado de campos R antes de construir valores
      print('🔍 DEBUG ANTES DE ENVIAR:');
      print('   _camposR: $_camposR');
      print('   R Inicial Controller: ${_rInicialiController.text}');
      print('   R Final Controller: ${_rFinalController.text}');
      print('   R Inicial Digito: ${_rInicialDigitoFinalController.text}');
      print('   R Final Digito: ${_rFinalDigitoFinalController.text}');

      // --- Lógica condicional para 'R' ---
      String rInicialCompleto;
      String rFinalCompleto;
      int registroR;

      if (!_camposR) {
        print('ℹ️ Campos R deshabilitados. Enviando valores en cero.');
        rInicialCompleto = _buildFormatoR('0000', '0');
        rFinalCompleto = _buildFormatoR('0000', '0');
        registroR = 0;
      } else {
        // ✅ Asegurar que tenemos valores válidos
        final rInicial4Digitos = _rInicialiController.text.isNotEmpty
            ? _rInicialiController.text.padLeft(4, '0')
            : '0000';
        final rInicialDigito = _rInicialDigitoFinalController.text.isNotEmpty
            ? _rInicialDigitoFinalController.text
            : '0';

        final rFinal4Digitos = _rFinalController.text.isNotEmpty
            ? _rFinalController.text.padLeft(4, '0')
            : '0000';
        final rFinalDigito = _rFinalDigitoFinalController.text.isNotEmpty
            ? _rFinalDigitoFinalController.text
            : '0';

        rInicialCompleto = _buildFormatoR(rInicial4Digitos, rInicialDigito);
        rFinalCompleto = _buildFormatoR(rFinal4Digitos, rFinalDigito);
        registroR = diferenciaR;

        print('✅ Campos R habilitados - Usando valores reales:');
        print('   R Inicial: $rInicialCompleto');
        print('   R Final: $rFinalCompleto');
      }

      // --- Lógica condicional para 'C' ---
      String cInicialCompleto;
      String cFinalCompleto;
      int registroC;

      if (!_camposC) {
        print('ℹ️ Campos C deshabilitados. Enviando valores en cero.');
        cInicialCompleto = _buildFormatoC('0000', '0');
        cFinalCompleto = _buildFormatoC('0000', '0');
        registroC = 0;
      } else {
        cInicialCompleto = _buildFormatoC(
          _cInicialiController.text.padLeft(4, '0'),
          _cInicialDigitoFinalController.text.isEmpty
              ? '0'
              : _cInicialDigitoFinalController.text,
        );
        cFinalCompleto = _buildFormatoC(
          _cFinalController.text.padLeft(4, '0'),
          _cFinalDigitoFinalController.text.isEmpty
              ? '0'
              : _cFinalDigitoFinalController.text,
        );
        registroC = diferenciaC;
      }

      // 4. Construir mapa de datos para el reporte
      final reporteData = {
        'fecha_reporte': _fechaController.text,
        'contador_inicial_c': cInicialCompleto,
        'contador_final_c': cFinalCompleto,
        'registro_c': registroC,
        'contador_inicial_r': rInicialCompleto,
        'contador_final_r': rFinalCompleto,
        'registro_r': registroR,
        'incidencias': _incidenciasController.text,
        'observaciones': _observacionesController.text,
        'operador': _userData!.operador!.idOperador,
        'estacion': _userData!.operador!.idEstacion,
        'centro_empadronamiento': _puntoEmpadronamientoId,
        'estado': 'ENVIO REPORTE',
        'sincronizar': true,
        'observacionC': _cObservacionesController.text,
        'observacionR': _rObservacionesController.text,
        'saltosenC': int.tryParse(_cSaltosController.text) ?? 0,
        'saltosenR': int.tryParse(_rSaltosController.text) ?? 0,
      };

      // 5. Construir mapa de datos para el despliegue/geolocalización
      final despliegueData = {
        'destino':
            'REPORTE DIARIO - ${_userData!.operador!.nroEstacion ?? "Estación"}',
        'latitud': _latitud ?? (_ubicacionRequerida ? '0.0' : null),
        'longitud': _longitud ?? (_ubicacionRequerida ? '0.0' : null),
        'descripcion_reporte': null,
        'estado': 'REPORTE ENVIADO',
        'sincronizar': true,
        'observaciones':
            'Reporte diario: ${_observacionesController.text.isNotEmpty ? _observacionesController.text : "Sin observaciones"}',
        'incidencias': _ubicacionRequerida
            ? (ubicacionCapturada
                  ? 'Ubicación capturada correctamente'
                  : 'No se pudo capturar ubicación')
            : 'Ubicación no requerida para este reporte',
        'fecha_hora': fechaHora,
        'operador': _userData!.operador!.idOperador,
        'sincronizado': false,
      };

      print('📤 Enviando reporte con formatos:');
      print('📍 R Inicial: $rInicialCompleto');
      print('📍 R Final: $rFinalCompleto');
      print('📍 C Inicial: $cInicialCompleto');
      print('📍 C Final: $cFinalCompleto');

      // 6. Preparar ApiService si hay conexión
      final authService = AuthService();
      final accessToken = await authService.getAccessToken();
      ApiService? apiService;
      if (tieneInternet && accessToken != null) {
        apiService = ApiService(accessToken: accessToken);
      }

      // 7. Guardar los datos localmente
      final result = await _syncService.saveReporteGeolocalizacion(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );

      // 8. Si hay conexión, intentar sincronizar inmediatamente
      if (tieneInternet && apiService != null) {
        print('🌐 Conexión disponible - sincronizando inmediatamente');
        await _syncService.sincronizarReportes(apiService: apiService);
      }

      if (!mounted) return;

      // 9. Mostrar resultado al usuario
      await _mostrarAlertaResultado(
        exito: result['success'],
        guardadoLocal: result['saved_locally'] == true,
        ubicacionCapturada: ubicacionCapturada,
        ubicacionRequerida: _ubicacionRequerida,
        tieneInternet: tieneInternet,
        mensaje: result['message'],
      );

      // 10. Limpiar formulario si todo fue exitoso
      if (result['success']) {
        _cleanFormulario();
        setState(() {
          _latitud = null;
          _longitud = null;
          _coordenadas = 'No capturadas';
          _locationCaptured = false;
          _ubicacionRequerida = true;
          _camposR = false;
          _camposC = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      await _mostrarAlertaError('Error al enviar reporte: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Agrega estos métodos a tu clase _ReporteDiarioViewState:

  Future<bool?> _mostrarConfirmacionActivarC() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Valores C detectados'),
          content: const Text(
            'Has ingresado valores en los campos C. '
            '¿Quieres activar la sección de Cambio de Domicilio (C) '
            'o limpiar los valores?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ACTIVAR C'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('LIMPIAR VALORES'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }

  // También necesitas este método adicional para C:
  Future<void> _mostrarDialogoConfirmacionC() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '⚠️ Valores C Ingresados',
            style: TextStyle(color: Colors.orange),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Has ingresado valores en los campos C, '
                'pero la sección de Cambio de Domicilio está deshabilitada.',
              ),
              const SizedBox(height: 12),
              Text(
                '• C Inicial: ${_cInicialiController.text}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '• C Final: ${_cFinalController.text}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Qué deseas hacer?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Opción 1: Activar sección C y usar los valores
                setState(() {
                  _camposC = true;
                });
                // Recalcular diferencia
                _calcularDiferencia();
                // Continuar con el envío
                _continuarEnvioReporte();
              },
              child: const Text(
                'ACTIVAR SECCIÓN C',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Opción 2: Limpiar valores C y enviar ceros
                _registroCenCero();
                // Continuar con el envío
                _continuarEnvioReporte();
              },
              child: const Text(
                'LIMPIAR VALORES C',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
          ],
        );
      },
    );
  }
}
