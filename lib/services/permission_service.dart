// lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Solicita y verifica todos los permisos necesarios para la app.
  /// Especialmente los de ubicación para el servicio de fondo.
  Future<bool> handleLocationPermission() async {
    // 1. Verifica si el servicio de ubicación está habilitado en el dispositivo
    bool serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      print('⚠️ El servicio de GPS está deshabilitado.');
      // Aquí podrías usar geolocator para pedir al usuario que lo active
      // o simplemente devolver false. Por ahora, devolvemos false.
      return false;
    }

    // 2. Verifica el estado del permiso de ubicación
    PermissionStatus status = await Permission.location.status;
    if (status.isDenied) {
      // Si es la primera vez, solicita el permiso
      status = await Permission.location.request();
      if (status.isDenied) {
        print('❌ Permiso de ubicación denegado por el usuario.');
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      print('❌ Permiso de ubicación denegado permanentemente. Abrir ajustes.');
      // Opcional: abrir los ajustes de la app para que el usuario los active manualmente
      await openAppSettings();
      return false;
    }

    // 3. Si el permiso de ubicación está concedido, solicita el permiso de ubicación en segundo plano
    if (status.isGranted) {
      PermissionStatus backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus.isDenied) {
        backgroundStatus = await Permission.locationAlways.request();
        if (!backgroundStatus.isGranted) {
          print('⚠️ Permiso de ubicación en segundo plano no concedido.');
          // La app puede funcionar, pero el tracking de fondo será limitado.
        }
      }
    }

    print('✅ Todos los permisos de ubicación están en orden.');
    return true;
  }
}
