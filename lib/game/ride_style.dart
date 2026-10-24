import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/obstacle.dart';
import '../models/pickup.dart';

/// 游戏内固定配色：黄昏海边的暖色调，与界面主题相互独立。
class RideColors {
  RideColors._();

  static const skyTop = Color(0xFF2E5E8C);
  static const skyMid = Color(0xFFFFA45B);
  static const skyLow = Color(0xFFFFD9A0);
  static const sun = Color(0xFFFFF0C2);
  static const sea = Color(0xFF2C7A86);
  static const seaDeep = Color(0xFF1D5C68);
  static const hillFar = Color(0xFF7C8C8A);
  static const hillNear = Color(0xFF586E6C);
  static const road = Color(0xFF3B3B3B);
  static const roadLine = Color(0xFFF2E4C9);
  static const tyre = Color(0xFF263238);
  static const frame = Color(0xFFEF6C4D);
  static const frameDark = Color(0xFFC94F35);
  static const pelican = Color(0xFFFFF8EC);
  static const pelicanShade = Color(0xFFE6D8C4);
  static const beak = Color(0xFFFFA940);
  static const pouch = Color(0xFFFFC46B);
  static const leg = Color(0xFFFF9F43);
  static const scarf = Color(0xFF2BA7A0);
  static const eye = Color(0xFF1B2527);
  static const fish = Color(0xFF4FC3F7);
  static const fishDark = Color(0xFF1E88B8);
  static const shield = Color(0xFF4DD0E1);
  static const magnet = Color(0xFF8093FF);
  static const crate = Color(0xFFB07A4A);
  static const crateDark = Color(0xFF8A5A33);
  static const rock = Color(0xFF8C8C8C);
  static const rockDark = Color(0xFF6A6A6A);
  static const log = Color(0xFF8E6239);
  static const banner = Color(0xFFEF6C4D);
  static const bannerPole = Color(0xFF5D4037);
}

Color pickupColor(PickupKind kind) {
  switch (kind) {
    case PickupKind.fish:
      return RideColors.fish;
    case PickupKind.shield:
      return RideColors.shield;
    case PickupKind.magnet:
      return RideColors.magnet;
  }
}

IconData pickupIcon(PickupKind kind) {
  switch (kind) {
    case PickupKind.fish:
      return Icons.set_meal;
    case PickupKind.shield:
      return Icons.shield_outlined;
    case PickupKind.magnet:
      return Icons.attractions;
  }
}

IconData difficultyIcon(Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.easy:
      return Icons.spa_outlined;
    case Difficulty.normal:
      return Icons.pedal_bike;
    case Difficulty.hard:
      return Icons.local_fire_department_outlined;
  }
}

Color obstacleColor(ObstacleKind kind) {
  switch (kind) {
    case ObstacleKind.rock:
      return RideColors.rock;
    case ObstacleKind.crate:
      return RideColors.crate;
    case ObstacleKind.log:
      return RideColors.log;
    case ObstacleKind.banner:
      return RideColors.banner;
  }
}
