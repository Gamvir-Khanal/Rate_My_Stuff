import 'dart:io';

import 'package:flutter/material.dart';

import '../models/rating_category.dart';
import '../models/rating_history_item.dart';
import '../services/database_helper.dart';
import '../widgets/encrypted_image_widget.dart';
import 'result_screen.dart';

enum HistorySortOption {
  newestFirst('Newest First', Icons.arrow_downward_rounded),
  oldestFirst('Oldest First', Icons.arrow_upward_rounded),
  highestScore('Highest Score', Icons.star_rounded),
  lowestScore('Lowest Score', Icons.star_border_rounded);

  final String label;
  final IconData icon;
  const HistorySortOption(this.label, this.icon);
}

class HistoryScreen extends StatefulWidget {
  /// Optional pre-fetched data from the caller to avoid the initial spinner.
  final List<RatingHistoryItem>? initialData;

  const HistoryScreen({super.key, this.initialData});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<RatingHistoryItem>> _historyFuture;
  List<RatingHistoryItem>? _resolvedData;
  String? _selectedCategoryFilter;
  HistorySortOption _sortOption = HistorySortOption.newestFirst;

  @override
  void initState() {
    super.initState();
    _loadHistory(prefetched: widget.initialData);
  }

  void _loadHistory({List<RatingHistoryItem>? prefetched}) {
    if (prefetched != null) {
      // Use pre-fetched data immediately — no spinner needed
      _resolvedData = prefetched;
      _historyFuture = Future.value(prefetched);
    } else {
      setState(() {
        _resolvedData = null;
        _historyFuture = DatabaseHelper.instance.getRatings();
      });
    }
  }

  Future<void> _deleteItem(RatingHistoryItem item) async {
    if (item.id == null) return;
    await DatabaseHelper.instance.deleteRating(item.id!);
    // After delete, always reload fresh from DB
    final fresh = await DatabaseHelper.instance.getRatings();
    if (mounted) {
      setState(() {
        _resolvedData = fresh;
        _historyFuture = Future.value(fresh);
      });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rating card deleted from history.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(RatingHistoryItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                'Delete Rating?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF2D1B4E),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this ${item.category.label} card (${item.rating.toStringAsFixed(1)}/10) from your history?',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteItem(item);
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
              // Header navigation bar
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'RATING HISTORY',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Swipe left or long press to delete',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<HistorySortOption>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sort_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      tooltip: 'Sort Ratings',
                      color: const Color(0xFF1E1035),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      initialValue: _sortOption,
                      onSelected: (option) {
                        setState(() => _sortOption = option);
                      },
                      itemBuilder: (context) => HistorySortOption.values.map((option) {
                        final isSelected = option == _sortOption;
                        return PopupMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              Icon(
                                option.icon,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFFFF6FD8)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Category Filter Chips + History list — driven by a single
              // FutureBuilder so chips only show categories that have data.
              Expanded(
                child: FutureBuilder<List<RatingHistoryItem>>(
                  future: _historyFuture,
                  initialData: _resolvedData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load history: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final allItems = snapshot.data ?? [];

                    // Build the set of category IDs that actually have items.
                    final presentCategoryIds =
                        allItems.map((i) => i.categoryId).toSet();

                    // If the active filter no longer has any items (e.g. after
                    // a delete), silently reset it to "All".
                    if (_selectedCategoryFilter != null &&
                        !presentCategoryIds.contains(_selectedCategoryFilter)) {
                      // Schedule outside the build frame.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _selectedCategoryFilter = null);
                        }
                      });
                    }

                    // --- Filter chips (only categories with data) ---
                    final chips = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            children: [
                              _buildFilterChip(
                                label: 'All',
                                emoji: '✨',
                                isSelected: _selectedCategoryFilter == null,
                                onTap: () => setState(
                                    () => _selectedCategoryFilter = null),
                              ),
                              // Only show a chip if that category has at least
                              // one saved rating.
                              ...ratingCategories
                                  .where((cat) =>
                                      presentCategoryIds.contains(cat.id))
                                  .map((cat) {
                                return _buildFilterChip(
                                  label: cat.label,
                                  emoji: cat.emoji,
                                  isSelected:
                                      _selectedCategoryFilter == cat.id,
                                  onTap: () => setState(
                                      () => _selectedCategoryFilter = cat.id),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    );

                    // --- Empty history (no items at all) ---
                    if (allItems.isEmpty) {
                      return Column(
                        children: [
                          chips,
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 72,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No saved ratings yet!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Take a photo on the home screen to get rated.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (allItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No saved ratings yet!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take a photo on the home screen to get rated.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 1. Filter items by selected category
                    var items = List<RatingHistoryItem>.from(allItems);
                    if (_selectedCategoryFilter != null) {
                      items = items
                          .where((i) => i.categoryId == _selectedCategoryFilter)
                          .toList();
                    }

                    // 2. Sort items according to selected sort option
                    switch (_sortOption) {
                      case HistorySortOption.newestFirst:
                        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                        break;
                      case HistorySortOption.oldestFirst:
                        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                        break;
                      case HistorySortOption.highestScore:
                        items.sort((a, b) => b.rating.compareTo(a.rating));
                        break;
                      case HistorySortOption.lowestScore:
                        items.sort((a, b) => a.rating.compareTo(b.rating));
                        break;
                    }

                    if (items.isEmpty) {
                      final category = ratingCategories.firstWhere(
                        (c) => c.id == _selectedCategoryFilter,
                        orElse: () => defaultRatingCategory,
                      );
                      return Column(
                        children: [
                          chips,
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    category.emoji,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No ${category.label} ratings found!',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: () => setState(
                                        () => _selectedCategoryFilter = null),
                                    icon: const Icon(
                                      Icons.clear_all_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'View All Categories',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Normal list — chips always visible above the list.
                    return Column(
                      children: [
                        chips,
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            cacheExtent: 600,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final file = File(item.imagePath);

                        return Dismissible(
                          key: Key('history_item_${item.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Row(
                                    children: const [
                                      Icon(
                                        Icons.delete_forever_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete Rating?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: Color(0xFF2D1B4E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete this ${item.category.label} card (${item.rating.toStringAsFixed(1)}/10) from your history?',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(false),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                            return confirm == true;
                          },
                          onDismissed: (_) => _deleteItem(item),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResultScreen(
                                      imageFile: file,
                                      rating: item.rating,
                                      remark: item.remark,
                                      category: item.category,
                                      isFromHistory: true,
                                    ),
                                  ),
                                ).then((_) async {
                                  // Reload from DB after returning from detail view
                                  final fresh =
                                      await DatabaseHelper.instance
                                          .getRatings();
                                  if (mounted) {
                                    setState(() {
                                      _resolvedData = fresh;
                                      _historyFuture = Future.value(fresh);
                                    });
                                  }
                                });
                              },
                              onLongPress: () => _showDeleteConfirmation(item),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Thumbnail image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: EncryptedImageWidget(
                                        imageFile: file,
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        cacheWidth: 200,
                                        cacheHeight: 200,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                width: 76,
                                                height: 76,
                                                color: Colors.grey.shade300,
                                                child: const Icon(
                                                  Icons.broken_image_rounded,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Info column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Category Tag
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF6A3DFF,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${item.category.emoji} ${item.category.label}',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF6A3DFF),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Rating badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFFFF6FD8),
                                                          Color(0xFF6A3DFF),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${item.rating.toStringAsFixed(1)} / 10',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Remark text snippet
                                          Text(
                                            item.remark,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2D1B4E),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF6A3DFF)
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
