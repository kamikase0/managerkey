// lib/services/punto_empadronamiento_service.dart (VERSIÓN CON MÁS LOGS)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manager_key/config/enviroment.dart';
import 'package:sqflite/sqflite.dart';
import '../models/punto_empadronamiento_model.dart';

class PuntoEmpadronamientoService {
  static const String _baseUrl = Enviroment.apiUrlDev;
  static const String _tableName = 'puntos_empadronamiento';

  // Obtener puntos de empadronamiento desde la API
  Future<List<PuntoEmpadronamiento>> getPuntosEmpadronamientoFromAPI(String token) async {
    try {
      print('🔄 [DEBUG] Obteniendo puntos de empadronamiento desde API...');

      final url = Uri.parse(_baseUrl + 'listar-puntos-empadronamiento');
      print('🔄 [DEBUG] URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('🔄 [DEBUG] Response status: ${response.statusCode}');
      print('🔄 [DEBUG] Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('✅ [DEBUG] JSON decodificado, cantidad de elementos: ${jsonData.length}');

        if (jsonData.isNotEmpty) {
          print('✅ [DEBUG] Primer elemento: ${jsonData.first}');
        }

        final puntos = jsonData.map((json) {
          try {
            return PuntoEmpadronamiento.fromJson(json);
          } catch (e) {
            print('❌ [DEBUG] Error parseando elemento: $e');
            print('❌ [DEBUG] Elemento problemático: $json');
            rethrow;
          }
        }).toList();

        print('✅ [DEBUG] Puntos parseados correctamente: ${puntos.length}');
        return puntos;
      } else {
        print('❌ [DEBUG] Error HTTP: ${response.statusCode}');
        print('❌ [DEBUG] Response body: ${response.body}');
        throw Exception('Error al obtener puntos de empadronamiento: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [DEBUG] Error en getPuntosEmpadronamientoFromAPI: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // Guardar puntos en la base de datos local
  Future<void> savePuntosToLocalDatabase(List<PuntoEmpadronamiento> puntos) async {
    try {
      print('🔄 [DEBUG] Guardando puntos en BD local...');
      final Database db = await _openDatabase();

      // Limpiar tabla existente
      final deletedCount = await db.delete(_tableName);
      print('🔄 [DEBUG] Registros eliminados: $deletedCount');

      // Insertar nuevos registros
      int insertedCount = 0;
      for (final punto in puntos) {
        await db.insert(
          _tableName,
          punto.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        insertedCount++;
      }

      await db.close();
      print('✅ [DEBUG] Puntos guardados en BD local: $insertedCount');
    } catch (e) {
      print('❌ [DEBUG] Error guardando en BD local: $e');
      rethrow;
    }
  }

  // Obtener puntos desde la base de datos local
  Future<List<PuntoEmpadronamiento>> getPuntosFromLocalDatabase() async {
    try {
      print('🔄 [DEBUG] Obteniendo puntos desde BD local...');
      final Database db = await _openDatabase();
      final List<Map<String, dynamic>> maps = await db.query(_tableName);
      await db.close();

      final puntos = List.generate(maps.length, (i) {
        return PuntoEmpadronamiento.fromJson(maps[i]);
      });

      print('✅ [DEBUG] Puntos obtenidos desde BD local: ${puntos.length}');
      return puntos;
    } catch (e) {
      print('❌ [DEBUG] Error obteniendo desde BD local: $e');
      rethrow;
    }
  }

  // Obtener provincias únicas desde la base de datos local
  Future<List<String>> getProvinciasFromLocalDatabase() async {
    try {
      final puntos = await getPuntosFromLocalDatabase();
      final provincias = puntos.map((p) => p.provincia).toSet().toList();
      provincias.sort();
      print('✅ [DEBUG] Provincias obtenidas: ${provincias.length}');
      return provincias;
    } catch (e) {
      print('❌ [DEBUG] Error obteniendo provincias: $e');
      rethrow;
    }
  }

  // Obtener puntos por provincia desde la base de datos local
  Future<List<PuntoEmpadronamiento>> getPuntosByProvincia(String provincia) async {
    try {
      final Database db = await _openDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'provincia = ?',
        whereArgs: [provincia],
      );
      await db.close();

      final puntos = List.generate(maps.length, (i) {
        return PuntoEmpadronamiento.fromJson(maps[i]);
      });

      print('✅ [DEBUG] Puntos para provincia $provincia: ${puntos.length}');
      return puntos;
    } catch (e) {
      print('❌ [DEBUG] Error obteniendo puntos por provincia: $e');
      rethrow;
    }
  }

  // Inicializar base de datos
  Future<Database> _openDatabase() async {
    return openDatabase(
      'empadronamiento.db',
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY,
            provincia TEXT,
            punto_de_empadronamiento TEXT
          )
        ''');
        print('✅ [DEBUG] Tabla $_tableName creada');
      },
    );
  }

  // Sincronizar datos (llamar después del login)
  Future<void> syncPuntosEmpadronamiento(String token) async {
    try {
      print('🔄 [DEBUG] Iniciando syncPuntosEmpadronamiento...');
      print('🔄 [DEBUG] Token recibido: ${token.substring(0, 20)}...');

      final puntosFromAPI = await getPuntosEmpadronamientoFromAPI(token);
      print('✅ [DEBUG] Puntos obtenidos de API: ${puntosFromAPI.length}');

      await savePuntosToLocalDatabase(puntosFromAPI);
      print('✅ [DEBUG] Puntos guardados en BD local');

      print('✅ Puntos de empadronamiento sincronizados: ${puntosFromAPI.length} registros');
    } catch (e) {
      print('❌ [DEBUG] Error en syncPuntosEmpadronamiento: $e');
      // No relanzamos la excepción para no afectar el flujo de login
    }
  }
}