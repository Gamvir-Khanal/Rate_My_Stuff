import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RateLimitService {
  static final RateLimitService instance = RateLimitService._init();
  RateLimitService._init();

  final _secureStorage = const FlutterSecureStorage();
  
  /// Maximum number of AI rating API calls allowed per calendar day.
  static const int maxDailyScans = 50;

  static const String _countKey = 'rate_limit_scan_count';
  static const String _dateKey = 'rate_limit_last_date';

  int? _cachedCount;
  String? _cachedDate;

  /// Real-time notifier for the remaining scans today
  final ValueNotifier<int> remainingScansNotifier =
      ValueNotifier<int>(maxDailyScans);

  /// Format current date as YYYY-MM-DD
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Refreshes and notifies listeners of current quota
  Future<int> syncRemaining() async {
    final remaining = await getRemainingScansToday();
    remainingScansNotifier.value = remaining;
    return remaining;
  }

  /// Gets the number of scans used today. Resets count if it's a new day.
  Future<int> getUsedScansToday() async {
    final today = _todayDateString();
    if (_cachedDate == today && _cachedCount != null) {
      return _cachedCount!;
    }

    final storedDate = await _secureStorage.read(key: _dateKey);

    if (storedDate != today) {
      // New day: reset counter to 0
      await _secureStorage.write(key: _dateKey, value: today);
      await _secureStorage.write(key: _countKey, value: '0');
      _cachedDate = today;
      _cachedCount = 0;
      remainingScansNotifier.value = maxDailyScans;
      return 0;
    }

    final countStr = await _secureStorage.read(key: _countKey);
    final count = int.tryParse(countStr ?? '0') ?? 0;
    _cachedDate = today;
    _cachedCount = count;
    final remaining = maxDailyScans - count;
    remainingScansNotifier.value = remaining < 0 ? 0 : remaining;
    return count;
  }

  /// Returns remaining scans available for today.
  Future<int> getRemainingScansToday() async {
    final used = await getUsedScansToday();
    final remaining = maxDailyScans - used;
    return remaining < 0 ? 0 : remaining;
  }

  /// Checks if the user has available scans today.
  Future<bool> canPerformScan() async {
    final used = await getUsedScansToday();
    return used < maxDailyScans;
  }

  /// Records a successful API scan call.
  Future<void> recordScan() async {
    final used = await getUsedScansToday();
    final newCount = used + 1;
    _cachedCount = newCount;
    final remaining = maxDailyScans - newCount;
    remainingScansNotifier.value = remaining < 0 ? 0 : remaining;
    await _secureStorage.write(key: _countKey, value: newCount.toString());
    debugPrint('📊 Recorded API scan. Total used today: $newCount / $maxDailyScans');
  }

  /// Shows an aesthetic limit reached dialog if the quota is exhausted.
  /// Returns `true` if scan is allowed, `false` if limit reached.
  Future<bool> checkAndEnforceLimit(BuildContext context) async {
    final used = await getUsedScansToday();
    if (used < maxDailyScans) return true;

    if (!context.mounted) return false;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            title: Row(
              children: const [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  color: Color(0xFF6A3DFF),
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Daily Limit Reached',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF2D1B4E),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have used all $used of your $maxDailyScans free AI ratings for today!',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D1B4E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A3DFF).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFF6A3DFF),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your limit will automatically reset tomorrow at midnight.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6A3DFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A3DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      );

    return false;
  }
}
