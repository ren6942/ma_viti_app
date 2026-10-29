import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Service de gestion des parcelles.
///
/// Toutes les opérations cascade (renommage, suppression) couvrent
/// l'ensemble des tables de travaux pour éviter les données orphelines.
class ParcelleService {
  static final ParcelleService instance = ParcelleService._internal();
  ParcelleService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // Liste exhaustive des tables de travaux liées aux parcelles.
  // À mettre à jour si une nouvelle table est ajoutée dans DatabaseHelper.
  static const List<String> _tablesLiees = [
    'taille',
    'sulfatage',
    'desherbage',
    'maintenance',
    'rognage',
    'vendange',
    'travaux_verts',
  ];

  /// Retourne la liste complète des parcelles triées par nom.
  /// Délègue directement à DatabaseHelper pour éviter la duplication.
  Future<List<Map<String, dynamic>>> getListeParcellesFull() =>
      _db.getListeParcellesFull();

  /// Insère une nouvelle parcelle.
  /// [nom] est normalisé en majuscules, [surface] en hectares.
  Future<void> insertParcelle(String nom, double surface) async {
    try {
      final db = await _db.database;
      await db.insert('parcelles', {
        'nom': nom.trim().toUpperCase(),
        'surface': surface,
        'geometrie': '',
        'surface_verrouillee': 0, // explicite — cohérent avec DatabaseHelper
      });
    } catch (e) {
      debugPrint("ParcelleService.insertParcelle : $e");
      rethrow;
    }
  }

  /// Renomme une parcelle et propage le nouveau nom dans toutes les tables
  /// de travaux via une transaction atomique.
  Future<void> updateParcelleCascade(
    int id,
    String ancienNom,
    String nouveauNom,
    double surface,
  ) async {
    try {
      final db = await _db.database;
      await db.transaction((txn) async {
        // 1. Mise à jour de la parcelle elle-même
        await txn.update(
          'parcelles',
          {'nom': nouveauNom.trim().toUpperCase(), 'surface': surface},
          where: 'id = ?',
          whereArgs: [id],
        );

        // 2. Propagation du nouveau nom dans toutes les tables liées
        for (final table in _tablesLiees) {
          await txn.update(
            table,
            {'parcelle': nouveauNom.trim().toUpperCase()},
            where: 'parcelle = ?',
            whereArgs: [ancienNom],
          );
        }
      });
    } catch (e) {
      debugPrint("ParcelleService.updateParcelleCascade : $e");
      rethrow;
    }
  }

  /// Supprime une parcelle et toutes ses données associées dans les tables
  /// de travaux via une transaction atomique.
  ///
  /// ⚠️ Action irréversible — à appeler uniquement après confirmation utilisateur.
  Future<void> deleteParcelleCascade(int id, String nom) async {
    try {
      final db = await _db.database;
      await db.transaction((txn) async {
        // 1. Suppression de la parcelle
        await txn.delete(
          'parcelles',
          where: 'id = ?',
          whereArgs: [id],
        );

        // 2. Suppression en cascade dans toutes les tables liées
        for (final table in _tablesLiees) {
          await txn.delete(
            table,
            where: 'parcelle = ?',
            whereArgs: [nom],
          );
        }
      });
    } catch (e) {
      debugPrint("ParcelleService.deleteParcelleCascade : $e");
      rethrow;
    }
  }
}
