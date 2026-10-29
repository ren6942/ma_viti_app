import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class ProduitService {
  static final ProduitService instance = ProduitService._internal();
  ProduitService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Retourne la liste de tous les produits triés par nom.
  /// Retourne une liste vide en cas d'erreur DB.
  Future<List<String>> getListeProduits() async {
    try {
      final db = await _db.database;
      final List<Map<String, dynamic>> maps =
          await db.query('produits', orderBy: 'nom ASC');
      return maps.map((e) => e['nom'] as String).toList();
    } catch (e) {
      debugPrint("ProduitService.getListeProduits : $e");
      return [];
    }
  }

  /// Insère un produit en ignorant les doublons.
  /// Le nom est normalisé en majuscules.
  Future<void> insertProduit(String nom) async {
    if (nom.trim().isEmpty) return;
    try {
      final db = await _db.database;
      await db.insert(
        'produits',
        {'nom': nom.trim().toUpperCase()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      debugPrint("ProduitService.insertProduit : $e");
      rethrow;
    }
  }

  /// Supprime un produit par son nom.
  /// Retourne true si le produit existait et a été supprimé.
  Future<bool> deleteProduit(String nom) async {
    try {
      final db = await _db.database;
      final int count = await db.delete(
        'produits',
        where: 'nom = ?',
        whereArgs: [nom.trim().toUpperCase()],
      );
      if (count == 0) {
        debugPrint(
            "ProduitService.deleteProduit : '${nom.toUpperCase()}' introuvable.");
      }
      return count > 0;
    } catch (e) {
      debugPrint("ProduitService.deleteProduit : $e");
      rethrow;
    }
  }
}
