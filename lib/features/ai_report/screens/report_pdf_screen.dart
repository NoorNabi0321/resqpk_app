import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/ai_report_repository.dart';
import '../data/models/ai_report_model.dart';

/// Full-screen viewer for the generated AI emergency report PDF, with sharing
/// and a save-to-device action.
class ReportPdfScreen extends ConsumerStatefulWidget {
  const ReportPdfScreen({super.key, required this.caseId, this.report});

  final String caseId;
  final AIReportModel? report;

  @override
  ConsumerState<ReportPdfScreen> createState() => _ReportPdfScreenState();
}

class _ReportPdfScreenState extends ConsumerState<ReportPdfScreen> {
  final AIReportRepository _repo = AIReportRepository();

  File? _file;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _pages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Names the file after the detected condition so it is recognisable in a
  /// file manager: "Cardiac_Emergency_RQ-20260726-0011.pdf".
  String get _fileName {
    final condition = (widget.report?.emergencyType ?? 'Emergency Report').trim();
    final safe = condition
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final suffix = widget.caseId.length >= 8 ? widget.caseId.substring(0, 8) : widget.caseId;
    return '${safe.isEmpty ? 'Emergency_Report' : safe}_$suffix.pdf';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // The PDF is rendered and uploaded moments after the JSON report is
      // saved, so a first request can legitimately 404. Retry briefly rather
      // than telling the patient it failed.
      String? url;
      for (var attempt = 0; attempt < 6 && url == null; attempt++) {
        url = await _repo.getReportPdfUrl(widget.caseId);
        if (url == null) await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
      if (url == null) throw Exception('The report PDF is still being prepared.');

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

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    final condition = widget.report?.emergencyType ?? 'Emergency';
    // Opens the system share sheet — WhatsApp, Gmail, Bluetooth, Drive, etc.
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'ResQPK Emergency Report — $condition',
      text: 'ResQPK AI emergency report ($condition).',
    );
  }

  Future<void> _download() async {
    final file = _file;
    if (file == null) return;
    setState(() => _saving = true);
    try {
      // Lets the user choose the destination folder, so the PDF lands
      // somewhere their file manager can actually see.
      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(sourceFilePath: file.path, fileName: _fileName),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved as $_fileName')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _file != null && !_loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency Report', style: AppTextStyles.subtitle),
            if (_pages > 0)
              Text('Page ${_currentPage + 1} of $_pages', style: AppTextStyles.caption),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share report',
            onPressed: ready ? _share : null,
            icon: const Icon(Icons.share, color: AppColors.infoBlue),
          ),
          IconButton(
            tooltip: 'Download report',
            onPressed: ready && !_saving ? _download : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.infoBlue),
                  )
                : const Icon(Icons.download, color: AppColors.infoBlue),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.sosRed),
            SizedBox(height: 16),
            Text('Preparing your report…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.textSecondary, size: 52),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18, color: AppColors.infoBlue),
                label: Text('Try again',
                    style: AppTextStyles.caption.copyWith(color: AppColors.infoBlue)),
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _file!.path,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: false,
      fitPolicy: FitPolicy.WIDTH,
      onRender: (pages) => setState(() => _pages = pages ?? 0),
      onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
      onError: (e) => setState(() => _error = 'Could not display the PDF: $e'),
    );
  }
}
