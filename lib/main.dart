// lib/main.dart

import 'package:flutter/material.dart';
import 'package:manager_key/services/reporte_sync_manager.dart';
import 'package:provider/provider.dart';
import 'package:manager_key/services/auth_service.dart';
import 'package:manager_key/services/reporte_sync_service.dart';
import 'package:manager_key/services/ubicacion_service.dart';
import 'package:manager_key/services/location_service.dart';
import 'package:manager_key/services/connectivity_service.dart';
import 'package:manager_key/services/database_service.dart';
import 'package:manager_key/views/login_page.dart';

// Imports para el servicio en segundo plano
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';

// ✅⭐ NUEVO IMPORT PARA EL SERVICIO DE PERMISOS ⭐✅
import 'package:manager_key/services/permission_service.dart';


// --- PUNTO DE ENTRADA DEL SERVICIO (SIN CAMBIOS) ---
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  debugPrint('✅ Servicio de fondo [onStart] - Iniciado');

  // Instanciamos los servicios necesarios en este Isolate
  final UbicacionService ubicacionService = UbicacionService();
  final DatabaseService databaseService = DatabaseService();
  final ConnectivityService connectivityService = ConnectivityService();
  final LocationService locationService = LocationService();

  // Es necesario inicializar los servicios
  databaseService.initializeDatabase();
  connectivityService.initialize();
  ubicacionService.initialize(
    locationService: locationService,
    connectivityService: connectivityService,
    databaseService: databaseService,
  );

  // Tarea periódica
  Timer.periodic(const Duration(minutes: 7), (timer) async {
    debugPrint('🛰️ [Background Service] Intentando registrar ubicación...');
    await ubicacionService.registrarUbicacion();
  });
}

// --- CONFIGURACIÓN DEL SERVICIO (SIN CAMBIOS) ---
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const String notificationChannelId = 'manager_key_foreground';
  const String notificationTitle = 'Manager Key';
  const String notificationContent = 'Monitoreo de ubicación activo';

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: notificationTitle,
      initialNotificationContent: notificationContent,
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

// ✅⭐ FUNCIÓN MAIN CORREGIDA ⭐✅
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. GESTIONAR PERMISOS PRIMERO ---
  // Se solicitan los permisos al usuario ANTES de inicializar cualquier servicio que los necesite.
  final permissionService = PermissionService();
  await permissionService.handleLocationPermission();

  // --- 2. INICIALIZAR EL SERVICIO DE FONDO ---
  // Ahora es seguro inicializarlo, ya que los permisos han sido solicitados.
  await initializeService();

  // --- 3. INICIALIZAR EL RESTO DE SERVICIOS ---
  final databaseService = DatabaseService();
  await databaseService.initializeDatabase();

  final connectivityService = ConnectivityService();
  connectivityService.initialize();

  final locationService = LocationService();

  // --- 4. CORRER LA APP ---
  runApp(
    MultiProvider(
      providers: [
        // Se inyecta el nuevo servicio de permisos para poder usarlo en otras partes si es necesario
        Provider<PermissionService>.value(value: permissionService),
        Provider<DatabaseService>.value(value: databaseService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<LocationService>.value(value: locationService),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ReporteSyncManager>(create: (_) => ReporteSyncManager()),
        Provider<UbicacionService>(
          create: (context) {
            final ubicacionService = UbicacionService();
            ubicacionService.initialize(
              locationService: context.read<LocationService>(),
              connectivityService: context.read<ConnectivityService>(),
              databaseService: context.read<DatabaseService>(),
            );
            return ubicacionService;
          },
        ),
        Provider<ReporteSyncService>(
          create: (context) => ReporteSyncService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manager Key',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(),
    );
  }
}
