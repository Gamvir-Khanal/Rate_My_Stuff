import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// A 3-step animated walkthrough shown to first-time users (0 scans).
/// Auto-advances every 4 seconds with smooth transitions.
class HowItWorksCard extends StatefulWidget {
  const HowItWorksCard({super.key});

  @override
  State<HowItWorksCard> createState() => _HowItWorksCardState();
}

class _HowItWorksCardState extends State<HowItWorksCard>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _iconBounceController;
  Timer? _autoAdvanceTimer;
  int _currentStep = 0;

  static const _steps = [
    _StepData(
      icon: Icons.category_rounded,
      title: 'Pick a Category From Above',
      subtitle: 'Choose what you want rated — food, pets, outfits, and more!',
      gradient: [Color(0xFFFF6FD8), Color(0xFFFF8FA0)],
    ),
    _StepData(
      icon: Icons.camera_alt_rounded,
      title: 'Snap or Upload a Photo',
      subtitle: 'Capture it with your camera or pick from your gallery.',
      gradient: [Color(0xFFAB7CFF), Color(0xFF9B5CFF)],
    ),
    _StepData(
      icon: Icons.auto_awesome_rounded,
      title: 'Get AI Rating and Remarks',
      subtitle: 'Our AI gives you a score out of 10 and a witty remark!',
      gradient: [Color(0xFF6A3DFF), Color(0xFF5B2EFF)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _iconBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final nextStep = (_currentStep + 1) % _steps.length;
      _pageController.animateToPage(
        nextStep,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    _iconBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 460,
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(height: 18),
          // "How It Works" label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.amberAccent,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Step content with PageView
          SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentStep = index);
                _iconBounceController.forward(from: 0);
                // Restart auto-advance timer on manual swipe
                _startAutoAdvance();
              },
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return _StepContent(
                  step: step,
                  stepNumber: index + 1,
                  bounceAnimation: _iconBounceController,
                );
              },
            ),
          ),
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (index) {
              final isActive = index == _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _StepData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}

class _StepContent extends StatelessWidget {
  final _StepData step;
  final int stepNumber;
  final AnimationController bounceAnimation;

  const _StepContent({
    required this.step,
    required this.stepNumber,
    required this.bounceAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon circle
          AnimatedBuilder(
            animation: bounceAnimation,
            builder: (context, child) {
              final bounce = sin(bounceAnimation.value * pi) * 6;
              return Transform.translate(
                offset: Offset(0, -bounce),
                child: child,
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: step.gradient),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: step.gradient.first.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(step.icon, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          // Step number + title
          Text(
            'Step $stepNumber',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
