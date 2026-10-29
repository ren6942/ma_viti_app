import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';
import 'parcelle_service.dart';
import 'carte_parcelle_page.dart';

class ParcellesPage extends StatefulWidget {
  const ParcellesPage({super.key});

  @override
  State<ParcellesPage> createState() => _ParcellesPageState();
}

class _ParcellesPageState extends State<ParcellesPage> {
  // Singleton — cohérent avec le reste de l'app
  final ParcelleService _pService = ParcelleService.instance;

  // Controllers déclarés ici pour être disposés proprement
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _surfaceController = TextEditingController();

  // Future en cache — évite le pattern UniqueKey fragile
  late Future<List<Map<String, dynamic>>> _futureParcelles;

  @override
  void initState() {
    super.initState();
    _futureParcelles = _pService.getListeParcellesFull();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _surfaceController.dispose();
    super.dispose();
  }

  void _chargerParcelles() {
    setState(() => _futureParcelles = _pService.getListeParcellesFull());
  }

  // --- EXPORT / IMPORT ---
  Future<void> _exporterParcelles() async {
    try {
      final String csvData = await DatabaseHelper.instance.exportTableToCSV(
        'parcelles',
        ['id', 'nom', 'surface', 'geometrie', 'surface_verrouillee'],
      );
      final String ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/parcelles_$ts.csv";
      await File(path).writeAsString(csvData);
      await Share.shareXFiles([XFile(path)],
          text: 'Sauvegarde parcelles viticoles');
    } catch (e) {
      _showSnackBar("Erreur export : $e", Colors.red);
    }
  }

  Future<void> _importerParcelles() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.single.path != null) {
        final String content =
            await File(result.files.single.path!).readAsString();
        await DatabaseHelper.instance.importParcellesCSV(content);
        _chargerParcelles();
        _showSnackBar("Importation réussie !", const Color(0xff76ff03));
      }
    } catch (e) {
      _showSnackBar("Erreur import : $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("GESTION DES PARCELLES",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.blueAccent),
            tooltip: "Importer CSV",
            onPressed: _importerParcelles,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xff76ff03)),
            tooltip: "Exporter CSV",
            onPressed: _exporterParcelles,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureParcelles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xff76ff03)));
          }

          final List<Map<String, dynamic>> parcelles = snapshot.data ?? [];

          if (parcelles.isEmpty) {
            return const Center(
              child: Text(
                "Aucune parcelle.\nCliquez sur + pour commencer.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 80),
            itemCount: parcelles.length,
            itemBuilder: (context, index) {
              final p = parcelles[index];
              final bool isLocked = (p['surface_verrouillee'] ?? 0) == 1;
              final String surface =
                  (p['surface'] as num?)?.toStringAsFixed(2) ?? '0.00';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xff76ff03),
                    child: IconButton(
                      icon:
                          const Icon(Icons.map, color: Colors.black, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                CarteParcellePage(parcelleNom: p['nom'])),
                      ).then((_) => _chargerParcelles()),
                    ),
                  ),
                  title: Text(p['nom'],
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "$surface Ha${isLocked ? '  (Verrouillée)' : ''}",
                    style: TextStyle(
                      color: isLocked
                          ? Colors.orangeAccent
                          : const Color(0xff76ff03),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.orangeAccent, size: 20),
                        onPressed: () => _showEditDialog(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDelete(p),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff76ff03),
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
    );
  }

  // --- DIALOGUE AJOUT ---
  void _showAddDialog() {
    // Controllers locaux pour éviter les valeurs résiduelles
    final nomCtrl = TextEditingController();
    final surfaceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Ajouter une parcelle",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: "Nom",
                  labelStyle: TextStyle(color: Colors.white60)),
            ),
            TextField(
              controller: surfaceCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Surface (Ha)",
                  labelStyle: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text("ANNULER", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff76ff03)),
            onPressed: () async {
              final String nom = nomCtrl.text.trim();
              if (nom.isEmpty) {
                _showSnackBar("Le nom est obligatoire", Colors.orange);
                return;
              }
              final navigator = Navigator.of(ctx);
              try {
                await _pService.insertParcelle(
                  nom,
                  double.tryParse(surfaceCtrl.text.replaceAll(',', '.')) ?? 0.0,
                );
                nomCtrl.dispose();
                surfaceCtrl.dispose();
                navigator.pop();
                if (mounted) _chargerParcelles();
              } catch (e) {
                _showSnackBar("Erreur : $e", Colors.red);
              }
            },
            child: const Text("AJOUTER", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // --- DIALOGUE MODIFICATION ---
  void _showEditDialog(Map<String, dynamic> parcelle) {
    // Controllers locaux pré-remplis
    final nomCtrl = TextEditingController(text: parcelle['nom'].toString());
    final surfaceCtrl = TextEditingController(
        text: (parcelle['surface'] as num?)?.toStringAsFixed(2) ?? '0.00');
    bool isLocked = (parcelle['surface_verrouillee'] ?? 0) == 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Modifier", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomCtrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: "Nom",
                    labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: surfaceCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Surface (Ha)",
                    labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Verrouiller surface",
                    style: TextStyle(color: Colors.white)),
                value: isLocked,
                activeThumbColor: const Color(0xff76ff03),
                onChanged: (v) => setDialogState(() => isLocked = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ANNULER"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent),
              onPressed: () async {
                final String nouveauNom = nomCtrl.text.trim();
                if (nouveauNom.isEmpty) {
                  _showSnackBar("Le nom est obligatoire", Colors.orange);
                  return;
                }
                final navigator = Navigator.of(ctx);
                try {
                  // 1. Renommage + cascade en transaction atomique
                  await _pService.updateParcelleCascade(
                    parcelle['id'],
                    parcelle['nom'],
                    nouveauNom,
                    double.tryParse(surfaceCtrl.text.replaceAll(',', '.')) ??
                        0.0,
                  );
                  // 2. Verrouillage appliqué APRÈS le renommage confirmé,
                  //    sur le nouveau nom désormais en base
                  await DatabaseHelper.instance.setVerrouillageSurface(
                    nouveauNom.toUpperCase(),
                    isLocked,
                  );
                  nomCtrl.dispose();
                  surfaceCtrl.dispose();
                  navigator.pop();
                  if (mounted) _chargerParcelles();
                } catch (e) {
                  _showSnackBar("Erreur : $e", Colors.red);
                }
              },
              child: const Text("ENREGISTRER",
                  style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOGUE SUPPRESSION ---
  void _confirmDelete(Map<String, dynamic> parcelle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Cela supprimera définitivement '${parcelle['nom']}' et tout son historique.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              try {
                await _pService.deleteParcelleCascade(
                    parcelle['id'], parcelle['nom']);
                navigator.pop();
                if (mounted) {
                  _chargerParcelles();
                  _showSnackBar("Parcelle supprimée", Colors.redAccent);
                }
              } catch (e) {
                navigator.pop();
                if (mounted) {
                  _showSnackBar("Erreur suppression : $e", Colors.red);
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
