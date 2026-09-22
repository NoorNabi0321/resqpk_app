import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart' show PrimaryButton, SecondaryButton;
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

  /// Which kind of account is signing in.
  ///
  /// It used to be read straight from the link, and one caller forgot to pass
  /// it — so a driver arrived here in patient mode, their correct credentials
  /// were checked against patient accounts, and they were told the phone or
  /// password was wrong. The link only seeds this now; the screen shows it, and
  /// the person signing in can correct it.
  String? _role;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _role ??= GoRouterState.of(context).uri.queryParameters['role'] == 'driver'
        ? 'driver'
        : 'patient';
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

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
    final roleLabel = _role == 'driver' ? 'driver' : 'patient';
    return Scaffold(
      backgroundColor: Resq.canvas,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Resq.ink),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome back', style: ResqType.display().copyWith(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  'Sign in as a $roleLabel',
                  style: ResqType.body().copyWith(color: Resq.inkSoft),
                ),
                const SizedBox(height: Resq.space5),

                // Visible, and changeable. Driver and patient accounts are
                // checked separately on the server, so picking the wrong one
                // looks exactly like a wrong password.
                _RoleSelector(
                  role: _role ?? 'patient',
                  onChanged: (role) => setState(() => _role = role),
                ),
                const SizedBox(height: Resq.space5),
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
                        color: Resq.inkSoft),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Login', loading: loading, onPressed: _submit),
                const SizedBox(height: 8),
                const SizedBox(height: Resq.space5),
                // Sign-up is one button that asks which kind of account, rather
                // than a screen of role buttons in front of the login form.
                SecondaryButton(
                  label: 'Sign up',
                  icon: Icons.person_add_alt_rounded,
                  onPressed: () => context.push(Routes.signupChoice),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Patient or driver, said out loud.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.role, required this.onChanged});

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Resq.surfaceAlt,
        borderRadius: BorderRadius.circular(Resq.radiusControl),
      ),
      child: Row(
        children: [
          _Option(
            label: 'Patient',
            icon: Icons.person_rounded,
            selected: role == 'patient',
            onTap: () => onChanged('patient'),
          ),
          _Option(
            label: 'Driver',
            icon: Icons.airport_shuttle_rounded,
            selected: role == 'driver',
            onTap: () => onChanged('driver'),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? Resq.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Resq.radiusControl - 2),
            boxShadow: selected ? Resq.cardShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? Resq.brandInk : Resq.inkMuted),
              const SizedBox(width: Resq.space2),
              Text(
                label,
                style: selected
                    ? ResqType.bodyStrong(color: Resq.brandInk)
                    : ResqType.body(color: Resq.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
