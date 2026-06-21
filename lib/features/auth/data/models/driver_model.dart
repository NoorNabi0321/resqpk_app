double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

class DriverModel {
  final String id;
  final String userId;
  final String vehicleNumber;
  final String vehicleType;
  final String licenseNumber;
  final String organization;
  final bool isAvailable;
  final bool isVerified;
  final double? currentLat;
  final double? currentLng;
  final int totalTrips;
  final double rating;

  const DriverModel({
    required this.id,
    required this.userId,
    required this.vehicleNumber,
    this.vehicleType = 'ambulance',
    required this.licenseNumber,
    this.organization = 'Private',
    this.isAvailable = false,
    this.isVerified = false,
    this.currentLat,
    this.currentLng,
    this.totalTrips = 0,
    this.rating = 5.0,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'ambulance',
      licenseNumber: json['license_number']?.toString() ?? '',
      organization: json['organization']?.toString() ?? 'Private',
      isAvailable: json['is_available'] == true,
      isVerified: json['is_verified'] == true,
      currentLat: _toDoubleOrNull(json['current_lat']),
      currentLng: _toDoubleOrNull(json['current_lng']),
      totalTrips: _toInt(json['total_trips']),
      rating: _toDoubleOrNull(json['rating']) ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        'license_number': licenseNumber,
        'organization': organization,
        'is_available': isAvailable,
        'is_verified': isVerified,
        'current_lat': currentLat,
        'current_lng': currentLng,
        'total_trips': totalTrips,
        'rating': rating,
      };
}
