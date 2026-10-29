import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';

// Classe pour gérer chaque ligne de produit/dose
class ProduitSaisi {
  String nom;
  TextEditingController doseController;

  ProduitSaisi({this.nom = "Glyphosate"})
      : doseController = TextEditingController();
}

class DesherbagePage extends StatefulWidget {
  final String campagne;
  const DesherbagePage({super.key, required this.campagne});

  @override
  State<DesherbagePage> createState() => _DesherbagePageState();
}

class _DesherbagePageState extends State<DesherbagePage> {
  final _formKey = GlobalKey<FormState>();
  DateTime _dateSelectionnee = DateTime.now();
  final TextEditingController _commentaireController = TextEditingController();

  // Liste dynamique de produits — toujours au moins un élément
  final List<ProduitSaisi> _listeProduits = [ProduitSaisi()];

  List<String> _parcellesBase = [];
  final List<String> _modesApplication = [
    "Sous le rang",
    "Inter-rang",
    "Total",
    "Localisé (taches)",
  ];

  final List<String> _produitsChimiques = [
    "Glyphosate",
    "Anti-germinatif",
    "Herbicide sélectif",
  ];

  final List<String> _parcellesSelectionnees = [];
  String _modeSelectionne = "Sous le rang";

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    for (var p in _listeProduits) {
      p.doseController.dispose();
    }
    _commentaireController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    final p = await DatabaseHelper.instance.getListeParcelles();
    if (mounted) setState(() => _parcellesBase = p);
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;

    if (_parcellesSelectionnees.isEmpty) {
      _notifier("Sélectionnez au moins une parcelle", Colors.orange);
      return;
    }

    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_dateSelectionnee);
      String campagneReelle = DatabaseHelper.instance.calculerCampagne(dateStr);

      for (String parcelle in _parcellesSelectionnees) {
        for (var p in _listeProduits) {
          if (p.nom.isEmpty) continue;
          double dose =
              double.tryParse(p.doseController.text.replaceAll(',', '.')) ??
                  0.0;

          await DatabaseHelper.instance.insertTravail('desherbage', {
            'campagne': campagneReelle,
            'parcelle': parcelle,
            'produit': p.nom,
            'parasite': _modeSelectionne,
            'dose_ha': dose,
            'date': dateStr,
            'commentaire': _commentaireController.text.trim(),
          });
        }
      }

      _notifier("Désherbage enregistré !", const Color(0xff76ff03));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _notifier("Erreur enregistrement : $e", Colors.red);
    }
  }

  void _notifier(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xff76ff03);
    final int annee = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("DÉSHERBAGE ${widget.campagne}"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.grass, color: primaryColor, size: 28),
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
              const Text(
                "PARCELLES",
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(
                    "${_parcellesSelectionnees.length} sélectionnée(s)",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  children: _parcellesBase
                      .map((p) => CheckboxListTile(
                            title: Text(p,
                                style: const TextStyle(color: Colors.white)),
                            value: _parcellesSelectionnees.contains(p),
                            onChanged: (val) => setState(() => val == true
                                ? _parcellesSelectionnees.add(p)
                                : _parcellesSelectionnees.remove(p)),
                          ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 25),

              // --- MODE D'APPLICATION ---
              const Text(
                "MODE D'APPLICATION",
                style: TextStyle(
                    color: Colors.orangeAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _modeSelectionne,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Type de passage"),
                items: _modesApplication
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _modeSelectionne = val);
                },
              ),

              const SizedBox(height: 25),

              // --- PRODUITS & DOSES ---
              const Text(
                "PRODUITS & DOSES",
                style: TextStyle(
                    color: Color(0xff76ff03), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _listeProduits.length,
                itemBuilder: (ctx, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _listeProduits[index].nom,
                          dropdownColor: const Color(0xFF1E1E1E),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Produit"),
                          items: _produitsChimiques
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _listeProduits[index].nom = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _listeProduits[index].doseController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("L/ha"),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Dose requise";
                            final d = double.tryParse(v.replaceAll(',', '.'));
                            if (d == null || d <= 0) return "Dose invalide";
                            return null;
                          },
                        ),
                      ),
                      // Bouton désactivé si un seul produit reste
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle,
                          color: _listeProduits.length > 1
                              ? Colors.red
                              : Colors.red.withValues(alpha: 0.3),
                        ),
                        onPressed: _listeProduits.length > 1
                            ? () {
                                _listeProduits[index].doseController.dispose();
                                setState(() => _listeProduits.removeAt(index));
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, color: Color(0xff76ff03)),
                label: const Text("Ajouter un produit",
                    style: TextStyle(color: Color(0xff76ff03))),
                onPressed: () =>
                    setState(() => _listeProduits.add(ProduitSaisi())),
              ),

              const SizedBox(height: 20),

              // --- DATE ---
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.calendar_today, color: primaryColor),
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

              // --- BOUTON ENREGISTRER ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff76ff03),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _valider,
                  child: const Text(
                    "ENREGISTRER",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
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
