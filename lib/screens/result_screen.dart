import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/rating_category.dart';
import '../widgets/real_rating_card.dart';
import 'camera_capture_screen.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final double rating;
  final String remark;
  final RatingCategory category;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.rating,
    required this.remark,
    required this.category,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;
  bool _isSaving = false;
  bool _isSaved = false;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _shareCard() async {
    setState(() => _isSharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('Failed to capture card');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rate_my_stuff_card.png');
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text:
              'I got ${widget.rating.toStringAsFixed(1)}/10 on Rate My Stuff! ${widget.category.emoji}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _tryAgain() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(category: widget.category),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _saveToPhone() async {
    setState(() => _isSaving = true);
    try {
      // Check and request permission
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!hasAccess) {
        throw Exception('Photo library access was denied.');
      }

      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('Failed to capture card');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/rate_my_stuff_card.png');
      await file.writeAsBytes(pngBytes);

      await Gal.putImage(file.path);

      if (mounted) {
        setState(() {
          _isSaved = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6FD8), Color(0xFF9B5CFF), Color(0xFF6A3DFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'YOUR RATING',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Category badge
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${widget.category.emoji} ${widget.category.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: RealRatingCard(
                            imageFile: widget.imageFile,
                            rating: widget.rating,
                            remark: widget.remark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // Share button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSharing ? null : _shareCard,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF6A3DFF),
                                ),
                              )
                            : const Icon(Icons.share_rounded),
                        label: Text(_isSharing ? 'Preparing...' : 'Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6A3DFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 6,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Try Again button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _tryAgain,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save to Phone button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isSaving || _isSaved)
                                ? null
                                : _saveToPhone,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : (_isSaved
                                      ? const Icon(Icons.check_rounded)
                                      : const Icon(Icons.save_alt_rounded)),
                            label: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : (_isSaved ? 'Saved' : 'Save to Phone'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white.withValues(
                                alpha: 0.6,
                              ),
                              side: BorderSide(
                                color: _isSaved
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.white,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
