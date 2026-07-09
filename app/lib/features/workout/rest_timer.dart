import 'dart:async';

import 'package:flutter/material.dart';

/// Show a rest-countdown bottom sheet for [seconds].
Future<void> showRestTimer(BuildContext context, int seconds) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => RestTimerSheet(seconds: seconds <= 0 ? 60 : seconds),
  );
}

class RestTimerSheet extends StatefulWidget {
  const RestTimerSheet({super.key, required this.seconds});

  final int seconds;

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> {
  late int _total = widget.seconds;
  late int _remaining = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        Navigator.of(context).maybePop();
      }
    });
  }

  void _add(int s) => setState(() {
        _remaining += s;
        if (_remaining > _total) _total = _remaining;
      });

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _fmt {
    final r = _remaining < 0 ? 0 : _remaining;
    return '${(r ~/ 60).toString().padLeft(2, '0')}:${(r % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final progress = _total <= 0 ? 0.0 : (_remaining.clamp(0, _total)) / _total;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('组间休息 ⏱', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: progress.toDouble(),
                        strokeWidth: 11,
                        strokeCap: StrokeCap.round,
                        color: color,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Text(_fmt, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(onPressed: () => _add(30), child: const Text('+30秒')),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('跳过')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
