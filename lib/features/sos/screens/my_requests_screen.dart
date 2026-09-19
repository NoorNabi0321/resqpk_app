import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../providers/session_provider.dart';
import '../providers/sos_provider.dart';

/// Every emergency raised from this phone, and a way in to any other.
///
/// This is what replaces an account for a patient. A request is identified by
/// its code — the one shown after the SOS and repeated in the WhatsApp chat —
/// so a request raised on a neighbour's phone opens here just as well as one
/// raised on this one.
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _opening = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _open(String code) async {
    if (code.trim().isEmpty) {
      setState(() => _error = 'Enter the code from your request');
      return;
    }

    setState(() {
      _error = null;
      _opening = true;
    });

    try {
      final found = await ref.read(sosProvider.notifier).openByAccessCode(code);
      if (!mounted) return;
      setState(() => _opening = false);

      if (found.status == 'completed') {
        context.push(Routes.aiReport, extra: found.caseId);
      } else if (found.status == 'cancelled') {
        setState(() => _error = 'That request was cancelled.');
      } else {
        context.push(Routes.tracking);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentRequestsProvider);

    return AppScaffold(
      title: 'My requests',
      body: ListView(
        padding: const EdgeInsets.only(bottom: Resq.space6),
        children: [
          _CodeCard(
            controller: _code,
            error: _error,
            busy: _opening,
            onSubmit: () => _open(_code.text),
          ),
          const SizedBox(height: Resq.space6),
          Text('From this phone', style: ResqType.section()),
          const SizedBox(height: Resq.space3),
          recent.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(Resq.space6),
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
            error: (_, __) => Text(
              'Could not read this phone\'s history.',
              style: ResqType.body(color: Resq.inkMuted),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Resq.space5),
                  decoration: BoxDecoration(
                    color: Resq.surfaceAlt,
                    borderRadius: BorderRadius.circular(Resq.radiusCard),
                  ),
                  child: Text(
                    'No emergencies raised from this phone in the last day. '
                    'That is the good outcome.',
                    style: ResqType.body(color: Resq.inkSoft),
                  ),
                );
              }
              return Column(
                children: [
                  for (final item in items)
                    _RequestTile(
                      item: item,
                      busy: _opening,
                      onOpen: () => _open(item['accessCode'] ?? ''),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.controller,
    required this.error,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? error;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Resq.space4),
      decoration: BoxDecoration(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        border: Border.all(color: Resq.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open a request by code', style: ResqType.section()),
          const SizedBox(height: Resq.space2),
          Text(
            'The code looks like RQ-4B7K-29QX. It is shown when the ambulance is '
            'requested, and sent again in the WhatsApp chat.',
            style: ResqType.body(color: Resq.inkSoft),
          ),
          const SizedBox(height: Resq.space4),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => onSubmit(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              LengthLimitingTextInputFormatter(20),
            ],
            style: ResqType.section(),
            decoration: InputDecoration(
              hintText: 'RQ-XXXX-XXXX',
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
          if (error != null) ...[
            const SizedBox(height: Resq.space2),
            Text(error!, style: ResqType.caption(color: Resq.critical)),
          ],
          const SizedBox(height: Resq.space4),
          SizedBox(
            width: double.infinity,
            height: Resq.tapTarget,
            child: ElevatedButton(
              onPressed: busy ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Resq.brandInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Resq.radiusControl),
                ),
                elevation: 0,
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text('Open request', style: ResqType.button()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item, required this.busy, required this.onOpen});

  final Map<String, String> item;
  final bool busy;
  final VoidCallback onOpen;

  String get _when {
    final at = DateTime.tryParse(item['savedAt'] ?? '');
    if (at == null) return '';
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
    return '${ago.inHours} hr ago';
  }

  @override
  Widget build(BuildContext context) {
    final code = item['accessCode'] ?? '';
    final number = item['caseNumber'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: Resq.space3),
      child: Material(
        color: Resq.surface,
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: InkWell(
          onTap: busy || code.isEmpty ? null : onOpen,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(Resq.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Resq.radiusCard),
              border: Border.all(color: Resq.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code.isEmpty ? 'Request' : code, style: ResqType.bodyStrong()),
                      const SizedBox(height: Resq.space1),
                      Text(
                        [if (number.isNotEmpty) 'Case $number', _when]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: ResqType.caption(),
                      ),
                    ],
                  ),
                ),
                if (code.isNotEmpty) const Icon(Icons.chevron_right_rounded, color: Resq.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
