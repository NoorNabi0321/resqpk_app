import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sos/data/models/emergency_case_model.dart';
import '../../sos/data/sos_repository.dart';

/// The run this driver is already on, if any.
///
/// The navigation screen tells drivers they can come back to a case from the
/// dashboard, and until this existed they could not: back from the map landed
/// on a duty screen with no mention of the case still assigned to them, and
/// nothing on it led anywhere near the patient. The server decides what counts
/// as resumable — assigned, arrived, or en route.
final driverActiveCaseProvider = FutureProvider<EmergencyCaseModel?>((ref) {
  return SOSRepository().getMyActiveCase();
});
