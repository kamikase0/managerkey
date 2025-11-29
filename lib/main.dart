import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:manager_key/views/home_page.dart';
import 'package:manager_key/views/login_page.dart';
import 'package:manager_key/views/operador/reporte_historial_view.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'firebase_options.dart';
import 'services/reporte_sync_service.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'views/operador/reporte_diario_view.dart';

// import 'pages/login_page.dart';
// import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar base de datos SQLite
  final database = await openDatabase(
    join(await getDatabasesPath(), 'manager_key.db'),
    version: 1,
    onCreate: (db, version) async {
      print('📝 Base de datos SQLite creada');
    },
  );

  // Inicializar ReporteSyncService
  final reporteSyncService = ReporteSyncService();
  await reporteSyncService.initializeDatabase(database);

  // Inyectar ReporteSyncService en AuthService
  AuthService().setReporteSyncService(reporteSyncService);

  runApp(
    MultiProvider(
      providers: [
        Provider<ReporteSyncService>(create: (_) => reporteSyncService),
        Provider<AuthService>(create: (_) => AuthService()),
        // ✅ NUEVO: Agregar ApiService a Provider
        Provider<ApiService?>(
          create: (_) => null,
          lazy: false,
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
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Widget wrapper para manejar autenticación
// Widget wrapper para manejar autenticación
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<AuthService>().isAuthenticated(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          // ✅ CORREGIDO:
          // 1. Se eliminó 'const'
          // 2. Se pasó una función anónima a onLogout
          return HomePage(
            onLogout: () => _handleLogout(context),
          );
        }

        return const LoginPage();
      },
    );
  }

  // ✅ NUEVO: Manejador de logout
  static void _handleLogout(BuildContext context) {
    // Es una buena práctica verificar si el widget sigue montado
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
    );
  }
}


// ✅ ELIMINADO: LoginScreen innecesario
// El login debe usar LoginPage en su lugar

// ✅ ELIMINADO: MainScreen innecesario
// El home debe usar HomePage en su lugar

// ✅ ELIMINADO: SyncManagementScreen innecesario
// Debe estar en HomePage

// ✅ NUEVO: Wrapper para HomePage (era HomePageWrapper)
// ✅ NUEVO: Wrapper para HomePage (era HomePageWrapper)
class HomePageWrapper extends StatelessWidget {
  const HomePageWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ CORREGIDO:
    // 1. Se eliminó 'const'
    // 2. Se pasó una función anónima a onLogout
    return HomePage(
      onLogout: () => _handleLogout(context),
    );
  }

  static void _handleLogout(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
    );
  }
}
