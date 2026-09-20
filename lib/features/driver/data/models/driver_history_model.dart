/// One run this driver was assigned.
class DriverTrip {
  const DriverTrip({
    required this.id,
    required this.caseNumber,
    required this.status,
    this.address,
    this.emergencyType,
    this.urgencyLevel,
    this.hospitalName,
    this.assignedAt,
    this.completedAt,
    this.arrivalSeconds,
  });

  final String id;
  final String caseNumber;
  final String status;
  final String? address;
  final String? emergencyType;
  final String? urgencyLevel;
  final String? hospitalName;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  /// How long the driver took to reach the patient.
  final int? arrivalSeconds;

  bool get isCompleted => status == 'completed';

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospital'];
    return DriverTrip(
      id: json['id']?.toString() ?? '',
      caseNumber: json['case_number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      address: json['patient_address']?.toString(),
      emergencyType: json['emergency_type']?.toString(),
      urgencyLevel: json['urgency_level']?.toString(),
      hospitalName: hospital is Map ? hospital['name']?.toString() : null,
      assignedAt: _date(json['driver_assigned_at']),
      completedAt: _date(json['completed_at']),
      arrivalSeconds: json['actual_driver_arrival_seconds'] is int
          ? json['actual_driver_arrival_seconds'] as int
          : int.tryParse('${json['actual_driver_arrival_seconds']}'),
    );
  }
}

/// What the driver has done, counted.
class DriverStats {
  const DriverStats({
    this.completed = 0,
    this.today = 0,
    this.offers = 0,
    this.accepted = 0,
    this.declined = 0,
    this.acceptRate,
    this.avgResponseSeconds,
    this.avgArrivalSeconds,
  });

  final int completed;
  final int today;
  final int offers;
  final int accepted;
  final int declined;

  /// Percent of offers answered with an accept, over the last 30 days.
  final int? acceptRate;

  /// How quickly this driver answers an offer — the number dispatch cares
  /// about, because every second is a second the patient is still waiting.
  final int? avgResponseSeconds;
  final int? avgArrivalSeconds;

  static int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
  static int? _nullableInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));

  factory DriverStats.fromJson(Map<String, dynamic> json) => DriverStats(
        completed: _int(json['completed']),
        today: _int(json['today']),
        offers: _int(json['offers']),
        accepted: _int(json['accepted']),
        declined: _int(json['declined']),
        acceptRate: _nullableInt(json['acceptRate']),
        avgResponseSeconds: _nullableInt(json['avgResponseSeconds']),
        avgArrivalSeconds: _nullableInt(json['avgArrivalSeconds']),
      );
}

class DriverHistory {
  const DriverHistory({required this.trips, required this.stats});

  final List<DriverTrip> trips;
  final DriverStats stats;

  /// Trips grouped under a date heading, newest first — a driver looks for
  /// "that run on Tuesday", not for row 14.
  Map<DateTime, List<DriverTrip>> get byDay {
    final grouped = <DateTime, List<DriverTrip>>{};
    for (final trip in trips) {
      final at = trip.assignedAt ?? trip.completedAt;
      if (at == null) continue;
      final day = DateTime(at.year, at.month, at.day);
      grouped.putIfAbsent(day, () => []).add(trip);
    }
    return grouped;
  }
}
