import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../sos/providers/session_provider.dart';
import '../../data/ai_report_repository.dart';
import '../../providers/ai_report_provider.dart';
import 'report_actions.dart';
import 'report_flow_chrome.dart';

/// The finished report: what it says, and where it can go.
///
/// The hospital already has it — the pipeline sends it the moment it is ready —
/// so "Send to hospital" here is a re-send for the case where staff say they
/// cannot see it. Sharing is separate and goes wherever the family is:
/// WhatsApp, mostly.
class ReportResultScreen extends ConsumerStatefulWidget {
  const ReportResultScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ReportResultScreen> createState() => _ReportResultScreenState();
}

class _ReportResultScreenState extends ConsumerState<ReportResultScreen> {
  final AIReportRepository _repo = AIReportRepository();

  File? _file;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _caseToken => caseTokenFor(
        ref.read(sessionProvider),
        signedIn: ref.read(authProvider).isAuthenticated,
        caseId: widget.caseId,
      );

  String get _fileName {
    final report = ref.read(aiReportProvider).report;
    final condition = (report?.emergencyType ?? 'Emergency report').trim();
    final safe = condition
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final suffix = widget.caseId.length >= 8 ? widget.caseId.substring(0, 8) : widget.caseId;
    return '${safe.isEmpty ? 'Emergency_report' : safe}_$suffix.pdf';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // The PDF is rendered and uploaded moments after the JSON report is
      // saved, so a first request can legitimately 404. Retry briefly rather
      // than telling someone it failed.
      String? url;
      for (var attempt = 0; attempt < 6 && url == null; attempt++) {
        url = await _repo.getReportPdfUrl(widget.caseId, caseToken: _caseToken);
        if (url == null) await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
      if (url == null) throw Exception('The report is still being prepared.');

      final dir = await getTemporaryDirectory();
      final file = await _repo.downloadPdf(url, '${dir.path}/$_fileName');
      if (!mounted) return;
      setState(() {
        _file = file;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _sendToHospital() async {
    setState(() => _sending = true);
    try {
      await _repo.sendReportToHospital(widget.caseId, caseToken: _caseToken);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to the hospital again')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    final report = ref.read(aiReportProvider).report;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'ResQPK emergency report'
          '${report?.emergencyType != null ? ' — ${report!.emergencyType}' : ''}',
    );
  }

  /// Runs the same inputs through again. The photo, recording and text are
  /// still in the notifier, so this costs one more API call and nothing else.
  Future<void> _regenerate() async {
    final state = ref.read(aiReportProvider);
    if (!state.hasAnyInput) {
      // Opened from history, with nothing left in memory to resend.
      context.pushReplacement(Routes.reportPhoto, extra: widget.caseId);
      return;
    }
    context.pushReplacement(Routes.reportGenerating, extra: widget.caseId);
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(aiReportProvider).report;

    return ReportFlowScaffold(
      step: 0,
      title: 'Report ready',
      subtitle: report?.emergencyType != null
          ? '${report!.emergencyType} · ${report.urgencyLevel ?? 'urgency unknown'}'
          : null,
      onBack: () => context.go(Routes.tracking),
      bottomBar: _Actions(
        sending: _sending,
        sent: _sent,
        canShare: _file != null,
        onSend: _sendToHospital,
        onShare: _share,
        onRegenerate: _regenerate,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Resq.surface,
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          border: Border.all(color: Resq.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: _preview(),
      ),
    );
  }

  Widget _preview() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Resq.brandInk));
    }
    if (_error != null || _file == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Resq.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, size: 48, color: Resq.inkFaint),
              const SizedBox(height: Resq.space3),
              Text(
                _error ?? 'The report could not be opened',
                textAlign: TextAlign.center,
                style: ResqType.body(color: Resq.inkSoft),
              ),
              const SizedBox(height: Resq.space2),
              Text(
                'The hospital already has it — this is only the copy for you.',
                textAlign: TextAlign.center,
                style: ResqType.caption(),
              ),
              const SizedBox(height: Resq.space4),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _file!.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: false,
      onError: (e) => setState(() => _error = e.toString()),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.sending,
    required this.sent,
    required this.canShare,
    required this.onSend,
    required this.onShare,
    required this.onRegenerate,
  });

  final bool sending;
  final bool sent;
  final bool canShare;
  final VoidCallback onSend;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return ReportActions(
      busy: sending,
      actions: [
        ReportAction(
          icon: Icons.autorenew_rounded,
          tooltip: 'Regenerate — this report is not accurate',
          onPressed: onRegenerate,
        ),
        ReportAction(
          icon: Icons.share_rounded,
          tooltip: 'Share the report',
          onPressed: canShare ? onShare : null,
          color: Resq.brandInk,
        ),
        ReportAction(
          icon: sent ? Icons.check_rounded : Icons.local_hospital_rounded,
          tooltip: sent ? 'Sent to the hospital' : 'Send to the hospital',
          onPressed: onSend,
          filled: true,
          color: sent ? Resq.ready : Resq.critical,
        ),
      ],
    );
  }
}
