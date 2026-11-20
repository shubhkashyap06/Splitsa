import 'package:flutter/material.dart';

/// Room icon keys stored in `rooms.icon` → Material icons.
const kRoomIconKeys = ['house', 'trip', 'food', 'party', 'work', 'other'];

IconData roomIcon(String key) => switch (key) {
  'house' || 'home' => Icons.home_rounded,
  'trip' || 'travel' => Icons.beach_access,
  'food' => Icons.restaurant,
  'party' => Icons.celebration,
  'work' => Icons.work_outline,
  _ => Icons.groups_rounded,
};
