// main.dart (CORREGIDO - Versión Final)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';
import 'services/reporte_sync_service.dart';
import 'views/login_page.dart';
import 'views/home_page.dart'; // Ajusta según tu estructura

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar servicios
  final dbService = DatabaseService();
  final apiService = ApiService();

  // Inicializar base de datos
  await dbService.database;

  // Crear ReporteSyncService (sin inicializar aún, esperamos el token del login)
  final reporteSyncService = ReporteSyncService(
    databaseService: dbService,
    apiService: apiService,
  );

  runApp(MyApp(
    dbService: dbService,
    apiService: apiService,
    reporteSyncService: reporteSyncService,
  ));
}

class MyApp extends StatefulWidget {
  final DatabaseService dbService;
  final ApiService apiService;
  final ReporteSyncService reporteSyncService;

  const MyApp({
    required this.dbService,
    required this.apiService,
    required this.reporteSyncService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.reporteSyncService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reintentar sincronización cuando app regresa al foreground
    if (state == AppLifecycleState.resumed) {
      print('App reanudada - continuando sincronización de reportes...');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: widget.dbService),
        Provider<ApiService>.value(value: widget.apiService),
        Provider<ReporteSyncService>.value(value: widget.reporteSyncService),
      ],
      child: MaterialApp(
        title: 'Sistema de Reportes Rural',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: false, // Mantener compatibilidad con tu diseño
        ),
        home: const LoginPage(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => HomePage(
            onLogout: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        },
      ),
    );
  }
}