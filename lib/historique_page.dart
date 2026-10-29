import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';

class HistoriquePage extends StatefulWidget {
  const HistoriquePage({super.key});

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final int _anneeActuelle = DateTime.now().year;
  late String _campagneActive;

  final List<String> _nomTables = [
    'taille',
    'sulfatage',
    'desherbage',
    'maintenance',
    'rognage',
    'vendange',
    'travaux_verts',
  ];

  @override
  void initState() {
    super.initState();
    _campagneActive = _anneeActuelle.toString();
    _tabController = TabController(length: _nomTables.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- IMPORTATION ---
  Future<void> _importerDonnees() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        String tableActuelle = _nomTables[_tabController.index];

        if (tableActuelle == 'taille') {
          await DatabaseHelper.instance.importTailleCSV(content);
        } else if (tableActuelle == 'sulfatage') {
          await DatabaseHelper.instance.importSulfatageCSV(content);
        } else if (tableActuelle == 'desherbage') {
          await DatabaseHelper.instance.importDesherbageCSV(content);
        } else if (tableActuelle == 'maintenance') {
          await DatabaseHelper.instance.importMaintenanceCSV(content);
        } else if (tableActuelle == 'travaux_verts') {
          await DatabaseHelper.instance.importTravauxVertsCSV(content);
        } else if (tableActuelle == 'rognage') {
          await DatabaseHelper.instance.importRognageCSV(content);
        } else if (tableActuelle == 'vendange') {
          await DatabaseHelper.instance.importVendangeCSV(content);
        } else {
          _notifier(
            "L'import n'est pas encore configuré pour $tableActuelle",
            Colors.orange,
          );
          return;
        }

        assert(() {
          DatabaseHelper.instance.debugPrintTable(tableActuelle);
          return true;
        }());

        _notifier("Importation réussie !", const Color(0xff76ff03));
        if (mounted) setState(() {});
      }
    } catch (e) {
      _notifier("Erreur d'import : $e", Colors.red);
    }
  }

  // --- EXPORTATION ---
  Future<void> _partagerExport(String table) async {
    try {
      List<Map<String, dynamic>> data;
      if (table == 'desherbage') {
        data = await DatabaseHelper.instance
            .getDesherbageChimique(_campagneActive);
      } else {
        data = await DatabaseHelper.instance
            .getTravauxParCampagne(table, _campagneActive);
      }

      if (data.isEmpty) {
        _notifier(
          "Aucune donnée pour ${table.toUpperCase()} en $_campagneActive",
          Colors.orange,
        );
        return;
      }

      String csvData = "";

      if (table == 'sulfatage') {
        // Format natif — réimportable directement
        csvData =
            "DATE;CAMPAGNE;PARCELLE;PRODUIT;VOLUME;DOSE_HA;PARASITE;COMMENTAIRE\n";
        for (var row in data) {
          csvData +=
              "${row['date'] ?? ''};${row['campagne'] ?? ''};${row['parcelle'] ?? ''};"
              "${row['produit'] ?? ''};${row['volume'] ?? '0'};${row['dose_ha'] ?? '0'};"
              "${row['parasite'] ?? ''};${(row['commentaire'] ?? '').toString().replaceAll(';', ',')}\n";
        }
      } else if (table == 'desherbage') {
        // Format natif désherbage — réimportable par importDesherbageCSV
        // Colonnes : date;parcelle;produit;parasite;dose_ha;commentaire
        csvData = "date;parcelle;produit;parasite;dose_ha;commentaire\n";
        for (var row in data) {
          csvData += "${row['date'] ?? ''};${row['parcelle'] ?? ''};"
              "${(row['produit'] ?? '').toString().replaceAll(';', ',')};"
              "${(row['parasite'] ?? '').toString().replaceAll(';', ',')};"
              "${row['dose_ha'] ?? '0'};"
              "${(row['commentaire'] ?? '').toString().replaceAll(';', ',')}\n";
        }
      } else {
        // Format générique pour les autres tables
        csvData = "DATE;PARCELLE;DETAILS;COMMENTAIRE\n";
        for (var row in data) {
          String detail = _getDetail(table, row).replaceAll(';', ',');
          String comm = (row['commentaire'] ?? row['description'] ?? "")
              .toString()
              .replaceAll(';', ',');
          csvData +=
              "${row['date'] ?? ''};${row['parcelle'] ?? ''};$detail;$comm\n";
        }
      }

      await _genererEtPartager(
        csvData,
        "Export_${table}_$_campagneActive.csv",
        "Export $table",
      );
    } catch (e) {
      _notifier("Erreur export : $e", Colors.red);
    }
  }

  Future<void> _partagerToutLaCampagne() async {
    try {
      String csvData = "TYPE_TRAVAIL;DATE;PARCELLE;INFOS;COMMENTAIRE\n";
      bool aDesDonnees = false;

      for (String table in _nomTables) {
        List<Map<String, dynamic>> data = (table == 'desherbage')
            ? await DatabaseHelper.instance
                .getDesherbageChimique(_campagneActive)
            : await DatabaseHelper.instance
                .getTravauxParCampagne(table, _campagneActive);

        if (data.isNotEmpty) {
          aDesDonnees = true;
          for (var row in data) {
            String detail = _getDetail(table, row).replaceAll(';', ',');
            String comm = (row['commentaire'] ?? row['description'] ?? '')
                .toString()
                .replaceAll(';', ',');
            csvData +=
                "${table.toUpperCase()};${row['date']};${row['parcelle']};$detail;$comm\n";
          }
        }
      }

      if (!aDesDonnees) {
        _notifier("La campagne $_campagneActive est vide", Colors.orange);
        return;
      }
      await _genererEtPartager(
        csvData,
        "BILAN_$_campagneActive.csv",
        "Bilan Campagne $_campagneActive",
      );
    } catch (e) {
      _notifier("Erreur bilan : $e", Colors.red);
    }
  }

  Future<void> _genererEtPartager(
      String content, String name, String shareText) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  }

  void _notifier(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- INTERFACE ---
  @override
  Widget build(BuildContext context) {
    final List<String> annees =
        List.generate(4, (i) => (_anneeActuelle - 1 + i).toString());

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("HISTORIQUE",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open, color: Colors.blueAccent),
            onPressed: _importerDonnees,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xff76ff03)),
            onPressed: _afficherMenuExport,
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: DropdownButton<String>(
              value: _campagneActive,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(
                  color: Color(0xff76ff03), fontWeight: FontWeight.bold),
              underline: Container(),
              items: annees
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _campagneActive = v);
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xff76ff03),
          labelColor: const Color(0xff76ff03),
          unselectedLabelColor: Colors.white60,
          tabs: _nomTables
              .map((t) => Tab(text: t.replaceAll('_', ' ').toUpperCase()))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _nomTables.map((table) => _buildListe(table)).toList(),
      ),
    );
  }

  void _afficherMenuExport() {
    String tableActuelle = _nomTables[_tabController.index];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xff76ff03)),
              title: Text("Exporter l'onglet ${tableActuelle.toUpperCase()}"),
              onTap: () {
                Navigator.pop(ctx);
                _partagerExport(tableActuelle);
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize, color: Colors.blueAccent),
              title: const Text("Bilan Global de la Campagne"),
              onTap: () {
                Navigator.pop(ctx);
                _partagerToutLaCampagne();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --- LISTE ---
  Widget _buildListe(String table) {
    final Future<List<Map<String, dynamic>>> futureData = (table ==
            'desherbage')
        ? DatabaseHelper.instance.getDesherbageChimique(_campagneActive)
        : DatabaseHelper.instance.getTravauxParCampagne(table, _campagneActive);

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('$_campagneActive$table'),
      future: futureData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xff76ff03)));
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(
              child: Text("Aucune donnée",
                  style: TextStyle(color: Colors.white24)));
        }

        if (table == 'desherbage') return _buildListeDesherbage(data);

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _formaterDate(item['date']),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xff76ff03),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                title: Text(item['parcelle'] ?? "Sans nom",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getDetail(table, item),
                        style: const TextStyle(
                            color: Color(0xff76ff03), fontSize: 12)),
                    if (item['commentaire'] != null &&
                        item['commentaire'].toString().isNotEmpty)
                      Text(
                        item['commentaire'],
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 22),
                  onPressed: () => _supprimer(table, item['id']),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListeDesherbage(List<Map<String, dynamic>> data) {
    Map<String, Map<String, dynamic>> groupe = {};
    for (var row in data) {
      String key = "${row['date']}_${row['parcelle']}";
      if (!groupe.containsKey(key)) {
        groupe[key] = {
          'date': row['date'],
          'parcelle': row['parcelle'],
          'mode': row['parasite'],
          'commentaire': row['commentaire'],
          'produits': <Map<String, dynamic>>[],
        };
      }
      groupe[key]!['produits'].add({
        'id': row['id'],
        'nom': row['produit'],
        'dose': row['dose_ha'],
      });
    }

    final List<Map<String, dynamic>> listeRegroupee = groupe.values.toList();

    return ListView.builder(
      itemCount: listeRegroupee.length,
      itemBuilder: (ctx, i) {
        var item = listeRegroupee[i];
        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text(
              "${_formaterDate(item['date'])} - ${item['parcelle']}",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Mode: ${item['mode']}",
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
            children: (item['produits'] as List<Map<String, dynamic>>)
                .map((p) => ListTile(
                      title: Text(
                        "• ${p['nom']} : ${p['dose']} L/ha",
                        style: const TextStyle(
                            color: Color(0xff76ff03), fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _supprimer('desherbage', p['id']),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  String _getDetail(String table, Map<String, dynamic> item) {
    switch (table) {
      case 'maintenance':
        return "${item['type_fil'] ?? item['type'] ?? 'Entretien'} (R:${item['rang']})";
      case 'taille':
        return item['type_taille'] ?? 'Taille';
      case 'sulfatage':
        return "${item['produit'] ?? 'N/A'} - ${item['dose_ha'] ?? '0'}L/ha";
      case 'desherbage':
        double dose = (item['dose_ha'] as num?)?.toDouble() ?? 0.0;
        return "${item['produit'] ?? 'N/A'} - ${dose.toStringAsFixed(1).replaceAll('.', ',')} L/ha (${item['parasite'] ?? 'N/A'})";
      case 'travaux_verts':
        return item['type_travail'] ?? 'Travaux';
      case 'rognage':
        return "Rognage effectué";
      case 'vendange':
        return "${item['details'] ?? 'Récolte'}";
      default:
        return "";
    }
  }

  Future<void> _supprimer(String table, int id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
        content: const Text("Cette action est irréversible.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.supprimerTravail(table, id);
        _notifier("Entrée supprimée", Colors.blueGrey);
        if (mounted) setState(() {});
      } catch (e) {
        _notifier("Erreur suppression : $e", Colors.red);
      }
    }
  }

  String _formaterDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return "??/??";
    try {
      List<String> parts = date.toString().split(' ')[0].split('-');
      if (parts.length >= 3) return "${parts[2]}/${parts[1]}";
      return date.toString();
    } catch (e) {
      return "??/??";
    }
  }
}
