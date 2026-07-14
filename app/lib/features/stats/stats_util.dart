import '../history/session_models.dart';

/// Distinct calendar days (local, midnight) on which the user trained.
Set<DateTime> trainedDays(List<WorkoutSessionSummary> sessions) {
  return sessions.map((s) {
    final d = s.when;
    return DateTime(d.year, d.month, d.day);
  }).toSet();
}

DateTime _startOfWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - 1)); // Monday
}

/// Distinct trained days in the current (Mon–Sun) week.
int weekCount(Set<DateTime> days, DateTime now) {
  final start = _startOfWeek(now);
  final end = start.add(const Duration(days: 7));
  return days.where((d) => !d.isBefore(start) && d.isBefore(end)).length;
}

int monthCount(Set<DateTime> days, int year, int month) =>
    days.where((d) => d.year == year && d.month == month).length;

/// Total sets per calendar day (local midnight) — the intensity source for the heatmap.
Map<DateTime, int> daySetLoads(List<WorkoutSessionSummary> sessions) {
  final m = <DateTime, int>{};
  for (final s in sessions) {
    final d = DateTime(s.when.year, s.when.month, s.when.day);
    m[d] = (m[d] ?? 0) + s.totalSets;
  }
  return m;
}

/// Heatmap intensity level 0–4 from a day's total sets (0 = rest day).
int heatLevel(int sets) {
  if (sets <= 0) return 0;
  if (sets <= 5) return 1;
  if (sets <= 12) return 2;
  if (sets <= 20) return 3;
  return 4;
}

/// Distinct trained days within a calendar year.
int yearCount(Set<DateTime> days, int year) => days.where((d) => d.year == year).length;

/// Consecutive trained days ending today (or yesterday if today not done yet).
int streak(Set<DateTime> days, DateTime now) {
  var d = DateTime(now.year, now.month, now.day);
  if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(d)) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

/// Longest run of consecutive trained days ever.
int longestStreak(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var best = 1, cur = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
      cur++;
    } else {
      cur = 1;
    }
    if (cur > best) best = cur;
  }
  return best;
}
