import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'icon_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ImagePicker _picker = ImagePicker();

  // Correspondance exacte avec les clés générées dans HomePage._menuItem()
  // key = customKey ?? titre.toLowerCase().replaceAll(" ", "_")
  static const List<Map<String, dynamic>> _items = [
    {'title': 'Sulfatage', 'key': 'sulfatage', 'icon': Icons.opacity},
    {'title': 'Désherbage', 'key': 'desherbage', 'icon': Icons.grass},
    {'title': 'Rognage', 'key': 'rognage', 'icon': Icons.agriculture},
    {'title': 'Taille', 'key': 'taille', 'icon': Icons.content_cut},
    {'title': 'Entretien', 'key': 'entretien', 'icon': Icons.build},
    {'title': 'Vendange', 'key': 'vendange', 'icon': Icons.wine_bar},
    {'title': 'Travaux Verts', 'key': 'travaux_verts', 'icon': Icons.nature},
    {'title': 'Météo', 'key': 'meteo', 'icon': Icons.wb_sunny},
    {'title': 'Historique', 'key': 'historique', 'icon': Icons.history},
    {'title': 'Config', 'key': 'config', 'icon': Icons.settings_applications},
  ];

  Future<void> _pickIcon(String key) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      // Copie l'image dans le dossier permanent de l'app
      // (nom fixe → la nouvelle image remplace silencieusement l'ancienne)
      final directory = await getApplicationDocumentsDirectory();
      final String localPath = '${directory.path}/icon_$key.jpg';
      final File localImage = await File(image.path).copy(localPath);

      await IconManager.setCustomIcon(key, localImage.path);

      // Force le rebuild pour que getIcon() relise le cache IconManager
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Icône mise à jour !"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint("SettingsPage._pickIcon [$key] : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Erreur lors de l'import de l'image"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetIcon(String key) async {
    await IconManager.removeCustomIcon(key);
    // Force le rebuild pour afficher à nouveau l'icône par défaut
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Icône réinitialisée"),
        backgroundColor: Colors.blueGrey,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("PERSONNALISATION")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildIconTile(
            item['title'] as String,
            item['key'] as String,
            item['icon'] as IconData,
          );
        },
      ),
    );
  }

  Widget _buildIconTile(String title, String key, IconData defIcon) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: IconManager.getIcon(
              key,
              defaultIcon: defIcon,
              size: 32, // taille explicite — ×1.5 dans IconManager = 48px
              color: const Color(0xff76ff03),
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: const Text(
          "Appuyez pour importer une image",
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton reset — revient à l'icône par défaut
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white30, size: 20),
              tooltip: "Réinitialiser",
              onPressed: () => _resetIcon(key),
            ),
            const Icon(Icons.edit, color: Colors.white30),
          ],
        ),
        onTap: () => _pickIcon(key),
      ),
    );
  }
}
