import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// All-time sets per body part (胸/背/腿/肩/手臂/核心/…).
final muscleMapProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final data = await ApiClient.get('/api/sessions/muscle-map') as List<dynamic>;
  final m = <String, int>{};
  for (final e in data) {
    final o = e as Map<String, dynamic>;
    m[o['bodyPart'] as String? ?? '其他'] = (o['sets'] as num?)?.toInt() ?? 0;
  }
  return m;
});

Color musclePartColor(String bp) {
  switch (bp) {
    case '胸':
      return const Color(0xFF3B82F6);
    case '背':
      return const Color(0xFF22C55E);
    case '腿':
      return const Color(0xFFF97316);
    case '肩':
      return const Color(0xFFA855F7);
    case '手臂':
    case '手':
      return const Color(0xFFEF4444);
    case '核心':
    case '腹':
      return const Color(0xFF14B8A6);
    default:
      return const Color(0xFF9CA3AF);
  }
}

const _mappedParts = ['胸', '背', '腿', '肩', '手臂', '核心'];

// SVG 键色(每个肌群一个哨兵色,运行时被 ColorMapper 替换成强度色)。
const int _kBody = 0xC9CDD6;
const Map<int, String> _keyToPart = {
  0xF1000A: '胸',
  0xF1000B: '背',
  0xF1000C: '腿',
  0xF1000D: '肩',
  0xF1000E: '手臂',
  0xF1000F: '核心',
};

