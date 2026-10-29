import 'package:flutter/material.dart';
import 'package:slider_button/slider_button.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'maintenance_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MaintenancePage extends StatefulWidget {
  final String campagne;
  const MaintenancePage({super.key, required this.campagne});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final _formKey = GlobalKey<FormState>();
  String? selectedParcelle;

  final List<String> typesMaintenance = [
    "Fil porteur",
    "Fil releveur",
    "Fil d'amarre",
    "Fil fixe",
    "Piquet de tête",
    "Piquet d'amarre",
    "Piquet de rang",
    "Autre",
  ];

  // Catégories associées à chaque type — robuste aux ajouts futurs
  static const Map<String, String> _typeCategory = {
    "Piquet de tête": "PIQUET",
    "Piquet d'amarre": "PIQUET",
    "Piquet de rang": "PIQUET",
  };

  late String typeCasse;

  final TextEditingController rangController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  List<String> parcellesList = [];
  DateTime dateSignalement = DateTime.now();

  @override
  void initState() {
    super.initState();
    typeCasse = typesMaintenance.first;
    _chargerParcelles();
  }

  @override
  void dispose() {
    rangController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> _chargerParcelles() async {
    final list = await DatabaseHelper.instance.getListeParcelles();
    if (mounted) setState(() => parcellesList = list);
  }

  Future<void> _choisirDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateSignalement,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.orange.shade900,
              onPrimary: Colors.white,
              surface: const Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => dateSignalement = picked);
  }

  Future<void> _exporterDonnees() async {
    try {
      List<String> colonnes = [
        'campagne',
        'parcelle',
        'type',
        'type_fil',
        'rang',
        'description',
        'statut',
        'date',
        'commentaire',
      ];

      String csv = await DatabaseHelper.instance
          .exportTableToCSV('maintenance', colonnes);
      final directory = await getTemporaryDirectory();
      String timestamp = DateFormat('HHmmss').format(DateTime.now());
      final file = File('${directory.path}/maintenance_$timestamp.csv');

      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Export Maintenance ${widget.campagne}',
      );
    } catch (e) {
      _showError("Erreur export : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "MAINTENANCE ${widget.campagne}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exporterDonnees,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "OÙ EST LE PROBLÈME ?",
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E1E1E),
                initialValue: selectedParcelle,
                items: parcellesList
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p,
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedParcelle = v),
                decoration: _inputDecoration("Sélectionner la parcelle"),
                validator: (v) => v == null ? "Champ obligatoire" : null,
              ),
              const SizedBox(height: 15),
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                title: Text(
                  "Date : ${DateFormat('dd/MM/yyyy').format(dateSignalement)}",
                  style: const TextStyle(color: Colors.white),
                ),
                trailing:
                    const Icon(Icons.calendar_today, color: Colors.orange),
                onTap: _choisirDate,
              ),
              const SizedBox(height: 25),
              const Text(
                "DÉTAILS TECHNIQUES",
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1E1E1E),
                initialValue: typeCasse,
                decoration: _inputDecoration("Type de casse"),
                style: const TextStyle(color: Colors.white),
                items: typesMaintenance
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => typeCasse = v);
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: rangController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("Numéro du rang (optionnel)"),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration:
                    _inputDecoration("Description / Localisation précise"),
                validator: (v) =>
                    (v == null || v.isEmpty) ? "Description requise" : null,
              ),
              const SizedBox(height: 40),
              Center(
                child: SliderButton(
                  width: 280,
                  height: 60,
                  action: () async {
                    if (_formKey.currentState!.validate()) {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        String dateString =
                            DateFormat('yyyy-MM-dd').format(dateSignalement);

                        await MaintenanceService.instance.insertMaintenance({
                          'campagne': widget.campagne,
                          'parcelle': selectedParcelle,
                          'date': dateString,
                          'type': _typeCategory[typeCasse] ?? "FIL",
                          'type_fil': typeCasse,
                          'rang': rangController.text.trim().isEmpty
                              ? "N/A"
                              : rangController.text.trim(),
                          'description': descController.text.trim(),
                          'statut': "A FAIRE",
                          'commentaire': "",
                        });

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("Signalement enregistré !"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        navigator.pop();
                        return true;
                      } catch (e) {
                        _showError("Erreur : $e");
                        return false;
                      }
                    }
                    return false;
                  },
                  label: const Text(
                    "GLISSER POUR SIGNALER",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 30),
                  buttonColor: Colors.orange.shade900,
                  backgroundColor: const Color(0xFF1E1E1E),
                  highlightedColor: Colors.white,
                  baseColor: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
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
            borderSide: const BorderSide(color: Colors.orange)),
      );
}
