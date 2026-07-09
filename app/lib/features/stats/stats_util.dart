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
