import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';
import 'services/reporte_sync_service.dart';
import 'services/auth_service.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa servicios globales
  final dbService = DatabaseService();
  final apiService = ApiService();
  final authService = AuthService();

  // Inicializa la base de datos
  await dbService.database;

  runApp(MyApp(
    dbService: dbService,
    apiService: apiService,
    authService: authService,
  ));
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;
  final ApiService apiService;
  final AuthService authService;

  const MyApp({
    super.key,
    required this.dbService,
    required this.apiService,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<DatabaseService>.value(value: dbService),
        Provider<ApiService>.value(value: apiService),
        // ✅ Agregar Provider para ReporteSyncService (sin inicializar aún)
        Provider<ReporteSyncService>(
          create: (_) => ReporteSyncService(
            databaseService: dbService,
            apiService: apiService,
          ),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Sistema de Reportes Rural',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: false,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginPage(),
        },
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data!) {
          return const HomePageWrapper();
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

  @override
  void initState() {
    super.initState();
    _initializeSyncService();
  }

  Future<void> _initializeSyncService() async {
    try {
      final authService = context.read<AuthService>();
      final syncService = context.read<ReporteSyncService>();

      final accessToken = await authService.getAccessToken();
      if (accessToken != null) {
        await syncService.initialize(accessToken: accessToken);
      }

      if (mounted) {
        setState(() {
          _isServiceInitialized = true;
        });
      }
    } catch (e) {
      print('Error inicializando sync service: $e');
      if (mounted) {
        setState(() {
          _isServiceInitialized = true; // Continuar aunque falle
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServiceInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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