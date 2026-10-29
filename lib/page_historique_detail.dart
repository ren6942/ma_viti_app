import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class PageHistoriqueDetail extends StatefulWidget {
  final String table;
  const PageHistoriqueDetail({super.key, required this.table});

  @override
  State<PageHistoriqueDetail> createState() => _PageHistoriqueDetailState();
}

class _PageHistoriqueDetailState extends State<PageHistoriqueDetail> {
  // Initialisé avec la campagne courante — cohérent avec DatabaseHelper
  late String _campagne;

  // Généré dynamiquement — cohérent avec HomePage et HistoriquePage
  late List<String> _campagnesDisponibles;

  // Future unique mis en cache — évite les 3 requêtes DB simultanées
  late Future<List<Map<String, dynamic>>> _futureData;

  @override
  void initState() {
    super.initState();
    final int annee = DateTime.now().year;
    _campagnesDisponibles = List.generate(4, (i) => (annee - 1 + i).toString());

    _campagne = DatabaseHelper.instance
        .calculerCampagne(DateTime.now().toIso8601String());

    _futureData = _charger();
  }

  Future<List<Map<String, dynamic>>> _charger() =>
      DatabaseHelper.instance.getTravauxParCampagne(widget.table, _campagne);

  void _recharger() {
    setState(() => _futureData = _charger());
  }

  // --- DÉTAIL SELON TABLE ---
  String _getDetail(Map<String, dynamic> item) {
    switch (widget.table) {
      case 'taille':
        return item['type_taille'] ?? 'Taille';
      case 'sulfatage':
        return "${item['produit'] ?? 'N/A'} - ${item['dose_ha'] ?? '0'} L/ha";
      case 'maintenance':
        return "${item['type'] ?? 'Entretien'} : ${item['description'] ?? ''}";
      case 'travaux_verts':
        return item['type_travail'] ?? 'Travaux';
      case 'rognage':
        return "Rognage effectué";
      case 'vendange':
        // Colonne 'details' (avec s) — cohérent avec database_helper.dart
        return "${item['details'] ?? 'Récolte'}";
      default:
        return item['details'] ?? "Données enregistrées";
    }
  }

  String _formaterDate(dynamic date) {
    if (date == null) return "??/??";
    try {
      final parts = date.toString().split(' ')[0].split('-');
      if (parts.length >= 3) return "${parts[2]}/${parts[1]}";
      return date.toString();
    } catch (e) {
      return date.toString();
    }
  }

  // --- EXPORT CSV ---
  Future<void> _exporterCSV(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;
    try {
      String csv = "CAMPAGNE;DATE;PARCELLE;DETAIL;COMMENTAIRE\n";
      for (var row in data) {
        csv += "${row['campagne'] ?? ''};${row['date'] ?? ''};"
            "${row['parcelle'] ?? ''};${_getDetail(row)};"
            "${(row['commentaire'] ?? '').toString().replaceAll(';', ',')}\n";
      }

      final String ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/Export_${widget.table}_${_campagne}_$ts.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Historique ${widget.table} - Campagne $_campagne",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur export : $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          widget.table.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          // Bouton export — utilise les données déjà chargées via _futureData
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureData,
            builder: (context, snap) => IconButton(
              icon: const Icon(Icons.share, color: Color(0xff76ff03)),
              tooltip: "Exporter en CSV",
              onPressed: (snap.hasData && snap.data!.isNotEmpty)
                  ? () => _exporterCSV(snap.data!)
                  : null,
            ),
          ),
          _buildCampagneDropdown(),
          const SizedBox(width: 10),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureData,
        builder: (context, snapshot) {
          // Banner résumé — même FutureBuilder, pas de requête supplémentaire
          final bool enChargement =
              snapshot.connectionState == ConnectionState.waiting;
          final List<Map<String, dynamic>> data = snapshot.data ?? [];
          final String compteur = enChargement ? "..." : "${data.length}";

          return Column(
            children: [
              // --- BANNER RÉSUMÉ ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.black12,
                child: Text(
                  "$compteur intervention(s) pour la campagne $_campagne",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              // --- LISTE ---
              Expanded(
                child: enChargement
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xff76ff03)))
                    : data.isEmpty
                        ? const Center(
                            child: Text(
                              "Aucune donnée pour cette campagne",
                              style: TextStyle(color: Colors.white24),
                            ),
                          )
                        : ListView.builder(
                            itemCount: data.length,
                            itemBuilder: (context, i) =>
                                _buildItemCard(data[i]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampagneDropdown() {
    return DropdownButton<String>(
      value: _campagne,
      dropdownColor: const Color(0xFF1E1E1E),
      underline: Container(),
      items: _campagnesDisponibles
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _campagne = val);
          _recharger();
        }
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.black26,
          child: Text(
            _formaterDate(item['date']),
            style: const TextStyle(fontSize: 10, color: Color(0xff76ff03)),
          ),
        ),
        title: Text(
          item['parcelle'] ?? "Inconnue",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _getDetail(item),
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: IconButton(
          icon:
              const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          onPressed: () => _confirmerSuppression(item),
        ),
      ),
    );
  }

  void _confirmerSuppression(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
        content: const Text("Cette action est définitive.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance
                    .supprimerTravail(widget.table, item['id']);
                if (mounted) {
                  Navigator.pop(ctx);
                  _recharger(); // Recharge les données — liste mise à jour
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Erreur suppression : $e"),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text("SUPPRIMER",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
