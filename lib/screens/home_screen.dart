import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/dummy_rating.dart';
import '../models/rating_category.dart';
import '../models/scan_error.dart';
import '../widgets/floating_rating_card.dart';
import 'camera_capture_screen.dart';
import 'category_picker_sheet.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  late int _selectedIndex;
  late DummyRating _previewRating;
  Timer? _previewTimer;
  ScanError? _currentError;
  Timer? _errorDismissTimer;

  @override
  void initState() {
    super.initState();
    _selectedIndex = ratingCategories.indexOf(defaultRatingCategory);
    final initialPage = (1000 * ratingCategories.length) + _selectedIndex;
    _pageController = PageController(
      viewportFraction: 0.34,
      initialPage: initialPage,
    );
    _previewRating = dummyRatings[Random().nextInt(dummyRatings.length)];
    _previewTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        _previewRating = _nextRandomRating();
      });
    });
  }

  DummyRating _nextRandomRating() {
    if (dummyRatings.length <= 1) return dummyRatings.first;
    DummyRating next;
    do {
      next = dummyRatings[Random().nextInt(dummyRatings.length)];
    } while (next.imagePath == _previewRating.imagePath);
    return next;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _previewTimer?.cancel();
    _errorDismissTimer?.cancel();
    super.dispose();
  }

  RatingCategory get _selectedCategory => ratingCategories[_selectedIndex];

  Future<void> _openCategoryPicker() async {
    final result = await CategoryPickerSheet.show(
      context,
      _selectedCategory.id,
    );
    if (result == null) return;

    final newIndex = ratingCategories.indexWhere((c) => c.id == result);
    if (newIndex == -1) return;

    final currentPage =
        _pageController.hasClients && _pageController.page != null
        ? _pageController.page!.round()
        : (1000 * ratingCategories.length) + _selectedIndex;
    final currentRealIndex = currentPage % ratingCategories.length;
    final difference = newIndex - currentRealIndex;
    final targetPage = currentPage + difference;

    setState(() => _selectedIndex = newIndex);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onGetRated() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(category: _selectedCategory),
      ),
    );

    if (result is ScanError && mounted) {
      _showError(result);
    }
  }

  void _showError(ScanError error) {
    _errorDismissTimer?.cancel();
    setState(() {
      _currentError = error;
    });

    _errorDismissTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() {
          _currentError = null;
        });
      }
    });
  }

  void _openHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  Widget _buildErrorCard(ScanError error) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1035).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              error.icon,
              color: const Color(0xFFFF5252),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  error.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () {
              _errorDismissTimer?.cancel();
              setState(() => _currentError = null);
            },
          ),
        ],
      ),
    );
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
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'Rate my...',
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 50,
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        double currentPage = _selectedIndex.toDouble();
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          currentPage = _pageController.page ?? currentPage;
                        }

                        return PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            final realIndex = index % ratingCategories.length;
                            setState(() => _selectedIndex = realIndex);
                          },
                          itemBuilder: (context, index) {
                            final realIndex = index % ratingCategories.length;
                            final category = ratingCategories[realIndex];
                            final distance = (currentPage - index).abs();
                            final scale = (1 - (distance * 0.22)).clamp(0.78, 1.0);
                            final opacity = (1 - (distance * 0.45)).clamp(
                              0.35,
                              1.0,
                            );
                            final isSelected = realIndex == _selectedIndex;

                            return Center(
                              child: Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  child: GestureDetector(
                                    onTap: _openCategoryPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: isSelected ? 0 : 0.5,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            category.emoji,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              category.label,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? const Color(0xFF6A3DFF)
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Tap above to see all categories.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.92,
                                end: 1.0,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: FloatingRatingCard(
                          key: ValueKey(_previewRating.imagePath),
                          data: _previewRating,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            iconSize: 26,
                            padding: const EdgeInsets.all(14),
                            icon: const Icon(
                              Icons.history_rounded,
                              color: Color(0xFF6A3DFF),
                            ),
                            onPressed: _openHistoryScreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Get Rated button squeezed to the right
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _onGetRated,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF6A3DFF),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 6,
                            ),
                            child: const Text(
                              'Get Rated !',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Floating error card overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _currentError != null
                      ? KeyedSubtree(
                          key: ValueKey(_currentError!.title),
                          child: _buildErrorCard(_currentError!),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
