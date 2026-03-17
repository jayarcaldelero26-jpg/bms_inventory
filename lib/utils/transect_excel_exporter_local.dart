import 'dart:io';
import 'package:excel/excel.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TransectExcelExporterLocal {
  // =========================================================
  // 🚀 MAIN ENTRY — OFFLINE / HIVE ONLY
  // =========================================================
  static Future<void> exportAndShare({required String transectId}) async {
    // ---------- LOAD LOCAL DATA ----------
    final transectsBox = Hive.box('transects');
    final offlineBox = Hive.box('offline_logs');

    final transect = transectsBox.get(transectId);
    if (transect == null) {
      throw Exception('Transect not found in local storage');
    }

    final List<Map<String, dynamic>> species = [];
    final List<Map<String, dynamic>> threats = [];

    for (final v in offlineBox.values.whereType<Map>()) {
      final type = v['type'];
      final data = Map<String, dynamic>.from(v['data'] ?? {});
      if (data['transectId'] != transectId) continue;

      if (type == 'species') species.add(data);
      if (type == 'threat') threats.add(data);
    }

    if (species.isEmpty && threats.isEmpty) {
      throw Exception('No species or threat data found locally');
    }

    // ---------- EXCEL ----------
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final flora = species.where((e) => e['category'] == 'Flora').toList();
    final fauna = species.where((e) => e['category'] == 'Fauna').toList();

    if (flora.isNotEmpty) {
      _buildAnnex(
        excel: excel,
        sheetName: 'FLORA',
        transect: transect,
        rows: flora,
        speciesType: 'flora',
      );
    }

    if (fauna.isNotEmpty) {
      _buildAnnex(
        excel: excel,
        sheetName: 'FAUNA',
        transect: transect,
        rows: fauna,
        speciesType: 'fauna',
      );
    }

    if (threats.isNotEmpty) {
      _buildThreatAnnex(
        excel: excel,
        sheetName: 'THREATS',
        transect: transect,
        rows: threats,
      );
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encode failed');

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ANNEX_1-C-1_OFFLINE_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );

    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'DENR BMS – ANNEX 1-C.1 (OFFLINE)');
  }

  // =========================================================
  // 📄 ANNEX — FLORA / FAUNA
  // =========================================================
  static void _buildAnnex({
    required Excel excel,
    required String sheetName,
    required Map<String, dynamic> transect,
    required List<Map<String, dynamic>> rows,
    required String speciesType,
  }) {
    final sheet = excel[sheetName];
    final italic = CellStyle(italic: true);

    DateTime parseTime(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final DateTime start = parseTime(transect['startTime']);
    final DateTime end = parseTime(transect['endTime']);

    String fmtCoord(v) =>
        v == null ? '--' : (v as num).toDouble().toStringAsFixed(6);

    String fmtTime(v) {
      if (v == null) return '';
      return DateFormat('hh:mm a').format(parseTime(v));
    }

    // ---------- HEADER ----------
    sheet.appendRow(['ANNEX 1-C.1 – SUMMARY OF TRANSECT DATA']);
    sheet.appendRow([]);
    sheet.appendRow(['Location', transect['bmsLocation'] ?? '--']);
    sheet.appendRow([
      'Date Conducted',
      DateFormat('MMMM dd, yyyy').format(start),
    ]);
    sheet.appendRow([
      'Start / End Time',
      '${DateFormat('hh:mm a').format(start)} – ${DateFormat('hh:mm a').format(end)}',
    ]);
    sheet.appendRow([
      'Length of Transect',
      '${((transect['distance'] ?? 0) / 1000).toStringAsFixed(2)} km',
    ]);
    sheet.appendRow([
      'GPS Reading',
      '${fmtCoord(transect['startLat'])}, ${fmtCoord(transect['startLng'])} (Start)\n'
          '${fmtCoord(transect['endLat'])}, ${fmtCoord(transect['endLng'])} (End)',
    ]);
    sheet.appendRow(['Weather Condition', transect['weather'] ?? '--']);
    sheet.appendRow(['Species Observed', speciesType.toUpperCase()]);
    sheet.appendRow([]);

    // ---------- TABLE ----------
    sheet.appendRow([
      'Station',
      'Time',
      'Scientific Name',
      'Common Name',
      'Count',
      'Mode',
      'Remarks',
    ]);

    for (final s in rows) {
      final rowIndex = sheet.maxRows;

      sheet.appendRow([
        s['station'] ?? '--',
        fmtTime(s['observedAt']),
        s['scientificName'] ?? '',
        s['commonName'] ?? '',
        s['count'] ?? '',
        speciesType == 'flora' ? 'Seen' : (s['detectionType'] ?? 'Seen'),
        s['remarks'] ?? '',
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
              )
              .cellStyle =
          italic;
    }
  }

  // =========================================================
  // ⚠️ ANNEX — THREATS
  // =========================================================
  static void _buildThreatAnnex({
    required Excel excel,
    required String sheetName,
    required Map<String, dynamic> transect,
    required List<Map<String, dynamic>> rows,
  }) {
    final sheet = excel[sheetName];
    final italic = CellStyle(italic: true);

    DateTime parseTime(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final DateTime start = parseTime(transect['startTime']);
    final DateTime end = parseTime(transect['endTime']);

    String fmtCoord(v) =>
        v == null ? '--' : (v as num).toDouble().toStringAsFixed(6);

    // ---------- HEADER ----------
    sheet.appendRow(['ANNEX 1-C.1 – SUMMARY OF TRANSECT DATA']);
    sheet.appendRow([]);
    sheet.appendRow(['Location', transect['bmsLocation'] ?? '--']);
    sheet.appendRow([
      'Date Conducted',
      DateFormat('MMMM dd, yyyy').format(start),
    ]);
    sheet.appendRow([
      'Start / End Time',
      '${DateFormat('hh:mm a').format(start)} – ${DateFormat('hh:mm a').format(end)}',
    ]);
    sheet.appendRow([
      'Length of Transect',
      '${((transect['distance'] ?? 0) / 1000).toStringAsFixed(2)} km',
    ]);
    sheet.appendRow([
      'GPS Reading',
      '${fmtCoord(transect['startLat'])}, ${fmtCoord(transect['startLng'])} (Start)\n'
          '${fmtCoord(transect['endLat'])}, ${fmtCoord(transect['endLng'])} (End)',
    ]);
    sheet.appendRow(['Weather Condition', transect['weather'] ?? '--']);
    sheet.appendRow([]);

    // ---------- TABLE ----------
    sheet.appendRow([
      'Station',
      'Threat Type',
      'Severity',
      'Latitude',
      'Longitude',
      'Remarks',
    ]);

    for (final t in rows) {
      final rowIndex = sheet.maxRows;

      sheet.appendRow([
        t['station'] ?? '--',
        t['threatType'] ?? '',
        t['threatSeverity'] ?? '',
        fmtCoord(t['latitude']),
        fmtCoord(t['longitude']),
        t['remarks'] ?? '',
      ]);

      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .cellStyle =
          italic;
    }
  }
}
