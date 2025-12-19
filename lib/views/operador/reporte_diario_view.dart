// lib/views/operador/reporte_diario_view.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:manager_key/services/punto_empadronamiento_service.dart';
import 'package:manager_key/models/punto_empadronamiento_model.dart';
import 'package:manager_key/models/reporte_diario_local.dart';
import 'package:manager_key/services/reporte_sync_manager.dart';
import 'package:manager_key/services/auth_service.dart';
import 'package:manager_key/models/user_model.dart';
import 'package:manager_key/utils/alert_helper.dart';

class ReporteDiarioView extends StatefulWidget {
  const ReporteDiarioView({Key? key}) : super(key: key);

  @override
  State<ReporteDiarioView> createState() => _ReporteDiarioViewState();
}

class _ReporteDiarioViewState extends State<ReporteDiarioView> {
  final _formKey = GlobalKey<FormState>();
  final ReporteSyncManager _syncManager = ReporteSyncManager();

  // --- Controladores ---
  final TextEditingController _codigoEstacionController = TextEditingController();
  final TextEditingController _transmitidoController = TextEditingController();
  final TextEditingController _rInicialiController = TextEditingController();
  final TextEditingController _rFinalController = TextEditingController();
  final TextEditingController _rTotalController = TextEditingController();
  final TextEditingController _rObservacionesController = TextEditingController();
  final TextEditingController _rSaltosController = TextEditingController();
  final TextEditingController _cInicialiController = TextEditingController();
  final TextEditingController _cFinalController = TextEditingController();
  final TextEditingController _cTotalController = TextEditingController();
  final TextEditingController _cObservacionesController = TextEditingController();
  final TextEditingController _cSaltosController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _incidenciasController = TextEditingController();
  final TextEditingController _rTotal = TextEditingController();
  final TextEditingController _cTotal = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _rInicialDigitoFinalController = TextEditingController();
  final TextEditingController _rFinalDigitoFinalController = TextEditingController();
  final TextEditingController _cInicialDigitoFinalController = TextEditingController();
  final TextEditingController _cFinalDigitoFinalController = TextEditingController();

  // --- Variables de estado ---
  late User? _userData;
  String _equipoId = '00000';
  int diferenciaR = 0;
  int diferenciaC = 0;
  bool _isSubmitting = false;

  // Geolocalización
  bool _gpsActivado = false;
  bool _ubicacionRequerida = true;

  // Puntos de empadronamiento
  String? _provinciaSeleccionada;
  String? _puntoEmpadronamientoSeleccionado;
  List<String> _provincias = [];
  List<String> _puntosEmpadronamiento = [];
  int? _puntoEmpadronamientoId;
  final PuntoEmpadronamientoService _puntoService = PuntoEmpadronamientoService();

  // Estado de secciones
  bool _camposR = false;
  bool _camposC = false;

  @override
  void initState() {
    super.initState();
    _fechaController.text = DateTime.now().toIso8601String().split('T').first;
    _initializeApp();
    _cargarDatosEmpadronamiento();
  }

  @override
  void dispose() {
    _codigoEstacionController.dispose();
    _transmitidoController.dispose();
    _rInicialiController.dispose();
    _rFinalController.dispose();
    _rTotalController.dispose();
    _rObservacionesController.dispose();
    _rSaltosController.dispose();
    _cInicialiController.dispose();
    _cFinalController.dispose();
    _cTotalController.dispose();
    _cObservacionesController.dispose();
    _cSaltosController.dispose();
    _observacionesController.dispose();
    _incidenciasController.dispose();
    _rTotal.dispose();
    _cTotal.dispose();
    _fechaController.dispose();
    _rInicialDigitoFinalController.dispose();
    _rFinalDigitoFinalController.dispose();
    _cInicialDigitoFinalController.dispose();
    _cFinalDigitoFinalController.dispose();
    super.dispose();
  }

  // ===================================================================
  // LÓGICA PRINCIPAL Y DE NEGOCIO
  // ===================================================================

