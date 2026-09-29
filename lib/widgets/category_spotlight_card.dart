import 'package:flutter/material.dart';

import '../models/rating_category.dart';

/// A dynamic card that changes content based on the currently selected
/// rating category. Shows a themed emoji, a fun tagline, and a contextual tip
/// to add personality and guide users toward better scans.
class CategorySpotlightCard extends StatelessWidget {
  final RatingCategory category;

  const CategorySpotlightCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final spotlight = _getSpotlight(category.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 460,
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            // Category emoji — large and prominent
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: spotlight.gradientColors,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: spotlight.gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 54),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Category label
            Text(
              category.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            // Fun tagline
            Text(
              spotlight.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 32),
            // Pro tip container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tips_and_updates_rounded,
                      color: Colors.amberAccent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pro Tip',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amberAccent.withValues(alpha: 0.9),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          spotlight.tip,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightData {
  final String tagline;
  final String tip;
  final List<Color> gradientColors;

  const _SpotlightData({
    required this.tagline,
    required this.tip,
    required this.gradientColors,
  });
}

_SpotlightData _getSpotlight(String categoryId) {
  return switch (categoryId) {
    'random' => const _SpotlightData(
      tagline: 'Literally anything goes. Surprise us! 🎲',
      tip: 'The weirder the item, the funnier the AI remark tends to be.',
      gradientColors: [Color(0xFFFF6FD8), Color(0xFF9B5CFF)],
    ),
    'food_drinks' => const _SpotlightData(
      tagline: 'Show off your plate — we\'ll judge every bite! 🍽️',
      tip: 'Good lighting makes your food look 10x better. Natural light works best!',
      gradientColors: [Color(0xFFFF8A65), Color(0xFFFF5252)],
    ),
    'outfit' => const _SpotlightData(
      tagline: 'Drip check incoming! Let\'s see that fit 👔',
      tip: 'Full-body mirror shots get the most detailed outfit feedback.',
      gradientColors: [Color(0xFFAB47BC), Color(0xFFE040FB)],
    ),
    'room' => const _SpotlightData(
      tagline: 'Show us your vibe — cozy, chaotic, or aesthetic? 🏠',
      tip: 'Clean up a bit first... or don\'t. The AI notices everything 👀',
      gradientColors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
    ),
    'pets' => const _SpotlightData(
      tagline: 'Let\'s see your furry (or scaly) bestie! 🐾',
      tip: 'Close-up shots of their face get the cutest remarks!',
      gradientColors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
    ),
    'looks' => const _SpotlightData(
      tagline: 'Mirror mirror on the wall... who\'s getting rated? 😎',
      tip: 'Good lighting + a clean background = the best selfie ratings.',
      gradientColors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
    ),
    'gaming_setup' => const _SpotlightData(
      tagline: 'RGB everything? Let\'s see your battle station! ⚔️',
      tip: 'Turn on those RGB lights and snap in the dark for maximum effect.',
      gradientColors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
    ),
    'tech_gadgets' => const _SpotlightData(
      tagline: 'Unbox, flex, and get rated. Tech nerds unite! 💻',
      tip: 'Show it from multiple angles — the AI loves detail shots.',
      gradientColors: [Color(0xFF26C6DA), Color(0xFF0097A7)],
    ),
    'cars_bikes' => const _SpotlightData(
      tagline: 'Vroom vroom! Let\'s rate your ride 🏎️',
      tip: 'Shoot from a low angle to make your vehicle look way more epic.',
      gradientColors: [Color(0xFFFF7043), Color(0xFFD84315)],
    ),
    'art_creativity' => const _SpotlightData(
      tagline: 'Picasso or preschooler? Only one way to find out! 🎨',
      tip: 'Make sure the whole artwork is visible — crop ruins the vibe.',
      gradientColors: [Color(0xFFFFCA28), Color(0xFFFF8F00)],
    ),
    'memes' => const _SpotlightData(
      tagline: 'Is it S-tier or cringe? Let the AI decide 😂',
      tip: 'The text in your meme matters — make sure it\'s readable!',
      gradientColors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
    ),
    'study_setup' => const _SpotlightData(
      tagline: 'Productivity heaven or procrastination station? 📚',
      tip: 'Include your whole desk setup — stationery, books, laptop, the works!',
      gradientColors: [Color(0xFF5C6BC0), Color(0xFF283593)],
    ),
    'fitness' => const _SpotlightData(
      tagline: 'Flex time! Show us what you\'ve been working on 💪',
      tip: 'Good gym lighting + pump = best fitness photos. You know the drill.',
      gradientColors: [Color(0xFFE53935), Color(0xFFB71C1C)],
    ),
    'scenario' => const _SpotlightData(
      tagline: 'Set the scene — dramatic, funny, or just plain weird 🎭',
      tip: 'The more context in the photo, the wittier the AI remark!',
      gradientColors: [Color(0xFF8D6E63), Color(0xFF4E342E)],
    ),
    'gifts' => const _SpotlightData(
      tagline: 'Thoughtful present or regift material? Let\'s find out 🎁',
      tip: 'Unwrap it first — the AI rates what it sees, not the wrapping paper!',
      gradientColors: [Color(0xFFEC407A), Color(0xFFC2185B)],
    ),
    'social_profile' => const _SpotlightData(
      tagline: 'Would this get likes? Let AI be the judge 📱',
      tip: 'Screenshot your post draft and scan it for honest feedback.',
      gradientColors: [Color(0xFF29B6F6), Color(0xFF0277BD)],
    ),
    _ => const _SpotlightData(
      tagline: 'Ready to get rated? Let\'s see what you\'ve got!',
      tip: 'Clear, well-lit photos always score higher ratings.',
      gradientColors: [Color(0xFFFF6FD8), Color(0xFF6A3DFF)],
    ),
  };
}
