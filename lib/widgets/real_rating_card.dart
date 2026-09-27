import 'dart:io';
import 'package:flutter/material.dart';
import 'encrypted_image_widget.dart';

class RealRatingCard extends StatelessWidget {
  final File imageFile;
  final double rating;
  final String remark;

  const RealRatingCard({
    super.key,
    required this.imageFile,
    required this.rating,
    required this.remark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: EncryptedImageWidget(
                  imageFile: imageFile,
                  height: MediaQuery.of(context).size.height * 0.44,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 13,
                bottom: -18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6FD8), Color(0xFF6A3DFF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '${rating.toStringAsFixed(1)} / 10',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
            child: Text(
              remark,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D1B4E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
