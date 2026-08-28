import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIRatingResult {
  final double rating;
  final String remarks;

  AIRatingResult({required this.rating, required this.remarks});

  factory AIRatingResult.fromJson(Map<String, dynamic> json) {
    return AIRatingResult(
      rating: (json['rating'] as num).toDouble(),
      remarks: json['remarks'] as String,
    );
  }
}

class AIRatingService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static bool get isKeyConfigured =>
      _apiKey.isNotEmpty && !_apiKey.startsWith('YOUR_');

  Future<Uint8List> _compressImage(File file, {int maxDim = 800}) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    int width = image.width;
    int height = image.height;
    if (width > maxDim || height > maxDim) {
      if (width > height) {
        height = (height * maxDim / width).round();
        width = maxDim;
      } else {
        width = (width * maxDim / height).round();
        height = maxDim;
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final resized = await recorder.endRecording().toImage(width, height);

    final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    resized.dispose();

    return byteData!.buffer.asUint8List();
  }

  Future<AIRatingResult> rateImage(File imageFile, String categoryLabel) async {
    if (!isKeyConfigured) {
      debugPrint(
        '⚠️ GEMINI_API_KEY is empty or starts with YOUR_. '
        'Open .env and paste your real key.',
      );
      throw Exception('Gemini API key is not configured.');
    }

    debugPrint('🔑 Calling Gemini for "$categoryLabel"...');

    try {
      final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _apiKey);

      final compressedBytes = await _compressImage(imageFile);
      debugPrint(
        '📸 Image compressed: ${(compressedBytes.length / 1024).toStringAsFixed(0)} KB',
      );

      final content = [
        Content.multi([
          DataPart('image/png', compressedBytes),
          TextPart(
            'Rate this "$categoryLabel" photo on a scale of 1.0 to 10.0. '
            'Be a funny, witty Gen-Z critic, specific about what you see in the photo, and use emojis. '
            'Keep your remarks to exactly 1 sentence and make it so comedy that anyone in the world will laugh no matter what. '
            'You MUST return ONLY a JSON object in this exact format: '
            '{"rating": 8.5, "remarks": "your funny review here"}',
          ),
        ]),
      ];

      final response = await model.generateContent(content);
      var text = response.text;

      debugPrint('✅ Gemini raw response: $text');

      if (text == null || text.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }
      text = text.trim();
      if (text.startsWith('```')) {
        text = text.replaceFirst(RegExp(r'^```(json)?'), '');
        if (text.endsWith('```')) {
          text = text.substring(0, text.length - 3);
        }
        text = text.trim();
      }

      final jsonResponse = jsonDecode(text) as Map<String, dynamic>;
      return AIRatingResult.fromJson(jsonResponse);
    } catch (e, stack) {
      debugPrint('❌ Gemini API call failed: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }
}
