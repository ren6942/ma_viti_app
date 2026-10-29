import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'parcelles_page.dart';
import 'sulfatage_page.dart';
import 'desherbage_page.dart';
import 'rognage_page.dart';
import 'taille_page.dart';
import 'maintenance_page.dart';
import 'historique_page.dart';
import 'vendange_page.dart';
import 'travaux_en_vert_page.dart';
import 'meteo_page.dart';
import 'icon_manager.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Initialisé immédiatement avec la bonne valeur — plus d'affichage incorrect
  // au premier build avant que _chargerCampagneActive() ne termine
  late String campagneActive;

  // Généré dynamiquement : année précédente + 3 suivantes — cohérent avec
  // HistoriquePage et les autres pages
  late List<String> listeSaisons;

  @override
  void initState() {
    super.initState();
    final int annee = DateTime.now().year;
    listeSaisons = List.generate(4, (i) => (annee - 1 + i).toString());

    // Valeur par défaut cohérente avec DatabaseHelper.calculerCampagne()
    campagneActive = DatabaseHelper.instance
        .calculerCampagne(DateTime.now().toIso8601String());

    _chargerCampagneActive();
  }

  Future<void> _chargerCampagneActive() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      // Source de vérité unique pour la logique campagne
      final String detectee = DatabaseHelper.instance
          .calculerCampagne(DateTime.now().toIso8601String());
      campagneActive = prefs.getString('campagne_active') ?? detectee;

      // Saisons personnalisées sauvegardées dans les prefs
      final List<String>? saisonsPerso =
          prefs.getStringList('liste_saisons_perso');
      if (saisonsPerso != null) {
        for (var s in saisonsPerso) {
          if (!listeSaisons.contains(s)) listeSaisons.add(s);
        }
      }
    });
  }

  Future<void> _changerCampagne(String nouvelleCampagne) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('campagne_active', nouvelleCampagne);
    if (mounted) setState(() => campagneActive = nouvelleCampagne);
  }

  void _confirmerResetBase() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "RESET TOTAL ?",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Cela va supprimer TOUTES vos données. Continuer ?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.reinitialiserBase();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Base de données réinitialisée"),
                  backgroundColor: Colors.green,
                ));
              }
            },
            child: const Text("OUI, TOUT SUPPRIMER"),
          ),
        ],
      ),
    );
  }

  Future<void> _naviguerVers(Widget page, {bool verifParcelle = true}) async {
    try {
      if (verifParcelle) {
        final parcelles = await DatabaseHelper.instance.getListeParcellesFull();
        if (!mounted) return;
        if (parcelles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Créez d'abord des parcelles dans 'CONFIG'"),
            backgroundColor: Colors.orange,
          ));
          return;
        }
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("VITI APP - $campagneActive"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Paramètres",
            onPressed: () =>
                _naviguerVers(const SettingsPage(), verifParcelle: false),
          ),
          // Bouton reset masqué en production — visible uniquement en debug
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.redAccent),
              tooltip: "Réinitialiser la base (debug)",
              onPressed: _confirmerResetBase,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Changer de campagne",
            onSelected: _changerCampagne,
            itemBuilder: (context) => listeSaisons
                .map((s) => PopupMenuItem(value: s, child: Text("Campagne $s")))
                .toList(),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(10),
        childAspectRatio: 1.1,
        children: [
          _menuItem(
            "SULFATAGE",
            Icons.opacity,
            () => _naviguerVers(SulfatagePage(campagne: campagneActive)),
          ),
          _menuItem(
            "DÉSHERBAGE",
            Icons.grass,
            () => _naviguerVers(DesherbagePage(campagne: campagneActive)),
          ),
          _menuItem(
            "ROGNAGE",
            Icons.content_cut,
            () => _naviguerVers(RognagePage(campagne: campagneActive)),
          ),
          _menuItem(
            "TAILLE",
            Icons.cut,
            () => _naviguerVers(TaillePage(campagne: campagneActive)),
          ),
          _menuItem(
            "ENTRETIEN",
            Icons.build,
            () => _naviguerVers(MaintenancePage(campagne: campagneActive)),
          ),
          _menuItem(
            "VENDANGE",
            Icons.local_drink,
            () => _naviguerVers(VendangePage(campagne: campagneActive)),
          ),
          _menuItem(
            "TRAVAUX VERTS",
            Icons.eco,
            () => _naviguerVers(TravauxVertsPage(campagne: campagneActive)),
          ),
          _menuItem(
            "MÉTÉO",
            Icons.wb_sunny,
            () => _naviguerVers(const MeteoPage(), verifParcelle: false),
          ),
          _menuItem(
            "HISTORIQUE",
            Icons.history,
            () => _naviguerVers(const HistoriquePage(), verifParcelle: false),
          ),
          _menuItem(
            "CONFIG",
            Icons.settings_applications,
            () => _naviguerVers(const ParcellesPage(), verifParcelle: false),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    String titre,
    IconData defaultIcon,
    VoidCallback action, {
    String? customKey,
  }) {
    // Normalisation : minuscules + underscores + suppression des accents
    // pour garantir des clés identiques entre HomePage et SettingsPage
    final String key = customKey ??
        titre
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('é', 'e')
            .replaceAll('è', 'e')
            .replaceAll('ê', 'e')
            .replaceAll('ë', 'e')
            .replaceAll('à', 'a')
            .replaceAll('â', 'a')
            .replaceAll('ô', 'o')
            .replaceAll('ù', 'u')
            .replaceAll('û', 'u')
            .replaceAll('î', 'i')
            .replaceAll('ï', 'i')
            .replaceAll('ç', 'c');

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: action,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconManager.getIcon(
              key,
              defaultIcon: defaultIcon,
              size: 60,
              color: const Color(0xff76ff03),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
