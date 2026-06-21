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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _role => GoRouterState.of(context).uri.queryParameters['role'] ?? 'patient';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isDriver = _role == 'driver';
    final notifier = ref.read(authProvider.notifier);
    final ok = isDriver
        ? await notifier.loginDriver(phone: _phone.text.trim(), password: _password.text)
        : await notifier.loginPatient(phone: _phone.text.trim(), password: _password.text);
    if (!mounted) return;
    if (ok) {
      context.go(isDriver ? Routes.driverHome : Routes.home);
    } else {
      final error = ref.read(authProvider).error ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    final roleLabel = _role == 'driver' ? 'Driver' : 'Patient';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome Back, $roleLabel', style: AppTextStyles.display.copyWith(fontSize: 28)),
                const SizedBox(height: 8),
                Text('Log in to continue',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 32),
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
                  validator: (v) => Validators.validateRequired(v, 'Password'),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Login', loading: loading, onPressed: _submit),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(
                      _role == 'driver' ? Routes.driverRegister : Routes.patientRegister),
                  child: Text("Don't have an account? Register",
                      style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
