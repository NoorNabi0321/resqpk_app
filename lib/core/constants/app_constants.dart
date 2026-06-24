/// App-wide constants. Extended in later modules (e.g. gateway/emergency
/// numbers in Module 7).
class AppConstants {
  AppConstants._();

  // --- Maps (MapTiler) -----------------------------------------------------
  // Client-side key for raster basemap tiles. Restrict it by allowed origins
  // in the MapTiler dashboard if needed.
  static const String mapTilerKey = 'J1U6h9bJqDPYg0v0htP6';

  // Dark street style — detailed enough for navigation, matches the dark UI.
  static const String mapStyle = 'streets-v2-dark';

  // flutter_map TileLayer urlTemplate ({z}/{x}/{y} are filled in by flutter_map).
  static const String mapTileUrl =
      'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=$mapTilerKey';

  static const String mapAttribution = '© MapTiler © OpenStreetMap contributors';
}
