import 'package:flutter/material.dart';

class GoalIconItem {
  final String key;
  final String label;
  final IconData icon;

  const GoalIconItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<GoalIconItem> kGoalIcons = [
  GoalIconItem(key: 'flag', label: 'Umum', icon: Icons.flag_rounded),
  GoalIconItem(key: 'savings', label: 'Tabungan', icon: Icons.savings_rounded),
  GoalIconItem(key: 'laptop', label: 'Laptop / Gadget', icon: Icons.laptop_mac_rounded),
  GoalIconItem(key: 'phone', label: 'Handphone', icon: Icons.phone_iphone_rounded),
  GoalIconItem(key: 'car', label: 'Kendaraan', icon: Icons.directions_car_rounded),
  GoalIconItem(key: 'home', label: 'Rumah', icon: Icons.home_rounded),
  GoalIconItem(key: 'flight', label: 'Liburan', icon: Icons.flight_takeoff_rounded),
  GoalIconItem(key: 'emergency', label: 'Dana Darurat', icon: Icons.health_and_safety_rounded),
  GoalIconItem(key: 'school', label: 'Pendidikan', icon: Icons.school_rounded),
  GoalIconItem(key: 'gift', label: 'Hadiah / Impian', icon: Icons.card_giftcard_rounded),
  GoalIconItem(key: 'wedding', label: 'Pernikahan', icon: Icons.favorite_rounded),
  GoalIconItem(key: 'shopping', label: 'Belanja', icon: Icons.shopping_bag_rounded),
  GoalIconItem(key: 'investment', label: 'Investasi', icon: Icons.trending_up_rounded),
  GoalIconItem(key: 'camera', label: 'Kamera', icon: Icons.photo_camera_rounded),
];

IconData getGoalIcon(String key) {
  for (final item in kGoalIcons) {
    if (item.key == key) return item.icon;
  }
  return Icons.flag_rounded;
}

const List<int> kGoalColors = [
  0xFF00897B, // Teal
  0xFF1E88E5, // Blue
  0xFF43A047, // Green
  0xFFFB8C00, // Orange
  0xFF8E24AA, // Purple
  0xFFE53935, // Red
  0xFF00ACC1, // Cyan
  0xFF3949AB, // Indigo
  0xFFD81B60, // Pink
  0xFF546E7A, // Blue Grey
];

