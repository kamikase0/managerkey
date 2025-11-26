import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

class AlertHelper {
  // Singleton pattern
  static final AlertHelper _instance = AlertHelper._internal();

  factory AlertHelper() => _instance;

  AlertHelper._internal();

  // Alerta de éxito
  static void showSuccess({
    required BuildContext context,
    String title = '¡Éxito!',
    String text = 'Operación completada correctamente',
    int autoCloseSeconds = 2,
    VoidCallback? onConfirm,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title,
      text: text,
      autoCloseDuration: Duration(seconds: autoCloseSeconds),
      onConfirmBtnTap: onConfirm,
    );
  }

  // Alerta de error
  static void showError({
    required BuildContext context,
    String title = 'Error',
    String text = 'Algo salió mal. Por favor intenta nuevamente.',
    VoidCallback? onConfirm,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: title,
      text: text,
      onConfirmBtnTap: onConfirm,
    );
  }

  // Alerta de advertencia
  static void showWarning({
    required BuildContext context,
    String title = 'Advertencia',
    String text = 'Esta acción no se puede deshacer',
    VoidCallback? onConfirm,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.warning,
      title: title,
      text: text,
      onConfirmBtnTap: onConfirm,
    );
  }

  // Alerta de información
  static void showInfo({
    required BuildContext context,
    String title = 'Información',
    String text = 'Esta es una alerta informativa',
    int autoCloseSeconds = 2,
    VoidCallback? onConfirm,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.info,
      title: title,
      text: text,
      autoCloseDuration: Duration(seconds: autoCloseSeconds),
      onConfirmBtnTap: onConfirm,
    );
  }

  // Alerta de confirmación
  static void showConfirm({
    required BuildContext context,
    String title = '¿Estás seguro?',
    String text = 'Esta acción no se puede deshacer',
    String confirmText = 'Sí',
    String cancelText = 'No',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: title,
      text: text,
      confirmBtnText: confirmText,
      cancelBtnText: cancelText,
      onConfirmBtnTap: () {
        Navigator.pop(context);
        onConfirm();
      },
      onCancelBtnTap: () {
        Navigator.pop(context);
        onCancel?.call();
      },
    );
  }


  // ✅ ALERTA DE CONFIRMACIÓN DE SALIDA (ya la tienes en home_page.dart)
  static Future<bool> mostrarDialogoDeSalida(BuildContext context) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Confirmar Salida'),
          content: const Text('¿Estás seguro de que quieres cerrar la sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('NO', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('SÍ, SALIR', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    return resultado ?? false;
  }

  // En tu archivo alert_helper.dart

  /// =======================================================
  /// ✅ NUEVA ALERTA: Confirmación para registrar C
  /// =======================================================
  /// Muestra una alerta para preguntar si se desea registrar "Cambio de Domicilio (C)".
  // static void showConfirmRegistrarC({
  //   required BuildContext context,
  //   required VoidCallback onConfirm,
  //   VoidCallback? onCancel,
  // }) {
  //   QuickAlert.show(
  //     context: context,
  //     type: QuickAlertType.confirm,
  //     title: 'Registros Cambio de Domicilio (C)',
  //     text: '¿Deseas registrar formularios de "Cambio de Domicilio"?',
  //     confirmBtnText: 'Sí, registrar',
  //     cancelBtnText: 'No, ahora no',
  //     confirmBtnColor: Colors.orange, // Color temático para 'C'
  //     onConfirmBtnTap: () {
  //       Navigator.pop(context);
  //       onConfirm();
  //     },
  //     onCancelBtnTap: () {
  //       Navigator.pop(context);
  //       onCancel?.call();
  //     },
  //   );
  // }


  // Alerta de carga
  static void showLoading({
    required BuildContext context,
    String title = 'Cargando',
    String text = 'Procesando información...',
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: title,
      text: text,
      barrierDismissible: false,
    );
  }

  // Cerrar alerta actual
  static void closeLoading(BuildContext context) {
    Navigator.pop(context);
  }

  // Alerta personalizada
  static void showCustom({
    required BuildContext context,
    required Widget widget,
    String title = '¡Personalizado!',
    String text = 'Alerta completamente personalizable',
    String confirmText = 'Genial',
    Color confirmColor = Colors.deepPurple,
    QuickAlertAnimType animType = QuickAlertAnimType.slideInUp,
    VoidCallback? onConfirm,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.custom,
      barrierColor: Colors.black54,
      title: title,
      text: text,
      widget: widget,
      confirmBtnText: confirmText,
      confirmBtnColor: confirmColor,
      animType: animType,
      onConfirmBtnTap: onConfirm,
    );
  }

  // Proceso con loading y resultado
  static Future<void> executeWithLoading({
    required BuildContext context,
    required Future<void> Function() action,
    String loadingTitle = 'Cargando',
    String loadingText = 'Procesando...',
    String successTitle = '¡Éxito!',
    String successText = 'Operación completada',
    String errorTitle = 'Error',
    String errorText = 'Algo salió mal',
  }) async {
    showLoading(context: context, title: loadingTitle, text: loadingText);

    try {
      await action();
      closeLoading(context);
      showSuccess(context: context, title: successTitle, text: successText);
    } catch (e) {
      closeLoading(context);
      showError(context: context, title: errorTitle, text: '$errorText: $e');
    }
  }

  //alert personalizada para errores de conexion
  static void showConnectionError({
    required BuildContext context,
    String message = 'Error de conexión',
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: 'Error de conexión',
      text: message,
      confirmBtnText: 'Reintentar',
    );
  }

// Alerta con acciones personalizadas
  static void showCustomAction({
    required BuildContext context,
    required String title,
    required String text,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    Color confirmColor = Colors.blue,
  }) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: title,
      text: text,
      confirmBtnText: confirmText,
      cancelBtnText: cancelText,
      confirmBtnColor: confirmColor,
      onConfirmBtnTap: () {
        Navigator.pop(context);
        onConfirm();
      },
      onCancelBtnTap: () {
        Navigator.pop(context);
        onCancel?.call();
      },
    );
  }


  // En AlertHelper - Versiones mejoradas
  static void showConfirmRegistrarR({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Activar Registros R',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Deseas activar los Registros Nuevos (R)?\n\n'
                'Podrás ingresar los valores iniciales y finales para el conteo de registros nuevos.',
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
                'NO, GRACIAS',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'SÍ, ACTIVAR',
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

  static void showConfirmRegistrarC({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.home_work, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Activar Registros C',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Deseas activar los Registros de Cambio de Domicilio (C)?\n\n'
                'Podrás ingresar los valores iniciales y finales para el conteo de cambios de domicilio.',
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
                'NO, GRACIAS',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'SÍ, ACTIVAR',
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

}
