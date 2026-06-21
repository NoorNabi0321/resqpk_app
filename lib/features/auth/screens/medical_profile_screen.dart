import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/models/medical_profile_model.dart';
import '../providers/auth_provider.dart';

class MedicalProfileScreen extends ConsumerStatefulWidget {
  const MedicalProfileScreen({super.key});

  @override
  ConsumerState<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends ConsumerState<MedicalProfileScreen> {
  static const List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  static const List<String> _genders = ['male', 'female', 'other'];

  String? _blood;
  String? _gender;
  final List<String> _conditions = [];
  final List<String> _allergies = [];
  final List<String> _medications = [];

  final _conditionCtl = TextEditingController();
  final _allergyCtl = TextEditingController();
  final _medicationCtl = TextEditingController();
  final _ecName = TextEditingController();
  final _ecPhone = TextEditingController();
  final _ecRelation = TextEditingController();

  @override
  void dispose() {
    _conditionCtl.dispose();
    _allergyCtl.dispose();
    _medicationCtl.dispose();
    _ecName.dispose();
    _ecPhone.dispose();
    _ecRelation.dispose();
    super.dispose();
  }

  String? _trimOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  // Strips spaces/dashes so "0333-123 4567" becomes a valid "03331234567".
  String? _phoneOrNull(TextEditingController c) {
    final v = c.text.replaceAll(RegExp(r'[\s-]'), '').trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final profile = MedicalProfileModel(
      id: '',
      userId: '',
      bloodGroup: _blood,
      gender: _gender,
      chronicConditions: _conditions,
      allergies: _allergies,
      currentMedications: _medications,
      emergencyContactName: _trimOrNull(_ecName),
      emergencyContactPhone: _phoneOrNull(_ecPhone),
      emergencyContactRelation: _trimOrNull(_ecRelation),
    );
    final ok = await ref.read(authProvider.notifier).updateMedicalProfile(profile);
    if (!mounted) return;
    if (ok) {
      context.go(Routes.home);
    } else {
      final error = ref.read(authProvider).error ?? 'Could not save profile';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('Your Medical Profile', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This helps us prepare hospitals before you arrive',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('You can update this anytime from your profile',
                  style: AppTextStyles.caption),
              const SizedBox(height: 16),
              Row(
                children: [
                  _stepPill('Account ✓', false),
                  const SizedBox(width: 8),
                  _stepPill('Medical Info', true),
                ],
              ),
              const SizedBox(height: 24),

              Text('Blood Group', style: AppTextStyles.subtitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bloodGroups
                    .map((b) => _pill(b, _blood == b, () => setState(() => _blood = b),
                        AppColors.confirmedGreen))
                    .toList(),
              ),
              const SizedBox(height: 20),

              Text('Gender', style: AppTextStyles.subtitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _genders
                    .map((g) => _pill(g[0].toUpperCase() + g.substring(1), _gender == g,
                        () => setState(() => _gender = g), AppColors.infoBlue))
                    .toList(),
              ),
              const SizedBox(height: 24),

              _chipSection('Chronic Conditions', _conditionCtl, _conditions),
              const SizedBox(height: 16),
              _chipSection('Allergies', _allergyCtl, _allergies),
              const SizedBox(height: 16),
              _chipSection('Current Medications', _medicationCtl, _medications),
              const SizedBox(height: 24),

              Text('Emergency Contact', style: AppTextStyles.subtitle),
              const SizedBox(height: 8),
              GlassTextField(label: 'Contact Name', controller: _ecName),
              const SizedBox(height: 12),
              GlassTextField(
                label: 'Contact Phone',
                hint: '03XXXXXXXXX',
                controller: _ecPhone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              GlassTextField(label: 'Relationship', controller: _ecRelation),
              const SizedBox(height: 28),

              PrimaryButton(
                label: 'Save & Continue',
                color: AppColors.confirmedGreen,
                loading: loading,
                onPressed: _save,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.go(Routes.home),
                  child: Text('Skip for now',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepPill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.sosRed.withValues(alpha: 0.15) : AppColors.surfaceTwo,
        border: Border.all(color: active ? AppColors.sosRed : AppColors.borderGlass),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: active ? AppColors.sosRed : AppColors.textSecondary)),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap, Color selColor) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selColor : Colors.transparent,
          border: Border.all(color: selected ? selColor : AppColors.borderGlass),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _chipSection(String title, TextEditingController ctl, List<String> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.subtitle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: GlassTextField(label: 'Add $title', controller: ctl)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.infoBlue, size: 32),
              onPressed: () {
                final v = ctl.text.trim();
                if (v.isNotEmpty) {
                  setState(() {
                    list.add(v);
                    ctl.clear();
                  });
                }
              },
            ),
          ],
        ),
        if (list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: list
                  .map((e) => Chip(
                        label: Text(e,
                            style: AppTextStyles.caption.copyWith(color: Colors.white)),
                        backgroundColor: AppColors.surfaceThree,
                        deleteIconColor: AppColors.textSecondary,
                        onDeleted: () => setState(() => list.remove(e)),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
