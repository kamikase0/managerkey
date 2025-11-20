import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';
import 'services/reporte_sync_service.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'services/ubicacion_service.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';
import 'widgets/connnectivity_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa servicios globales
  final dbService = DatabaseService();
  final authService = AuthService();
  final connectivityService = ConnectivityService();
  final locationService = LocationService();
  final ubicacionService = UbicacionService();

  // Inicializa la base de datos
  await dbService.database;

  // INICIALIZAR UbicacionService
  ubicacionService.initialize(
    locationService: locationService,
    connectivityService: connectivityService,
    databaseService: dbService,
  );

  // VERIFICAR SI HAY SESIÓN ACTIVA
  final isAuthenticated = await authService.isAuthenticated();
  if (isAuthenticated) {
    final user = await authService.getCurrentUser();
    final accessToken = await authService.getAccessToken();
    final idOperador = await authService.getIdOperador();

    // DEBUG: Mostrar información del usuario
    final userInfo = await authService.getUserInfo();
    print('DEBUG: Información del usuario: $userInfo');

    if (user != null && accessToken != null && idOperador != null) {
      final userType = authService.determinarTipoUsuario(user);
      ubicacionService.iniciarServicioUbicacion(
        idOperador, // ✅ Ahora es int, no int?
        userType,
        accessToken,
      );
      print('DEBUG: ✅ Servicio de ubicación reiniciado al iniciar app');
      print('DEBUG: ID Operador: $idOperador, Tipo: $userType');
    } else {
      print('DEBUG: ❌ Faltan datos para iniciar servicio de ubicación');
      print('DEBUG: User: ${user != null}, Token: ${accessToken != null}, IdOperador: $idOperador');
    }
  } else {
    print('DEBUG: ℹ️ No hay sesión activa al iniciar app');
  }

  runApp(
    MyApp(
      dbService: dbService,
      authService: authService,
      connectivityService: connectivityService,
      locationService: locationService,
      ubicacionService: ubicacionService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;
  final AuthService authService;
  final ConnectivityService connectivityService;
  final LocationService locationService;
  final UbicacionService ubicacionService;

  const MyApp({
    super.key,
    required this.dbService,
    required this.authService,
    required this.connectivityService,
    required this.locationService,
    required this.ubicacionService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<DatabaseService>.value(value: dbService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<LocationService>.value(value: locationService),
        Provider<UbicacionService>.value(value: ubicacionService),
        Provider<ApiService>(
          create: (context) => ApiService(authService: authService),
        ),
        Provider<ReporteSyncService>(
          create: (context) => ReporteSyncService(databaseService: dbService),
        ),
      ],
      child: MaterialApp(
        title: 'Sistema de Reportes Rural',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
        home: const AuthWrapper(),
        routes: {'/login': (context) => const LoginPage()},
      ),
    );
  }
}

// ... (AuthWrapper y HomePageWrapper se mantienen igual)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<AuthService>().isAuthenticated(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verificando autenticación...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Error en autenticación: ${snapshot.error}');
          return const LoginPage();
        }

        if (snapshot.hasData && snapshot.data!) {
          return ConnectivityHandler(
            customMessage: 'No se puede conectar con el servidor de reportes. '
                'Verifica tu conexión a internet y intenta nuevamente.',
            child: const HomePageWrapper(),
          );
        }

        return const LoginPage();
      },
    );
  }
}

class HomePageWrapper extends StatefulWidget {
  const HomePageWrapper({super.key});

  @override
  State<HomePageWrapper> createState() => _HomePageWrapperState();
}

class _HomePageWrapperState extends State<HomePageWrapper> {
  bool _isServiceInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final syncService = Provider.of<ReporteSyncService>(context, listen: false);
      final ubicacionService = Provider.of<UbicacionService>(context, listen: false);

      final accessToken = await authService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        await syncService.initialize(accessToken: accessToken);
        print('✅ SyncService inicializado correctamente');

