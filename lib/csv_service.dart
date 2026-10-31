import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class CSVService {
  static final CSVService instance = CSVService._internal();
  CSVService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // --- PARCELLES ---

  Future<String> exportParcellesToCSV() async {
    final data = await (await _db.database).query('parcelles');

    if (data.isEmpty) {
      throw Exception("Aucune parcelle à exporter.");
    }

    // surface_verrouillee incluse pour un import/export sans perte
    final List<List<dynamic>> rows = [
      ["id", "nom", "surface", "geometrie", "surface_verrouillee"],
    ];
    for (var r in data) {
      rows.add([
        r['id'],
        r['nom'],
        r['surface'],
        r['geometrie'],
        r['surface_verrouillee'],
      ]);
    }

    final String csv =
        const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final String timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String dir = (await getApplicationDocumentsDirectory()).path;
    final File file = File('$dir/parcelles_export_$timestamp.csv');
    return await file.writeAsString(csv, encoding: utf8).then((f) => f.path);
  }

  Future<void> importParcellesCSV(String content) async {
    final db = await _db.database;
    final List<List<dynamic>> rows =
        const CsvToListConverter(fieldDelimiter: ';').convert(content);

    if (rows.length < 2) {
      debugPrint(
          "CSVService.importParcellesCSV : fichier vide ou sans données.");
      return;
    }

    final batch = db.batch();
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((e) => e == null || e.toString().isEmpty)) {
        continue;
      }
      batch.insert(
        'parcelles',
        {
          'nom': row[1].toString().toUpperCase(),
          'surface': row[2],
          'geometrie': row.length > 3 ? row[3] : '',
          'surface_verrouillee':
              row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // --- TRAVAUX (SULFATAGE, TAILLE, MAINTENANCE, etc.) ---

  /// Exporte toutes les données d'une table vers un fichier CSV horodaté.
  /// Lance une exception si la table est vide.
  Future<String> exportTravauxToCSV(String tableName) async {
    final data = await (await _db.database).query(tableName);

    if (data.isEmpty) {
      throw Exception("Aucune donnée dans la table '$tableName'.");
    }

    final List<String> headers = data.first.keys.toList();
    final List<List<dynamic>> rows = [headers];
    for (var r in data) {
      rows.add(r.values.toList());
    }

    final String csv =
        const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final String timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String dir = (await getApplicationDocumentsDirectory()).path;
    final File file = File('$dir/${tableName}_export_$timestamp.csv');
    return await file.writeAsString(csv, encoding: utf8).then((f) => f.path);
  }

  /// Importe les données pour les travaux depuis un CSV.
  ///
  /// [forcedCampaign] : force la campagne (ex: '2025') pour les fichiers
  /// sans colonne campagne ou avec des dates ambiguës.
  Future<void> importTravauxCSV(
    String tableName,
    String content, {
    String? forcedCampaign,
  }) async {
    final db = await _db.database;
    final List<List<dynamic>> rows =
        const CsvToListConverter(fieldDelimiter: ';').convert(content);

    if (rows.length < 2) {
      debugPrint("CSVService.importTravauxCSV : fichier '$tableName' vide.");
      return;
    }

    // Normalisation des headers en lowercase sans espaces
    final List<String> headers = List<String>.from(rows[0])
        .map((h) => h.toString().toLowerCase().trim())
        .toList();

    debugPrint("--- IMPORT DANS $tableName (${rows.length - 1} lignes) ---");

    final batch = db.batch();
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      // Ignorer les lignes vides ou entièrement nulles
      if (row.isEmpty || row.every((e) => e == null || e.toString().isEmpty)) {
        continue;
      }

      final Map<String, dynamic> rowData = {};
      for (int j = 0; j < headers.length; j++) {
        if (j >= row.length) continue;

        String key = headers[j];

        // Correction de noms de colonnes connus — loggée pour traçabilité
        if (key == 'details') {
          debugPrint("Correction colonne ligne $i : 'details' → 'detail'");
          key = 'detail';
        }

        rowData[key] = row[j];
      }

      // Logique campagne — priorité : forcée > colonne campagne > calculée depuis date
      if (forcedCampaign != null && forcedCampaign.isNotEmpty) {
        rowData['campagne'] = forcedCampaign;
      } else if (!rowData.containsKey('campagne') ||
          rowData['campagne'] == null ||
          rowData['campagne'].toString().isEmpty) {
        final String dateStr = rowData['date']?.toString() ?? '';
        // calculerCampagne() gère Nov/Déc → campagne année suivante
        rowData['campagne'] = _db.calculerCampagne(dateStr);
      }

      debugPrint("Ligne $i : campagne=${rowData['campagne']} → $tableName");

      batch.insert(
        tableName,
        rowData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    debugPrint("--- IMPORTATION '$tableName' TERMINÉE ---");
  }
}
