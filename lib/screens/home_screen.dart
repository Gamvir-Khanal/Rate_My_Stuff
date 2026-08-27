import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/dummy_rating.dart';
import '../models/rating_category.dart';
import '../widgets/floating_rating_card.dart';
import 'category_picker_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedIndex = ratingCategories.indexOf(defaultRatingCategory);
    _pageController = PageController(
      viewportFraction: 0.34,
      initialPage: _selectedIndex,
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

    setState(() => _selectedIndex = newIndex);
    _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _onGetRated() {
    debugPrint('Get Rated tapped for category: ${_selectedCategory.id}');
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
              const SizedBox(height: 32),
              const Text(
                'Rate my...',
                style: TextStyle(
                  fontSize: 45,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '${_selectedCategory.emoji}  ${_selectedCategory.label}',
                  key: ValueKey(_selectedCategory.id),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap below to see all options.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 60,
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
                      itemCount: ratingCategories.length,
                      onPageChanged: (index) {
                        setState(() => _selectedIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final category = ratingCategories[index];
                        final distance = (currentPage - index).abs();
                        final scale = (1 - (distance * 0.22)).clamp(0.78, 1.0);
                        final opacity = (1 - (distance * 0.45)).clamp(
                          0.35,
                          1.0,
                        );
                        final isSelected = index == _selectedIndex;

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
                                        : Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(
                                        isSelected ? 0 : 0.5,
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
                  horizontal: 32,
                  vertical: 28,
                ),
                child: SizedBox(
                  width: double.infinity,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
