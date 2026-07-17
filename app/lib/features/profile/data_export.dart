import 'dart:convert';
import 'dart:typed_data';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html; // web-only build; used for file download + pick

import '../../core/api_client.dart';
import '../history/session_models.dart';

/// Summary returned by [importTrainingJson].
class ImportSummary {
  ImportSummary({this.imported = 0, this.skipped = 0, this.exercisesCreated = 0, this.cancelled = false});
  final int imported;
  final int skipped;
  final int exercisesCreated;
  final bool cancelled;
}

/// Export all training as a per-set CSV (UTF-8 BOM, Excel-friendly). Returns set-row count.
Future<int> exportTrainingCsv() async {
  final data = await ApiClient.get('/api/sessions/export') as List<dynamic>;
  final sessions = data.map((e) => SessionDetail.fromJson(e as Map<String, dynamic>)).toList();

  final rows = <String>['日期,动作,部位,组号,重量(kg),次数,容量'];
  var count = 0;
  for (final s in sessions) {
    final date = _fmtDate(s.finishedAt);
    for (final ex in s.exercises) {
      for (final set in ex.sets) {
        final w = set.weight;
        final reps = set.reps;
        final vol = (w != null && reps != null) ? w * reps : null;
        rows.add([
          date,
          _csv(ex.name),
          _csv(ex.bodyPart ?? ''),
          set.setNo?.toString() ?? '',
          w == null ? '' : _num(w),
          reps?.toString() ?? '',
          vol == null ? '' : _num(vol),
        ].join(','));
        count++;
      }
    }
  }
  // BOM so Excel opens the UTF-8 file without turning Chinese into mojibake.
  _download(utf8.encode('﻿${rows.join('\r\n')}'), 'gymos-训练记录-${_stamp()}.csv', 'text/csv;charset=utf-8');
  return count;
}

/// Export all training as a JSON backup (exact structure, re-importable). Returns session count.
Future<int> exportTrainingJson() async {
  final data = await ApiClient.get('/api/sessions/export') as List<dynamic>;
  final json = const JsonEncoder.withIndent('  ').convert(data);
  _download(utf8.encode(json), 'gymos-备份-${_stamp()}.json', 'application/json');
  return data.length;
}

/// Pick a JSON backup file and import it. Server-side is idempotent (skips duplicate sessions).
Future<ImportSummary> importTrainingJson() async {
  final text = await _pickFileText('.json,application/json');
  if (text == null) return ImportSummary(cancelled: true);

  final dynamic parsed = jsonDecode(text);
  final List<dynamic> sessions;
  if (parsed is List) {
    sessions = parsed;
  } else if (parsed is Map && parsed['sessions'] is List) {
    sessions = parsed['sessions'] as List<dynamic>;
  } else {
    throw const FormatException('文件格式不对：应为导出的训练记录 JSON');
  }

  final resp = await ApiClient.post('/api/sessions/import', {'sessions': sessions}) as Map<String, dynamic>;
  return ImportSummary(
    imported: (resp['imported'] as num?)?.toInt() ?? 0,
    skipped: (resp['skipped'] as num?)?.toInt() ?? 0,
    exercisesCreated: (resp['exercisesCreated'] as num?)?.toInt() ?? 0,
  );
}

// ---- helpers ----

// CSV field escaping: wrap in quotes + double internal quotes when the value has a comma/quote/newline.
String _csv(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
String _fmtDate(DateTime? d) => d == null ? '' : '${d.year}-${_two(d.month)}-${_two(d.day)}';

String _stamp() {
  final d = DateTime.now();
  return '${d.year}${_two(d.month)}${_two(d.day)}';
}

String _two(int v) => v.toString().padLeft(2, '0');

void _download(List<int> bytes, String filename, String mime) {
  final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Opens the browser file picker and returns the chosen file's text (null if none chosen).
Future<String?> _pickFileText(String accept) async {
  final input = html.FileUploadInputElement()..accept = accept;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final reader = html.FileReader();
  reader.readAsText(files.first);
  await reader.onLoad.first;
  return reader.result as String?;
}
