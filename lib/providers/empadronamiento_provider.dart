// import 'package:flutter/material.dart';
// import '../models/punto_empadronamiento_model.dart';
// import '../services/punto_empadronamiento_service.dart';
// import '../database/database_helper.dart';
//
// class EmpadronamientoProvider with ChangeNotifier {
//   List<PuntoEmpadronamiento> _puntos = [];
//   List<String> _provincias = [];
//   List<String> _puntosFiltrados = [];
//
//   String? _provinciaSeleccionada;
//   String? _puntoSeleccionado;
//
//   bool _isLoading = false;
//
//   // Getters
//   List<String> get provincias => _provincias;
//   List<String> get puntosFiltrados => _puntosFiltrados;
//   String? get provinciaSeleccionada => _provinciaSeleccionada;
//   String? get puntoSeleccionado => _puntoSeleccionado;
//   bool get isLoading => _isLoading;
//
//   // Cargar datos iniciales
//   Future<void> cargarDatos() async {
//     _isLoading = true;
//     notifyListeners();
//
//     try {
//       final dbHelper = DatabaseHelper();
//
//       // Verificar si la base de datos tiene datos
//       bool tieneDatos = await dbHelper.tieneDatos();
//
//       if (!tieneDatos) {
//         // Cargar desde JSON y guardar en BD
//         _puntos = await EmpadronamientoService.cargaDatosDesdeJson();
//         await dbHelper.insertarPuntos(_puntos);
//       }
//
//       // Cargar provincias desde BD
//       _provincias = await dbHelper.obtenerProvincias();
//
//     } catch (e) {
//       print('Error cargando datos: $e');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   // Seleccionar provincia
//   void seleccionarProvincia(String? provincia) {
//     _provinciaSeleccionada = provincia;
//     _puntoSeleccionado = null;
//     _puntosFiltrados = [];
//
//     if (provincia != null) {
//       _cargarPuntosPorProvincia(provincia);
//     }
//
//     notifyListeners();
//   }
//
//   // Seleccionar punto
//   void seleccionarPunto(String? punto) {
//     _puntoSeleccionado = punto;
//     notifyListeners();
//   }
//
//   // Cargar puntos por provincia
//   Future<void> _cargarPuntosPorProvincia(String provincia) async {
//     _isLoading = true;
//     notifyListeners();
//
//     try {
//       final dbHelper = DatabaseHelper();
//       _puntosFiltrados = await dbHelper.obtenerPuntosPorProvincia(provincia);
//     } catch (e) {
//       print('Error cargando puntos: $e');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   // Resetear selección
//   void resetearSeleccion() {
//     _provinciaSeleccionada = null;
//     _puntoSeleccionado = null;
//     _puntosFiltrados = [];
//     notifyListeners();
//   }
// }