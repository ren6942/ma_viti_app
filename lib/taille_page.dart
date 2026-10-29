import 'package:flutter/material.dart';
import 'package:slider_button/slider_button.dart';
import 'package:intl/intl.dart';
import 'parcelle_service.dart';
import 'taille_service.dart';

class TaillePage extends StatefulWidget {
  final String campagne;
  const TaillePage({super.key, required this.campagne});

  @override
  State<TaillePage> createState() => _TaillePageState();
}

class _TaillePageState extends State<TaillePage> {
  // Singletons — cohérents avec le reste de l'app
  final ParcelleService _pService = ParcelleService.instance;
  final TailleService _tService = TailleService.instance;

  Map<String, bool> selectedParcelles = {};
  DateTime dateDebut = DateTime.now();
  DateTime dateFin = DateTime.now();

  String typeTaille = "Guyot simple";
  final List<String> modelesTaille = [
    "Guyot simple",
    "Guyot double",
    "Cordon",
    "Gobelet",
    "Taille rase",
  ];

  final TextEditingController _commController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerParcelles();
  }

  @override
  void dispose() {
    _commController.dispose();
    super.dispose();
  }

  Future<void> _chargerParcelles() async {
    try {
      final list = await _pService.getListeParcellesFull();
      if (mounted) {
        setState(() {
          selectedParcelles = {for (var p in list) p['nom'].toString(): false};
        });
      }
    } catch (e) {
      debugPrint("TaillePage._chargerParcelles : $e");
    }
  }

  Future<void> _selectionnerDate(BuildContext context, bool isDebut) async {
    final int annee = DateTime.now().year;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? dateDebut : dateFin,
      firstDate: DateTime(annee - 1),
      lastDate: DateTime(annee + 2),
      locale: const Locale('fr', 'FR'),
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
      setState(() {
        if (isDebut) {
          dateDebut = picked;
          if (dateFin.isBefore(dateDebut)) dateFin = dateDebut;
        } else {
          dateFin = picked;
        }
      });
    }
  }

  // Retourne true si succès — utilisé par SliderButton
  Future<bool> _validerChantier() async {
    if (!mounted) return false;

    final List<String> selection = selectedParcelles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sélectionnez au moins une parcelle"),
        backgroundColor: Colors.orange,
      ));
      return false;
    }

    try {
      String commentaireFinal =
          "Chantier du ${DateFormat('dd/MM').format(dateDebut)}"
          " au ${DateFormat('dd/MM').format(dateFin)} - $typeTaille";
      if (_commController.text.trim().isNotEmpty) {
        commentaireFinal += " - ${_commController.text.trim()}";
      }

      for (final p in selection) {
        await _tService.insertTaille({
          'campagne': widget.campagne,
          'parcelle': p,
          'type_taille': typeTaille,
          'date': DateFormat('yyyy-MM-dd').format(dateDebut),
          'commentaire': commentaireFinal,
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
    final String dStr = DateFormat('dd/MM').format(dateDebut);
    final String fStr = DateFormat('dd/MM').format(dateFin);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("TAILLE ${widget.campagne}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E1E1E),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // --- SÉLECTION DATES ---
            Row(
              children: [
                Expanded(
                  child: _buildDateCard(
                    "Début",
                    "$dStr/${dateDebut.year}",
                    () => _selectionnerDate(context, true),
                    Icons.calendar_today,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward, color: Colors.white24),
                ),
                Expanded(
                  child: _buildDateCard(
                    "Fin",
                    "$fStr/${dateFin.year}",
                    () => _selectionnerDate(context, false),
                    Icons.event_available,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // --- TYPE DE TAILLE ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: typeTaille,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: modelesTaille
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => typeTaille = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- LISTE PARCELLES ---
            Expanded(
              child: selectedParcelles.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucune parcelle disponible.\nAjoutez-en dans CONFIG.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView(
                      children: selectedParcelles.keys.map((String key) {
                        return CheckboxListTile(
                          title: Text(key,
                              style: const TextStyle(color: Colors.white)),
                          value: selectedParcelles[key] ?? false,
                          activeColor: const Color(0xff76ff03),
                          onChanged: (bool? v) {
                            if (v != null) {
                              setState(() => selectedParcelles[key] = v);
                            }
                          },
                        );
                      }).toList(),
                    ),
            ),

            // --- COMMENTAIRE ---
            TextField(
              controller: _commController,
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
            const SizedBox(height: 20),

            // --- SLIDER VALIDATION ---
            SliderButton(
              action: () async => await _validerChantier(),
              label: const Text(
                "VALIDER LE CHANTIER",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              icon: const Icon(Icons.content_cut, color: Colors.black),
              backgroundColor: const Color(0xff76ff03),
              width: 280,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(
    String title,
    String date,
    VoidCallback onTap,
    IconData icon,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(children: [
              Icon(icon, color: Colors.white24, size: 14),
              const SizedBox(width: 5),
              Text(title,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            Text(
              date,
              style: const TextStyle(
                color: Color(0xff76ff03),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
