import 'package:flutter/material.dart';
import 'page_historique_detail.dart';

class PageMenuHistorique extends StatelessWidget {
  const PageMenuHistorique({super.key});

  // static const — recréation inutile évitée à chaque rebuild
  static const Map<String, Map<String, dynamic>> _travauxConfig = {
    'sulfatage': {'nom': 'SUIVI PHYTOSANITAIRE', 'icon': Icons.opacity},
    'desherbage': {'nom': 'DÉSHERBAGE', 'icon': Icons.grass},
    'taille': {'nom': 'TAILLE DES VIGNES', 'icon': Icons.content_cut},
    'maintenance': {'nom': 'MAINTENANCE', 'icon': Icons.build},
    'travaux_verts': {'nom': 'TRAVAUX EN VERT', 'icon': Icons.nature},
    'rognage': {'nom': 'ROGNAGE', 'icon': Icons.agriculture},
    'vendange': {'nom': 'VENDANGE', 'icon': Icons.wine_bar},
  };

  @override
  Widget build(BuildContext context) {
    final List<String> tables = _travauxConfig.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("HISTORIQUE",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: tables.isEmpty
          ? const Center(
              child: Text("Aucune catégorie disponible",
                  style: TextStyle(color: Colors.white24)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: tables.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final String tableKey = tables[index];
                final Map<String, dynamic> config = _travauxConfig[tableKey]!;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Icon(config['icon'] as IconData,
                          color: const Color(0xff76ff03)),
                    ),
                    title: Text(
                      config['nom'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PageHistoriqueDetail(table: tableKey),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
