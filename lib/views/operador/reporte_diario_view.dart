// lib/views/operador/reporte_diario_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manager_key/services/punto_empadronamiento_service.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../../models/punto_empadronamiento_model.dart';
import '../../services/reporte_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';

class ReporteDiarioView extends StatefulWidget {
  const ReporteDiarioView({Key? key}) : super(key: key);

  @override
  State<ReporteDiarioView> createState() => _ReporteDiarioViewState();
}

class _ReporteDiarioViewState extends State<ReporteDiarioView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _codigoEstacionController =  TextEditingController();
  final TextEditingController _transmitidoController = TextEditingController();
  final TextEditingController _rInicialiController = TextEditingController();
  final TextEditingController _rFinalController = TextEditingController();
  final TextEditingController _rTotalController = TextEditingController();
  final TextEditingController _cInicialiController = TextEditingController();
  final TextEditingController _cFinalController = TextEditingController();
  final TextEditingController _cTotalController = TextEditingController();
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

  // ✅ CORREGIDO: Método para construir formato R
  String _buildFormatoR(String cuatroDigitos, String digitoFinal) {
    return 'R-$_equipoId-${cuatroDigitos.padLeft(4, '0')}-$digitoFinal';
  }

  // ✅ CORREGIDO: Método para construir formato C
  String _buildFormatoC(String cuatroDigitos, String digitoFinal) {
    return 'C-$_equipoId-${cuatroDigitos.padLeft(4, '0')}-$digitoFinal';
  }

  // ✅ MÉTODO ACTUALIZADO: Validar registro R con formato completo
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

    // Construir formato completo
    final formatoCompleto = _buildFormatoR(limpio, digitoFinalController.text);
    print(
      '📝 R ${esInicial ? 'Inicial' : 'Final'} formateado: $formatoCompleto',
    );

    _calcularDiferencia();
  }

  // ✅ MÉTODO ACTUALIZADO: Validar registro C con formato completo
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

    // Construir formato completo
    final formatoCompleto = _buildFormatoC(limpio, digitoFinalController.text);
    print(
      '📝 C ${esInicial ? 'Inicial' : 'Final'} formateado: $formatoCompleto',
    );

    _calcularDiferencia();
  }

  // ✅ MÉTODO ACTUALIZADO: Validar dígito final
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

    // Recalcular con el nuevo dígito final
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

  // ✅ MÉTODO ACTUALIZADO: Calcular diferencia con formato completo
  void _calcularDiferencia() {
    // Obtener solo los 4 dígitos principales (ignorar el dígito final)
    final rInicial4Digitos = _rInicialiController.text.padLeft(4, '0');
    final rFinal4Digitos = _rFinalController.text.padLeft(4, '0');
    final cInicial4Digitos = _cInicialiController.text.padLeft(4, '0');
    final cFinal4Digitos = _cFinalController.text.padLeft(4, '0');

    // Convertir SOLO los 4 dígitos a números (ignorar dígito final)
    final rInicial = int.tryParse(rInicial4Digitos) ?? 0;
    final rFinal = int.tryParse(rFinal4Digitos) ?? 0;
    final cInicial = int.tryParse(cInicial4Digitos) ?? 0;
    final cFinal = int.tryParse(cFinal4Digitos) ?? 0;

    // Calcular diferencia para R (solo con 4 dígitos)
    if (rInicial4Digitos.isNotEmpty && rFinal4Digitos.isNotEmpty) {
      if (rFinal >= rInicial) {
        setState(() {
          diferenciaR = (rFinal - rInicial) + 1;
          _rTotal.text = diferenciaR.toString();
        });
      } else {
        setState(() {
          _rTotal.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El valor final de R debe ser mayor o igual que el inicial',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }

    // Calcular diferencia para C (solo con 4 dígitos)
    if (cInicial4Digitos.isNotEmpty && cFinal4Digitos.isNotEmpty) {
      if (cFinal >= cInicial) {
        setState(() {
          diferenciaC = (cFinal - cInicial) + 1;
          _cTotal.text = diferenciaC.toString();
        });
      } else {
        setState(() {
          _cTotal.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El valor final de C debe ser mayor o igual que el inicial',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }

    // ✅ LOG PARA VERIFICAR
    print('🧮 Cálculo - R: $rInicial → $rFinal = $diferenciaR');
    print('🧮 Cálculo - C: $cInicial → $cFinal = $diferenciaC');
  }

  // ✅ MÉTODO ACTUALIZADO: Enviar reporte con formato completo
  void _enviarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_gpsActivado && _ubicacionRequerida) {
      _mostrarDialogoActivacionGPS();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_userData?.operador == null) {
        throw Exception('Datos de operador no disponibles');
      }

      bool ubicacionCapturada = false;
      if (_gpsActivado && _ubicacionRequerida) {
        ubicacionCapturada = await _capturarGeolocalizacionAlEnviar();
      }

      final ahora = DateTime.now();
      final fechaHora = ahora.toIso8601String();

      // ✅ CONSTRUIR FORMATOS COMPLETOS
      final rInicialCompleto = _buildFormatoR(
        _rInicialiController.text.padLeft(4, '0'),
        _rInicialDigitoFinalController.text.isEmpty
            ? '0'
            : _rInicialDigitoFinalController.text,
      );

      final rFinalCompleto = _buildFormatoR(
        _rFinalController.text.padLeft(4, '0'),
        _rFinalDigitoFinalController.text.isEmpty
            ? '0'
            : _rFinalDigitoFinalController.text,
      );

      final cInicialCompleto = _buildFormatoC(
        _cInicialiController.text.padLeft(4, '0'),
        _cInicialDigitoFinalController.text.isEmpty
            ? '0'
            : _cInicialDigitoFinalController.text,
      );

      final cFinalCompleto = _buildFormatoC(
        _cFinalController.text.padLeft(4, '0'),
        _cFinalDigitoFinalController.text.isEmpty
            ? '0'
            : _cFinalDigitoFinalController.text,
      );

      // ✅ NUEVO: Incluir punto de empadronamiento en el reporte
      final reporteData = {
        'fecha_reporte': _fechaController.text,
        'contador_inicial_c': cInicialCompleto, // ✅ FORMATO COMPLETO
        'contador_final_c': cFinalCompleto, // ✅ FORMATO COMPLETO
        'registro_c': diferenciaC,
        'contador_inicial_r': rInicialCompleto, // ✅ FORMATO COMPLETO
        'contador_final_r': rFinalCompleto, // ✅ FORMATO COMPLETO
        'registro_r': diferenciaR,
        'incidencias': _incidenciasController.text,
        'observaciones': _observacionesController.text,
        'operador': _userData!.operador!.idOperador,
        'estacion': _userData!.operador!.idEstacion,
        'centro_empadronamiento': _puntoEmpadronamientoId, // ✅ NUEVO CAMPO
        'estado': 'ENVIO REPORTE',
        'sincronizar': true,
      };

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
      print('📍 Punto Empadronamiento ID: $_puntoEmpadronamientoId');

      final result = await _syncService.saveReporteGeolocalizacion(
        reporteData: reporteData,
        despliegueData: despliegueData,
      );

      if (!mounted) return;

      final mensaje = result['success']
          ? (result['saved_locally'] == true
          ? '📱 Reporte guardado localmente. Se sincronizará cuando haya internet.'
          : (_ubicacionRequerida
          ? (ubicacionCapturada
          ? '✅ Reporte enviado con geolocalización'
          : '⚠️ Reporte enviado sin geolocalización')
          : '✅ Reporte enviado sin ubicación'))
          : result['message'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: result['success']
              ? (result['saved_locally'] == true ? Colors.orange : Colors.green)
              : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      if (result['success']) {
        _cleanFormulario();
        setState(() {
          _latitud = null;
          _longitud = null;
          _coordenadas = 'No capturadas';
          _locationCaptured = false;
          _ubicacionRequerida = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ✅ MÉTODO ACTUALIZADO: Limpiar formulario
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

      // Limpiar también los dígitos finales
      _rInicialDigitoFinalController.text = '';
      _rFinalDigitoFinalController.text = '';
      _cInicialDigitoFinalController.text = '';
      _cFinalDigitoFinalController.text = '';

      // Limpiar campos de empadronamiento
      _provinciaSeleccionada = null;
      _puntoEmpadronamientoSeleccionado = null;
      _puntoEmpadronamientoId = null;

      _fechaController.text = DateTime.now().toString().split('.')[0];
      diferenciaC = 0;
      diferenciaR = 0;
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

  // WIDGET PARA CAMPO CON FORMATO COMPLETO
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
              // Prefijo fijo con el número de estación
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
                  // ✅ Muestra el número de estación
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              // 4 dígitos principales
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

              // Separador
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

              // Dígito final (NO interviene en cálculo)
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

                    // ✅ MOSTRAR FORMATO COMPLETO EN CONSOLA
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

  // ✅ NUEVO: Widget para campos de empadronamiento
  // Solución con Autocomplete para búsqueda
  // Widget _buildCamposEmpadronamiento() {
  //   return Card(
  //     elevation: 2,
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'UBICACIÓN DE EMPADRONAMIENTO',
  //             style: TextStyle(
  //               fontWeight: FontWeight.bold,
  //               fontSize: 16,
  //               color: Colors.purple,
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //
  //           // Selector de Provincia/Municipio
  //           DropdownButtonFormField<String>(
  //             value: _provinciaSeleccionada,
  //             decoration: InputDecoration(
  //               labelText: 'Provincia/Municipio',
  //               border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               contentPadding: const EdgeInsets.symmetric(
  //                 horizontal: 12,
  //                 vertical: 10,
  //               ),
  //             ),
  //             isExpanded: true,
  //             items: _provincias.map((String provincia) {
  //               return DropdownMenuItem<String>(
  //                 value: provincia,
  //                 child: Text(
  //                   provincia,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               );
  //             }).toList(),
  //             onChanged: _onProvinciaSeleccionada,
  //             validator: (value) {
  //               if (value == null || value.isEmpty) {
  //                 return 'Seleccione una provincia';
  //               }
  //               return null;
  //             },
  //           ),
  //
  //           const SizedBox(height: 12),
  //
  //           // Autocomplete para Punto de Empadronamiento
  //           Autocomplete<String>(
  //             optionsBuilder: (TextEditingValue textEditingValue) {
  //               if (textEditingValue.text == '') {
  //                 return const Iterable<String>.empty();
  //               }
  //               return _puntosEmpadronamiento.where((String option) {
  //                 return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
  //               });
  //             },
  //             onSelected: (String selection) {
  //               _onPuntoEmpadronamientoSeleccionado(selection);
  //             },
  //             fieldViewBuilder: (
  //                 BuildContext context,
  //                 TextEditingController textEditingController,
  //                 FocusNode focusNode,
  //                 VoidCallback onFieldSubmitted,
  //                 ) {
  //               return TextFormField(
  //                 controller: textEditingController,
  //                 focusNode: focusNode,
  //                 decoration: InputDecoration(
  //                   labelText: 'Punto de Empadronamiento',
  //                   hintText: 'Escriba para buscar...',
  //                   border: OutlineInputBorder(
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   contentPadding: const EdgeInsets.symmetric(
  //                     horizontal: 12,
  //                     vertical: 10,
  //                   ),
  //                 ),
  //                 validator: (value) {
  //                   if (value == null || value.isEmpty || _puntoEmpadronamientoSeleccionado == null) {
  //                     return 'Seleccione un punto de empadronamiento';
  //                   }
  //                   return null;
  //                 },
  //               );
  //             },
  //             optionsViewBuilder: (
  //                 BuildContext context,
  //                 AutocompleteOnSelected<String> onSelected,
  //                 Iterable<String> options,
  //                 ) {
  //               return Align(
  //                 alignment: Alignment.topLeft,
  //                 child: Material(
  //                   elevation: 4.0,
  //                   child: SizedBox(
  //                     height: 200.0,
  //                     child: ListView.builder(
  //                       padding: EdgeInsets.zero,
  //                       itemCount: options.length,
  //                       itemBuilder: (BuildContext context, int index) {
  //                         final String option = options.elementAt(index);
  //                         return ListTile(
  //                           title: Text(
  //                             option,
  //                             overflow: TextOverflow.ellipsis,
  //                             maxLines: 2,
  //                           ),
  //                           onTap: () {
  //                             onSelected(option);
  //                           },
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                 ),
  //               );
  //             },
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // ✅ NUEVO: Método para cuando se selecciona una provincia
  void _onProvinciaSeleccionada(String? provincia) async {
    if (provincia == null) return;

    setState(() {
      _provinciaSeleccionada = provincia;
      _puntoEmpadronamientoSeleccionado = null;
      _puntosEmpadronamiento = [];
      _puntoEmpadronamientoId = null;
    });

    try {
      // Cargar puntos de empadronamiento para la provincia seleccionada
      final puntos = await _puntoService.getPuntosByProvincia(provincia);
      final nombresPuntos = puntos.map((p) => p.puntoEmpadronamiento).toList();

      setState(() {
        _puntosEmpadronamiento = nombresPuntos;
      });

      print('✅ Puntos de empadronamiento cargados: ${puntos.length} para $provincia');
    } catch (e) {
      print('❌ Error cargando puntos de empadronamiento: $e');
    }
  }

  // ✅ NUEVO: Método para cuando se selecciona un punto de empadronamiento
  void _onPuntoEmpadronamientoSeleccionado(String? punto) async {
    if (punto == null) return;

    setState(() {
      _puntoEmpadronamientoSeleccionado = punto;
    });

    try {
      // Obtener el ID del punto seleccionado
      final puntos = await _puntoService.getPuntosByProvincia(_provinciaSeleccionada!);
      final puntoSeleccionado = puntos.firstWhere(
            (p) => p.puntoEmpadronamiento == punto,
        orElse: () => PuntoEmpadronamiento(
          id: 0,
          provincia: '',
          puntoEmpadronamiento: '',
        ),
      );

      if (puntoSeleccionado.id != 0) {
        setState(() {
          _puntoEmpadronamientoId = puntoSeleccionado.id;
        });
        print('✅ Punto de empadronamiento seleccionado: ID ${_puntoEmpadronamientoId} - $punto');
      }
    } catch (e) {
      print('❌ Error obteniendo ID del punto de empadronamiento: $e');
    }
  }

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

            // Provincia con Autocomplete
            _buildProvinciaAutocomplete(),

            const SizedBox(height: 12),

            // Punto de Empadronamiento con Autocomplete
            _buildPuntoEmpadronamientoAutocomplete(),
          ],
        ),
      ),
    );
  }

  Widget _buildProvinciaAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _provincias;
        }
        return _provincias.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _provinciaSeleccionada = selection;
        });
        _onProvinciaSeleccionada(selection);
      },
      fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
          ) {
        // Sincronizar el controlador con el valor seleccionado
        if (_provinciaSeleccionada != null && textEditingController.text.isEmpty) {
          textEditingController.text = _provinciaSeleccionada!;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Provincia/Municipio',
            hintText: 'Escriba para buscar...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: _provinciaSeleccionada != null
                ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                textEditingController.clear();
                setState(() {
                  _provinciaSeleccionada = null;
                  _puntoEmpadronamientoSeleccionado = null;
                  _puntosEmpadronamiento = [];
                });
              },
            )
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty || _provinciaSeleccionada == null) {
              return 'Seleccione una provincia';
            }
            return null;
          },
          onChanged: (value) {
            // Si el usuario borra el texto, limpiar la selección
            if (value.isEmpty) {
              setState(() {
                _provinciaSeleccionada = null;
                _puntoEmpadronamientoSeleccionado = null;
                _puntosEmpadronamiento = [];
              });
            }
          },
        );
      },
      optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
          ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPuntoEmpadronamientoAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _puntosEmpadronamiento;
        }
        return _puntosEmpadronamiento.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _puntoEmpadronamientoSeleccionado = selection;
        });
        _onPuntoEmpadronamientoSeleccionado(selection);
      },
      fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
          ) {
        // Sincronizar el controlador con el valor seleccionado
        if (_puntoEmpadronamientoSeleccionado != null && textEditingController.text.isEmpty) {
          textEditingController.text = _puntoEmpadronamientoSeleccionado!;
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: _provinciaSeleccionada != null, // Solo habilitar si hay provincia seleccionada
          decoration: InputDecoration(
            labelText: 'Punto de Empadronamiento',
            hintText: _provinciaSeleccionada != null
                ? 'Escriba para buscar...'
                : 'Primero seleccione una provincia',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: _puntoEmpadronamientoSeleccionado != null
                ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                textEditingController.clear();
                setState(() {
                  _puntoEmpadronamientoSeleccionado = null;
                  _puntoEmpadronamientoId = null;
                });
              },
            )
                : null,
          ),
          validator: (value) {
            if (_provinciaSeleccionada != null &&
                (value == null || value.isEmpty || _puntoEmpadronamientoSeleccionado == null)) {
              return 'Seleccione un punto de empadronamiento';
            }
            return null;
          },
          onChanged: (value) {
            // Si el usuario borra el texto, limpiar la selección
            if (value.isEmpty) {
              setState(() {
                _puntoEmpadronamientoSeleccionado = null;
                _puntoEmpadronamientoId = null;
              });
            }
          },
        );
      },
      optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<String> onSelected,
          Iterable<String> options,
          ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
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

                      // ✅ NUEVO: CAMPOS DE EMPADRONAMIENTO
                      _buildCamposEmpadronamiento(),

                      const SizedBox(height: 20),

                      // SECCIÓN RECEPCIÓN (R)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'REGISTROS NUEVOS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // SECCIÓN CAMBIO DE DOMICILIO(C)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'REGISTROS CAMBIO DE DOMICILIO',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // OBSERVACIONES
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OBSERVACIONES ADICIONALES',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _observacionesController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Observaciones',
                                  hintText: 'Ingrese sus observaciones aquí...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _incidenciasController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Incidencias (Opcional)',
                                  hintText: 'Ingrese incidencias si las hay...',
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

    // Dispose de los nuevos controladores de dígitos finales
    _rInicialDigitoFinalController.dispose();
    _rFinalDigitoFinalController.dispose();
    _cInicialDigitoFinalController.dispose();
    _cFinalDigitoFinalController.dispose();

    super.dispose();
  }

  // ... (mantén los métodos de geolocalización existentes)
  Future<void> _verificarEstadoGPS() async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      setState(() {
        _gpsActivado = servicioHabilitado;
      });
      print(
        '📍 Estado GPS: ${servicioHabilitado ? "ACTIVADO" : "DESACTIVADO"}',
      );
    } catch (e) {
      print('❌ Error verificando estado GPS: $e');
      setState(() {
        _gpsActivado = false;
      });
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
        setState(() {
          _latitud = position.latitude.toStringAsFixed(6);
          _longitud = position.longitude.toStringAsFixed(6);
          _coordenadas = 'Lat: ${_latitud}\nLong: ${_longitud}';
          _locationCaptured = true;
        });
        print('📍 Geolocalización capturada: $_coordenadas');
        return true;
      } else {
        setState(() {
          _locationCaptured = false;
          _coordenadas = 'Error al capturar ubicación';
        });
        print('⚠️ No se pudo capturar la ubicación');
        return false;
      }
    } catch (e) {
      setState(() {
        _locationCaptured = false;
        _coordenadas = 'Error: $e';
      });
      print('❌ Error capturando ubicación: $e');
      return false;
    } finally {
      setState(() => _locationLoading = false);
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

  // ✅ CORREGIDO: Método para cargar datos de empadronamiento
  Future<void> _cargarDatosEmpadronamiento() async {
    try {
      setState(() {
        _cargadoProvincias = false;
      });
      final provincias = await _puntoService.getProvinciasFromLocalDatabase();

      setState(() {
        _provincias = provincias;
        _cargadoProvincias = true;
      });

      print('✅ Provincias cargadas: ${_provincias.length}');
    } catch (e) {
      print('❌ Error cargando provincias: $e');
      setState(() {
        _cargadoProvincias = false;
      });
    }
  }
}