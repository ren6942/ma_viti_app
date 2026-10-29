import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class TailleService {
  static final TailleService instance = TailleService._internal();
  TailleService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Insère une opération de taille en base de données.
  /// Lance une exception en cas d'erreur — l'appelant doit gérer.
  Future<int> insertTaille(Map<String, dynamic> data) async {
    try {
      final db = await _db.database;
      return await db.insert('taille', data);
    } catch (e) {
      debugPrint("TailleService.insertTaille : $e");
      rethrow;
    }
  }

  /// Récupère les tailles effectuées pour une campagne spécifique.
  /// Retourne une liste vide en cas d'erreur DB.
  Future<List<Map<String, dynamic>>> getTaillesParCampagne(
      String campagne) async {
    try {
      final db = await _db.database;
      return await db.query(
        'taille',
        where: 'campagne = ?',
        whereArgs: [campagne],
        orderBy: 'date DESC',
      );
    } catch (e) {
      debugPrint("TailleService.getTaillesParCampagne : $e");
      return [];
    }
  }
}
