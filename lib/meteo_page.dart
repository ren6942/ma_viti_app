import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'weather_service.dart';

// Seuil vent modéré — Beaufort 5 (~20 km/h)
const double _seuilVentAlerte = 20.0;

class MeteoPage extends StatefulWidget {
  const MeteoPage({super.key});

  @override
  State<MeteoPage> createState() => _MeteoPageState();
}

class _MeteoPageState extends State<MeteoPage> {
  late Future<Map<String, dynamic>> _futureMeteo;

  @override
  void initState() {
    super.initState();
    _futureMeteo = WeatherService.fetchWeather();
  }

  void _rafraichir() {
    setState(() => _futureMeteo = WeatherService.fetchWeather());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PRÉVISIONS MÉTÉO"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Rafraîchir",
            onPressed: _rafraichir,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureMeteo,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xff76ff03)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text("Erreur : ${snapshot.error}",
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _rafraichir,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Réessayer"),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text("Aucune donnée disponible",
                    style: TextStyle(color: Colors.grey)));
          }

          final current = snapshot.data!['current'];
          final daily = snapshot.data!['daily'];

          // Nombre réel de jours retournés par l'API, max 7
          final int nbJours =
              ((daily['time'] as List?)?.length ?? 0).clamp(0, 7);

          final double tempActuelle =
              (current['temperature_2m'] as num).toDouble();

          return Column(
            children: [
              // --- MÉTÉO ACTUELLE ---
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xff76ff03), width: 0.5),
                ),
                child: Column(
                  children: [
                    const Text("Actuellement",
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(
                      "${tempActuelle.toStringAsFixed(1)}°C",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _couleurTemperature(tempActuelle),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoActu(
                          Icons.air,
                          "${(current['wind_speed_10m'] as num).toDouble()} km/h",
                          "Vent",
                        ),
                        _infoActu(
                          Icons.water_drop,
                          "${(current['relative_humidity_2m'] as num).toInt()}%",
                          "Humidité",
                        ),
                        // Icône météo WMO si disponible
                        if (current['weathercode'] != null)
                          _infoActu(
                            _iconeMeteo(
                                (current['weathercode'] as num).toInt()),
                            "",
                            _libelleMeteo(
                                (current['weathercode'] as num).toInt()),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "7 PROCHAINS JOURS",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ),

              // --- PRÉVISIONS 7 JOURS ---
              Expanded(
                child: nbJours == 0
                    ? const Center(
                        child: Text("Aucune prévision disponible",
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: nbJours,
                        itemBuilder: (context, index) {
                          final DateTime date = DateTime.parse(
                              (daily['time'] as List)[index] as String);
                          final String jour =
                              DateFormat('EEEE d', 'fr_FR').format(date);
                          final double ventMax =
                              (daily['wind_speed_10m_max'][index] as num)
                                  .toDouble();
                          final double pluie =
                              (daily['rain_sum'][index] as num).toDouble();
                          final double tMax =
                              (daily['temperature_2m_max'][index] as num)
                                  .toDouble();
                          final double tMin =
                              (daily['temperature_2m_min'][index] as num)
                                  .toDouble();

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            child: ListTile(
                              leading: Text(jour,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              title: Row(
                                children: [
                                  Text(
                                    "${tMax.toStringAsFixed(0)}°",
                                    style: TextStyle(
                                        color: _couleurTemperature(tMax),
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Text(" / "),
                                  Text(
                                    "${tMin.toStringAsFixed(0)}°",
                                    style: TextStyle(
                                        color: _couleurTemperature(tMin)),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                "Pluie : ${pluie.toStringAsFixed(1)} mm",
                                style: TextStyle(
                                    color:
                                        pluie > 0 ? Colors.blue : Colors.grey),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.air,
                                    size: 16,
                                    color: ventMax >= _seuilVentAlerte
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  Text(
                                    "${ventMax.toStringAsFixed(0)} km/h",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ventMax >= _seuilVentAlerte
                                          ? Colors.red
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoActu(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70),
        if (val.isNotEmpty)
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // Couleur adaptative selon la température
  Color _couleurTemperature(double temp) {
    if (temp <= 5) return Colors.blue;
    if (temp <= 15) return Colors.lightBlue;
    if (temp <= 25) return const Color(0xff76ff03);
    if (temp <= 32) return Colors.orange;
    return Colors.red;
  }

  // Icône Material selon le code météo WMO
  IconData _iconeMeteo(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 2) return Icons.wb_cloudy;
    if (code <= 3) return Icons.cloud;
    if (code <= 49) return Icons.foggy;
    if (code <= 59) return Icons.grain;
    if (code <= 69) return Icons.ac_unit;
    if (code <= 79) return Icons.snowing;
    if (code <= 82) return Icons.umbrella;
    if (code <= 99) return Icons.thunderstorm;
    return Icons.cloud;
  }

  // Libellé court selon le code météo WMO
  String _libelleMeteo(int code) {
    if (code == 0) return "Clair";
    if (code <= 2) return "Peu nuageux";
    if (code <= 3) return "Couvert";
    if (code <= 49) return "Brouillard";
    if (code <= 59) return "Bruine";
    if (code <= 69) return "Pluie";
    if (code <= 79) return "Neige";
    if (code <= 82) return "Averses";
    if (code <= 99) return "Orage";
    return "Inconnu";
  }
}
