import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../providers/session_provider.dart';

/// Normalises what people actually type: +92 300 1234567, 0300-1234567,
/// 923001234567. The backend accepts 03XXXXXXXXX and +92XXXXXXXXXX.
String? normalizePkPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('92')) digits = '0${digits.substring(2)}';
  if (RegExp(r'^03\d{9}$').hasMatch(digits)) return digits;
  return null;
}

/// Asks for a callback number — once, and then never again on this device.
///
/// This is the whole of registration for a patient: no password, no OTP, no
/// email. The crew needs a number they can ring when an address turns out to be
/// vague, and at the moment of the call nothing else about the person matters.
///
/// Returns true when a number was saved.
Future<bool> showReporterPhoneSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ReporterPhoneSheet(),
  );
  return saved ?? false;
}

class _ReporterPhoneSheet extends ConsumerStatefulWidget {
  const _ReporterPhoneSheet();

  @override
  ConsumerState<_ReporterPhoneSheet> createState() => _ReporterPhoneSheetState();
}

class _ReporterPhoneSheetState extends ConsumerState<_ReporterPhoneSheet> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _phone.text = session.reporterPhone ?? '';
    _name.text = session.reporterName ?? '';
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = normalizePkPhone(_phone.text);
    if (phone == null) {
      setState(() => _error = 'Enter a mobile number like 0300 1234567');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    await ref.read(sessionProvider.notifier).saveReporter(phone: phone, name: _name.text);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard; without this the number field sits
      // under it on short phones and nobody can see what they typed.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Resq.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Resq.radiusCard)),
        ),
        padding: const EdgeInsets.fromLTRB(
          Resq.space5,
          Resq.space3,
          Resq.space5,
          Resq.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Resq.border,
                  borderRadius: BorderRadius.circular(Resq.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: Resq.space5),
            Text('Your number', style: ResqType.title()),
            const SizedBox(height: Resq.space2),
            Text(
              'The ambulance crew calls this number if they cannot find you. '
              'Asked once — no account, no password.',
              style: ResqType.body(color: Resq.inkSoft),
            ),
            const SizedBox(height: Resq.space5),
            _Field(
              controller: _phone,
              label: 'Mobile number',
              hint: '0300 1234567',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                LengthLimitingTextInputFormatter(17),
              ],
              autofocus: true,
            ),
            const SizedBox(height: Resq.space4),
            _Field(
              controller: _name,
              label: 'Name (optional)',
              hint: 'So the crew knows who to ask for',
              keyboardType: TextInputType.name,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
            ),
            if (_error != null) ...[
              const SizedBox(height: Resq.space3),
              Text(_error!, style: ResqType.caption(color: Resq.critical)),
            ],
            const SizedBox(height: Resq.space5),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Resq.critical,
                  disabledBackgroundColor: Resq.critical.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Resq.radiusControl),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text('Save and call ambulance', style: ResqType.button()),
              ),
            ),
            const SizedBox(height: Resq.space2),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                child: Text('Not now', style: ResqType.body(color: Resq.inkMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.inputFormatters,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ResqType.caption(color: Resq.inkSoft)),
        const SizedBox(height: Resq.space1),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          style: ResqType.section(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ResqType.body(color: Resq.inkFaint),
            filled: true,
            fillColor: Resq.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Resq.space4,
              vertical: Resq.space4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Resq.radiusControl),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
