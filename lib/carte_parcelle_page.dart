import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'database_helper.dart';

class CarteParcellePage extends StatefulWidget {
  final String parcelleNom;
  const CarteParcellePage({super.key, required this.parcelleNom});

  @override
  State<CarteParcellePage> createState() => _CarteParcellePageState();
}

class _CarteParcellePageState extends State<CarteParcellePage> {
  List<LatLng> pointsPolygone = [];
  LatLng maPosition = const LatLng(43.116, 2.152);
  LatLng? positionGPS; // position GPS réelle, affichée comme marqueur bleu
  final MapController _mapController = MapController();
  double surfaceHectares = 0.0;
  bool _isLoading = true;
  bool _cartePretre = false;

  @override
  void initState() {
    super.initState();
    _chargerDonneesInitiales();
  }

  // --- CHARGEMENT ---
  Future<void> _chargerDonneesInitiales() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'parcelles',
      columns: ['geometrie', 'surface'],
      where: 'nom = ?',
      whereArgs: [widget.parcelleNom],
    );

    if (res.isNotEmpty && res.first['geometrie'] != null) {
      final points = DatabaseHelper.instance
          .stringToPoints(res.first['geometrie'] as String?);
      if (points.isNotEmpty) {
        if (mounted) {
          setState(() {
            pointsPolygone = points;
            surfaceHectares = (res.first['surface'] as num?)?.toDouble() ?? 0.0;
            maPosition = points.first;
            _isLoading = false;
          });
        }
        return;
      }
    }

    await _centrerSurUtilisateur();
    if (mounted) setState(() => _isLoading = false);
  }

  // --- CALCUL GÉOMÉTRIQUE ---
  // Formule de Shoelace adaptée à la sphère terrestre.
  // Approximation sphérique : aire = R² / 2 × |Σ Δλ × (2 + sin φᵢ + sin φⱼ)|
  // R = rayon moyen de la Terre en mètres, résultat converti en hectares (÷ 10 000).
  void _calculerSurface() {
    if (pointsPolygone.length < 3) {
      setState(() => surfaceHectares = 0.0);
      return;
    }
    const double earthRadius = 6378137.0;
    double area = 0.0;
    for (int i = 0; i < pointsPolygone.length; i++) {
      final int j = (i + 1) % pointsPolygone.length;
      area += (pointsPolygone[j].longitude - pointsPolygone[i].longitude) *
          (2 +
              math.sin(pointsPolygone[i].latitude * math.pi / 180) +
              math.sin(pointsPolygone[j].latitude * math.pi / 180));
    }
    setState(() => surfaceHectares =
        (area.abs() * earthRadius * earthRadius / 2.0) / 10000.0);
  }

  // --- GPS ---
  Future<void> _centrerSurUtilisateur() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        debugPrint("GPS : permission refusée définitivement.");
        return;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint("GPS : permission refusée par l'utilisateur.");
          return;
        }
      }

      final Position pos = await Geolocator.getCurrentPosition();
      final LatLng nouvellePosition = LatLng(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          maPosition = nouvellePosition;
          positionGPS = nouvellePosition;
        });
        _mapController.move(maPosition, 17.5);
      }
    } catch (e) {
      debugPrint("Erreur GPS : $e");
    }
  }

  // --- SAUVEGARDE ---
  Future<void> _sauvegarder() async {
    if (!mounted) return;

    if (pointsPolygone.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tracez 3 points minimum !")));
      return;
    }

    await DatabaseHelper.instance.updateGeometrieParcelle(
      widget.parcelleNom,
      DatabaseHelper.instance.pointsToString(pointsPolygone),
      double.parse(surfaceHectares.toStringAsFixed(2)),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Géométrie enregistrée"),
          backgroundColor: Colors.green));
      Navigator.pop(context, true);
    }
  }

  // --- RÉINITIALISATION ---
  void _toutEffacer() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Effacer le tracé ?",
            style: TextStyle(color: Colors.white)),
        content: const Text("Tous les points seront supprimés.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ANNULER"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                pointsPolygone.clear();
                surfaceHectares = 0.0;
              });
            },
            child: const Text("EFFACER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parcelleNom.toUpperCase()),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: "Effacer le tracé",
            onPressed: pointsPolygone.isNotEmpty ? _toutEffacer : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: maPosition,
                    initialZoom: 17.5,
                    onMapReady: () {
                      // Centrer une fois la carte prête, sans délai arbitraire
                      if (!_cartePretre) {
                        _cartePretre = true;
                        _mapController.move(maPosition, 17.5);
                      }
                    },
                    onTap: (_, point) {
                      setState(() => pointsPolygone.add(point));
                      _calculerSurface();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://data.geopf.fr/wmts?REQUEST=GetTile&SERVICE=WMTS&VERSION=1.0.0&STYLE=normal&TILEMATRIXSET=PM&FORMAT=image/jpeg&LAYER=ORTHOIMAGERY.ORTHOPHOTOS&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}",
                      userAgentPackageName: 'com.vigne.ma_viti_app',
                    ),
                    PolygonLayer(polygons: [
                      Polygon(
                        points: pointsPolygone,
                        color: const Color(0xff76ff03).withValues(alpha: 0.35),
                        borderStrokeWidth: 3,
                        borderColor: const Color(0xff76ff03),
                        isFilled: true,
                      ),
                    ]),
                    // Marqueur bleu sur la position GPS réelle
                    if (positionGPS != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: positionGPS!,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),

                // Affichage surface — centré en haut
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${surfaceHectares.toStringAsFixed(2)} Ha",
                        style: const TextStyle(
                          color: Color(0xff76ff03),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Boutons bas de page
                Positioned(
                  bottom: 30,
                  left: 10,
                  right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        heroTag: "undo",
                        mini: true,
                        tooltip: "Annuler le dernier point",
                        onPressed: pointsPolygone.isNotEmpty
                            ? () {
                                setState(() => pointsPolygone.removeLast());
                                _calculerSurface();
                              }
                            : null,
                        child: const Icon(Icons.undo),
                      ),
                      ElevatedButton.icon(
                        onPressed: _sauvegarder,
                        icon: const Icon(Icons.check),
                        label: const Text("VALIDER"),
                      ),
                      FloatingActionButton(
                        heroTag: "gps",
                        mini: true,
                        tooltip: "Centrer sur ma position",
                        onPressed: _centrerSurUtilisateur,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
