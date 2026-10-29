import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  // Position de repli si le GPS est indisponible (centre de la France)
  static const double _latDefaut = 46.603354;
  static const double _lngDefaut = 1.888334;

  static Future<Map<String, dynamic>> fetchWeather() async {
    try {
      final position = await _obtenirPosition();
      return await _appelAPI(position.latitude, position.longitude);
    } on Exception catch (e) {
      // GPS indisponible ou refusé → position de repli (centre de la France)
      debugPrint("WeatherService : GPS indisponible ($e), position de repli.");
      return await _appelAPI(_latDefaut, _lngDefaut);
    }
  }

  // --- POSITION GPS ---

  static Future<Position> _obtenirPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();

    // Refus définitif — impossible de demander à nouveau
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission GPS refusée définitivement. '
          'Activez la localisation dans les paramètres.');
    }

    // Première demande ou refus récent
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permission GPS refusée.');
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  // --- APPEL API OPEN-METEO ---

  static Future<Map<String, dynamic>> _appelAPI(double lat, double lng) async {
    // Uri.https() avec queryParameters — plus robuste que la concaténation
    final url = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'wind_speed_10m',
        'weathercode', // utilisé par MeteoPage pour les icônes météo
      ].join(','),
      'daily': [
        'temperature_2m_max',
        'temperature_2m_min',
        'rain_sum',
        'wind_speed_10m_max',
      ].join(','),
      'timezone': 'auto',
    });

    final http.Response response = await http.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception(
              'Délai dépassé — vérifiez votre connexion réseau.'),
        );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Erreur serveur météo : ${response.statusCode}');
    }
  }
}
