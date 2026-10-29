import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'database_helper.dart';

class CarteGlobalePage extends StatefulWidget {
  const CarteGlobalePage({super.key});

  @override
  State<CarteGlobalePage> createState() => _CarteGlobalePageState();
}

class _CarteGlobalePageState extends State<CarteGlobalePage> {
  List<Polygon> _polygones = [];
  bool _chargement = true;
  bool _modeEdition = false;
  List<LatLng> _pointsEnCours = [];
  String? _parcelleEnEdition;
  final MapController _mapController = MapController();

  // Limites de zoom pour éviter les comportements indéfinis
  static const double _zoomMin = 5.0;
  static const double _zoomMax = 21.0;

  @override
  void initState() {
    super.initState();
    _chargerToutesLesParcelles();
  }

  // --- CALCUL DE SURFACE ---
  // Formule de Shoelace sphérique.
  // Surface = R² / 2 × |Σ Δλ × (2 + sin φᵢ + sin φⱼ)|
  // Δλ en degrés (non converti en radians) — cohérent avec CarteParcellePage.
  // R = rayon moyen de la Terre (m), résultat en hectares (÷ 10 000).
  double _calculerSurfaceHectares(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    const double earthRadius = 6378137.0;
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final int j = (i + 1) % points.length;
      area += (points[j].longitude - points[i].longitude) *
          (2 +
              math.sin(points[i].latitude * math.pi / 180) +
              math.sin(points[j].latitude * math.pi / 180));
    }
    return (area.abs() * earthRadius * earthRadius / 2.0) / 10000.0;
  }

  // --- CHARGEMENT ---
  Future<void> _chargerToutesLesParcelles() async {
    try {
      final data = await DatabaseHelper.instance.getListeParcellesFull();
      final List<Polygon> temporaire = [];

      for (var row in data) {
        if (row['geometrie'] == null || row['geometrie'].toString().isEmpty)
          continue;

        final List<LatLng> points =
            DatabaseHelper.instance.stringToPoints(row['geometrie'] as String);

        if (points.isNotEmpty) {
          temporaire.add(Polygon(
            points: points,
            color: const Color(0xff76ff03).withValues(alpha: 0.3),
            borderStrokeWidth: 3,
            borderColor: const Color(0xff76ff03),
            isFilled: true,
            label: row['nom'],
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _polygones = temporaire;
        _chargement = false;
      });

      if (_polygones.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recadrerVue();
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement parcelles : $e");
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _recadrerVue() {
    if (_polygones.isEmpty) return;
    final List<LatLng> tousLesPoints = [
      for (var poly in _polygones) ...poly.points,
    ];
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(tousLesPoints),
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  // --- EDITION ---
  Future<void> _sauvegarderDessin() async {
    if (_pointsEnCours.length < 3) {
      _notifier("Il faut au moins 3 points !", Colors.orange);
      return;
    }

    try {
      final double surfaceCalculee = _calculerSurfaceHectares(_pointsEnCours);
      final String geoJson =
          DatabaseHelper.instance.pointsToString(_pointsEnCours);

      await DatabaseHelper.instance.updateGeometrieParcelle(
        _parcelleEnEdition!,
        geoJson,
        surfaceCalculee,
      );

      if (!mounted) return;

      // Rechargement des polygones avant le setState pour éviter le double rebuild
      final data = await DatabaseHelper.instance.getListeParcellesFull();
      final List<Polygon> temporaire = [];
      for (var row in data) {
        if (row['geometrie'] == null || row['geometrie'].toString().isEmpty)
          continue;
        final List<LatLng> points =
            DatabaseHelper.instance.stringToPoints(row['geometrie'] as String);
        if (points.isNotEmpty) {
          temporaire.add(Polygon(
            points: points,
            color: const Color(0xff76ff03).withValues(alpha: 0.3),
            borderStrokeWidth: 3,
            borderColor: const Color(0xff76ff03),
            isFilled: true,
            label: row['nom'],
            labelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ));
        }
      }

      if (!mounted) return;

      // Un seul setState — évite le double rebuild
      setState(() {
        _polygones = temporaire;
        _modeEdition = false;
        _pointsEnCours = [];
        _parcelleEnEdition = null;
      });

      _notifier(
        "Tracé sauvegardé (${surfaceCalculee.toStringAsFixed(2)} ha)",
        const Color(0xff76ff03),
      );
    } catch (e) {
      _notifier("Erreur sauvegarde : $e", Colors.red);
    }
  }

  Future<void> _selectionnerParcelleAEditer() async {
    try {
      final parcelles = await DatabaseHelper.instance.getListeParcelles();
      if (!mounted) return;

      if (parcelles.isEmpty) {
        _notifier("Créez d'abord une parcelle dans la liste", Colors.redAccent);
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Quelle parcelle dessiner ?",
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: parcelles.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.ads_click, color: Color(0xff76ff03)),
                title: Text(parcelles[i],
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _modeEdition = true;
                    _parcelleEnEdition = parcelles[i];
                    _pointsEnCours = [];
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _notifier("Erreur chargement parcelles : $e", Colors.red);
    }
  }

  void _notifier(String msg, Color couleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: couleur,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- INTERFACE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modeEdition ? "DESSIN : $_parcelleEnEdition" : "VUE DU DOMAINE",
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          // Compteur de points en mode édition
          if (_modeEdition)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "${_pointsEnCours.length} pt${_pointsEnCours.length > 1 ? 's' : ''}",
                  style: const TextStyle(
                    color: Color(0xff76ff03),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!_modeEdition)
            IconButton(
              icon:
                  const Icon(Icons.edit_location_alt, color: Color(0xff76ff03)),
              tooltip: "Dessiner une parcelle",
              onPressed: _selectionnerParcelleAEditer,
            ),
          if (_modeEdition && _pointsEnCours.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.orangeAccent),
              tooltip: "Annuler le dernier point",
              onPressed: () => setState(() => _pointsEnCours.removeLast()),
            ),
          if (_modeEdition && _pointsEnCours.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: "Effacer tous les points",
              onPressed: () => setState(() => _pointsEnCours.clear()),
            ),
          if (_modeEdition)
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xff76ff03), size: 30),
              tooltip: "Valider le tracé",
              onPressed: _sauvegarderDessin,
            ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: "Recadrer la vue",
            onPressed: _recadrerVue,
          ),
        ],
      ),
      body: _chargement
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xff76ff03)))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(43.116, 2.152),
                    initialZoom: 15.0,
                    minZoom: _zoomMin,
                    maxZoom: _zoomMax,
                    onTap: (_, point) {
                      if (_modeEdition) {
                        setState(() => _pointsEnCours.add(point));
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://data.geopf.fr/wmts?"
                          "REQUEST=GetTile&SERVICE=WMTS&VERSION=1.0.0"
                          "&STYLE=normal&TILEMATRIXSET=PM&FORMAT=image/jpeg"
                          "&LAYER=ORTHOIMAGERY.ORTHOPHOTOS"
                          "&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}",
                      userAgentPackageName: 'com.vigne.ma_viti_app',
                    ),
                    TileLayer(
                      urlTemplate: "https://data.geopf.fr/wmts?"
                          "REQUEST=GetTile&SERVICE=WMTS&VERSION=1.0.0"
                          "&STYLE=bdparcellaire&TILEMATRIXSET=PM&FORMAT=image/png"
                          "&LAYER=CADASTRALPARCELS.PARCELS"
                          "&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}",
                      userAgentPackageName: 'com.vigne.ma_viti_app',
                      tileBuilder: (context, tileWidget, tile) =>
                          Opacity(opacity: 0.6, child: tileWidget),
                    ),
                    PolygonLayer(polygons: _polygones),
                    if (_modeEdition && _pointsEnCours.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              ..._pointsEnCours,
                              if (_pointsEnCours.length > 2)
                                _pointsEnCours.first,
                            ],
                            color: Colors.redAccent,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    if (_modeEdition)
                      MarkerLayer(
                        markers: _pointsEnCours
                            .map((p) => Marker(
                                  point: p,
                                  width: 12,
                                  height: 12,
                                  child: const Icon(Icons.circle,
                                      color: Colors.white, size: 10),
                                ))
                            .toList(),
                      ),
                  ],
                ),
                if (_modeEdition) _buildInstructionOverlay(),
                _buildZoomButtons(),
              ],
            ),
    );
  }

  Widget _buildInstructionOverlay() {
    return Positioned(
      top: 15,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xff76ff03), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "DESSIN : ${_parcelleEnEdition?.toUpperCase()}",
              style: const TextStyle(
                  color: Color(0xff76ff03), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              "Tapez sur la carte pour poser les jalons.\n"
              "Utilisez ↶ pour corriger ou ✔ pour valider.",
              style: TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButtons() {
    return Positioned(
      bottom: 30,
      right: 20,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: "z_in",
            mini: true,
            backgroundColor: const Color(0xff76ff03),
            onPressed: () {
              final double zoom = _mapController.camera.zoom;
              if (zoom < _zoomMax) {
                _mapController.move(_mapController.camera.center, zoom + 1);
              }
            },
            child: const Icon(Icons.add, color: Colors.black),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "z_out",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final double zoom = _mapController.camera.zoom;
              if (zoom > _zoomMin) {
                _mapController.move(_mapController.camera.center, zoom - 1);
              }
            },
            child: const Icon(Icons.remove, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