  Future<void> _enviarReporte() async {
    if (!_formKey.currentState!.validate()) {
      _mostrarAlertaError("Por favor, corrige los errores en el formulario.");
      return;
    }
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await _verificarEstadoGPS();
      if (!_gpsActivado && _ubicacionRequerida) {
        _mostrarDialogoActivacionGPS();
        setState(() => _isSubmitting = false);
        return;
      }

      final reporte = await _crearReporteLocalDesdeForm();
      final resultado = await _syncManager.guardarReporte(reporte);

      await _mostrarAlertaResultado(
        exito: resultado['success'] == true,
        sincronizado: resultado['sincronizado'] == true,
        mensaje: resultado['message'],
      );

      if (resultado['success'] == true) {
        _cleanFormulario();
      }

    } catch (e) {
      await _mostrarAlertaResultado(
        exito: false,
        sincronizado: false,
        mensaje: 'Error inesperado: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<ReporteDiarioLocal> _crearReporteLocalDesdeForm() async {
    final userData = await AuthService().getCurrentUser();
    if (userData?.operador == null) {
      throw Exception('Datos de operador no disponibles. Vuelve a iniciar sesión.');
    }
    final operador = userData!.operador!;

    String rInicialCompleto = _buildFormatoR('0000', '0');
    String rFinalCompleto = _buildFormatoR('0000', '0');
    if (_camposR) {
      rInicialCompleto = _buildFormatoR(_rInicialiController.text, _rInicialDigitoFinalController.text);
      rFinalCompleto = _buildFormatoR(_rFinalController.text, _rFinalDigitoFinalController.text);
    }

    String cInicialCompleto = _buildFormatoC('0000', '0');
    String cFinalCompleto = _buildFormatoC('0000', '0');
    if (_camposC) {
      cInicialCompleto = _buildFormatoC(_cInicialiController.text, _cInicialDigitoFinalController.text);
      cFinalCompleto = _buildFormatoC(_cFinalController.text, _cFinalDigitoFinalController.text);
    }

    return ReporteDiarioLocal(
      contadorInicialR: rInicialCompleto,
      contadorFinalR: rFinalCompleto,
      saltosenR: int.tryParse(_rSaltosController.text) ?? 0,
      contadorR: _camposR ? diferenciaR.toString() : '0',

      contadorInicialC: cInicialCompleto,
      contadorFinalC: cFinalCompleto,
      saltosenC: int.tryParse(_cSaltosController.text) ?? 0,
      contadorC: _camposC ? diferenciaC.toString() : '0',

      fechaReporte: _fechaController.text,
      observaciones: _observacionesController.text,
      incidencias: _incidenciasController.text,

      estado: 'pendiente',
      idOperador: operador.idOperador,
      estacionId: operador.idEstacion,
      nroEstacion: operador.nroEstacion.toString(),

      fechaCreacion: DateTime.now(),

      observacionC: _cObservacionesController.text,
      observacionR: _rObservacionesController.text,
      centroEmpadronamiento: _puntoEmpadronamientoId,
    );
  }

  // ===================================================================
  // CONSTRUCCIÓN DE WIDGETS (UI)
  // ===================================================================

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
              color: _gpsActivado ? Colors.lightGreenAccent : Colors.redAccent,
            ),
            onPressed: _verificarEstadoGPS,
            tooltip: _gpsActivado ? 'GPS Activado' : 'GPS Desactivado',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_gpsActivado)
              _buildBannerGPS(),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardInformacionGeneral(),
                  const SizedBox(height: 20),
                  _buildCamposEmpadronamiento(),
                  const SizedBox(height: 20),
                  _buildExpansionTileR(),
                  const SizedBox(height: 12),
                  _buildExpansionTileC(),
                  const SizedBox(height: 12),
                  _buildCardIncidencias(),
                  const SizedBox(height: 24),
                  _buildBotonesAccion(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerGPS() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GPS Desactivado', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                SizedBox(height: 4),
                Text('Active el GPS para enviar el reporte.', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: _abrirConfiguracionGPS,
            child: Text('ACTIVAR', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInformacionGeneral() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('INFORMACIÓN GENERAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 16),
            TextFormField(controller: _fechaController, decoration: InputDecoration(labelText: 'Fecha Reporte', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _codigoEstacionController, enabled: false, decoration: InputDecoration(labelText: 'Estación', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 12),
            TextFormField(controller: _transmitidoController, decoration: InputDecoration(labelText: 'ID Operador', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), enabled: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCamposEmpadronamiento() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UBICACIÓN DE EMPADRONAMIENTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
            const SizedBox(height: 16),
            _buildProvinciaDropdown(),
            const SizedBox(height: 12),
            _buildPuntoEmpadronamientoDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionTileR() {
    return ExpansionTile(
      key: Key('panel_r_${_camposR.toString()}'),
      maintainState: true,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_camposR) {
            AlertHelper.showConfirmRegistrarR(context: context, onConfirm: () => setState(() => _camposR = true));
          } else {
            _mostrarConfirmacionDesactivarR();
          }
        },
        child: Text('REGISTROS NUEVOS (R) ${_camposR ? '(Activado)' : ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _camposR ? Colors.blue : Colors.blue.withOpacity(0.7))),
      ),
      leading: Icon(Icons.receipt, color: _camposR ? Colors.blue : Colors.blue.withOpacity(0.7)),
      initiallyExpanded: _camposR,
      onExpansionChanged: (isExpanding) {
        if (isExpanding && !_camposR) AlertHelper.showConfirmRegistrarR(context: context, onConfirm: () => setState(() => _camposR = true));
        else if (!isExpanding && _camposR) _mostrarConfirmacionDesactivarR();
      },
      collapsedBackgroundColor: _camposR ? Colors.blue.shade50 : Colors.grey.shade100,
      backgroundColor: _camposR ? Colors.blue.shade50 : Colors.grey.shade100,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCampoConFormatoCompleto(label: 'R Inicial', controller4Digitos: _rInicialiController, controllerDigitoFinal: _rInicialDigitoFinalController, esR: true, esInicial: true),
              const SizedBox(height: 12),
              _buildCampoConFormatoCompleto(label: 'R Final', controller4Digitos: _rFinalController, controllerDigitoFinal: _rFinalDigitoFinalController, esR: true, esInicial: false),
              const SizedBox(height: 12),
              TextFormField(controller: _rSaltosController, decoration: InputDecoration(labelText: 'Saltos en registro R (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, onChanged: (v) => _calcularDiferencia()),
              const SizedBox(height: 12),
              TextFormField(readOnly: true, controller: _rTotal, decoration: InputDecoration(labelText: 'TOTAL REGISTROS R', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.blue.shade50, prefixIcon: const Icon(Icons.house, color: Colors.blue)), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(controller: _rObservacionesController, maxLines: 3, decoration: InputDecoration(labelText: 'Observacion R (Opcional)', hintText: 'Ingrese observaciones de registro R...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionTileC() {
    return ExpansionTile(
      key: Key('panel_c_${_camposC.toString()}'),
      maintainState: true,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_camposC) {
            AlertHelper.showConfirmRegistrarC(context: context, onConfirm: () => setState(() => _camposC = true));
          } else {
            _mostrarConfirmacionDesactivarC();
          }
        },
        child: Text('REGISTROS CAMBIO DE DOMICILIO (C) ${_camposC ? '(Activado)' : ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _camposC ? Colors.orange : Colors.orange.withOpacity(0.7))),
      ),
      leading: Icon(Icons.home_work, color: _camposC ? Colors.orange : Colors.orange.withOpacity(0.7)),
      initiallyExpanded: _camposC,
      onExpansionChanged: (isExpanding) {
        if (isExpanding && !_camposC) AlertHelper.showConfirmRegistrarC(context: context, onConfirm: () => setState(() => _camposC = true));
        else if (!isExpanding && _camposC) _mostrarConfirmacionDesactivarC();
      },
      collapsedBackgroundColor: _camposC ? Colors.orange.shade50 : Colors.grey.shade100,
      backgroundColor: _camposC ? Colors.orange.shade50 : Colors.grey.shade100,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCampoConFormatoCompleto(label: 'C Inicial', controller4Digitos: _cInicialiController, controllerDigitoFinal: _cInicialDigitoFinalController, esR: false, esInicial: true),
              const SizedBox(height: 12),
              _buildCampoConFormatoCompleto(label: 'C Final', controller4Digitos: _cFinalController, controllerDigitoFinal: _cFinalDigitoFinalController, esR: false, esInicial: false),
              const SizedBox(height: 12),
              TextFormField(controller: _cSaltosController, decoration: InputDecoration(labelText: 'Saltos en registro C (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, onChanged: (v) => _calcularDiferencia()),
              const SizedBox(height: 12),
              TextFormField(readOnly: true, controller: _cTotal, decoration: InputDecoration(labelText: 'TOTAL REGISTROS C', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.orange.shade50, prefixIcon: const Icon(Icons.swap_horiz, color: Colors.orange)), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(controller: _cObservacionesController, maxLines: 3, decoration: InputDecoration(labelText: 'Observacion C (Opcional)', hintText: 'Ingrese observaciones de registro C...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardIncidencias() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('INCIDENCIAS ADICIONALES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
            const SizedBox(height: 16),
            TextFormField(controller: _incidenciasController, maxLines: 4, decoration: InputDecoration(labelText: 'Incidencias de Reporte Diario', hintText: 'Ingrese sus incidente aquí...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _enviarReporte,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Text('ENVIAR REPORTE', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _cleanFormulario,
            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('LIMPIAR FORMULARIO', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoConFormatoCompleto({required String label, required TextEditingController controller4Digitos, required TextEditingController controllerDigitoFinal, required bool esR, required bool esInicial}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade400), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))), child: Text('${esR ? 'R' : 'C'}-$_equipoId-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Expanded(child: TextFormField(controller: controller4Digitos, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: '0000', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14), counterText: ''), keyboardType: TextInputType.number, maxLength: 4, onChanged: (v) => esR ? _validarRegistroR(v, controller4Digitos, controllerDigitoFinal, esInicial) : _validarRegistroC(v, controller4Digitos, controllerDigitoFinal, esInicial))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)), child: const Text('-', style: TextStyle(fontSize: 14))),
              SizedBox(width: 60, child: TextFormField(controller: controllerDigitoFinal, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: '0', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14), counterText: ''), keyboardType: TextInputType.number, maxLength: 1, onChanged: (v) => _validarDigitoFinal(v, controllerDigitoFinal, controller4Digitos, esR, esInicial))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('Formato: ${esR ? 'R' : 'C'}-$_equipoId-xxxx-N', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // ===================================================================
  // MÉTODOS AUXILIARES
  // ===================================================================

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
      if (_userData?.operador != null) {
        setState(() {
          final operador = _userData!.operador!;
          _transmitidoController.text = operador.idOperador.toString();
          _codigoEstacionController.text = 'Estación: ${operador.nroEstacion ?? 'N/A'}';
          _equipoId = (operador.nroEstacion ?? '0').toString().padLeft(5, '0');
          print('📱 Número de Estación configurado: $_equipoId');
        });
      }
    } catch (e) {
      print('❌ Error cargando datos de usuario: $e');
    }
  }

  String _buildFormatoR(String cuatroDigitos, String digitoFinal) {
    return 'R-$_equipoId-${cuatroDigitos.padLeft(4, '0')}-${digitoFinal.padLeft(1, '0')}';
  }

  String _buildFormatoC(String cuatroDigitos, String digitoFinal) {
    return 'C-$_equipoId-${cuatroDigitos.padLeft(4, '0')}-${digitoFinal.padLeft(1, '0')}';
  }

  void _validarRegistroR(String valor, TextEditingController controller, TextEditingController digitoFinalController, bool esInicial) {
    String limpio = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (limpio.length > 4) limpio = limpio.substring(0, 4);
    if (limpio != valor) {
      controller.text = limpio;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: limpio.length));
    }
    print('📝 R ${esInicial ? 'Inicial' : 'Final'} formateado: ${_buildFormatoR(limpio, digitoFinalController.text)}');
    _calcularDiferencia();
  }

  void _validarRegistroC(String valor, TextEditingController controller, TextEditingController digitoFinalController, bool esInicial) {
    String limpio = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (limpio.length > 4) limpio = limpio.substring(0, 4);
    if (limpio != valor) {
      controller.text = limpio;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: limpio.length));
    }
    print('📝 C ${esInicial ? 'Inicial' : 'Final'} formateado: ${_buildFormatoC(limpio, digitoFinalController.text)}');
    _calcularDiferencia();
  }

  void _validarDigitoFinal(String valor, TextEditingController controller, TextEditingController cuatroDigitosController, bool esR, bool esInicial) {
    String limpio = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (limpio.length > 1) limpio = limpio.substring(0, 1);
    if (limpio != valor) {
      controller.text = limpio;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: limpio.length));
    }
    if (esR) {
      _validarRegistroR(cuatroDigitosController.text, cuatroDigitosController, controller, esInicial);
    } else {
      _validarRegistroC(cuatroDigitosController.text, cuatroDigitosController, controller, esInicial);
    }
    final formatoCompleto = esR
        ? _buildFormatoR(cuatroDigitosController.text.padLeft(4, '0'), limpio.isEmpty ? '0' : limpio)
        : _buildFormatoC(cuatroDigitosController.text.padLeft(4, '0'), limpio.isEmpty ? '0' : limpio);
    print('🎯 ${esR ? 'R' : 'C'} ${esInicial ? 'Inicial' : 'Final'}: $formatoCompleto');
  }

  void _calcularDiferencia() {
    final rInicial = int.tryParse(_rInicialiController.text) ?? 0;
    final rFinal = int.tryParse(_rFinalController.text) ?? 0;
    final rSaltos = int.tryParse(_rSaltosController.text) ?? 0;
    if (rFinal >= rInicial) {
      setState(() {
        diferenciaR = (rFinal - rInicial + 1) - rSaltos;
        _rTotal.text = diferenciaR.toString();
      });
    } else {
      setState(() => _rTotal.clear());
    }

    final cInicial = int.tryParse(_cInicialiController.text) ?? 0;
    final cFinal = int.tryParse(_cFinalController.text) ?? 0;
    final cSaltos = int.tryParse(_cSaltosController.text) ?? 0;
    if (cFinal >= cInicial) {
      setState(() {
        diferenciaC = (cFinal - cInicial + 1) - cSaltos;
        _cTotal.text = diferenciaC.toString();
      });
    } else {
      setState(() => _cTotal.clear());
    }
  }

  void _mostrarConfirmacionDesactivarR() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar Registros R', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        content: const Text('¿Estás seguro de que quieres desactivar los Registros Nuevos (R)?\n\nLos datos ingresados se perderán.', style: TextStyle(fontSize: 14)),
        backgroundColor: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
          ElevatedButton(onPressed: () { Navigator.of(ctx).pop(); setState(() { _camposR = false; _registroRenCero(); }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('DESACTIVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _mostrarConfirmacionDesactivarC() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar Registros C', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        content: const Text('¿Estás seguro de que quieres desactivar los Registros de Cambio de Domicilio (C)?\n\nLos datos ingresados se perderán.', style: TextStyle(fontSize: 14)),
        backgroundColor: Colors.orange.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
          ElevatedButton(onPressed: () { Navigator.of(ctx).pop(); setState(() { _camposC = false; _registroCenCero(); }); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('DESACTIVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _verificarEstadoGPS() async {
    final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _gpsActivado = servicioHabilitado);
    print('📍 Estado GPS: ${servicioHabilitado ? "ACTIVADO" : "DESACTIVADO"}');
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
    await Geolocator.openLocationSettings();
  }

  void _mostrarDialogoActivacionGPS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GPS Requerido', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_off, size: 48, color: Colors.orange), SizedBox(height: 16), Text('Para enviar el reporte, necesitas activar el GPS.')]),
        actions: [
          TextButton(onPressed: () { Navigator.of(ctx).pop(); setState(() => _ubicacionRequerida = false); _enviarReporte(); }, child: const Text('ENVIAR SIN UBICACIÓN', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { Navigator.of(ctx).pop(); _abrirConfiguracionGPS(); }, child: const Text('ACTIVAR GPS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildProvinciaDropdown() {
    return DropdownButtonFormField<String>(
      value: _provinciaSeleccionada,
      decoration: InputDecoration(labelText: 'Provincia/Municipio *', hintText: 'Seleccione una provincia', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.location_city)),
      isExpanded: true,
      items: _provincias.map((p) => DropdownMenuItem<String>(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (p) => _onProvinciaSeleccionada(p),
      validator: (v) => v == null || v.isEmpty ? 'Seleccione una provincia' : null,
    );
  }

  Widget _buildPuntoEmpadronamientoDropdown() {
    return DropdownButtonFormField<String>(
      value: _puntoEmpadronamientoSeleccionado,
      decoration: InputDecoration(labelText: 'Punto de Empadronamiento *', hintText: _provinciaSeleccionada != null ? (_puntosEmpadronamiento.isEmpty ? 'Cargando...' : 'Seleccione un punto') : 'Primero seleccione provincia', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.place)),
      isExpanded: true,
      items: _puntosEmpadronamiento.map((p) => DropdownMenuItem<String>(value: p, child: Text(p, overflow: TextOverflow.ellipsis, maxLines: 2))).toList(),
      onChanged: (_provinciaSeleccionada != null && _puntosEmpadronamiento.isNotEmpty) ? (p) => _onPuntoEmpadronamientoSeleccionado(p) : null,
      validator: (v) => (_provinciaSeleccionada != null && (v == null || v.isEmpty)) ? 'Seleccione un punto' : null,
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
      final puntos = await _puntoService.getPuntosByProvincia(provincia);
      if (mounted) setState(() => _puntosEmpadronamiento = puntos.map((p) => p.puntoEmpadronamiento).toList());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar puntos: $e'), backgroundColor: Colors.red));
    }
  }

  void _onPuntoEmpadronamientoSeleccionado(String? punto) async {
    if (punto == null) return;
    setState(() => _puntoEmpadronamientoSeleccionado = punto);
    try {
      final puntos = await _puntoService.getPuntosByProvincia(_provinciaSeleccionada!);
      final puntoSeleccionado = puntos.firstWhere((p) => p.puntoEmpadronamiento == punto, orElse: () => PuntoEmpadronamiento(id: 0, provincia: '', puntoEmpadronamiento: ''));
      if (puntoSeleccionado.id != 0) {
        setState(() => _puntoEmpadronamientoId = puntoSeleccionado.id);
        print('✅ Punto de empadronamiento seleccionado: ID: $_puntoEmpadronamientoId, Nombre: $punto');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar punto: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _cargarDatosEmpadronamiento() async {
    try {
      final provincias = await _puntoService.getProvinciasFromLocalDatabase();
      if (mounted) setState(() => _provincias = provincias);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar provincias: $e'), backgroundColor: Colors.red));
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
      _fechaController.text = DateTime.now().toIso8601String().split('T').first;
      diferenciaC = 0;
      diferenciaR = 0;
      _camposR = false;
      _camposC = false;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formulario limpiado'), backgroundColor: Colors.blueGrey));
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

  Future<void> _mostrarAlertaError(String mensaje) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.error, size: 28, color: Colors.red.shade700), const SizedBox(width: 12), const Text('❌ Error de Validación', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18))]),
        content: Text(mensaje, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), style: TextButton.styleFrom(foregroundColor: Colors.red.shade700), child: const Text('CORREGIR', style: TextStyle(fontWeight: FontWeight.bold)))],
      ),
    );
  }

  Future<void> _mostrarAlertaResultado({required bool exito, required bool sincronizado, String? mensaje}) async {
    String titulo;
    Color colorFondo, colorTexto;
    IconData icono;

    if (exito) {
      if (sincronizado) {
        titulo = '✅ Reporte Enviado';
        colorFondo = Colors.green.shade50;
        colorTexto = Colors.green.shade800;
        icono = Icons.check_circle;
      } else {
        titulo = '📱 Reporte Guardado Localmente';
        colorFondo = Colors.orange.shade50;
        colorTexto = Colors.orange.shade800;
        icono = Icons.save;
      }
    } else {
      titulo = '❌ Error';
      colorFondo = Colors.red.shade50;
      colorTexto = Colors.red.shade800;
      icono = Icons.error;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorFondo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icono, size: 28, color: colorTexto),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorTexto))),
        ]),
        content: Text(mensaje ?? 'Operación completada.', style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('ACEPTAR', style: TextStyle(fontWeight: FontWeight.bold, color: colorTexto)))],
      ),
    );
  }

  Future<bool?> _mostrarDialogoConfirmacionR() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Valores R Ingresados', style: TextStyle(color: Colors.orange)),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Has ingresado valores en los campos R, pero la sección está deshabilitada.\n¿Qué deseas hacer?')]),
        actionsPadding: const EdgeInsets.all(12),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), child: const Text('ACTIVAR SECC. R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('LIMPIAR VALORES')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('CANCELAR')),
            ],
          )
        ],
      ),
    );
  }

  Future<bool?> _mostrarDialogoConfirmacionC() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Valores C Ingresados', style: TextStyle(color: Colors.orange)),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Has ingresado valores en los campos C, pero la sección está deshabilitada.\n¿Qué deseas hacer?')]),
        actionsPadding: const EdgeInsets.all(12),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('ACTIVAR SECC. C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('LIMPIAR VALORES')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('CANCELAR')),
            ],
          ),
        ],
      ),
    );
  }
}
