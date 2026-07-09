import 'package:flutter/material.dart';

/// Visual identity for each body part: an emoji + accent color, so the UI reads
/// at a glance and feels lively instead of a wall of text.
class BodyPartStyle {
  const BodyPartStyle(this.emoji, this.color);
  final String emoji;
  final Color color;
}

BodyPartStyle bodyPartStyle(String bodyPart) {
  switch (bodyPart) {
    case '胸':
      return const BodyPartStyle('💪', Color(0xFF6366F1));
    case '背':
      return const BodyPartStyle('🦾', Color(0xFF14B8A6));
    case '腿':
      return const BodyPartStyle('🦵', Color(0xFFF97316));
    case '肩':
      return const BodyPartStyle('🤸', Color(0xFFA855F7));
    case '核心':
      return const BodyPartStyle('🔥', Color(0xFFEF4444));
    case '手臂':
      return const BodyPartStyle('💪', Color(0xFF3B82F6));
    case '有氧':
      return const BodyPartStyle('🏃', Color(0xFF22C55E));
    case '全身':
      return const BodyPartStyle('⚡', Color(0xFFF59E0B));
    default:
      return const BodyPartStyle('🏋️', Color(0xFF6366F1));
  }
}

/// A row of flame emojis representing difficulty (1–5).
String difficultyFlames(int? level) {
  final n = (level ?? 0).clamp(0, 5);
  return '🔥' * n;
}

/// Selectable options for the exercise form.
const List<String> kBodyParts = ['胸', '背', '腿', '肩', '核心', '手臂', '有氧', '全身'];
const List<String> kEquipments = ['杠铃', '哑铃', '器械', '自重', '绳索', '壶铃', '弹力带'];
