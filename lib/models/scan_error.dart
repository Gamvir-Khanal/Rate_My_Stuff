import 'package:flutter/material.dart';

class ScanError {
  final String title;
  final String message;
  final IconData icon;

  const ScanError({
    required this.title,
    required this.message,
    required this.icon,
  });

  factory ScanError.fromException(dynamic e) {
    final err = e.toString().toLowerCase();

    if (err.contains('socket') ||
        err.contains('failed host lookup') ||
        err.contains('network') ||
        err.contains('connection refused') ||
        err.contains('clientexception') ||
        err.contains('offline')) {
      return const ScanError(
        title: 'No Internet Connection',
        message: 'Please check your connection and try scanning again.',
        icon: Icons.wifi_off_rounded,
      );
    }

    if (err.contains('429') ||
        err.contains('rate limit') ||
        err.contains('quota') ||
        err.contains('resourceexhausted')) {
      return const ScanError(
        title: 'API Limit Reached',
        message: 'The AI service rate limit was exceeded. Please wait a moment.',
        icon: Icons.hourglass_top_rounded,
      );
    }

    if (err.contains('key') ||
        err.contains('401') ||
        err.contains('unauthorized')) {
      return const ScanError(
        title: 'API Key Issue',
        message: 'Your API key is missing or invalid in your .env configuration.',
        icon: Icons.vpn_key_off_rounded,
      );
    }

    if (err.contains('timeout') ||
        err.contains('timed out') ||
        err.contains('503') ||
        err.contains('unavailable') ||
        err.contains('high demand')) {
      return const ScanError(
        title: 'Server Busy / Timeout',
        message: 'The AI model took too long to respond or is under high load.',
        icon: Icons.timer_off_rounded,
      );
    }

    String rawMsg = e.toString();
    if (rawMsg.startsWith('Exception: ')) {
      rawMsg = rawMsg.substring(11);
    }

    return ScanError(
      title: 'Rating Failed',
      message: rawMsg.isNotEmpty ? rawMsg : 'An unexpected error occurred during AI scanning.',
      icon: Icons.error_outline_rounded,
    );
  }
}
