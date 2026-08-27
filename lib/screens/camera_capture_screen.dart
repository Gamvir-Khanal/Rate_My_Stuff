import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../models/rating_category.dart';
import 'scanning_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  final RatingCategory category;
  const CameraCaptureScreen({super.key, required this.category});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  int? _timerSeconds; // null = off
  int _countdownValue = 0;
  bool _isCountingDown = false;
  bool _showFrontFlashOverlay = false;

  final List<int?> _timerOptions = [null, 3, 5, 10];

  final List<_AspectOption> _aspectOptions = const [
    _AspectOption(ratio: 3 / 4, label: '3:4', icon: Icons.crop_portrait),
    _AspectOption(ratio: 1, label: '1:1', icon: Icons.crop_square),
    _AspectOption(ratio: 9 / 16, label: '9:16', icon: Icons.crop_free),
    _AspectOption(ratio: null, label: 'Full', icon: Icons.fullscreen),
  ];
  int _aspectIndex = 0;

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
      _initializeControllerFuture = newController.initialize().then((_) async {
        try {
          await newController.setFlashMode(_flashMode);
        } catch (e) {
          debugPrint('Failed to set initial flash mode: $e');
        }
      });
    });

    await previousController?.dispose();
  }

  Future<void> _setBrightnessMax() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (e) {
      debugPrint('Failed to set brightness to max: $e');
    }
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      debugPrint('Failed to reset brightness: $e');
    }
  }

  @override
  void dispose() {
    _resetBrightness();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _controller!.setFlashMode(next);
    } catch (e) {
      debugPrint('Failed to set flash mode: $e');
    }
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

  void _cycleAspectRatio() {
    setState(() => _aspectIndex = (_aspectIndex + 1) % _aspectOptions.length);
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

    final isFrontCamera =
        _controller!.description.lensDirection == CameraLensDirection.front;
    final isFlashOn = _flashMode != FlashMode.off;

    try {
      if (isFrontCamera && isFlashOn) {
        setState(() {
          _showFrontFlashOverlay = true;
        });
        await _setBrightnessMax();
        // Give it a brief delay to ensure the screen is fully white before capture
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await _takePicture();
    } finally {
      if (isFrontCamera && isFlashOn) {
        await _resetBrightness();
      }
      if (mounted) {
        setState(() {
          _showFrontFlashOverlay = false;
        });
      }
    }
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
    debugPrint('Image ready: ${imageFile.path}');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanningScreen(
          imageFile: imageFile,
          category: widget.category,
        ),
      ),
    );
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

            final currentAspect = _aspectOptions[_aspectIndex];

            return LayoutBuilder(
              builder: (context, constraints) {
                final double screenRatio =
                    constraints.maxWidth / constraints.maxHeight;
                final double currentRatio = currentAspect.ratio ?? screenRatio;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Live camera preview, framed to the selected aspect ratio
                    Center(
                      child: AspectRatio(
                        aspectRatio: currentRatio,
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width:
                                      _controller!.value.previewSize?.height ??
                                          0,
                                  height:
                                      _controller!.value.previewSize?.width ??
                                          0,
                                  child: CameraPreview(_controller!),
                                ),
                              ),
                              const _CornerBrackets(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top row: flash, timer, aspect ratio
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
                            icon: currentAspect.icon,
                            onTap: _cycleAspectRatio,
                          ),
                        ],
                      ),
                    ),

                    // Countdown overlay
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

                    // Bottom row: gallery (left), shutter (center), flip camera (right)
                    Positioned(
                      bottom: 28,
                      left: 24,
                      right: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          _ShutterButton(onTap: _onCapturePressed),
                          _TopIconButton(
                            icon: Icons.cameraswitch,
                            onTap: _switchCamera,
                          ),
                        ],
                      ),
                    ),

                    // Front camera flash overlay
                    if (_showFrontFlashOverlay)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AspectOption {
  final double? ratio;
  final String label;
  final IconData icon;

  const _AspectOption({
    required this.ratio,
    required this.label,
    required this.icon,
  });
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

/// Big gradient-ringed shutter button with a press-down scale animation
/// and an outward pulse ring that fires on capture.
class _ShutterButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ShutterButton({required this.onTap});

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pulseController.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      child: SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // outward pulse ring on capture
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final value = _pulseController.value;
                return Opacity(
                  opacity: (1 - value).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + value * 0.6,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF6FD8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // gradient ring + white core, scales down on press
            AnimatedScale(
              scale: _isPressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6FD8), Color(0xFF6A3DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four corner brackets overlaid on the preview frame to help the
/// user line up the subject inside the shot.
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  static const double _size = 30;
  static const double _thickness = 3;
  static const double _inset = 18;
  static const Color _color = Colors.white70;

  Widget _corner({required bool top, required bool left}) {
    return Positioned(
      top: top ? _inset : null,
      bottom: top ? null : _inset,
      left: left ? _inset : null,
      right: left ? null : _inset,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: _color, width: _thickness)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: _color, width: _thickness)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: _color, width: _thickness)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: _color, width: _thickness)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _corner(top: true, left: true),
        _corner(top: true, left: false),
        _corner(top: false, left: true),
        _corner(top: false, left: false),
      ],
    );
  }
}
