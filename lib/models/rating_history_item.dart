import 'rating_category.dart';

class RatingHistoryItem {
  final int? id;
  final String imagePath;
  final double rating;
  final String remark;
  final String categoryId;
  final int createdAt;

  RatingHistoryItem({
    this.id,
    required this.imagePath,
    required this.rating,
    required this.remark,
    required this.categoryId,
    required this.createdAt,
  });

  // Convert a model item into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'image_path': imagePath,
      'rating': rating,
      'remark': remark,
      'category_id': categoryId,
      'created_at': createdAt,
    };
  }

  // Extract a model item from an SQLite row Map
  factory RatingHistoryItem.fromMap(Map<String, dynamic> map) {
    return RatingHistoryItem(
      id: map['id'] as int?,
      imagePath: map['image_path'] as String,
      rating: (map['rating'] as num).toDouble(),
      remark: map['remark'] as String,
      categoryId: map['category_id'] as String,
      createdAt: map['created_at'] as int,
    );
  }

  // Get the matching RatingCategory object from the global category list
  RatingCategory get category {
    return ratingCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => defaultRatingCategory,
    );
  }
}
