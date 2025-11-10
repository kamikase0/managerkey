import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formulario de Registro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6B4FA0),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 6,
            iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    home: const RecepcionView(),
    );
    }
}

class RecepcionView extends StatefulWidget {
  const RecepcionView({Key? key}) : super(key: key);

  @override
  State<RecepcionView> createState() => _RecepcionViewState();
}

class _RecepcionViewState extends State<RecepcionView> {
  final TextEditingController _serieController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();

  bool formularioPcPortatil = true;
  bool seleccionarTodos = true;
  bool recepcionKit = true;
  bool hojaActivos = true;
  bool tieneCargador = true;
  bool tieneMouse = true;

  void _toggleSeleccionarTodos() {
    setState(() {
      seleccionarTodos = !seleccionarTodos;
      recepcionKit = seleccionarTodos;
      hojaActivos = seleccionarTodos;
      tieneCargador = seleccionarTodos;
      tieneMouse = seleccionarTodos;
    });
  }

  void _updateSeleccionarTodos() {
    setState(() {
      seleccionarTodos = recepcionKit && hojaActivos && tieneCargador && tieneMouse;
    });
  }

  void _generarEtiqueta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etiqueta Generada'),
        content: const Text('Código de Etiqueta: BIOF-041'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarScannerOInput(TextEditingController controller, String titulo) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BarcodeScannerWidget(
                controller: controller,
                onCodeDetected: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serieController.dispose();
    _modeloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Camila Quspe', style: TextStyle(fontSize: 16)),
            Text(
              'Soporte Tecnico',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menú de pestañas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildTab(Icons.favorite_border, 'Favorites'),
                  const SizedBox(width: 16),
                  _buildTab(Icons.history, 'History'),
                  const SizedBox(width: 16),
                  _buildTab(Icons.person_add_outlined, 'Following'),
                  const Spacer(),
                  const Icon(Icons.calendar_today_outlined, size: 20),
                ],
              ),
            ),
            const Divider(height: 1),

            // Título de sección
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Recepción',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Formulario de Registro',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),

            // Opciones de registro con cámara y TextBox
            _buildCameraOptionWithInput(
              'Registrar de Serie',
              _serieController,
            ),
            _buildCameraOptionWithInput(
              'Registrar de Modelo',
              _modeloController,
            ),

            const SizedBox(height: 20),

            // Switch FORMULARIO PC PORTATIL
            _buildSwitchOption(
              'FORMULARIO PC PORTATIL',
              formularioPcPortatil,
                  (value) {
                setState(() {
                  formularioPcPortatil = value;
                });
              },
              showDivider: false,
            ),

            const Divider(height: 1),
            const SizedBox(height: 10),

            // Mostrar formulario según el switch
            if (formularioPcPortatil)
              _buildFormularioPortatil()
            else
              _buildFormularioEscritorio(),

            const SizedBox(height: 30),

            // Código de etiqueta
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Codigo Etiqueta',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Text(
                    'BIOF-041',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Botón generar etiqueta
            Center(
              child: ElevatedButton.icon(
                onPressed: _generarEtiqueta,
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text(
                  'Generar Etiqueta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4FA0),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ),
    );
  }

  Widget _buildFormularioPortatil() {
    return Column(
      children: [
        // Seleccionar todos
        _buildSwitchOption(
          'SELECCIONAR TODOS',
          seleccionarTodos,
              (value) => _toggleSeleccionarTodos(),
          showDivider: false,
        ),

        const Divider(height: 1),

        // Opciones con checkbox
        _buildCheckboxOption(
          'RC',
          'Recepcion kIT',
          recepcionKit,
          const Color(0xFFE8D4F8),
              (value) {
            setState(() {
              recepcionKit = value!;
              _updateSeleccionarTodos();
            });
          },
        ),

        _buildCheckboxOption(
          'HA',
          'Hoja de Activos',
          hojaActivos,
          const Color(0xFFE8D4F8),
              (value) {
            setState(() {
              hojaActivos = value!;
              _updateSeleccionarTodos();
            });
          },
        ),

        _buildCheckboxOption(
          '',
          'Tiene Cargador',
          tieneCargador,
          Colors.transparent,
              (value) {
            setState(() {
              tieneCargador = value!;
              _updateSeleccionarTodos();
            });
          },
        ),

        _buildCheckboxOption(
          '',
          'Tiene Mouse',
          tieneMouse,
          Colors.transparent,
              (value) {
            setState(() {
              tieneMouse = value!;
              _updateSeleccionarTodos();
            });
          },
        ),
      ],
    );
  }

  Widget _buildFormularioEscritorio() {
    return Column(
      children: [
        // Seleccionar todos
        _buildSwitchOption(
          'SELECCIONAR TODOS',
          seleccionarTodos,
              (value) => _toggleSeleccionarTodos(),
          showDivider: false,
        ),

        const Divider(height: 1),

        // Opciones con checkbox para PC Escritorio
        _buildCheckboxOption(
          'RC',
          'Recepcion kIT',
          recepcionKit,
          const Color(0xFFE8D4F8),
              (value) {
            setState(() {
              recepcionKit = value!;
              _updateSeleccionarTodos();
            });
          },
        ),

        _buildCheckboxOption(
          'HA',
          'Hoja de Activos',
          hojaActivos,
          const Color(0xFFE8D4F8),
              (value) {
            setState(() {
              hojaActivos = value!;
              _updateSeleccionarTodos();
            });
          },
        ),

        _buildCheckboxOption(
          '',
          'Tiene Mouse',
          tieneMouse,
          Colors.transparent,
              (value) {
            setState(() {
              tieneMouse = value!;
              _updateSeleccionarTodos();
            });
          },
        ),
      ],
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildCameraOptionWithInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => _mostrarScannerOInput(controller, label),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Ingrese el código manualmente',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6B4FA0), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOption(String label, bool value, Function(bool) onChanged, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF6B4FA0),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  Widget _buildCheckboxOption(
      String initials,
      String label,
      bool value,
      Color bgColor,
      Function(bool?) onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (initials.isNotEmpty)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B4FA0),
                  ),
                ),
              ),
            ),
          if (initials.isNotEmpty) const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6B4FA0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget del Scanner de Código de Barras
class BarcodeScannerWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onCodeDetected;

  const BarcodeScannerWidget({
    Key? key,
    required this.controller,
    required this.onCodeDetected,
  }) : super(key: key);

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanned = false;
  bool isTorchOn = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _toggleTorch() {
    setState(() {
      isTorchOn = !isTorchOn;
    });
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              MobileScanner(
                controller: cameraController,
                onDetect: (capture) {
                  if (!isScanned) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        setState(() {
                          isScanned = true;
                          widget.controller.text = code;
                        });
                        widget.onCodeDetected();
                      }
                    }
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6B4FA0), width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Escanee el código de barras',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coloque el código dentro del recuadro',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _toggleTorch,
                      icon: Icon(
                        isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: const Color(0xFF6B4FA0),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      onPressed: () => cameraController.switchCamera(),
                      icon: const Icon(
                        Icons.cameraswitch,
                        color: Color(0xFF6B4FA0),
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}