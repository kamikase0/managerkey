import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';
import 'services/reporte_sync_service.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';
import 'widgets/connnectivity_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa servicios globales
  final dbService = DatabaseService();
  final authService = AuthService();
  final connectivityService = ConnectivityService();

  // Inicializa la base de datos
  await dbService.database;

  runApp(
    MyApp(
      dbService: dbService,
      authService: authService,
      connectivityService: connectivityService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;
  final AuthService authService;
  final ConnectivityService connectivityService;

  const MyApp({
    super.key,
    required this.dbService,
    required this.authService,
    required this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<DatabaseService>.value(value: dbService),
        Provider<ConnectivityService>.value(value: connectivityService),
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
        home: const AuthWrapper(), // MODIFICADO: Volvemos al AuthWrapper directo
        routes: {'/login': (context) => const LoginPage()},
      ),
    );
  }
}

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
          // SOLUCIÓN: Aplicar ConnectivityHandler solo cuando el usuario esté autenticado
          return ConnectivityHandler(
            customMessage: 'No se puede conectar con el servidor de reportes. '
                'Verifica tu conexión a internet y intenta nuevamente.',
            child: const HomePageWrapper(),
          );
        }

        // Para el login, no verificamos conexión
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

      final accessToken = await authService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        await syncService.initialize(accessToken: accessToken);
        print('✅ SyncService inicializado correctamente');
      } else {
        print('⚠️ No hay accessToken disponible para inicializar SyncService');
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      },
    );
  }
}