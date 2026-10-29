import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'parcelle_service.dart';
import 'travaux_service.dart';

class VendangePage extends StatefulWidget {
  final String campagne;
  const VendangePage({super.key, required this.campagne});

  @override
  State<VendangePage> createState() => _VendangePageState();
}

class _VendangePageState extends State<VendangePage> {
  // Singletons — cohérents avec le reste de l'app
  final ParcelleService _pService = ParcelleService.instance;
  final TravauxService _tService = TravauxService.instance;

  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _commentaireController = TextEditingController();

  String? _parcelleSelectionnee;
  List<String> _parcelles = [];
  DateTime _dateSelectionnee = DateTime.now();

  @override
  void initState() {
    super.initState();
    _chargerParcelles();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _commentaireController.dispose();
    super.dispose();
  }

  Future<void> _chargerParcelles() async {
    try {
      final list = await _pService.getListeParcellesFull();
      final noms = list.map((e) => e['nom'].toString()).toList();
      if (mounted) {
        setState(() {
          _parcelles = noms;
          _parcelleSelectionnee =
              _parcelles.isNotEmpty ? _parcelles.first : null;
        });
      }
    } catch (e) {
      debugPrint("VendangePage._chargerParcelles : $e");
    }
  }

  Future<void> _choisirDate() async {
    final int annee = DateTime.now().year;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateSelectionnee,
      firstDate: DateTime(annee - 1),
      lastDate: DateTime(annee + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.purple.shade300,
            onPrimary: Colors.white,
            surface: const Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateSelectionnee = picked);
  }

  Future<void> _enregistrerVendange() async {
    if (!mounted) return;

    if (_parcelleSelectionnee == null ||
        _detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sélectionnez une parcelle et saisissez les détails"),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    try {
      await _tService.enregistrerVendange({
        'campagne': widget.campagne,
        'parcelle': _parcelleSelectionnee,
        'date': DateFormat('yyyy-MM-dd').format(_dateSelectionnee),
        'details': _detailsController.text.trim(),
        'commentaire': _commentaireController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Récolte enregistrée pour ${widget.campagne}"),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Erreur : $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("VENDANGE ${widget.campagne}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple.shade900,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- PARCELLE ---
            _parcelles.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.white38, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Aucune parcelle disponible.\nAjoutez-en dans CONFIG.",
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    initialValue: _parcelleSelectionnee,
                    items: _parcelles
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p,
                                  style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _parcelleSelectionnee = v);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Parcelle",
                      labelStyle: TextStyle(color: Colors.purple.shade200),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: Colors.purple.shade300)),
                    ),
                  ),

            const SizedBox(height: 15),

            // --- DATE ---
            ListTile(
              tileColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              title: Text(
                "Date : ${DateFormat('dd/MM/yyyy').format(_dateSelectionnee)}",
                style: const TextStyle(color: Colors.white),
              ),
              trailing:
                  Icon(Icons.calendar_today, color: Colors.purple.shade300),
              onTap: _choisirDate,
            ),

            const SizedBox(height: 15),

            // --- DÉTAILS ---
            TextField(
              controller: _detailsController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Détails (ex: kg récoltés)"),
            ),

            const SizedBox(height: 12),

            // --- COMMENTAIRE ---
            TextField(
              controller: _commentaireController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecoration("Commentaire"),
            ),

            const SizedBox(height: 30),

            // --- BOUTON ENREGISTRER ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _enregistrerVendange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "ENREGISTRER LA RÉCOLTE",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
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
            borderSide: BorderSide(color: Colors.purple.shade300)),
      );
}
