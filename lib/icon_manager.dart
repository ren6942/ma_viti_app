import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestionnaire d'icônes personnalisées.
///
/// INITIALISATION OBLIGATOIRE au démarrage de l'app (dans main.dart) :
///   await IconManager.init();
///
/// Cela charge les SharedPreferences en cache une seule fois,
/// ce qui rend getIcon() entièrement synchrone et sans clignotement.
class IconManager {
  IconManager._(); // Empêche l'instanciation

  static SharedPreferences? _prefs;

  /// À appeler UNE SEULE FOIS dans main() avant runApp().
  /// Exemple :
  ///   void main() async {
  ///     WidgetsFlutterBinding.ensureInitialized();
  ///     await IconManager.init();
  ///     runApp(const MyApp());
  ///   }
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Enregistre le chemin d'une image personnalisée pour une clé donnée.
  /// Vérifie que le fichier existe avant de sauvegarder.
  static Future<void> setCustomIcon(String key, String path) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();

    if (!await File(path).exists()) {
      debugPrint("IconManager.setCustomIcon : fichier introuvable → $path");
      return;
    }

    await prefs.setString('custom_icon_$key', path);
    debugPrint("IconManager : icône '$key' enregistrée → $path");
  }

  /// Supprime l'icône personnalisée d'une clé — revient à l'icône par défaut.
  static Future<void> removeCustomIcon(String key) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove('custom_icon_$key');
    debugPrint("IconManager : icône '$key' supprimée.");
  }

  /// Retourne le widget icône pour une clé donnée.
  ///
  /// - Si une image personnalisée valide est enregistrée → Image.file
  /// - Sinon → Icon avec [defaultIcon]
  ///
  /// Entièrement synchrone grâce au cache _prefs initialisé dans init().
  /// Si init() n'a pas été appelé, retourne silencieusement l'icône par défaut.
  static Widget getIcon(
    String key, {
    required IconData defaultIcon,
    double size = 30,
    Color? color,
  }) {
    // Facteur d'agrandissement de 50% par rapport à la taille demandée
    final double adjustedSize = size * 1.5;

    final Widget fallback = Icon(defaultIcon, size: adjustedSize, color: color);

    if (_prefs == null) {
      // init() non appelé — retour silencieux sur l'icône par défaut
      debugPrint(
          "IconManager.getIcon : init() non appelé. Appelez IconManager.init() dans main().");
      return fallback;
    }

    final String? path = _prefs!.getString('custom_icon_$key');

    if (path == null) return fallback;

    // Vérification synchrone de l'existence du fichier.
    // Note : statSync() est utilisé ici car getIcon() doit rester synchrone.
    // Le nettoyage des chemins orphelins est fait de façon asynchrone.
    final bool exists = File(path).existsSync();

    if (!exists) {
      // Nettoyage asynchrone du chemin orphelin — sans bloquer le build
      _prefs!.remove('custom_icon_$key').then((_) =>
          debugPrint("IconManager : chemin orphelin nettoyé pour '$key'."));
      return fallback;
    }

    return Image.file(
      File(path),
      width: adjustedSize,
      height: adjustedSize,
      fit: BoxFit.contain,
      // Retour sur l'icône par défaut si le fichier est corrompu ou illisible
      errorBuilder: (_, __, ___) {
        debugPrint("IconManager : erreur lecture image pour '$key' → $path");
        return fallback;
      },
    );
  }
}
