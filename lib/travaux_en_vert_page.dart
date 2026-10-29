import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:slider_button/slider_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'parcelle_service.dart';
import 'travaux_service.dart';

class TravauxVertsPage extends StatefulWidget {
  final String campagne;
  const TravauxVertsPage({super.key, required this.campagne});

  @override
  State<TravauxVertsPage> createState() => _TravauxVertsPageState();
}

class _TravauxVertsPageState extends State<TravauxVertsPage> {
  // Singletons — cohérents avec le reste de l'app
  final ParcelleService _pService = ParcelleService.instance;
  final TravauxService _tService = TravauxService.instance;

  // Types de base — source unique de vérité, utilisée partout
  static const List<String> _typesBase = [
    "Ébourgeonnage",
    "Relevage / Palissage",
    "Épamprage",
    "Effeuillage",
    "Vendange en vert",
  ];

  List<String> parcellesList = [];
  Map<String, bool> selectedParcelles = {};
  DateTime dateTravail = DateTime.now();
  final TextEditingController commentController = TextEditingController();
  String? typeTravail;
  List<String> typesVerts = [..._typesBase, "Autre"];

  @override
  void initState() {
    super.initState();
    _chargerDonneesInitiales();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonneesInitiales() async {
    try {
      final list = await _pService.getListeParcellesFull();
      final noms = list.map((e) => e['nom'].toString()).toList();

      final prefs = await SharedPreferences.getInstance();
      final List<String> travauxPerso =
          prefs.getStringList('types_verts_perso') ?? [];

      if (mounted) {
        setState(() {
          parcellesList = noms;
          selectedParcelles = {for (var p in noms) p: false};
          // Reconstruction propre depuis la source unique
          typesVerts = [..._typesBase, ...travauxPerso, "Autre"];
        });
      }
    } catch (e) {
      debugPrint("TravauxVertsPage._chargerDonneesInitiales : $e");
    }
  }

  Future<void> _ajouterNouveauTravail(String nouveauType) async {
    if (nouveauType.isEmpty || typesVerts.contains(nouveauType)) return;
    try {
      setState(() {
        // Insère avant "Autre" qui reste toujours en dernier
        typesVerts.insert(typesVerts.length - 1, nouveauType);
        typeTravail = nouveauType;
      });

      final prefs = await SharedPreferences.getInstance();
      final List<String> travauxPerso =
          prefs.getStringList('types_verts_perso') ?? [];
      travauxPerso.add(nouveauType);
      await prefs.setStringList('types_verts_perso', travauxPerso);
    } catch (e) {
      debugPrint("TravauxVertsPage._ajouterNouveauTravail : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Erreur lors de l'ajout du travail"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _supprimerTravailPerso(String travail) async {
    try {
      setState(() {
        typesVerts.remove(travail);
        if (typeTravail == travail) typeTravail = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final List<String> travauxPerso =
          prefs.getStringList('types_verts_perso') ?? [];
      travauxPerso.remove(travail);
      await prefs.setStringList('types_verts_perso', travauxPerso);
    } catch (e) {
      debugPrint("TravauxVertsPage._supprimerTravailPerso : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Erreur lors de la suppression"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _afficherDialogAutre() {
    final TextEditingController autreController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Nouveau type de travail",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: autreController,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: "Nom du travail...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xff76ff03))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () {
              final String val = autreController.text.trim();
              Navigator.pop(ctx);
              if (val.isNotEmpty) _ajouterNouveauTravail(val);
            },
            child: const Text("AJOUTER",
                style: TextStyle(color: Color(0xff76ff03))),
          ),
        ],
      ),
    );
  }

  void _afficherMenuTravaux() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView.builder(
        itemCount: typesVerts.length,
        itemBuilder: (ctx, i) {
          final String t = typesVerts[i];
          final bool isPerso = !_typesBase.contains(t) && t != "Autre";
          final bool isSelected = t == typeTravail;

          return ListTile(
            title: Text(
              t,
              style: TextStyle(
                color: isSelected ? const Color(0xff76ff03) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: t == "Autre"
                ? const Icon(Icons.add, color: Color(0xff76ff03))
                : isPerso
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _supprimerTravailPerso(t);
                        },
                      )
                    : null,
            onTap: () {
              if (t == "Autre") {
                Navigator.pop(ctx);
                _afficherDialogAutre();
              } else {
                setState(() => typeTravail = t);
                Navigator.pop(ctx);
              }
            },
          );
        },
      ),
    );
  }

  // Retourne true si succès — utilisé par SliderButton
  Future<bool> _validerChantier() async {
    if (!mounted) return false;

    final List<String> selection = selectedParcelles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selection.isEmpty || typeTravail == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sélectionnez un travail et au moins une parcelle"),
        backgroundColor: Colors.orange,
      ));
      return false;
    }

    try {
      for (final p in selection) {
        await _tService.enregistrerTravauxVerts({
          'campagne': widget.campagne,
          'parcelle': p,
          'type_travail': typeTravail,
          'date': DateFormat('yyyy-MM-dd').format(dateTravail),
          'commentaire': commentController.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int annee = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("TRAVAUX EN VERT - ${widget.campagne}"),
        backgroundColor: Colors.green.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // --- DATE ---
            ListTile(
              tileColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              leading:
                  const Icon(Icons.calendar_today, color: Color(0xff76ff03)),
              title: Text(
                DateFormat('dd/MM/yyyy').format(dateTravail),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: dateTravail,
                  firstDate: DateTime(annee - 1),
                  lastDate: DateTime(annee + 2),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: const Color(0xff76ff03),
                        onPrimary: Colors.black,
                        surface: const Color(0xFF1E1E1E),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (date != null) setState(() => dateTravail = date);
              },
            ),
            const SizedBox(height: 10),

            // --- TYPE DE TRAVAUX ---
            InkWell(
              onTap: _afficherMenuTravaux,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: typeTravail != null
                        ? const Color(0xff76ff03)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      typeTravail ?? "Sélectionner un travail",
                      style: TextStyle(
                        color:
                            typeTravail != null ? Colors.white : Colors.white38,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // --- LISTE PARCELLES ---
            Expanded(
              child: parcellesList.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucune parcelle disponible.\nAjoutez-en dans CONFIG.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: parcellesList.length,
                      itemBuilder: (context, index) => CheckboxListTile(
                        activeColor: Colors.greenAccent,
                        title: Text(parcellesList[index],
                            style: const TextStyle(color: Colors.white)),
                        value: selectedParcelles[parcellesList[index]] ?? false,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() =>
                                selectedParcelles[parcellesList[index]] = v);
                          }
                        },
                      ),
                    ),
            ),

            // --- COMMENTAIRE ---
            TextField(
              controller: commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Commentaire...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff76ff03))),
              ),
            ),
            const SizedBox(height: 15),

            // --- SLIDER VALIDATION ---
            SliderButton(
              action: () async => await _validerChantier(),
              label: const Text(
                "VALIDER LES TRAVAUX",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.check, color: Colors.black),
              backgroundColor: const Color(0xff76ff03),
              width: 280,
            ),
          ],
        ),
      ),
    );
  }
}
