import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'produit_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SulfatagePage extends StatefulWidget {
  final String campagne;
  const SulfatagePage({super.key, required this.campagne});

  @override
  State<SulfatagePage> createState() => _SulfatagePageState();
}

class _SulfatagePageState extends State<SulfatagePage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _dateSelectionnee = DateTime.now();
  final TextEditingController _volumeBouillieController =
      TextEditingController();
  final TextEditingController _nouveauProduitController =
      TextEditingController();
  final TextEditingController _commentaireController = TextEditingController();

  // Controllers dynamiques par produit sélectionné
  final Map<String, TextEditingController> _dosesProduitsControllers = {};

  List<String> _parcellesBase = [];
  List<String> _produitsBase = [];
  final List<String> _parasitesDisponibles = [
    "Mildiou",
    "Oïdium",
    "Pourriture",
    "Vers de la grappe",
    "Carence",
    "Black-rot",
  ];

  List<String> _parcellesSelectionnees = [];
  final List<String> _produitsSelectionnes = [];
  final List<String> _parasitesSelectionnes = [];

  @override
  void initState() {
    super.initState();
    _chargerDonneesInitiales();
  }

  @override
  void dispose() {
    _volumeBouillieController.dispose();
    _nouveauProduitController.dispose();
    _commentaireController.dispose();
    for (var controller in _dosesProduitsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerDonneesInitiales() async {
    try {
      final parcelles = await DatabaseHelper.instance.getListeParcelles();
      // Délègue à ProduitService — cohérent avec le reste de l'app
      final produits = await ProduitService.instance.getListeProduits();

      if (mounted) {
        setState(() {
          _parcellesBase = parcelles;
          _produitsBase = produits.isNotEmpty ? produits : ["Cuivre", "Soufre"];
        });
      }
    } catch (e) {
      debugPrint("SulfatagePage._chargerDonneesInitiales : $e");
    }
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;

    if (_parcellesSelectionnees.isEmpty) {
      _notifier("Sélectionnez au moins une parcelle", Colors.orange);
      return;
    }
    if (_produitsSelectionnes.isEmpty) {
      _notifier("Sélectionnez au moins un produit", Colors.orange);
      return;
    }

    try {
      final double volumeVal = double.tryParse(
              _volumeBouillieController.text.replaceAll(',', '.')) ??
          0.0;
      final String dateStr = DateFormat('yyyy-MM-dd').format(_dateSelectionnee);
      final String campagneReelle = widget.campagne;

      // Détail lisible de tous les produits et leurs doses
      // ex: "Cuivre (2.0 L/ha), Soufre (5.0 L/ha)"
      final String detailProduitsDoses = _produitsSelectionnes.map((p) {
        final String dose = _dosesProduitsControllers[p]?.text ?? "0";
        return "$p ($dose)";
      }).join(", ");

      // Dose numérique du premier produit pour la colonne dose_ha
      // Les doses des autres produits sont dans detailProduitsDoses
      double premiereDose = 0.0;
      if (_produitsSelectionnes.isNotEmpty) {
        final String doseTxt =
            _dosesProduitsControllers[_produitsSelectionnes.first]?.text ?? "0";
        premiereDose = double.tryParse(doseTxt.replaceAll(',', '.')) ?? 0.0;
      }

      for (final String parcelle in _parcellesSelectionnees) {
        await DatabaseHelper.instance.insertTravail('sulfatage', {
          'campagne': campagneReelle,
          'parcelle': parcelle,
          'produit': detailProduitsDoses,
          'volume': volumeVal,
          'dose_ha': premiereDose,
          'parasite': _parasitesSelectionnes.join(", "),
          'date': dateStr,
          'commentaire': _commentaireController.text.trim(),
        });
      }

      _notifier(
        "Enregistré pour ${_parcellesSelectionnees.length} parcelle(s)",
        const Color(0xff76ff03),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _notifier("Erreur enregistrement : $e", Colors.red);
    }
  }

  Future<void> _exporterDonnees() async {
    try {
      final List<String> colonnes = [
        'campagne',
        'parcelle',
        'produit',
        'volume',
        'dose_ha',
        'parasite',
        'date',
        'commentaire',
      ];
      final String csv =
          await DatabaseHelper.instance.exportTableToCSV('sulfatage', colonnes);
      final directory = await getTemporaryDirectory();
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File file = File('${directory.path}/sulfatage_$timestamp.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Export Sulfatage ${widget.campagne}',
      );
    } catch (e) {
      _notifier("Erreur export : $e", Colors.red);
    }
  }

  Future<void> _ajouterProduitALaBase() async {
    final String nom = _nouveauProduitController.text.trim();
    if (nom.isEmpty) return;
    try {
      // Délègue à ProduitService — plus d'accès direct à la DB
      await ProduitService.instance.insertProduit(nom);
      _nouveauProduitController.clear();
      await _chargerDonneesInitiales();
    } catch (e) {
      _notifier("Erreur ajout produit : $e", Colors.red);
    }
  }

  void _notifier(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final int annee = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("SULFATAGE ${widget.campagne}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Exporter CSV",
            onPressed: _exporterDonnees,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PARCELLES ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("PARCELLES",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() =>
                        _parcellesSelectionnees = List.from(_parcellesBase)),
                    child: const Text("TOUT COCHER",
                        style:
                            TextStyle(color: Color(0xff76ff03), fontSize: 12)),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(
                    "${_parcellesSelectionnees.length} / ${_parcellesBase.length} sélectionnée(s)",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  children: _parcellesBase
                      .map((p) => CheckboxListTile(
                            activeColor: const Color(0xff76ff03),
                            title: Text(p,
                                style: const TextStyle(color: Colors.white)),
                            value: _parcellesSelectionnees.contains(p),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => val
                                    ? _parcellesSelectionnees.add(p)
                                    : _parcellesSelectionnees.remove(p));
                              }
                            },
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 25),

              // --- PRODUITS & DOSES ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("PRODUITS & DOSES UNITAIRES",
                      style: TextStyle(
                          color: Color(0xff76ff03),
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Color(0xff76ff03)),
                    tooltip: "Ajouter un produit",
                    onPressed: () {
                      _nouveauProduitController.clear();
                      _dialogueProduit();
                    },
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _produitsBase
                    .map((p) => FilterChip(
                          label: Text(p),
                          selected: _produitsSelectionnes.contains(p),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _produitsSelectionnes.add(p);
                                _dosesProduitsControllers[p] =
                                    TextEditingController();
                              } else {
                                _produitsSelectionnes.remove(p);
                                _dosesProduitsControllers[p]?.dispose();
                                _dosesProduitsControllers.remove(p);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              ..._produitsSelectionnes.map((p) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(p,
                              style: const TextStyle(color: Colors.white70)),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _dosesProduitsControllers[p],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration("Dose (kg ou L / ha)"),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? "Obligatoire" : null,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 25),

              // --- VOLUME DE BOUILLIE ---
              const Text("VOLUME DE BOUILLIE",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _volumeBouillieController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration("Volume total épandu (L/ha)"),
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Champ obligatoire" : null,
              ),
              const SizedBox(height: 25),

              // --- CIBLES ---
              const Text("CIBLES",
                  style: TextStyle(
                      color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _parasitesDisponibles
                    .map((p) => FilterChip(
                          label: Text(p),
                          selected: _parasitesSelectionnes.contains(p),
                          onSelected: (val) => setState(() => val
                              ? _parasitesSelectionnes.add(p)
                              : _parasitesSelectionnes.remove(p)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // --- DATE ---
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading:
                    const Icon(Icons.calendar_today, color: Color(0xff76ff03)),
                title: Text(
                  DateFormat('dd / MM / yyyy').format(_dateSelectionnee),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateSelectionnee,
                    firstDate: DateTime(annee - 1),
                    lastDate: DateTime(annee + 2),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xff76ff03),
                          onPrimary: Colors.black,
                          surface: Color(0xFF1E1E1E),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() => _dateSelectionnee = picked);
                  }
                },
              ),
              const SizedBox(height: 15),

              // --- COMMENTAIRE ---
              TextFormField(
                controller: _commentaireController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Commentaire"),
              ),
              const SizedBox(height: 30),

              // --- BOUTON VALIDER ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff76ff03),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _valider,
                  child: const Text(
                    "VALIDER LE PASSAGE",
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dialogueProduit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Nouveau Produit",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _nouveauProduitController,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration("Nom du produit"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              await _ajouterProduitALaBase();
              navigator.pop();
            },
            child: const Text("AJOUTER",
                style: TextStyle(color: Color(0xff76ff03))),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xff76ff03))),
      );
}
