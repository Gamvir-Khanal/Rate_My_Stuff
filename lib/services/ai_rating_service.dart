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

  static String get _groqModel =>
      dotenv.env['GROQ_MODEL'] ?? 'qwen/qwen3.8-27b';

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

  /// Collects all valid, non-placeholder Gemini API keys from .env
  static List<String> get _geminiApiKeys {
    final List<String> keys = [];

    // 1. Check single/legacy GEMINI_API_KEY
    final singleKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (singleKey.isNotEmpty &&
        !singleKey.contains('YOUR_') &&
        !keys.contains(singleKey)) {
      keys.add(singleKey);
    }

    // 2. Check GEMINI_API_KEY_1 through GEMINI_API_KEY_5
    for (int i = 1; i <= 5; i++) {
      final k = dotenv.env['GEMINI_API_KEY_$i'] ?? '';
      if (k.isNotEmpty && !k.contains('YOUR_') && !keys.contains(k)) {
        keys.add(k);
      }
    }

    return keys;
  }

  static bool get isGroqConfigured => _groqApiKeys.isNotEmpty;

  static bool get isGeminiConfigured => _geminiApiKeys.isNotEmpty;

  static bool get isKeyConfigured => isGroqConfigured || isGeminiConfigured;

  /// Tracks cooldown timestamps for throttled (429) or invalid API keys
  static final Map<String, DateTime> _keyCooldowns = {};

  /// Checks if a key is currently on cooldown
  static bool isKeyOnCooldown(String apiKey) {
    final cooldownUntil = _keyCooldowns[apiKey];
    if (cooldownUntil == null) return false;
    if (DateTime.now().isAfter(cooldownUntil)) {
      _keyCooldowns.remove(apiKey);
      return false;
    }
    return true;
  }

  /// Sets a cooldown for a throttled/errored key
  static void markKeyCooldown(String apiKey, Duration duration) {
    _keyCooldowns[apiKey] = DateTime.now().add(duration);
  }

  /// Quick offline check (completes in < 2 seconds)
  static Future<bool> hasInternetConnection() async {
    try {
      final lookup = await InternetAddress.lookup('api.groq.com')
          .timeout(const Duration(milliseconds: 2000));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallbackLookup = await InternetAddress.lookup('google.com')
            .timeout(const Duration(milliseconds: 1500));
        return fallbackLookup.isNotEmpty &&
            fallbackLookup[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

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

    // ── Instant Offline Pre-check ─────────────────────────────────────────
    final isOnline = await hasInternetConnection();
    if (!isOnline) {
      debugPrint('❌ Instant offline detection: device not connected.');
      throw Exception('No internet connection. Please check your network and try again.');
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

        if (isKeyOnCooldown(apiKey)) {
          debugPrint(
            '⏳ Groq Key #${keyIndex + 1} ($maskedKey...) is on cooldown. Skipping...',
          );
          continue;
        }

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
        '⚠️ All ${groqKeys.length} Groq API keys failed or on cooldown. Falling back to Gemini...',
      );
    }

    // ── 2. Fallback to Gemini if all Groq keys fail or none configured ─
    final geminiKeys = _geminiApiKeys;
    if (geminiKeys.isNotEmpty) {
      debugPrint(
        '🔑 Calling Gemini fallback sequence (${geminiKeys.length} key(s) available) for "$categoryLabel"...',
      );
      dynamic lastGeminiError;

      for (int i = 0; i < geminiKeys.length; i++) {
        final apiKey = geminiKeys[i];
        final maskedKey = apiKey.length > 8 ? apiKey.substring(0, 8) : apiKey;

        if (isKeyOnCooldown(apiKey)) {
          debugPrint(
            '⏳ Gemini Key #${i + 1} ($maskedKey...) is on cooldown. Skipping...',
          );
          continue;
        }

        try {
          debugPrint(
            '🔑 Attempting Gemini Key #${i + 1} ($maskedKey...)...',
          );
          return await _executeGeminiRateImageCall(
            imageFile,
            categoryLabel,
            apiKey,
          );
        } catch (e) {
          debugPrint(
            '⚠️ Gemini Key #${i + 1} failed ($e). Silently trying next Gemini key...',
          );
          lastGeminiError = e;
        }
      }

      debugPrint('❌ All ${geminiKeys.length} Gemini fallback key(s) failed.');
      throw lastGeminiError ??
          Exception('All Gemini API keys failed to rate the image.');
    }

    throw Exception(
      'All Groq API keys failed and no valid Gemini API keys are configured.',
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
      if (response.statusCode == 429) {
        // Cooldown for 60 seconds on rate limit
        markKeyCooldown(apiKey, const Duration(seconds: 60));
        debugPrint('⏳ Marked Groq key on cooldown for 60s due to 429 rate limit.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Cooldown for 1 hour on invalid/unauthorized key
        markKeyCooldown(apiKey, const Duration(hours: 1));
        debugPrint('⏳ Marked Groq key on cooldown for 1h due to auth error (${response.statusCode}).');
      }
      throw Exception('Groq API returned error status ${response.statusCode}: ${response.body}');
    }

    // Success! Clear any cooldown for this key
    _keyCooldowns.remove(apiKey);

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
    String apiKey,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
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

    try {
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

      // Success! Clear any cooldown for this Gemini key
      _keyCooldowns.remove(apiKey);

      final jsonResponse = jsonDecode(text) as Map<String, dynamic>;
      return AIRatingResult.fromJson(jsonResponse);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('429') ||
          errStr.contains('quota') ||
          errStr.contains('resourceexhausted')) {
        markKeyCooldown(apiKey, const Duration(seconds: 60));
        debugPrint('⏳ Marked Gemini key on cooldown for 60s due to rate limit.');
      }
      rethrow;
    }
  }
}
