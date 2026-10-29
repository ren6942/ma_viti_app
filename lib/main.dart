import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_page.dart';
import 'database_helper.dart';
import 'icon_manager.dart';

void main() async {
  // Indispensable pour permettre les appels asynchrones avant runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialisation de la base de données
  await DatabaseHelper.instance.database;

  // 2. Chargement du cache des icônes personnalisées
  await IconManager.init();

  // 3. Lancement de l'application
  runApp(const MaVitiApp());
}

class MaVitiApp extends StatelessWidget {
  const MaVitiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Viti App',
      debugShowCheckedModeBanner: false,
      // Configuration de la langue en français pour les dates et calendriers
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      // Thème sombre "Viti" avec le vert fluo caractéristique
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff76ff03),
          secondary: Color(0xff76ff03),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xff76ff03),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Style des boutons par défaut
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff76ff03),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
