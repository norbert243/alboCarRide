import 'package:flutter/material.dart';

class Vehicle {
  final String name;
  final String description;
  final IconData icon;
  final int capacity;
  final double priceMultiplier;

  Vehicle({
    required this.name,
    required this.description,
    required this.icon,
    required this.capacity,
    required this.priceMultiplier,
  });
}
