import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/location/gps_persistence_provider.dart';
import '../../../core/storage/driver_contact_storage.dart';
import '../../auth/providers/auth_provider.dart';

/// Loads the locally-cached assigned-driver contact (if any).
final activeDriverContactProvider = FutureProvider.autoDispose<Map<String, String?>?>((ref) {
  return DriverContactStorage.getActiveDriverContact();
});

class OfflineSOSScreen extends ConsumerWidget {
  const OfflineSOSScreen({super.key});

  Future<void> _triggerSMSsos(BuildContext context) async {
    const gateway = AppConstants.gatewayPhoneNumber;
    final uri = Uri(scheme: 'sms', path: gateway, queryParameters: {'body': AppConstants.sosKeyword});
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.confirmedGreen,
          content: Text('SOS SMS opened — press Send to alert ResQPK.'),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open SMS app. Text "SOS" to $gateway manually.')),
      );
    }
  }

  Future<void> _confirmAndSend(BuildContext context, String ageText) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surfaceTwo,
        title: Text('Send Emergency SMS?', style: AppTextStyles.subtitle),
        content: Text(
          'Your last saved location will be used.\n$ageText\n\n'
          'This opens your SMS app with an SOS message ready — just press send.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text('Open SMS', style: AppTextStyles.body.copyWith(color: AppColors.sosRed)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _triggerSMSsos(context);
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _smsDriver(String phone, String patientName, String? caseId) async {
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {
      'body': 'ResQPK Emergency: $patientName has lost internet. '
          'Please continue to my last location.${caseId != null && caseId.isNotEmpty ? ' Case: $caseId' : ''}',
    });
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final gps = ref.read(gpsPersistenceServiceProvider);
    final loc = gps.getLastKnownLocation();
    final ageText = gps.getLocationAgeText();
    final fresh = gps.isLocationFresh();
    final driverContact = ref.watch(activeDriverContactProvider).value;
    final patientName = ref.watch(currentUserProvider)?.fullName ?? 'Patient';

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0E), // dark red tint
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Status banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                color: isOnline ? AppColors.confirmedGreen : AppColors.sosRed,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  isOnline ? '📶 Connected — Offline mode as backup' : '📵 No Internet Connection',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Illustration
                    const SizedBox(height: 16),
                    Icon(Icons.signal_cellular_off, size: 72, color: AppColors.sosRed.withValues(alpha: 0.8)),
                    const SizedBox(height: 12),
                    Text('Emergency Without Internet',
                        style: AppTextStyles.title.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Send one SMS — works with no internet connection',
                        textAlign: TextAlign.center, style: AppTextStyles.caption),
                    const SizedBox(height: 24),

                    // Location status card
                    _LocationCard(loc: loc, ageText: ageText, fresh: fresh),
                    const SizedBox(height: 20),

                    // Main SMS SOS button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: () => _confirmAndSend(context, ageText),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sosRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                        ),
                        child: Text('📩 Send SMS SOS',
                            style: AppTextStyles.buttonLabel.copyWith(color: Colors.white, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Opens your SMS app with SOS ready to send', style: AppTextStyles.caption),

                    // Direct driver contact (only when a driver is assigned + cached)
                    if (DriverContactStorage.hasActiveDriverContact(driverContact)) ...[
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.surfaceTwo),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('Direct Driver Contact',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceOne,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceTwo),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverContact!['name']?.isNotEmpty == true
                                  ? driverContact['name']!
                                  : 'Your driver',
                              style: AppTextStyles.body.copyWith(color: Colors.white),
                            ),
                            if (driverContact['vehicleNumber']?.isNotEmpty == true)
                              Text(driverContact['vehicleNumber']!, style: AppTextStyles.caption),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _smsDriver(
                                        driverContact['phone']!, patientName, driverContact['caseId']),
                                    icon: const Icon(Icons.sms_outlined, size: 16),
                                    label: const Text('Text Driver'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _dial(driverContact['phone']!),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.confirmedGreen),
                                    icon: const Icon(Icons.call, size: 16, color: Colors.white),
                                    label: const Text('Call', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
                    const Divider(color: AppColors.surfaceTwo),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Other Emergency Services',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                    ...AppConstants.emergencyServices.map((s) => _ServiceRow(
                          icon: s['icon']!,
                          name: s['name']!,
                          number: s['number']!,
                          onTap: () => _dial(s['number']!),
                        )),

                    const SizedBox(height: 24),
                    Text('When internet returns, the ResQPK app will fully activate.',
                        textAlign: TextAlign.center, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text('ResQPK ${AppConstants.appVersion}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.loc, required this.ageText, required this.fresh});
  final Map<String, dynamic>? loc;
  final String ageText;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final Color dot;
    final String title;
    final String hint;
    if (loc == null) {
      dot = AppColors.sosRed;
      title = 'No location saved';
      hint = 'Open the app with internet at least once, or use the numbers below.';
    } else if (fresh) {
      dot = AppColors.confirmedGreen;
      title = 'Location saved ✓';
      hint = 'This location will be used when you send SOS.';
    } else {
      dot = const Color(0xFFF59E0B);
      title = 'Location saved (may be outdated)';
      hint = 'Open the app with internet to refresh.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOne,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceTwo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.body.copyWith(color: Colors.white))),
            ],
          ),
          const SizedBox(height: 6),
          if (loc != null) ...[
            Text('Last updated: $ageText', style: AppTextStyles.caption),
            Text(
              '${(loc!['lat'] as num).toStringAsFixed(4)}, ${(loc!['lng'] as num).toStringAsFixed(4)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
          ],
          Text(hint, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.icon, required this.name, required this.number, required this.onTap});
  final String icon;
  final String name;
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: AppTextStyles.body.copyWith(color: Colors.white))),
            Text(number, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
