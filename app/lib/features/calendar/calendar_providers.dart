import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'calendar_models.dart';

/// Trained days for a given month ("yyyy-MM"). Family-keyed so each month is
/// fetched and cached independently; invalidated when a session is added/removed.
final calendarProvider = FutureProvider.autoDispose.family<List<CalendarDay>, String>((ref, month) async {
  final data = await ApiClient.get('/api/sessions/calendar?month=$month') as List<dynamic>;
  return data.map((e) => CalendarDay.fromJson(e as Map<String, dynamic>)).toList();
});

/// Rolling "next up" day in the active plan; null when there's no active plan/days.
final nextUpProvider = FutureProvider.autoDispose<NextUp?>((ref) async {
  final data = await ApiClient.get('/api/plans/next');
  if (data == null) return null;
  return NextUp.fromJson(data as Map<String, dynamic>);
});

/// Body-part → colour for the calendar dots + legend. Falls back to grey.
Color bodyPartColor(String bp) {
  switch (bp) {
    case '胸':
      return const Color(0xFF3B82F6); // blue
    case '背':
      return const Color(0xFF22C55E); // green
    case '腿':
      return const Color(0xFFF97316); // orange
    case '肩':
      return const Color(0xFFA855F7); // purple
    case '手臂':
    case '手':
      return const Color(0xFFEF4444); // red
    case '核心':
    case '腹':
      return const Color(0xFF14B8A6); // teal
    case '有氧':
      return const Color(0xFFEC4899); // pink
    default:
      return const Color(0xFF9CA3AF); // grey
  }
}

/// The body parts shown in the legend (fixed order).
const kLegendParts = ['胸', '背', '腿', '肩', '手臂', '核心'];
