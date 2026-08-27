class RatingCategory {
  final String id;
  final String label;
  final String emoji;

  const RatingCategory({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

const List<RatingCategory> ratingCategories = [
  RatingCategory(id: 'random', label: 'Random Stuff', emoji: '🎲'),
  RatingCategory(id: 'food_drinks', label: 'Food & Drinks', emoji: '🍔'),
  RatingCategory(id: 'outfit', label: 'Clothing & Outfits', emoji: '👗'),
  RatingCategory(id: 'room', label: 'Room', emoji: '🛋️'),
  RatingCategory(id: 'pets', label: 'Pets', emoji: '🐾'),
  RatingCategory(id: 'looks', label: 'Looks', emoji: '😎'),
  RatingCategory(id: 'gaming_setup', label: 'Gaming Setup', emoji: '🎮'),
  RatingCategory(id: 'tech_gadgets', label: 'Tech & Gadgets', emoji: '💻'),
  RatingCategory(id: 'cars_bikes', label: 'Cars & Bikes', emoji: '🚗'),
  RatingCategory(id: 'art_creativity', label: 'Art & Creativity', emoji: '🎨'),
  RatingCategory(id: 'memes', label: 'Memes', emoji: '😂'),
  RatingCategory(id: 'study_setup', label: 'Study Setup', emoji: '📚'),
  RatingCategory(id: 'fitness', label: 'Fitness', emoji: '💪'),
  RatingCategory(id: 'scenario', label: 'Scenario', emoji: '🎭'),
  RatingCategory(id: 'gifts', label: 'Gifts', emoji: '🎁'),
  RatingCategory(id: 'social_profile', label: 'Social Media Post', emoji: '📱'),
];

RatingCategory get defaultRatingCategory =>
    ratingCategories.firstWhere((c) => c.id == 'random');
