import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Target weight (kg), persisted locally. null = 未设定.
class GoalWeightNotifier extends Notifier<double?> {
  static const _key = 'goal_weight';

  @override
  double? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getDouble(_key);
    if (v != null) state = v;
  }

  Future<void> set(double? v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    if (v == null) {
      await p.remove(_key);
    } else {
      await p.setDouble(_key, v);
    }
  }
}

final goalWeightProvider = NotifierProvider<GoalWeightNotifier, double?>(GoalWeightNotifier.new);
