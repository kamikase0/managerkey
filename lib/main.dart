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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa los servicios que no dependen de otros
  final databaseService = DatabaseService();
  await databaseService.initializeDatabase();

  final connectivityService = ConnectivityService();
  connectivityService.initialize();

  final locationService = LocationService();

  runApp(
    MultiProvider(
      providers: [
        // Servicios que no dependen de otros
        Provider<DatabaseService>.value(value: databaseService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<LocationService>.value(value: locationService),

        // Servicios que pueden depender de otros
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ReporteSyncManager>(create: (_) => ReporteSyncManager()),


        // UbicacionService depende de varios servicios
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

        // ✅ CORRECCIÓN FINAL:
        // 1. Usa 'Provider' en lugar de 'ChangeNotifierProvider'.
        // 2. Llama al constructor sin argumentos, ya que no los define.
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
