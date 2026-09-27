import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/encryption_service.dart';

/// A widget that seamlessly displays both standard unencrypted image files
/// and AES-256-GCM encrypted (.enc) image files stored at rest.
class EncryptedImageWidget extends StatefulWidget {
  final File imageFile;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  const EncryptedImageWidget({
    super.key,
    required this.imageFile,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.errorBuilder,
  });

  @override
  State<EncryptedImageWidget> createState() => _EncryptedImageWidgetState();
}

class _EncryptedImageWidgetState extends State<EncryptedImageWidget> {
  late Future<Uint8List?> _imageBytesFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant EncryptedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile.path != widget.imageFile.path) {
      _loadImage();
    }
  }

  void _loadImage() {
    _imageBytesFuture = _getDecryptedOrRawBytes(widget.imageFile);
  }

  static Future<Uint8List?> _getDecryptedOrRawBytes(File file) async {
    if (!await file.exists()) {
      return null;
    }

    final path = file.path;
    if (path.endsWith('.enc')) {
      try {
        return await EncryptionService.instance.readAndDecryptFile(path);
      } catch (e) {
        debugPrint('⚠️ Error decrypting image file $path: $e');
        return null;
      }
    } else {
      try {
        return await file.readAsBytes();
      } catch (e) {
        debugPrint('⚠️ Error reading plain image file $path: $e');
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6A3DFF),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
              context,
              snapshot.error ?? Exception('Failed to load image'),
              snapshot.stackTrace,
            );
          }
          return Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade300,
            child: const Icon(
              Icons.broken_image_rounded,
              color: Colors.grey,
            ),
          );
        }

        final bytes = snapshot.data!;
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}
