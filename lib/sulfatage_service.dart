import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class SulfatageService {
  static final SulfatageService instance = SulfatageService._internal();
  SulfatageService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Insère un sulfatage.
  /// Utilise ConflictAlgorithm.abort — lève une exception si doublon d'id.
  /// Lance une exception en cas d'erreur — l'appelant doit gérer.
  Future<int> insertSulfatage(Map<String, dynamic> data) async {
    try {
      final db = await _db.database;
      return await db.insert(
        'sulfatage',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      debugPrint("SulfatageService.insertSulfatage : $e");
      rethrow;
    }
  }

  /// Retourne tous les sulfatages d'une campagne, triés par date décroissante.
  /// Retourne une liste vide en cas d'erreur DB.
  Future<List<Map<String, dynamic>>> getSulfatagesParCampagne(
      String campagne) async {
    try {
      final db = await _db.database;
      return await db.query(
        'sulfatage',
        where: 'campagne = ?',
        whereArgs: [campagne],
        orderBy: 'date DESC',
      );
    } catch (e) {
      debugPrint("SulfatageService.getSulfatagesParCampagne : $e");
      return [];
    }
  }

  /// Importe des sulfatages depuis un contenu CSV.
  /// Lance une exception en cas d'erreur.
  Future<void> importSulfatageCSV(String content) async {
    try {
      await _db.importSulfatageCSV(content);
    } catch (e) {
      debugPrint("SulfatageService.importSulfatageCSV : $e");
      rethrow;
    }
  }

  /// Supprime tous les sulfatages d'une campagne donnée.
  /// ⚠️ Action irréversible — à appeler uniquement après confirmation utilisateur.
  Future<void> deleteSulfatagesParCampagne(String campagne) async {
    try {
      final db = await _db.database;
      await db.delete(
        'sulfatage',
        where: 'campagne = ?',
        whereArgs: [campagne],
      );
    } catch (e) {
      debugPrint("SulfatageService.deleteSulfatagesParCampagne : $e");
      rethrow;
    }
  }
}
