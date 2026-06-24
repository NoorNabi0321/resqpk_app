/// Socket event names — must match the backend's socket.events.js exactly.
class SocketEvents {
  SocketEvents._();

  // Connection
  static const String authenticated = 'authenticated';
  static const String authError = 'auth_error';

  // Driver
  static const String driverGoOnline = 'driver:go_online';
  static const String driverGoOffline = 'driver:go_offline';
  static const String driverLocationUpdate = 'driver:location_update';
  static const String driverLocationBroadcast = 'driver:location_broadcast';
  static const String driverStatusChanged = 'driver:status_changed';
  static const String driverHeadingUpdate = 'driver:heading_update';

  // Patient
  static const String patientJoinCase = 'patient:join_case';
  static const String patientLeaveCase = 'patient:leave_case';
  static const String patientLocationUpdate = 'patient:location_update';

  // Emergency
  static const String caseCreated = 'emergency:case_created';
  static const String driverAssigned = 'emergency:driver_assigned';
  static const String driverEnRoute = 'emergency:driver_en_route';
  static const String driverArrived = 'emergency:driver_arrived';
  static const String caseCompleted = 'emergency:case_completed';
  static const String caseCancelled = 'emergency:case_cancelled';
  static const String noDriverFound = 'emergency:no_driver_found';

  // ETA
  static const String etaUpdate = 'eta:update';

  // Hospital
  static const String hospitalJoin = 'hospital:join';
  static const String newCase = 'hospital:new_case';
  static const String caseUpdate = 'hospital:case_update';
  static const String ambulanceUpdate = 'hospital:ambulance_update';
  static const String bedStatusChanged = 'hospital:bed_status_changed';

  // AI report (Module 6)
  static const String aiProcessing = 'ai:processing';
  static const String aiReportReady = 'ai:report_ready';
  static const String aiError = 'ai:error';
}
