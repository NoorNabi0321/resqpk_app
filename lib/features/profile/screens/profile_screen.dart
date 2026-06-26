import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/fcm_service.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../first_aid/providers/first_aid_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _guidesRead = 0;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final box = Hive.isBoxOpen('app_stats') ? Hive.box('app_stats') : await Hive.openBox('app_stats');
    if (mounted) {
      setState(() {
        _guidesRead = (box.get('guides_read') as int?) ?? 0;
        _notifications = (box.get('notifications_enabled') as bool?) ?? true;
      });
    }
  }

  Future<void> _setNotifications(bool on) async {
    final box = await Hive.openBox('app_stats');
    await box.put('notifications_enabled', on);
    setState(() => _notifications = on);
    if (on) FCMService.initialize();
  }

  Future<void> _dial(String? number) async {
    if (number == null || number.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surfaceTwo,
        title: Text('Log out?', style: AppTextStyles.subtitle),
        content: Text('You will need to sign in again to use ResQPK.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(d);
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go(Routes.roleSelect);
            },
            child: Text('Log out', style: AppTextStyles.body.copyWith(color: AppColors.sosRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final mp = auth.medicalProfile;
    final lang = ref.watch(firstAidProvider).selectedLanguage;
    final fa = ref.watch(firstAidProvider);
    final initials = (user?.fullName ?? 'U')
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
              ],
            ),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.sosRed,
                    child: Text(initials.isEmpty ? 'U' : initials,
                        style: AppTextStyles.title.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  Text(user?.fullName ?? 'Patient', style: AppTextStyles.title),
                  Text(user?.phone ?? '', style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Medical profile
            _card(
              title: 'My Medical Profile',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.sosRed.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(mp?.bloodGroup ?? '?',
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.sosRed, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text(mp?.bloodGroup != null ? 'Blood Group' : 'Blood group not set',
                          style: AppTextStyles.body.copyWith(
                              color: mp?.bloodGroup != null
                                  ? AppColors.textPrimary
                                  : AppColors.warningAmber)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _chips('Conditions', mp?.chronicConditions ?? const [], AppColors.warningAmber,
                      'No conditions recorded'),
                  const SizedBox(height: 8),
                  _chips('Allergies', mp?.allergies ?? const [], AppColors.sosRed,
                      'No allergies recorded'),
                  if ((mp?.emergencyContactName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _dial(mp.emergencyContactPhone),
                      child: Row(
                        children: [
                          const Icon(Icons.contact_phone, size: 18, color: AppColors.confirmedGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Emergency: ${mp!.emergencyContactName}'
                              '${mp.emergencyContactRelation != null ? ' (${mp.emergencyContactRelation})' : ''}',
                              style: AppTextStyles.caption,
                            ),
                          ),
                          const Icon(Icons.call, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => context.push(Routes.medicalProfile),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: const Text('Update Medical Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick stats
            Row(
              children: [
                _stat('Emergencies', '—'),
                _stat('Guides Read', '$_guidesRead'),
                _stat('Member Since',
                    user != null ? DateFormat('MMM yyyy').format(user.createdAt) : '—'),
              ],
            ),
            const SizedBox(height: 16),

            // Settings
            _card(
              title: 'Settings',
              child: Column(
                children: [
                  _settingRow(
                    Icons.language,
                    'Language',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _miniToggle('EN', lang == 'en',
                            () => ref.read(firstAidProvider.notifier).setLanguage('en')),
                        const SizedBox(width: 6),
                        _miniToggle('اردو', lang == 'ur',
                            () => ref.read(firstAidProvider.notifier).setLanguage('ur')),
                      ],
                    ),
                  ),
                  _settingRow(
                    Icons.notifications_outlined,
                    'Notifications',
                    Switch(
                      value: _notifications,
                      activeThumbColor: AppColors.sosRed,
                      onChanged: _setNotifications,
                    ),
                  ),
                  _settingRow(
                    Icons.cloud_download_outlined,
                    fa.isOfflineCacheAvailable ? 'First Aid cached' : 'First Aid not cached',
                    TextButton(
                      onPressed: fa.isSyncing
                          ? null
                          : () => ref.read(firstAidProvider.notifier).syncInBackground(),
                      child: Text(fa.isSyncing ? 'Syncing…' : 'Sync Now'),
                    ),
                  ),
                  _settingRow(Icons.my_location, 'Location Updates',
                      Text('Every 5 min', style: AppTextStyles.caption)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text('ResQPK 1.0.0  •  FYP Project  •  SZABIST Hyderabad',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.sosRed),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text('Log Out',
                  style: AppTextStyles.buttonLabel.copyWith(color: AppColors.sosRed)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceOne,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _chips(String label, List<String> items, Color color, String empty) {
    if (items.isEmpty) {
      return Text(empty, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(c, style: AppTextStyles.caption.copyWith(color: color)),
              ))
          .toList(),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOne,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(value, style: AppTextStyles.title.copyWith(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      );

  Widget _settingRow(IconData icon, String label, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            trailing,
          ],
        ),
      );

  Widget _miniToggle(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.infoBlue : AppColors.surfaceTwo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: active ? Colors.white : AppColors.textSecondary)),
        ),
      );
}
