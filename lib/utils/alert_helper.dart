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
}