class MuscleMapCard extends ConsumerWidget {
  const MuscleMapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(muscleMapProvider);
    return async.when(
      loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
      data: (sets) {
        if (sets.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.pad),
              child: Row(
                children: [
                  const Text('💪', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('练了就点亮身体 —— 记录训练后,对应肌群会在这里逐渐亮起来',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          );
        }
        final maxSets = sets.values.fold<int>(0, (a, b) => b > a ? b : a);
        final intensity = <String, double>{
          for (final p in _mappedParts) p: maxSets == 0 ? 0 : (sets[p] ?? 0) / maxSets,
        };
        final scheme = Theme.of(context).colorScheme;
        final neutral = scheme.onSurfaceVariant.withValues(alpha: 0.16);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💪', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text('肌肉训练地图', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text('累计 · 越练越亮', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  // 打开时身体从暗灰逐渐"点亮"到实际训练强度
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => SvgPicture.string(
                      _muscleSvg,
                      fit: BoxFit.contain,
                      colorMapper: _MuscleColorMapper(
                        {for (final e in intensity.entries) e.key: e.value * t},
                        neutral,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('正面', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Text('背面', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _mappedParts)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: musclePartColor(p).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: musclePartColor(p), shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text('$p ${sets[p] ?? 0} 组', style: TextStyle(fontSize: 12, color: scheme.onSurface, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Maps each muscle group's sentinel key colour → its training-intensity colour.
class _MuscleColorMapper extends ColorMapper {
  const _MuscleColorMapper(this.intensity, this.neutral);

  final Map<String, double> intensity;
  final Color neutral;

  @override
  Color substitute(String? id, String? elementName, String? attributeName, Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    if (rgb == _kBody) return neutral;
    final part = _keyToPart[rgb];
    if (part == null) return color;
    final inten = intensity[part] ?? 0;
    return inten <= 0 ? neutral : musclePartColor(part).withValues(alpha: 0.30 + 0.70 * inten);
  }

  @override
  bool operator ==(Object other) =>
      other is _MuscleColorMapper && mapEquals(other.intensity, intensity) && other.neutral == neutral;

  @override
  int get hashCode => Object.hash(neutral, Object.hashAllUnordered(intensity.entries.map((e) => '${e.key}:${e.value}')));
}

// ---- 人体解剖 SVG:前面(左)+ 背面(右),每肌群涂键色 ----
final String _muscleSvg = _buildSvg();

String _buildSvg() {
  final b = StringBuffer()..write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 410 300">');
  _figure(b, 0, front: true);
  _figure(b, 210, front: false);
  b.write('</svg>');
  return b.toString();
}

const _bodyHex = 'C9CDD6';
const _hChest = 'F1000A', _hBack = 'F1000B', _hLeg = 'F1000C', _hSh = 'F1000D', _hArm = 'F1000E', _hCore = 'F1000F';

void _figure(StringBuffer b, double ox, {required bool front}) {
  String n(num v) => v.toStringAsFixed(1);
  double X(num x) => x + ox;
  void ell(num cx, num cy, num rx, num ry, String hex) =>
      b.write('<ellipse cx="${n(X(cx))}" cy="${n(cy)}" rx="${n(rx)}" ry="${n(ry)}" fill="#$hex"/>');
  void rr(num x, num y, num w, num h, num rad, String hex) =>
      b.write('<rect x="${n(X(x))}" y="${n(y)}" width="${n(w)}" height="${n(h)}" rx="${n(rad)}" fill="#$hex"/>');

  // ---- 灰色人体剪影 ----
  b.write('<circle cx="${n(X(100))}" cy="24" r="14" fill="#$_bodyHex"/>'); // 头
  rr(93, 33, 14, 12, 4, _bodyHex); // 脖
  // 躯干(宽肩→收腰→髋)
  b.write('<path d="M ${n(X(72))} 51 Q ${n(X(100))} 43 ${n(X(128))} 51 '
      'Q ${n(X(151))} 57 ${n(X(146))} 96 Q ${n(X(140))} 138 ${n(X(122))} 150 '
      'Q ${n(X(135))} 165 ${n(X(129))} 184 L ${n(X(71))} 184 '
      'Q ${n(X(65))} 165 ${n(X(78))} 150 Q ${n(X(60))} 138 ${n(X(54))} 96 '
      'Q ${n(X(49))} 57 ${n(X(72))} 51 Z" fill="#$_bodyHex"/>');
  rr(37, 58, 20, 98, 10, _bodyHex); // 左臂
  rr(153, 58, 20, 98, 10, _bodyHex); // 右臂
  rr(70, 180, 27, 118, 13, _bodyHex); // 左腿
  rr(103, 180, 27, 118, 13, _bodyHex); // 右腿

  // ---- 肌群(键色)----
  // 肩(三角肌)
  ell(61, 57, 16, 11, _hSh);
  ell(139, 57, 16, 11, _hSh);
  // 手臂(上臂 + 前臂)
  ell(47, 88, 11, 18, _hArm);
  ell(153, 88, 11, 18, _hArm);
  ell(47, 132, 9, 18, _hArm);
  ell(153, 132, 9, 18, _hArm);
  // 腿(大腿 + 小腿)
  ell(83, 214, 13, 30, _hLeg);
  ell(117, 214, 13, 30, _hLeg);
  ell(83, 268, 10, 24, _hLeg);
  ell(117, 268, 10, 24, _hLeg);

  if (front) {
    // 胸肌
    ell(86, 80, 20, 16, _hChest);
    ell(114, 80, 20, 16, _hChest);
    // 腹肌(六块 + 两侧腹斜)
    for (var row = 0; row < 3; row++) {
      rr(88, 106 + row * 16.0, 11, 13, 3, _hCore);
      rr(101, 106 + row * 16.0, 11, 13, 3, _hCore);
    }
    ell(78, 128, 6, 15, _hCore);
    ell(122, 128, 6, 15, _hCore);
  } else {
    // 背:斜方 + 背阔
    ell(100, 58, 22, 12, _hBack); // 斜方
    ell(100, 82, 24, 20, _hBack); // 上背
    ell(83, 104, 15, 24, _hBack); // 左背阔
    ell(117, 104, 15, 24, _hBack); // 右背阔
    // 核心:下背
    ell(100, 132, 17, 11, _hCore);
    // 腿:臀(髋部)并入腿色
    ell(86, 178, 15, 13, _hLeg);
    ell(114, 178, 15, 13, _hLeg);
  }
}
