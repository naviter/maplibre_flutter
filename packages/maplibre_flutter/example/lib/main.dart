import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_flutter/maplibre_flutter.dart';

/// Native-spike map: seeyou.cloud terrain.json rendered by native mbgl-core
/// (Vulkan) with the austria.igc flight track as a GeoJSON line layer. Native
/// HTTP means the seeyou.cloud tiles load directly — no CORS proxy.
void main() => runApp(const NativeSpikeApp());

class NativeSpikeApp extends StatelessWidget {
  const NativeSpikeApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: SpikeMap()),
      );
}

class SpikeMap extends StatefulWidget {
  const SpikeMap({super.key});
  @override
  State<SpikeMap> createState() => _SpikeMapState();
}

class _SpikeMapState extends State<SpikeMap> {
  final MapLibreMapController _controller = MapLibreMapController();
  String? _style;
  List<LatLng> _track = const [];
  double _cLat = 47, _cLon = 14.3, _zoom = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Inline JSON: the patched core detects a '{'-prefixed style and loadJSON's
    // it. Its tile/sprite/glyph URLs are absolute maps.seeyou.cloud endpoints,
    // fetched directly by native mbgl — no CORS proxy.
    final style = await rootBundle.loadString('assets/terrain.json');
    final igc = await rootBundle.loadString('assets/austria.igc');
    final track = _parseIgc(igc);

    var w = 180.0, e = -180.0, s = 90.0, n = -90.0;
    for (final p in track) {
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
    }
    final cLat = (s + n) / 2, cLon = (w + e) / 2;
    final span = math.max((e - w).abs(), (n - s).abs()).clamp(0.01, 360.0);
    final zoom = (math.log(360.0 / (span * 1.5)) / math.ln2).clamp(2.0, 16.0);

    if (!mounted) return;
    setState(() {
      _style = style;
      _track = track;
      _cLat = cLat;
      _cLon = cLon;
      _zoom = zoom;
    });

    _controller.onReady.then((_) async {
      if (!mounted) return;
      _controller.layers
        ..addSource('track', GeoJsonSource(data: GeoJsonData.lineThrough(track)))
        ..addLayer(
          LineLayer(
            id: 'track',
            source: 'track',
            lineColor: const StyleValue(Color(0xFFE20000)),
            lineWidth: const StyleValue(3.0),
            lineJoin: const StyleValue(LineJoin.round),
            lineCap: const StyleValue(LineCap.round),
          ),
        );
      await _controller.camera.move(MapCamera(center: LatLng(cLat, cLon), zoom: zoom));
    });
  }

  List<LatLng> _parseIgc(String content) {
    final pts = <LatLng>[];
    for (final raw in content.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty || line.codeUnitAt(0) != 0x42 || line.length < 35) {
        continue;
      }
      final latDeg = int.tryParse(line.substring(7, 9));
      final latMin = int.tryParse(line.substring(9, 14));
      final lonDeg = int.tryParse(line.substring(15, 18));
      final lonMin = int.tryParse(line.substring(18, 23));
      if (latDeg == null || latMin == null || lonDeg == null || lonMin == null) {
        continue;
      }
      var lat = latDeg + latMin / 60000.0;
      var lon = lonDeg + lonMin / 60000.0;
      if (line[14].toUpperCase() == 'S') lat = -lat;
      if (line[23].toUpperCase() == 'W') lon = -lon;
      pts.add(LatLng(lat, lon));
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
            controller: _controller,
            style: style,
            options: MapOptions(
              initialCamera: MapCamera(center: LatLng(_cLat, _cLon), zoom: _zoom),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xCC000000),
            child: Text(
              'Native mbgl-core (Vulkan) — terrain.json (seeyou.cloud)\n'
              '${_track.length} fixes · no CORS proxy',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
