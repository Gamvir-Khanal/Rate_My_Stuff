import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class AIRatingResult {
  final double rating;
  final String remarks;

  AIRatingResult({required this.rating, required this.remarks});

  factory AIRatingResult.fromJson(Map<String, dynamic> json) {
    double parsedRating = 7.0;
    if (json.containsKey('rating')) {
      final r = json['rating'];
      if (r is num) {
        parsedRating = r.toDouble();
      } else if (r is String) {
        parsedRating = double.tryParse(r) ?? 7.0;
      }
    }

    String parsedRemarks = 'Solid overall!';
    if (json.containsKey('remarks') && json['remarks'] != null) {
      parsedRemarks = json['remarks'].toString();
    } else if (json.containsKey('remark') && json['remark'] != null) {
      parsedRemarks = json['remark'].toString();
    } else if (json.containsKey('review') && json['review'] != null) {
      parsedRemarks = json['review'].toString();
    }

    return AIRatingResult(
      rating: parsedRating,
      remarks: parsedRemarks,
    );
  }
}

class AIRatingService {
  static int _currentGroqKeyIndex = 0;

  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _groqModel =>
      dotenv.env['GROQ_MODEL'] ?? 'llama-3.2-11b-vision-preview';

  /// Collects all valid, non-placeholder Groq API keys from .env
  static List<String> get _groqApiKeys {
    final List<String> keys = [];

    // 1. Check comma-separated GROQ_API_KEYS if defined
    final commaSeparated = dotenv.env['GROQ_API_KEYS'] ?? '';
    if (commaSeparated.isNotEmpty) {
      for (final rawKey in commaSeparated.split(',')) {
        final k = rawKey.trim();
        if (k.isNotEmpty && !k.contains('YOUR_') && !keys.contains(k)) {
          keys.add(k);
        }
      }
    }

    // 2. Check GROQ_API_KEY
    final singleKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (singleKey.isNotEmpty &&
        !singleKey.contains('YOUR_') &&
        !keys.contains(singleKey)) {
      keys.add(singleKey);
    }

    // 3. Check GROQ_API_KEY_1 through GROQ_API_KEY_20
    for (int i = 1; i <= 20; i++) {
      final k = dotenv.env['GROQ_API_KEY_$i'] ?? '';
      if (k.isNotEmpty && !k.contains('YOUR_') && !keys.contains(k)) {
        keys.add(k);
      }
    }

    return keys;
  }

  static bool get isGroqConfigured => _groqApiKeys.isNotEmpty;

  static bool get isGeminiConfigured =>
      _geminiApiKey.isNotEmpty && !_geminiApiKey.contains('YOUR_');

  static bool get isKeyConfigured => isGroqConfigured || isGeminiConfigured;

  Future<Uint8List> _compressImage(File file, {int maxDim = 600}) async {
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
        '⚠️ Neither GROQ_API_KEY nor GEMINI_API_KEY is configured in .env!',
      );
      throw Exception('AI API key is not configured.');
    }

    final groqKeys = _groqApiKeys;

    // ── 1. Try Groq Keys in round-robin sequence ────────────────────────
    if (groqKeys.isNotEmpty) {
      final startIndex = _currentGroqKeyIndex % groqKeys.length;
      // Advance key index for the next user rating call
      _currentGroqKeyIndex = (_currentGroqKeyIndex + 1) % groqKeys.length;

      debugPrint(
        '⚡ Round-Robin Groq: ${groqKeys.length} key(s) available. Starting with Key #${startIndex + 1}...',
      );

      for (int i = 0; i < groqKeys.length; i++) {
        final keyIndex = (startIndex + i) % groqKeys.length;
        final apiKey = groqKeys[keyIndex];
        final maskedKey = apiKey.length > 8 ? apiKey.substring(0, 8) : apiKey;

        try {
          debugPrint(
            '🔑 Attempting Groq Key #${keyIndex + 1} ($maskedKey...)...',
          );
          return await _executeGroqRateImageCall(
            imageFile,
            categoryLabel,
            apiKey,
          );
        } catch (e) {
          debugPrint(
            '⚠️ Groq Key #${keyIndex + 1} failed ($e). Silently trying next key...',
          );
          // Seamlessly try next key in loop without showing error to user
        }
      }

      debugPrint(
        '⚠️ All ${groqKeys.length} Groq API keys failed. Falling back to Gemini...',
      );
    }

    // ── 2. Fallback to Gemini if all Groq keys fail or none configured ─
    if (isGeminiConfigured) {
      debugPrint('🔑 Calling Gemini fallback for "$categoryLabel"...');
      try {
        return await _executeGeminiRateImageCall(imageFile, categoryLabel);
      } catch (e) {
        debugPrint('❌ Gemini fallback failed: $e');
        rethrow;
      }
    }

    throw Exception(
      'All Groq API keys failed and Gemini API key is not configured.',
    );
  }

  static String get staticModelName => _groqModel;

  Future<AIRatingResult> _executeGroqRateImageCall(
    File imageFile,
    String categoryLabel,
    String apiKey,
  ) async {
    final compressedBytes = await _compressImage(imageFile);
    final base64Image = base64Encode(compressedBytes);
    debugPrint(
      '📸 Image compressed for Groq: ${(compressedBytes.length / 1024).toStringAsFixed(0)} KB',
    );

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final promptText =
        'Rate this "$categoryLabel" photo on a scale of 1.0 to 10.0. '
        'Be a funny, witty Gen-Z critic, specific about what you see in the photo, and use emojis. '
        'Keep your remarks to exactly 1 sentence and make it so comedy that anyone in the world will laugh no matter what. '
        'You MUST return ONLY a JSON object in this exact format: '
        '{"rating": 8.5, "remarks": "your funny review here"}';

    final body = jsonEncode({
      "model": _groqModel,
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": promptText,
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/png;base64,$base64Image",
              },
            }
          ]
        }
      ],
      "temperature": 0.7,
      "response_format": {"type": "json_object"}
    });

    final response = await http
        .post(url, headers: headers, body: body)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Groq API request timed out (30s).');
          },
        );

    if (response.statusCode != 200) {
      debugPrint('❌ Groq API error response (${response.statusCode}): ${response.body}');
      throw Exception('Groq API returned error status ${response.statusCode}: ${response.body}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq returned empty choices in response.');
    }

    var text = choices[0]['message']['content'] as String?;
    debugPrint('✅ Groq raw response: $text');

    if (text == null || text.trim().isEmpty) {
      throw Exception('Groq returned an empty response.');
    }

    text = text.trim();
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
    if (jsonMatch != null) {
      text = jsonMatch.group(0)!;
    }

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AIRatingResult.fromJson(parsed);
  }

  Future<AIRatingResult> _executeGeminiRateImageCall(
    File imageFile,
    String categoryLabel,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: _geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final compressedBytes = await _compressImage(imageFile);
    debugPrint(
      '📸 Image compressed for Gemini: ${(compressedBytes.length / 1024).toStringAsFixed(0)} KB',
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

    final response = await model
        .generateContent(content)
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            throw Exception('Gemini API request timed out (45s).');
          },
        );
    var text = response.text;

    debugPrint('✅ Gemini raw response: $text');

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }
    text = text.trim();
    final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
    if (jsonMatch != null) {
      text = jsonMatch.group(0)!;
    }

    final jsonResponse = jsonDecode(text) as Map<String, dynamic>;
    return AIRatingResult.fromJson(jsonResponse);
  }
}
