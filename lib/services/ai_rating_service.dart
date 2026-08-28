import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  Future<AIRatingResult> rateImage(File imageFile, String categoryLabel) async {
    if (!isKeyConfigured) {
      debugPrint(
        '⚠️ GEMINI_API_KEY is empty or starts with YOUR_. '
        'Open .env and paste your real key.',
      );
      throw Exception('Gemini API key is not configured.');
    }

    debugPrint(
      '🔑 API key loaded (${_apiKey.substring(0, 8)}...). '
      'Calling Gemini for "$categoryLabel"...',
    );

    try {
      final model = GenerativeModel(
        model: 'gemini-3.6-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final imageBytes = await imageFile.readAsBytes();

      final content = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart('''
You are a brutally honest, hilarious, and witty Gen-Z critic on a "Rate My Stuff" app.

The user submitted a photo in the "$categoryLabel" category. Look at the image carefully and rate it.

RULES:
- Be GENUINELY funny. Use humor, sarcasm, pop-culture references, and emojis.
- Be specific about what you SEE in the image — don't be generic.
- If it's bad, roast it lovingly. If it's great, hype it up like a best friend would.
- Keep remarks to 1 sentences max. Every word should hit.
- Rating must be honest (1.0 = disaster, 10.0 = absolute perfection).

Respond with ONLY this JSON (no extra text):
{
  "rating": <number between 1.0 and 10.0>,
  "remarks": "<your hilarious 2-3 sentence review>"
}
          '''),
        ]),
      ];

      final response = await model.generateContent(content);
      final text = response.text;

      debugPrint('✅ Gemini response: $text');

      if (text == null || text.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
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
