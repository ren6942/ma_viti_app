import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class TravauxService {
  static final TravauxService instance = TravauxService._internal();
  TravauxService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Insertion générique dans n'importe quelle table de travaux.
  /// Lance une exception en cas d'erreur — l'appelant doit gérer.
  Future<int> insertTravaux(
    Map<String, dynamic> data, {
    required String tableName,
  }) async {
    try {
      final db = await _db.database;
      return await db.insert(tableName, data);
    } catch (e) {
      debugPrint("TravauxService.insertTravaux [$tableName] : $e");
      rethrow;
    }
  }

  /// Supprime un enregistrement par son id dans la table donnée.
  /// Lance une exception en cas d'erreur — cohérent avec insertTravaux.
  Future<void> supprimerTravail(String table, int id) async {
    try {
      await _db.supprimerTravail(table, id);
    } catch (e) {
      debugPrint("TravauxService.supprimerTravail [$table] : $e");
      rethrow;
    }
  }

  // --- MÉTHODES DÉDIÉES PAR TABLE ---
  // Raccourcis typés pour éviter les erreurs de nom de table à la saisie.

  Future<int> enregistrerVendange(Map<String, dynamic> data) =>
      insertTravaux(data, tableName: 'vendange');

  Future<int> enregistrerSulfatage(Map<String, dynamic> data) =>
      insertTravaux(data, tableName: 'sulfatage');

  Future<int> enregistrerMaintenance(Map<String, dynamic> data) =>
      insertTravaux(data, tableName: 'maintenance');

  Future<int> enregistrerRognage(Map<String, dynamic> data) =>
      insertTravaux(data, tableName: 'rognage');

  Future<int> enregistrerTravauxVerts(Map<String, dynamic> data) =>
      insertTravaux(data, tableName: 'travaux_verts');

  Future<int> enregistrerTaille(Map<String, dynamic> data) =>
      insertTravaux(data, tableName: 'taille');
}
