import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  // Position de repli si le GPS est indisponible (centre de la France)
  static const double _latDefaut = 46.603354;
  static const double _lngDefaut = 1.888334;
  static const Duration defaultTimeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> fetchWeather({
    http.Client? client,
    Duration timeoutDuration = defaultTimeout,
  }) async {
    double lat = _latDefaut;
    double lng = _lngDefaut;

    try {
      final position = await _obtenirPosition();
      lat = position.latitude;
      lng = position.longitude;
    } catch (e) {
      // GPS indisponible ou refusé → position de repli (centre de la France)
      debugPrint("WeatherService : GPS indisponible ($e), position de repli.");
    }

    return await appelAPI(
      lat,
      lng,
      client: client,
      timeoutDuration: timeoutDuration,
    );
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  // --- APPEL API OPEN-METEO ---

  static Future<Map<String, dynamic>> appelAPI(
    double lat,
    double lng, {
    http.Client? client,
    Duration timeoutDuration = defaultTimeout,
  }) async {
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

    final httpClient = client ?? http.Client();
    final bool shouldCloseClient = client == null;

    try {
      final http.Response response = await httpClient.get(url).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else {
            throw const FormatException('Format de réponse météo inattendu.');
          }
        } on FormatException catch (e) {
          throw FormatException('Données météo corrompues ou illisibles : ${e.message}');
        }
      } else {
        throw HttpException(
          'Erreur serveur météo (${response.statusCode}) : ${response.reasonPhrase ?? 'réponse invalide'}',
          uri: url,
        );
      }
    } on TimeoutException {
      throw TimeoutException('Délai dépassé — vérifiez votre connexion réseau.');
    } on SocketException catch (e) {
      throw SocketException('Erreur de connexion réseau : ${e.message}');
    } on http.ClientException catch (e) {
      throw http.ClientException('Erreur réseau HTTP : ${e.message}', url);
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }
}
