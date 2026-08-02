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

  // Light basemap for the light-themed patient screens.
  static const String mapStyleLight = 'streets-v2';

  // flutter_map TileLayer urlTemplate ({z}/{x}/{y} are filled in by flutter_map).
  //
  // @2x tiles carry the same map area at double resolution, so their labels
  // are drawn twice as large. Paired with ResQPKMap's tileSize 512 /
  // zoomOffset -1 this renders street and place names at roughly the size
  // Google Maps uses, instead of the tiny 256px defaults that were unreadable
  // even zoomed in.
  static const String mapTileUrl =
      'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}@2x.png?key=$mapTilerKey';

  // Standard-resolution fallback (used if a device reports low pixel density).
  static const String mapTileUrlStandard =
      'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=$mapTilerKey';

  static const String mapTileUrlLight =
      'https://api.maptiler.com/maps/$mapStyleLight/{z}/{x}/{y}@2x.png?key=$mapTilerKey';
  static const String mapTileUrlLightStandard =
      'https://api.maptiler.com/maps/$mapStyleLight/{z}/{x}/{y}.png?key=$mapTilerKey';

  static const String mapAttribution = '© MapTiler © OpenStreetMap contributors';

  // --- Offline SOS (Module 7) ----------------------------------------------
  // The ResQPK gateway SIM running the "SMS to URL Forwarder" app. Patients
  // SMS the keyword here when offline.
  static const String gatewayPhoneNumber = '+923133394113';
  static const String sosKeyword = 'SOS';

  static const String appVersion = '1.0.0-fyp';

  // Pakistani emergency services (fallback dialer rows on the offline screen).
  static const List<Map<String, String>> emergencyServices = [
    {'name': 'Rescue 1122', 'number': '1122', 'icon': '🚑'},
    {'name': 'Edhi Foundation', 'number': '115', 'icon': '🏥'},
    {'name': 'Chhipa Welfare', 'number': '1020', 'icon': '🩺'},
    {'name': 'Police Emergency', 'number': '15', 'icon': '👮'},
  ];
}
