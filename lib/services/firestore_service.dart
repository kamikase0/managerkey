

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manager_key/models/ubicacion_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener el ID del usuario actual
  String? get _userId => _auth.currentUser?.uid;

  /// Guardar una salida de ruta en Firestore
  Future<bool> guardarSalida({
    required double latitud,
    required double longitud,
    required String observaciones,
  }) async {
    try {
      if (_userId == null) {
        print('Error: Usuario no autenticado');
        return false;
      }

      // Guardar en la colección 'salidas_rutas'
      await _firestore.collection('salidas_rutas').add({
        'userId': _userId,
        'latitud': latitud,
        'longitud': longitud,
        'observaciones': observaciones,
        'fechaHora': DateTime.now(),
        'estado': 'registrada',
        'sincronizado': true,
      });

      print('Salida guardada exitosamente');
      return true;
    } catch (e) {
      print('Error al guardar salida: $e');
      return false;
    }
  }

  /// Obtener todas las salidas del usuario actual
  Future<List<Map<String, dynamic>>> obtenerSalidas() async {
    try {
      if (_userId == null) {
        print('Error: Usuario no autenticado');
        return [];
      }

      final snapshot = await _firestore
          .collection('salidas_rutas')
          .where('userId', isEqualTo: _userId)
          .orderBy('fechaHora', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('Error al obtener salidas: $e');
      return [];
    }
  }

  /// Stream en tiempo real de las salidas
  Stream<List<Map<String, dynamic>>> obtenerSalidasStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('salidas_rutas')
        .where('userId', isEqualTo: _userId)
        .orderBy('fechaHora', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList());
  }

  /// Actualizar una salida
  Future<bool> actualizarSalida({
    required String docId,
    required String observaciones,
  }) async {
    try {
      await _firestore
          .collection('salidas_rutas')
          .doc(docId)
          .update({
        'observaciones': observaciones,
        'fechaActualizacion': DateTime.now(),
      });

      print('Salida actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar salida: $e');
      return false;
    }
  }

  /// Eliminar una salida
  Future<bool> eliminarSalida(String docId) async {
    try {
      await _firestore.collection('salidas_rutas').doc(docId).delete();
      print('Salida eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar salida: $e');
      return false;
    }
  }

  Future<void> guardarUbicacion(UbicacionModel ubicacion) async {
    try {
      await _firestore.collection('ubicaciones').add(ubicacion.toJson());
  }catch(e){
      print('Error al guardar ubicación en Firestore: $e');
      throw e;
    }
    }
}