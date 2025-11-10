import 'dart:io';

class NetworkUtils {
  /// Verifica si hay conexión a Internet haciendo un ping a Google
  static Future<bool> verificarConexion() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException {
      return false;
    }
  }
}
