import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _initFuture;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _initFuture ??= _initDB('viti.db');
    try {
      _database = await _initFuture!;
      return _database!;
    } finally {
      _initFuture = null;
    }
  }

  /// Ferme proprement la base de données si elle est ouverte.
  Future<void> close() async {
    if (_initFuture != null) {
      try {
        await _initFuture;
      } catch (_) {}
    }
    if (_database != null) {
      if (_database!.isOpen) {
        await _database!.close();
      }
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 12) {
          await _recreerToutesLesTables(db);
        }
      },
    );
  }

  Future<void> _recreerToutesLesTables(Database db) async {
    const List<String> tables = [
      'parcelles',
      'sulfatage',
      'desherbage',
      'desherbage_produits',
      'maintenance',
      'rognage',
      'vendange',
      'travaux_verts',
      'taille',
      'produits',
    ];
    for (final table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _createDB(db, 12);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(
        'CREATE TABLE parcelles (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT, surface REAL, surface_verrouillee INTEGER DEFAULT 0, geometrie TEXT)');
    await db.execute(
        'CREATE TABLE sulfatage (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, produit TEXT, volume REAL, dose_ha REAL, parasite TEXT, date TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE desherbage (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, produit TEXT, parasite TEXT, dose_ha REAL, date TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE maintenance (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, type TEXT, type_fil TEXT, rang TEXT, description TEXT, statut TEXT, date TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE rognage (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, date TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE vendange (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, date TEXT, details TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE travaux_verts (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, type_travail TEXT, date TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE taille (id INTEGER PRIMARY KEY AUTOINCREMENT, campagne TEXT, parcelle TEXT, type_taille TEXT, date TEXT, commentaire TEXT)');
    await db.execute(
        'CREATE TABLE produits (id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT UNIQUE)');
    // Table de liaison pour les produits d'une intervention désherbage
    // Réservée pour une future refonte multi-produits par intervention
    await db.execute('''
      CREATE TABLE desherbage_produits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        intervention_id INTEGER,
        nom_produit TEXT,
        dose REAL,
        FOREIGN KEY(intervention_id) REFERENCES desherbage(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- LOGIQUE CAMPAGNE VITICOLE ---
  // Novembre et décembre appartiennent à la campagne de l'année suivante
  String calculerCampagne(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr);
      if (dt.month >= 11) {
        return (dt.year + 1).toString();
      } else {
        return dt.year.toString();
      }
    } catch (e) {
      debugPrint("Erreur calculerCampagne pour '$dateStr' : $e");
      return DateTime.now().year.toString();
    }
  }

  // --- MÉTHODES GÉOSPATIALES ---
  String pointsToString(List<LatLng> points) => jsonEncode(
      points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList());

  List<LatLng> stringToPoints(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((item) => LatLng(
                (item['lat'] as num).toDouble(),
                (item['lng'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint("Erreur stringToPoints : $e");
      return [];
    }
  }

  // --- GESTION PARCELLES ---
  Future<List<Map<String, dynamic>>> getListeParcellesFull() async {
    final db = await database;
    return await db.query('parcelles', orderBy: 'nom ASC');
  }

  Future<List<String>> getListeParcelles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('parcelles', columns: ['nom'], orderBy: 'nom ASC');
    return List.generate(maps.length, (i) => maps[i]['nom'] as String);
  }

  Future<int> insertParcelle(String nom, double surface) async {
    final db = await database;
    return await db.insert('parcelles', {
      'nom': nom.trim().toUpperCase(),
      'surface': surface,
      'surface_verrouillee': 0,
      'geometrie': '',
    });
  }

  Future<void> updateSurfaceSiNonVerrouillee(
      String nom, double surfaceCalculee) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE parcelles SET surface = ? WHERE nom = ? AND surface_verrouillee = 0',
        [surfaceCalculee, nom]);
  }

  Future<void> setVerrouillageSurface(String nom, bool estVerrouillee) async {
    final db = await database;
    await db.update(
      'parcelles',
      {'surface_verrouillee': estVerrouillee ? 1 : 0},
      where: 'nom = ?',
      whereArgs: [nom],
    );
  }

  Future<void> updateGeometrieParcelle(
      String nom, String geometrie, double surface) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE parcelles SET geometrie = ?, surface = CASE WHEN surface_verrouillee = 0 THEN ? ELSE surface END WHERE nom = ?',
        [geometrie, surface, nom]);
  }

  // --- IMPORT CSV ---
  Future<void> importParcellesCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');
      if (v.length >= 3) {
        batch.insert(
          'parcelles',
          {
            'nom': v[1].trim(),
            'surface': double.tryParse(v[2].trim()) ?? 0.0,
            'geometrie': v.length > 3 ? v[3].trim() : '',
            'surface_verrouillee':
                v.length > 4 ? int.tryParse(v[4].trim()) ?? 0 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importTailleCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');
      if (v.length >= 4) {
        final String dateVal = v[0].trim();
        batch.insert(
          'taille',
          {
            'date': dateVal,
            'campagne': calculerCampagne(dateVal),
            'parcelle': v[1].trim(),
            'type_taille': v[2].trim(),
            'commentaire': v[3].trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importMaintenanceCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');

      // Format complet (9 colonnes) — export 2026+
      if (v.length >= 8) {
        final String dateVal = v[7].trim();
        batch.insert(
          'maintenance',
          {
            'campagne': v[0].trim(),
            'parcelle': v[1].trim(),
            'type': v[2].trim(),
            'type_fil': v[3].trim(),
            'rang': v[4].trim(),
            'description': v[5].trim(),
            'statut': v[6].trim(),
            'date': dateVal,
            'commentaire': v.length > 8 ? v[8].trim() : '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      // Format ancien (4 colonnes) — compatibilité fichiers existants
      else if (v.length >= 4) {
        final String dateVal = v[0].trim();
        batch.insert(
          'maintenance',
          {
            'date': dateVal,
            'campagne': calculerCampagne(dateVal),
            'parcelle': v[1].trim(),
            'type': v[2].toLowerCase().contains('piquet') ? 'PIQUET' : 'FIL',
            'type_fil': v[2].trim(),
            'rang': 'N/A',
            'description': v[2].trim(),
            'statut': 'ANCIEN',
            'commentaire': v[3].trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importRognageCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');
      if (v.length >= 4) {
        final String dateVal = v[0].trim();
        batch.insert(
          'rognage',
          {
            'campagne': calculerCampagne(dateVal),
            'parcelle': v[1].trim(),
            'date': dateVal,
            'commentaire': v[3].trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importVendangeCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');
      if (v.length >= 4) {
        final String dateVal = v[0].trim();
        batch.insert(
          'vendange',
          {
            'campagne': calculerCampagne(dateVal),
            'parcelle': v[1].trim(),
            'date': dateVal,
            'details': v[2].trim(),
            'commentaire': v[3].trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importTravauxVertsCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');
      if (v.length >= 4) {
        final String dateVal = v[0].trim();
        batch.insert(
          'travaux_verts',
          {
            'campagne': calculerCampagne(dateVal),
            'parcelle': v[1].trim(),
            'type_travail': v[2].trim(),
            'date': dateVal,
            'commentaire': v[3].trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importSulfatageCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    final batch = db.batch();

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final List<String> v = lines[i].split(';');

      try {
        // Format complet (8 colonnes) — export 2026+
        if (v.length >= 8) {
          batch.insert(
            'sulfatage',
            {
              'date': v[0].trim(),
              'campagne': v[1].trim(),
              'parcelle': v[2].trim(),
              'produit': v[3].trim(),
              'volume': double.tryParse(v[4]
                      .trim()
                      .replaceAll(',', '.')
                      .replaceAll(RegExp(r'[^0-9.]'), '')) ??
                  0.0,
              'dose_ha':
                  double.tryParse(v[5].trim().replaceAll(',', '.')) ?? 0.0,
              'parasite': v[6].trim(),
              'commentaire': v[7].trim(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        // Format ancien (4 colonnes) — compatibilité
        else if (v.length >= 4) {
          final String dateVal = v[0].trim();
          batch.insert(
            'sulfatage',
            {
              'date': dateVal,
              'campagne': calculerCampagne(dateVal),
              'parcelle': v[1].trim(),
              'produit': v[2].trim(),
              'volume': 0.0,
              'dose_ha': 0.0,
              'parasite': v[3].trim(),
              'commentaire': '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        debugPrint("Erreur import sulfatage ligne $i : $e");
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> importDesherbageCSV(String csv) async {
    final db = await database;
    final List<String> lines = csv.replaceAll('\r', '').split('\n');
    if (lines.isEmpty) return;

    final batch = db.batch();

    // Détection du format via l'en-tête (insensible à la casse)
    final String header = lines[0].trim().toUpperCase();
    final bool isAncienFormat = header.startsWith('DATE;PARCELLE;DETAILS');

    if (isAncienFormat) {
      // --- FORMAT ANCIEN : DATE;PARCELLE;DETAILS;COMMENTAIRE ---
      // DETAILS contient tout : "Glyphosate - 2,0 L/ha (Sous le rang)"
      // On parse pour extraire produit, dose et mode.
      debugPrint("importDesherbageCSV : format ancien détecté (DETAILS)");

      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final List<String> v = lines[i].split(';');
        if (v.length < 2) continue;

        final String dateVal = v[0].trim();
        final String parcelle = v[1].trim();
        final String details = v.length > 2 ? v[2].trim() : '';
        final String commentaire = v.length > 3 ? v[3].trim() : '';

        // Parse le champ DETAILS : "Produit - 2,0 L/ha (Mode)"
        // Exemples réels :
        //   "Glyphosate - 2,0 L/ha (Sous le rang)"
        //   "Anti-germinatif - 0,4 L/ha (Sous le rang)"
        //   "Glyphosate - 2,0 L/ha (Sous le rang) - 0,0 L/ha (commentaire)"
        String produit = 'Inconnu';
        double dose = 0.0;
        String mode = '';

        try {
          // Extraction du produit : tout ce qui est avant " - "
          final int tiretIdx = details.indexOf(' - ');
          if (tiretIdx > 0) {
            produit = details.substring(0, tiretIdx).trim();

            // Extraction de la dose : nombre entre " - " et " L/ha"
            final RegExp doseRegex = RegExp(r'([\d,\.]+)\s*L/ha');
            final Match? doseMatch = doseRegex.firstMatch(details);
            if (doseMatch != null) {
              dose =
                  double.tryParse(doseMatch.group(1)!.replaceAll(',', '.')) ??
                      0.0;
            }

            // Extraction du mode : contenu entre parenthèses
            final RegExp modeRegex = RegExp(r'\(([^)]+)\)');
            final Match? modeMatch = modeRegex.firstMatch(details);
            if (modeMatch != null) {
              mode = modeMatch.group(1)!.trim();
            }
          } else {
            // Pas de tiret → on prend tout comme produit
            produit = details;
          }
        } catch (e) {
          debugPrint(
              "importDesherbageCSV : erreur parsing DETAILS ligne $i : $e");
        }

        // On n'insère que les produits chimiques reconnus
        // (cohérent avec getDesherbageChimique et l'affichage)
        const List<String> produitsAutorises = [
          'Glyphosate',
          'Anti-germinatif',
          'Herbicide sélectif',
        ];
        final bool produitReconnu = produitsAutorises.any(
          (p) => produit.toLowerCase().contains(p.toLowerCase()),
        );
        if (!produitReconnu) {
          debugPrint(
              "importDesherbageCSV : produit '$produit' ignoré (ligne $i)");
          continue;
        }

        batch.insert(
          'desherbage',
          {
            'campagne': calculerCampagne(dateVal),
            'parcelle': parcelle,
            'produit': produit,
            'parasite': mode,
            'dose_ha': dose,
            'date': dateVal,
            'commentaire': commentaire,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } else {
      // --- FORMAT NATIF : date;parcelle;produit;parasite;dose_ha;commentaire ---
      debugPrint("importDesherbageCSV : format natif détecté");

      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        final List<String> v = lines[i].split(';');

        if (v.length >= 4) {
          final String dateVal = v[0].trim();
          final double dose = v.length >= 5
              ? (double.tryParse(v[4].trim().replaceAll(',', '.')) ?? 0.0)
              : 0.0;

          batch.insert(
            'desherbage',
            {
              'campagne': calculerCampagne(dateVal),
              'parcelle': v[1].trim(),
              'produit': v[2].trim(),
              'parasite': v[3].trim(),
              'dose_ha': dose,
              'date': dateVal,
              'commentaire': v.length > 5 ? v[5].trim() : '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
    await batch.commit(noResult: true);
  }

  // --- EXPORT CSV ---
  // Exporte toutes les campagnes confondues.
  // Pour un export filtré par campagne, utiliser exporterParCampagneCSV().
  Future<String> exportTableToCSV(String table, List<String> colonnes) async {
    final db = await database;
    final List<Map<String, dynamic>> data = await db.query(table);

    String csvData = '${colonnes.join(';')}\n';
    for (var row in data) {
      final List<String> valeurs = colonnes.map((col) {
        return (row[col]?.toString() ?? '').replaceAll(';', ',');
      }).toList();
      csvData += '${valeurs.join(';')}\n';
    }
    return csvData;
  }

  Future<String> exporterDesherbageCSV(String campagne) async {
    final db = await database;
    final List<Map<String, dynamic>> data = await db.query(
      'desherbage',
      where: 'campagne = ?',
      whereArgs: [campagne],
      orderBy: 'date ASC',
    );

    String csv = "Date;Parcelle;Produit;Mode;Dose(L/ha);Commentaire\n";
    for (var row in data) {
      csv += "${row['date'] ?? ''};"
          "${row['parcelle'] ?? ''};"
          "${row['produit'] ?? ''};"
          "${row['parasite'] ?? ''};"
          "${(row['dose_ha'] ?? 0.0).toString().replaceAll('.', ',')};"
          "${(row['commentaire'] ?? '').toString().replaceAll(';', ',')}\n";
    }
    return csv;
  }

  // --- MÉTHODES GÉNÉRIQUES TRAVAUX ---
  Future<int> insertTravail(String table, Map<String, dynamic> data) async {
    final db = await database; // corrigé : était instance.database
    return await db.insert(table, data);
  }

  Future<List<Map<String, dynamic>>> getTravauxParCampagne(
      String table, String campagne) async {
    final db = await database;
    return await db.query(
      table,
      where: 'campagne = ?',
      whereArgs: [campagne],
      orderBy: 'date DESC',
    );
  }

  // --- DÉSHERBAGE CHIMIQUE ---
  // Filtre directement en SQL pour éviter de charger toute la table en mémoire
  Future<List<Map<String, dynamic>>> getDesherbageChimique(
      String campagne) async {
    final db = await database;

    const List<String> produitsAutorises = [
      'Glyphosate',
      'Anti-germinatif',
      'Herbicide sélectif',
    ];

    final String placeholders = produitsAutorises.map((_) => '?').join(',');

    return await db.query(
      'desherbage',
      where: 'campagne = ? AND produit IN ($placeholders)',
      whereArgs: [campagne, ...produitsAutorises],
      orderBy: 'date DESC',
    );
  }

  // --- MÉTHODES UTILITAIRES ---
  Future<int> supprimerTravail(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // Réservé au mode debug — ne s'exécute pas en release grâce à assert()
  Future<void> debugPrintTable(String table) async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.query(table);
    debugPrint("DEBUG [$table] : $res");
  }

  // ⚠️ DESTRUCTIF — supprime et recrée toute la base de données
  Future<void> reinitialiserBase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'viti.db');
    await close();
    await deleteDatabase(path);
    await database;
  }

  // Supprime les entrées désherbage dont le produit n'est pas dans la liste autorisée
  Future<void> nettoyerDonneesIncoherentes() async {
    final db = await database;

    const List<String> produitsChimiques = [
      'Glyphosate',
      'Anti-germinatif',
      'Herbicide sélectif',
    ];

    // Placeholders pour éviter toute injection SQL
    final String placeholders = produitsChimiques.map((_) => '?').join(',');

    await db.delete(
      'desherbage',
      where: 'produit NOT IN ($placeholders)',
      whereArgs: produitsChimiques,
    );

    debugPrint(
        "Nettoyage effectué : seules les données chimiques ont été conservées.");
  }
}
