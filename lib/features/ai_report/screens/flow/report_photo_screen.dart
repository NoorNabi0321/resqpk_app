import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../providers/ai_report_provider.dart';
import 'report_flow_chrome.dart';

/// Step 1 of the report: a photo of the patient.
///
/// The camera is the screen, not a button on it. Someone kneeling next to a
/// casualty should not have to find a control — they point the phone and press
/// the shutter. Everything else (gallery, skip) is secondary and sits out of
/// the way at the bottom.
class ReportPhotoScreen extends ConsumerStatefulWidget {
  const ReportPhotoScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ReportPhotoScreen> createState() => _ReportPhotoScreenState();
}

class _ReportPhotoScreenState extends ConsumerState<ReportPhotoScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _starting = true;
  bool _taking = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    // The OS takes the camera away when the app is backgrounded; holding a
    // dead controller shows a frozen frame that looks like a crash.
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _starting = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('This phone has no camera');

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      // No camera, or permission refused. The gallery still works, and so does
      // skipping the photo entirely — neither should be a dead end.
      setState(() {
        _starting = false;
        _cameraError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || _taking) return;
    setState(() => _taking = true);
    try {
      final shot = await controller.takePicture();
      ref.read(aiReportProvider.notifier).setPhoto(shot.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not take the photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  void _next() => context.push(Routes.reportMethod, extra: widget.caseId);

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(aiReportProvider).selectedImages.firstOrNull;

    return ReportFlowScaffold(
      step: 1,
      title: 'Photo of the patient',
      subtitle: 'One clear picture helps the doctor more than any description.',
      onBack: () => context.pop(),
      bottomBar: _Actions(
        hasPhoto: photo != null,
        onGallery: () => ref.read(aiReportProvider.notifier).pickPhotoFromGallery(),
        onRetake: () => ref.read(aiReportProvider.notifier).clearPhoto(),
        onShoot: _controller == null ? null : _shoot,
        onNext: _next,
        taking: _taking,
      ),
      body: ClipRRect(
        borderRadius: BorderRadius.circular(Resq.radiusCard),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          child: photo != null
              ? Image.file(File(photo), fit: BoxFit.cover)
              : _viewfinder(),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    if (_starting) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Resq.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, size: 48, color: Colors.white54),
              const SizedBox(height: Resq.space3),
              Text(
                _cameraError ?? 'The camera is not available',
                textAlign: TextAlign.center,
                style: ResqType.body(color: Colors.white70),
              ),
              const SizedBox(height: Resq.space2),
              Text(
                'Pick a photo from the gallery instead, or carry on without one.',
                textAlign: TextAlign.center,
                style: ResqType.caption(color: Colors.white54),
              ),
              const SizedBox(height: Resq.space4),
              TextButton.icon(
                onPressed: _startCamera,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text('Try the camera again', style: ResqType.button()),
              ),
            ],
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.hasPhoto,
    required this.onGallery,
    required this.onRetake,
    required this.onShoot,
    required this.onNext,
    required this.taking,
  });

  final bool hasPhoto;
  final VoidCallback onGallery;
  final VoidCallback onRetake;
  final VoidCallback? onShoot;
  final VoidCallback onNext;
  final bool taking;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasPhoto)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.replay_rounded, size: 18, color: Resq.inkSoft),
                  label: Text('Retake', style: ResqType.button(color: Resq.inkSoft)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    side: BorderSide(color: Resq.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Resq.space3),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Resq.brandInk,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(Resq.tapTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Resq.radiusControl),
                    ),
                  ),
                  child: Text('Next', style: ResqType.button()),
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SmallAction(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: onGallery,
              ),
              _Shutter(onTap: onShoot, busy: taking),
              _SmallAction(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                onTap: onNext,
              ),
            ],
          ),
      ],
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap, required this.busy});

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null ? Resq.surfaceAlt : Resq.surface,
          border: Border.all(
            color: onTap == null ? Resq.border : Resq.critical,
            width: 4,
          ),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(strokeWidth: 3, color: Resq.critical),
              )
            : Icon(
                Icons.camera_alt_rounded,
                color: onTap == null ? Resq.inkFaint : Resq.critical,
                size: 30,
              ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Resq.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Resq.space3, vertical: Resq.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Resq.inkSoft),
            const SizedBox(height: 4),
            Text(label, style: ResqType.caption(color: Resq.inkSoft)),
          ],
        ),
      ),
    );
  }
}
