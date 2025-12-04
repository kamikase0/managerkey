import 'package:flutter/material.dart';
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
  // ✅ CORRECCIÓN: El método initialize() ahora existe en ConnectivityService
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

        // ReporteSyncService
        ChangeNotifierProvider(
          create: (context) => ReporteSyncService(
            databaseService: context.read<DatabaseService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
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


// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:manager_key/services/database_service.dart';
// import 'package:manager_key/views/home_page.dart';
// import 'package:manager_key/views/login_page.dart';
// import 'package:provider/provider.dart';
// import 'firebase_options.dart';
// import 'services/reporte_sync_service.dart';
// import 'services/auth_service.dart';
// import 'services/api_service.dart';
//
// // ✅ CORREGIDO: Función principal de la aplicación
// void main() async {
//   // Asegura que los bindings de Flutter estén inicializados
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Inicializa Firebase
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   print('✅ Aplicación iniciando...');
//
//   // Crea las instancias de los servicios
//   final authService = AuthService();
//   final databaseService = DatabaseService();
//   final apiService = ApiService(authService: authService);
//
//   print('✅ Servicios instanciados.');
//
//   // ✅ CORRECCIÓN: AÑADIR AQUÍ LA INICIALIZACIÓN Y VERIFICACIÓN DE BD
//   print('🔧 Inicializando y verificando base de datos...');
//   try {
//     // 1. Verificar y reparar estructura de la BD
//     await databaseService.verificarYRepararEstructura();
//
//     // 2. Diagnosticar para verificar que todo está bien
//     final diagnostico = await databaseService.diagnosticarTablaRegistros();
//     print('🔍 Diagnóstico BD: $diagnostico');
//
//     // 3. Forzar migración si se detectan problemas (opcional)
//     if (!diagnostico['tiene_operador_id'] ||
//         !diagnostico['tiene_centro_empadronamiento_id']) {
//       print('⚠️ Problemas detectados, forzando migración...');
//       await databaseService.migracionForzadaV10();
//     }
//
//     // 4. Asegurar que todas las tablas estén creadas
//     await databaseService.ensureTablesCreated();
//
//     print('✅ Base de datos inicializada y verificada correctamente');
//   } catch (e) {
//     print('❌ Error al inicializar base de datos: $e');
//     // Continuar de todos modos, la app intentará crear las tablas cuando sea necesario
//   }
//
//   // Ejecuta la aplicación inyectando los servicios con MultiProvider
//   runApp(
//     MultiProvider(
//       providers: [
//         // ✅ SERVICIOS SIN ESTADO (Provider.value)
//         Provider<AuthService>.value(value: authService),
//         Provider<DatabaseService>.value(value: databaseService),
//         Provider<ApiService>.value(value: apiService),
//
//         // ✅ CORREGIDO: Usar ChangeNotifierProvider para ReporteSyncService
//         ChangeNotifierProvider<ReporteSyncService>(
//           create: (context) => ReporteSyncService(databaseService, authService),
//         ),
//       ],
//       child: const MyApp(),
//     ),
//   );
// }
//
// // Widget raíz de la aplicación
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Manager Key',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         useMaterial3: true,
//         scaffoldBackgroundColor: Colors.grey[100],
//       ),
//       home: const AuthWrapper(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }
//
// // Widget para controlar el flujo de autenticación
// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});
//
//   // Función de logout
//   static Future<void> _handleLogout(BuildContext context) async {
//     final authService = context.read<AuthService>();
//     await authService.logout();
//
//     // Navega a LoginPage y elimina todas las rutas anteriores
//     if (context.mounted) {
//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(builder: (context) => const LoginPage()),
//             (route) => false,
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<bool>(
//       // Verifica si el usuario está autenticado al iniciar
//       future: context.read<AuthService>().isAuthenticated(),
//       builder: (context, snapshot) {
//         // Muestra un indicador de carga mientras se verifica el estado
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(
//               child: CircularProgressIndicator(),
//             ),
//           );
//         }
//
//         // Si el usuario está autenticado, muestra HomePage
//         if (snapshot.hasData && snapshot.data == true) {
//           return HomePage(
//             // Pasa la función de logout al HomePage
//             onLogout: () => _handleLogout(context),
//           );
//         }
//
//         // Si no, muestra LoginPage
//         return const LoginPage();
//       },
//     );
//   }
//
//
//
// }