import 'dart:convert';

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class UserModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String role;
  final String? profilePhotoUrl;
  final String? fcmToken;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.role,
    this.profilePhotoUrl,
    this.fcmToken,
    this.lastKnownLat,
    this.lastKnownLng,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'patient',
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      fcmToken: json['fcm_token']?.toString(),
      lastKnownLat: _toDoubleOrNull(json['last_known_lat']),
      lastKnownLng: _toDoubleOrNull(json['last_known_lng']),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'role': role,
        'profile_photo_url': profilePhotoUrl,
        'fcm_token': fcmToken,
        'last_known_lat': lastKnownLat,
        'last_known_lng': lastKnownLng,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserModel.fromLocalStorage(String jsonString) =>
      UserModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  String toLocalStorage() => jsonEncode(toJson());
}
