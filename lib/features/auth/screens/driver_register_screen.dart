import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_provider.dart';

class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  ConsumerState<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends ConsumerState<DriverRegisterScreen> {
  static const List<String> _organizations = [
    'Private',
    'Rescue 1122',
    'Edhi Foundation',
    'Chhipa Welfare',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _vehicle = TextEditingController();
  final _license = TextEditingController();
  String _organization = 'Private';
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _vehicle.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).registerDriver(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          vehicleNumber: _vehicle.text.trim(),
          licenseNumber: _license.text.trim(),
          organization: _organization,
        );
    if (!mounted) return;
    if (ok) {
      context.go(Routes.driverHome);
    } else {
      final error = ref.read(authProvider).error ?? 'Registration failed';
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
        title: Text('Driver Sign Up', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassTextField(
                  label: 'Full Name',
                  controller: _name,
                  validator: Validators.validateName,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  label: 'Phone Number',
                  hint: '03XXXXXXXXX',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: Validators.validatePhone,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  label: 'Password',
                  controller: _password,
                  obscureText: _obscure,
                  validator: Validators.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  label: 'Vehicle Number',
                  controller: _vehicle,
                  validator: (v) => Validators.validateRequired(v, 'Vehicle number'),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  label: 'License Number',
                  controller: _license,
                  validator: (v) => Validators.validateRequired(v, 'License number'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _organization,
                  dropdownColor: AppColors.surfaceTwo,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    labelText: 'Organization',
                    labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surfaceTwo,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderGlass),
                    ),
                  ),
                  items: _organizations
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (v) => setState(() => _organization = v ?? 'Private'),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Create Account', loading: loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