        // INICIAR SERVICIO DE UBICACIÓN DESPUÉS DEL LOGIN
        final user = await authService.getCurrentUser();
        final idOperador = await authService.getIdOperador();

        if (user != null && idOperador != null) {
          final userType = authService.determinarTipoUsuario(user);
          ubicacionService.iniciarServicioUbicacion(
            idOperador, // ✅ Ahora es int
            userType,
            accessToken,
          );
          print('✅ Servicio de ubicación iniciado después del login');

          // PROBAR EL SERVICIO
          final stats = await ubicacionService.obtenerEstadisticas();
          print('📊 Estadísticas del servicio: $stats');
        } else {
          print('⚠️ Usuario o idOperador no disponible');
        }
      } else {
        print('⚠️ No hay accessToken disponible');
      }

      if (mounted) {
        setState(() {
          _isServiceInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error inicializando servicios: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isServiceInitialized = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServiceInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Inicializando servicios...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inicializando: $_errorMessage'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }

    return HomePage(
      onLogout: () {
        final ubicacionService = Provider.of<UbicacionService>(context, listen: false);
        ubicacionService.detenerServicioUbicacion();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      },
    );
  }
}
// // import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import 'services/database_service.dart';
// // import 'services/api_service.dart';
// // import 'services/reporte_sync_service.dart';
// // import 'services/auth_service.dart';
// // import 'services/connectivity_service.dart';
// // import 'services/location_service.dart';
// // import 'services/ubicacion_service.dart';
// // import 'views/login_page.dart';
// // import 'views/home_page.dart';
// // import 'widgets/connnectivity_handler.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Inicializa servicios globales
//   final dbService = DatabaseService();
//   final authService = AuthService();
//   final connectivityService = ConnectivityService();
//   final locationService = LocationService();
//   final ubicacionService = UbicacionService();
//   final idOperador = await authService.getIdOperador();
//
//
//   // Inicializa la base de datos
//   await dbService.database;
//
//   // INICIALIZAR UbicacionService con sus dependencias
//   ubicacionService.initialize(
//     locationService: locationService,
//     connectivityService: connectivityService,
//     databaseService: dbService,
//   );
//
//   // VERIFICAR SI HAY SESIÓN ACTIVA Y REINICIAR SERVICIO DE UBICACIÓN
//   final isAuthenticated = await authService.isAuthenticated();
//   if (isAuthenticated) {
//     final user = await authService.getCurrentUser();
//     final accessToken = await authService.getAccessToken();
//     if (user != null && accessToken != null) {
//
//       final userType = authService.determinarTipoUsuario(user);
//       ubicacionService.iniciarServicioUbicacion(
//         idOperador, // ENVIAMOS el id_operador, no el user.id
//         userType,
//         accessToken,
//       );
//       print('DEBUG: Servicio de ubicación reiniciado al iniciar app');
//     } else {
//       print('DEBUG: Usuario o token no disponibles al iniciar app');
//     }
//   } else {
//     print('DEBUG: No hay sesión activa al iniciar app');
//   }
//
//   runApp(
//     MyApp(
//       dbService: dbService,
//       authService: authService,
//       connectivityService: connectivityService,
//       locationService: locationService,
//       ubicacionService: ubicacionService,
//     ),
//   );
// }
//
// class MyApp extends StatelessWidget {
//   final DatabaseService dbService;
//   final AuthService authService;
//   final ConnectivityService connectivityService;
//   final LocationService locationService;
//   final UbicacionService ubicacionService;
//
//   const MyApp({
//     super.key,
//     required this.dbService,
//     required this.authService,
//     required this.connectivityService,
//     required this.locationService,
//     required this.ubicacionService,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         Provider<AuthService>.value(value: authService),
//         Provider<DatabaseService>.value(value: dbService),
//         Provider<ConnectivityService>.value(value: connectivityService),
//         Provider<LocationService>.value(value: locationService),
//         Provider<UbicacionService>.value(value: ubicacionService),
//         Provider<ApiService>(
//           create: (context) => ApiService(authService: authService),
//         ),
//         Provider<ReporteSyncService>(
//           create: (context) => ReporteSyncService(databaseService: dbService),
//         ),
//       ],
//       child: MaterialApp(
//         title: 'Sistema de Reportes Rural',
//         theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
//         home: const AuthWrapper(),
//         routes: {'/login': (context) => const LoginPage()},
//       ),
//     );
//   }
// }
//
// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<bool>(
//       future: context.read<AuthService>().isAuthenticated(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(),
//                   SizedBox(height: 16),
//                   Text('Verificando autenticación...'),
//                 ],
//               ),
//             ),
//           );
//         }
//
//         if (snapshot.hasError) {
//           print('Error en autenticación: ${snapshot.error}');
//           return const LoginPage();
//         }
//
//         if (snapshot.hasData && snapshot.data!) {
//           return ConnectivityHandler(
//             customMessage: 'No se puede conectar con el servidor de reportes. '
//                 'Verifica tu conexión a internet y intenta nuevamente.',
//             child: const HomePageWrapper(),
//           );
//         }
//
//         return const LoginPage();
//       },
//     );
//   }
// }
//
// class HomePageWrapper extends StatefulWidget {
//   const HomePageWrapper({super.key});
//
//   @override
//   State<HomePageWrapper> createState() => _HomePageWrapperState();
// }
//
// class _HomePageWrapperState extends State<HomePageWrapper> {
//   bool _isServiceInitialized = false;
//   String? _errorMessage;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeServices();
//   }
//
//   Future<void> _initializeServices() async {
//     try {
//       final authService = Provider.of<AuthService>(context, listen: false);
//       final syncService = Provider.of<ReporteSyncService>(context, listen: false);
//       final ubicacionService = Provider.of<UbicacionService>(context, listen: false);
//       final idOperador = await authService.getIdOperador();
//
//
//       final accessToken = await authService.getAccessToken();
//       if (accessToken != null && accessToken.isNotEmpty) {
//         await syncService.initialize(accessToken: accessToken);
//         print('✅ SyncService inicializado correctamente');
//
//         // INICIAR SERVICIO DE UBICACIÓN DESPUÉS DEL LOGIN
//         final user = await authService.getCurrentUser();
//         if (user != null) {
//           final userType = authService.determinarTipoUsuario(user);
//           ubicacionService.iniciarServicioUbicacion(
//             idOperador,
//             userType,
//             accessToken,
//           );
//           print('✅ Servicio de ubicación iniciado después del login');
//
//           // PROBAR EL SERVICIO INMEDIATAMENTE
//           final stats = await ubicacionService.obtenerEstadisticas();
//           print('📊 Estadísticas del servicio: $stats');
//         } else {
//           print('⚠️ Usuario no disponible para iniciar servicio de ubicación');
//         }
//       } else {
//         print('⚠️ No hay accessToken disponible');
//       }
//
//       if (mounted) {
//         setState(() {
//           _isServiceInitialized = true;
//         });
//       }
//     } catch (e, stackTrace) {
//       print('❌ Error inicializando servicios: $e');
//       print('Stack trace: $stackTrace');
//
//       if (mounted) {
//         setState(() {
//           _isServiceInitialized = true;
//           _errorMessage = e.toString();
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_isServiceInitialized) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Inicializando servicios...'),
//             ],
//           ),
//         ),
//       );
//     }
//
//     if (_errorMessage != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error inicializando: $_errorMessage'),
//             backgroundColor: Colors.orange,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       });
//     }
//
//     return HomePage(
//       onLogout: () {
//         // DETENER SERVICIO DE UBICACIÓN AL HACER LOGOUT
//         final ubicacionService = Provider.of<UbicacionService>(context, listen: false);
//         ubicacionService.detenerServicioUbicacion();
//
//         Navigator.of(context).pushAndRemoveUntil(
//           MaterialPageRoute(builder: (_) => const LoginPage()),
//               (route) => false,
//         );
//       },
//     );
//   }
// }