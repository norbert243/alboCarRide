import 'package:flutter/material.dart';

class PlaceIconHelper {
  // Map icon names to Material icons
  static final Map<String, IconData> iconMap = {
    'home': Icons.home,
    'work': Icons.work,
    'church': Icons.church,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'local_hospital': Icons.local_hospital,
    'restaurant': Icons.restaurant,
    'store': Icons.store,
    'sports_soccer': Icons.sports_soccer,
    'theater_comedy': Icons.theater_comedy,
    'flight': Icons.flight,
    'beach_access': Icons.beach_access,
    'school_outlined': Icons.school_outlined,
    'fitness_center': Icons.fitness_center,
    'shopping_cart': Icons.shopping_cart,
    'place': Icons.place,
  };

  // Get icon from name
  static IconData getIcon(String iconName) {
    return iconMap[iconName] ?? Icons.place;
  }

  // Get all available icons
  static List<MapEntry<String, IconData>> getAllIcons() {
    return iconMap.entries.toList();
  }
}
