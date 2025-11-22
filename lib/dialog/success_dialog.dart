import 'package:flutter/material.dart';

class SuccessDialog extends StatefulWidget {
  final String? title;
  final String? message;
  final Duration duration;
  final VoidCallback? onDismiss;

  const SuccessDialog({
    Key? key,
    this.title = 'Éxito',
    this.message = 'Operación completada',
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  }) : super(key: key);

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador de animación
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animación de escala (pop)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Animación de rotación
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Iniciar animación
    _controller.forward();

    // Cerrar después de 3 segundos
    Future.delayed(widget.duration, () {
      if (mounted) {
        Navigator.pop(context);
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Contenido principal
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono animado con rotación
                    RotationTransition(
                      turns: _rotationAnimation,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            size: 50,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Título
                    Text(
                      widget.title ?? 'Éxito',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Mensaje
                    Text(
                      widget.message ?? 'Operación completada',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Indicador de progreso (línea que se reduce)
                    LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade600,
                      ),
                      value: 1.0,
                    ),
                  ],
                ),
              ),
              // Botón cerrar en la esquina superior derecha
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey.shade600,
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

// // ========== EJEMPLO DE USO EN TU LLEGADA RUTA VIEW ==========
//
// class LlegadaRutaViewExample extends StatelessWidget {
//   const LlegadaRutaViewExample({Key? key}) : super(key: key);
//
//   void _mostrarExito(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return SuccessDialog(
//           title: 'Llegada Registrada',
//           message: 'Se registró correctamente en Quime, Inquisivi',
//           duration: const Duration(seconds: 3),
//           onDismiss: () {
//             // Aquí puedes hacer algo después de que se cierre
//             print('✅ Diálogo cerrado después de 3 segundos');
//           },
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Ejemplo')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () => _mostrarExito(context),
//           child: const Text('Mostrar Success Dialog'),
//         ),
//       ),
//     );
//   }
// }