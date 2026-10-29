import 'package:flutter/material.dart';
import 'package:slider_button/slider_button.dart';
import 'package:intl/intl.dart';
import 'parcelle_service.dart';
import 'travaux_service.dart';

class RognagePage extends StatefulWidget {
  final String campagne;
  const RognagePage({super.key, required this.campagne});

  @override
  State<RognagePage> createState() => _RognagePageState();
}

class _RognagePageState extends State<RognagePage> {
  final ParcelleService _pService = ParcelleService.instance;
  final TravauxService _tService = TravauxService.instance;

  List<String> parcellesList = [];
  Map<String, bool> selectedParcelles = {};
  DateTime dateRognage = DateTime.now();
  final TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerParcelles();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _chargerParcelles() async {
    try {
      final data = await _pService.getListeParcellesFull();
      final noms = data.map((e) => e['nom'].toString()).toList();
      if (mounted) {
        setState(() {
          parcellesList = noms;
          selectedParcelles = {for (var p in noms) p: false};
        });
      }
    } catch (e) {
      debugPrint("RognagePage._chargerParcelles : $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final int annee = DateTime.now().year;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateRognage,
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
    if (picked != null && picked != dateRognage) {
      setState(() => dateRognage = picked);
    }
  }

  Future<bool> _validerRognage() async {
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
      final String sqlDateStr = DateFormat('yyyy-MM-dd').format(dateRognage);
      for (final p in selection) {
        await _tService.insertTravaux({
          'campagne': widget.campagne,
          'parcelle': p,
          'date': sqlDateStr,
          'commentaire': commentController.text.trim(),
        }, tableName: 'rognage');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Rognage enregistré !"),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text("ROGNAGE ${widget.campagne}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            ListTile(
              tileColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              title: Text(
                "Date : ${DateFormat('dd/MM/yyyy').format(dateRognage)}",
                style: const TextStyle(color: Colors.white),
              ),
              trailing:
                  const Icon(Icons.calendar_today, color: Color(0xff76ff03)),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 10),
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
                      itemBuilder: (context, index) {
                        final String p = parcellesList[index];
                        return CheckboxListTile(
                          title: Text(p,
                              style: const TextStyle(color: Colors.white)),
                          value: selectedParcelles[p] ?? false,
                          activeColor: const Color(0xff76ff03),
                          onChanged: (bool? v) {
                            if (v != null) {
                              setState(() => selectedParcelles[p] = v);
                            }
                          },
                        );
                      },
                    ),
            ),
            TextField(
              controller: commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Commentaire",
                labelStyle: const TextStyle(color: Colors.white54),
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
            SliderButton(
              action: () async => await _validerRognage(),
              label: const Text("VALIDER LE ROGNAGE",
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
