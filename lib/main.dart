  import 'package:firebase_core/firebase_core.dart';
  import 'package:flutter/material.dart';
  import 'firebase_options.dart';
  import 'services/auth_service.dart';
  import 'views/login_page.dart';
  import 'views/home_page.dart';

  void main() async{
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(MyApp());
  }

  class MyApp extends StatelessWidget {
    const MyApp({Key? key}) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Administrador de LLaves',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      );
    }
  }

  class AuthWrapper extends StatefulWidget {
    const AuthWrapper({Key? key}) : super(key: key);

    @override
    _AuthWrapperState createState() => _AuthWrapperState();
  }

  class _AuthWrapperState extends State<AuthWrapper> {
    bool _isAuthenticated = false;

    @override
    void initState() {
      super.initState();
      _checkAuth();
    }

    Future<void> _checkAuth() async {
      final authenticated = await AuthService().isAuthenticated();
      setState(() {
        _isAuthenticated = authenticated;
      });
    }

    void _handleLoginSuccess() {
      setState(() {
        _isAuthenticated = true;
      });
    }

    void _handleLogout() {
      setState(() {
        _isAuthenticated = false;
      });
    }

    @override
    Widget build(BuildContext context) {
      return _isAuthenticated
          ? HomePage(onLogout: _handleLogout)
          : LoginPage(onLoginSuccess: _handleLoginSuccess);
    }
  }