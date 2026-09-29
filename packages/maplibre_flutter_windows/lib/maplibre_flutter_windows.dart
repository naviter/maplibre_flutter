import 'package:maplibre_flutter_core/maplibre_flutter_core.dart' as core;
import 'package:maplibre_flutter_platform_interface/maplibre_flutter_platform_interface.dart';

import 'src/maplibre_flutter_windows_controller.dart';

/// The Windows implementation of `maplibre_flutter`.
///
/// Registered automatically via `dartPluginClass` in pubspec.yaml. Windows is
/// part of the desktop tier (CLAUDE.md §3): it renders MapLibre Native
/// (`mbgl-core`, via `maplibre_flutter_core`'s ANGLE/OpenGL-ES + EGL arm)
/// off-screen and composites through a Flutter `Texture`. The native half
/// (`MaplibreFlutterWindowsPlugin`) owns the texture registrar; [createMap]
/// delegates to [MapLibreFlutterWindowsController].
///
/// NOTE: not yet run on real Windows hardware — see CLAUDE.md §8.
class MapLibreFlutterWindows extends MapLibreFlutterPlatform {
  /// Called by the Flutter plugin registrant to install this implementation.
  static void registerWith() {
    MapLibreFlutterPlatform.instance = MapLibreFlutterWindows();
  }

  @override
  Future<MapLibreMapPlatformController> createMap({
    required String style,
    required MapOptions options,
  }) => MapLibreFlutterWindowsController.create(style, options);

  /// Creates the process-wide Vulkan instance on a background thread (see the
  /// core's `mbl_prewarm`), so the first map view doesn't spend ~1.6 s in driver
  /// initialisation on the UI's clock.
  @override
  void prewarm() => core.MapLibreCoreMap.prewarm();

  @override
  void setCachePath(String path) => core.MapLibreCoreMap.setCachePath(path);
}
