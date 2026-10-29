import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class MaintenanceService {
  static final MaintenanceService instance = MaintenanceService._internal();
  MaintenanceService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> insertMaintenance(Map<String, dynamic> data) async {
    try {
      final db = await _db.database;
      return await db.insert('maintenance', data);
    } catch (e) {
      debugPrint("Erreur insertion maintenance : $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMaintenanceParCampagne(
      String campagne) async {
    try {
      final db = await _db.database;
      return await db.query(
        'maintenance',
        where: "campagne = ?",
        whereArgs: [campagne],
        orderBy: 'date DESC',
      );
    } catch (e) {
      debugPrint("Erreur récupération maintenances : $e");
      rethrow;
    }
  }
}
