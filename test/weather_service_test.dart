import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ma_viti_app/weather_service.dart';

void main() {
  group('WeatherService.appelAPI', () {
    test('succès 200 retourne le JSON météo décodé', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        expect(request.url.path, '/v1/forecast');
        expect(request.url.queryParameters['latitude'], '46.603354');
        expect(request.url.queryParameters['longitude'], '1.888334');

        final fakeResponse = {
          'current': {
            'temperature_2m': 18.5,
            'relative_humidity_2m': 65,
            'wind_speed_10m': 12.0,
            'weathercode': 1,
          },
          'daily': {
            'time': ['2023-01-01'],
            'temperature_2m_max': [20.0],
            'temperature_2m_min': [10.0],
            'rain_sum': [0.0],
            'wind_speed_10m_max': [15.0],
          },
        };
        return http.Response(jsonEncode(fakeResponse), 200);
      });

      final result = await WeatherService.appelAPI(
        46.603354,
        1.888334,
        client: mockClient,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['current']['temperature_2m'], 18.5);
    });

    test('gère le timeout et lève TimeoutException avec message clair', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response('{}', 200);
      });

      expect(
        () => WeatherService.appelAPI(
          46.603354,
          1.888334,
          client: mockClient,
          timeoutDuration: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            contains('Délai dépassé'),
          ),
        ),
      );
    });

    test('gère les erreurs SocketException', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup');
      });

      expect(
        () => WeatherService.appelAPI(
          46.603354,
          1.888334,
          client: mockClient,
        ),
        throwsA(
          isA<SocketException>().having(
            (e) => e.message,
            'message',
            contains('Erreur de connexion réseau'),
          ),
        ),
      );
    });

    test('gère les erreurs http.ClientException', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connexion fermée brutalement');
      });

      expect(
        () => WeatherService.appelAPI(
          46.603354,
          1.888334,
          client: mockClient,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (e) => e.message,
            'message',
            contains('Erreur réseau HTTP'),
          ),
        ),
      );
    });

    test('gère les réponses avec code HTTP non 200 (ex: 500)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500, reasonPhrase: 'Internal Server Error');
      });

      expect(
        () => WeatherService.appelAPI(
          46.603354,
          1.888334,
          client: mockClient,
        ),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            allOf(contains('500'), contains('Erreur serveur météo')),
          ),
        ),
      );
    });

    test('gère les réponses avec JSON mal formé', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Ceci n\'est pas du json', 200);
      });

      expect(
        () => WeatherService.appelAPI(
          46.603354,
          1.888334,
          client: mockClient,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Données météo corrompues ou illisibles'),
          ),
        ),
      );
    });

    test('gère les réponses JSON qui ne sont pas un Map', () async {
      final mockClient = MockClient((request) async {
        return http.Response('[1, 2, 3]', 200);
      });

      expect(
        () => WeatherService.appelAPI(
          46.603354,
          1.888334,
          client: mockClient,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Format de réponse météo inattendu'),
          ),
        ),
      );
    });
  });
}
