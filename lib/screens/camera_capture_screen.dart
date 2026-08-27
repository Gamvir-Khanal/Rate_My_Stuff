import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  int? _timerSeconds;
  int _countdownValue = 0;
  bool _isCountingDown = false;

  final List<int?> _timerOptions = [null, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _setupCameras();
  }

  Future<void> _setupCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startCamera(_cameraIndex);
  }

  Future<void> _startCamera(int index) async {
    final previousController = _controller;

    final newController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    setState(() {
      _controller = newController;
      _initializeControllerFuture = newController.initialize().then((_) {
        newController.setFlashMode(_flashMode);
      });
    });

    await previousController?.dispose();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _flashMode = FlashMode.off;
    await _startCamera(_cameraIndex);
  }

  void _cycleTimer() {
    final currentIndex = _timerOptions.indexOf(_timerSeconds);
    final nextIndex = (currentIndex + 1) % _timerOptions.length;
    setState(() => _timerSeconds = _timerOptions[nextIndex]);
  }

  Future<void> _onCapturePressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCountingDown) return;

    if (_timerSeconds != null && _timerSeconds! > 0) {
      setState(() {
        _isCountingDown = true;
        _countdownValue = _timerSeconds!;
      });

      for (int i = _timerSeconds!; i > 0; i--) {
        setState(() => _countdownValue = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      setState(() => _isCountingDown = false);
    }

    await _takePicture();
  }

  Future<void> _takePicture() async {
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      _returnImage(File(file.path));
    } catch (e) {
      debugPrint('Capture failed: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;
    _returnImage(File(picked.path));
  }

  void _returnImage(File imageFile) {
    // TODO: navigate to loading/result screen, passing `imageFile`
    // and the selected category, then call your AI rating service.
    debugPrint('Image ready: ${imageFile.path}');
    Navigator.pop(context, imageFile);
  }

  String get _timerLabel {
    if (_timerSeconds == null) return 'Off';
    return '${_timerSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (_controller == null ||
                snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize?.height ?? 0,
                      height: _controller!.value.previewSize?.width ?? 0,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),

                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopIconButton(
                        icon: _flashMode == FlashMode.torch
                            ? Icons.flash_on
                            : Icons.flash_off,
                        onTap: _toggleFlash,
                      ),
                      GestureDetector(
                        onTap: _cycleTimer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _timerLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _TopIconButton(
                        icon: Icons.cameraswitch,
                        onTap: _switchCamera,
                      ),
                    ],
                  ),
                ),

                if (_isCountingDown)
                  Center(
                    child: Text(
                      '$_countdownValue',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 96,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 28,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 52,
                          height: 52,
                          margin: const EdgeInsets.only(right: 36),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _onCapturePressed,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 88),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
