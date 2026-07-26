/// A free medical camp the patient can discover nearby.
/// Camps are read-only in this version: no booking, no camp SOS.
class CampModel {
  final String id;
  final String name;
  final String? organizerName;
  final String? description;
  final List<String> servicesOffered;
  final String? address;
  final double lat;
  final double lng;
  final int? distanceMeters;
  final String? distanceText;
  final String? startDate;
  final String? endDate;
  final int? daysRemaining;
  final String? contactPhone;

  const CampModel({
    required this.id,
    required this.name,
    this.organizerName,
    this.description,
    this.servicesOffered = const [],
    this.address,
    required this.lat,
    required this.lng,
    this.distanceMeters,
    this.distanceText,
    this.startDate,
    this.endDate,
    this.daysRemaining,
    this.contactPhone,
  });

  /// True when the camp is close to ending — the UI warns in amber.
  bool get isEndingSoon => daysRemaining != null && daysRemaining! <= 2;

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  factory CampModel.fromJson(Map<String, dynamic> json) {
    return CampModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Medical camp',
      organizerName: json['organizerName']?.toString(),
      description: json['description']?.toString(),
      servicesOffered:
          (json['servicesOffered'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      address: json['address']?.toString(),
      lat: _d(json['lat']),
      lng: _d(json['lng']),
      distanceMeters: _i(json['distanceMeters']),
      distanceText: json['distanceText']?.toString(),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      daysRemaining: _i(json['daysRemaining']),
      contactPhone: json['contactPhone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'organizerName': organizerName,
        'description': description,
        'servicesOffered': servicesOffered,
        'address': address,
        'lat': lat,
        'lng': lng,
        'distanceMeters': distanceMeters,
        'distanceText': distanceText,
        'startDate': startDate,
        'endDate': endDate,
        'daysRemaining': daysRemaining,
        'contactPhone': contactPhone,
      };
}
