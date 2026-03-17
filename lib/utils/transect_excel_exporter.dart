import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TransectExcelExporter {
  // =========================================================
  // 🚀 MAIN ENTRY (ONLINE / FIRESTORE ONLY)
  // =========================================================
  static Future<void> exportAndShare(String transectId) async {
    // ================= TRANSECT =================
    final transectSnap = await FirebaseFirestore.instance
        .collection('transects')
        .doc(transectId)
        .get();

    if (!transectSnap.exists) {
      throw Exception('Transect not found in Firestore');
    }

    final transect = transectSnap.data()!;

    // ================= SPECIES =================
    final speciesSnap = await FirebaseFirestore.instance
        .collection('species_records')
        .where('transectId', isEqualTo: transectId)
        .get();

    if (speciesSnap.docs.isEmpty) {
      throw Exception('No species records found');
    }
    // ================= THREATS =================
    final threatsSnap = await FirebaseFirestore.instance
        .collection('threat_records')
        .where('transectId', isEqualTo: transectId)
        .get();

    final threats = threatsSnap.docs.map((d) => d.data()).toList();
    final species = speciesSnap.docs.map((d) => d.data()).toList();

    final flora = species.where((e) => e['category'] == 'Flora').toList();
    final fauna = species.where((e) => e['category'] == 'Fauna').toList();

    final excel = Excel.createExcel();
    excel.delete('Sheet1');

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
      '${dir.path}/ANNEX_1-C-1_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );

    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'DENR BMS – ANNEX 1-C.1');
  }

  // =========================================================
  // 📄 ANNEX BUILDER (FLORA / FAUNA)
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

    final DateTime start = (transect['startTime'] as Timestamp).toDate();
    final DateTime end = (transect['endTime'] as Timestamp).toDate();

    String fmtCoord(v) =>
        v == null ? '--' : (v as num).toDouble().toStringAsFixed(6);

    String fmtTime(v) {
      if (v == null) return '';
      return DateFormat('hh:mm a').format(DateTime.parse(v));
    }

    double? minElev;
    double? maxElev;

    // 1️⃣ PRIORITY: transect summary values
    if (transect['minElevation'] != null && transect['maxElevation'] != null) {
      minElev = (transect['minElevation'] as num).toDouble();
      maxElev = (transect['maxElevation'] as num).toDouble();
    }

    // 2️⃣ FALLBACK: compute from species elevations
    if (minElev == null || maxElev == null) {
      final elevations = rows
          .map((e) => e['elevation_m_asl'])
          .where((e) => e is num)
          .map((e) => (e as num).toDouble())
          .toList();

      if (elevations.isNotEmpty) {
        elevations.sort();
        minElev ??= elevations.first;
        maxElev ??= elevations.last;
      }
    }
    // ================= HEADER =================
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
    final elevationText = (minElev != null && maxElev != null)
        ? '${minElev.toStringAsFixed(2)} - ${maxElev.toStringAsFixed(2)} masl'
        : '--';

    sheet.appendRow(['Elevation', elevationText]);

    // ================= ECOSYSTEM (HABITAT TYPE) =================
    final ecosystem = rows
        .map((e) => e['habitatType'])
        .where((e) => e != null && e.toString().isNotEmpty)
        .toSet()
        .join(', ');

    sheet.appendRow(['Ecosystem Type', ecosystem.isEmpty ? '--' : ecosystem]);

    sheet.appendRow(['Species Observed', speciesType]);

    // ================= OBSERVERS =================
    final observers = rows
        .map((e) => e['observerName'])
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .toSet()
        .join(', ');

    sheet.appendRow(['Observer(s)', observers.isEmpty ? '--' : observers]);

    sheet.appendRow([]);
    sheet.appendRow([]); // space

    // ================= TABLE HEADER =================
    sheet.appendRow([
      'Station',
      'Time',
      'Scientific Name',
      'Common Name',
      'Count',
      'Mode',
      'Remarks',
    ]);

    // ================= TABLE ROWS =================
    for (final s in rows) {
      final rowIndex = sheet.maxRows;

      final station =
          (s['station'] != null && s['station'].toString().isNotEmpty)
          ? s['station']
          : '--';

      final count = speciesType == 'flora'
          ? (s['count'] != null && s['count'].toString() != 'Prominent'
                ? s['count']
                : 'Prominent')
          : (s['count'] ?? 1);

      final mode = speciesType == 'flora'
          ? 'Seen'
          : (s['detectionType'] ?? 'Seen');

      sheet.appendRow([
        station,
        fmtTime(s['observedAt']),
        s['scientificName'] ?? '',
        s['commonName'] ?? '',
        count,
        mode,
        s['remarks'] ?? '',
      ]);

      // 🔥 ITALIC SCIENTIFIC NAME
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
              )
              .cellStyle =
          italic;
    }
  }

  // =========================================================
  // ⚠️ ANNEX – THREATS
  // =========================================================
  static void _buildThreatAnnex({
    required Excel excel,
    required String sheetName,
    required Map<String, dynamic> transect,
    required List<Map<String, dynamic>> rows,
  }) {
    final sheet = excel[sheetName];
    final italic = CellStyle(italic: true);

    final DateTime start = (transect['startTime'] as Timestamp).toDate();
    final DateTime end = (transect['endTime'] as Timestamp).toDate();
    // Elevation (from transect if naa)
    double? minElev;
    double? maxElev;

    // compute from threat rows
    final elevations = rows
        .map((e) => e['elevation_m_asl'])
        .where((e) => e is num)
        .map((e) => (e as num).toDouble())
        .toList();

    if (elevations.isNotEmpty) {
      elevations.sort();
      minElev = elevations.first;
      maxElev = elevations.last;
    }

    final elevationText = (minElev != null && maxElev != null)
        ? '${minElev.toStringAsFixed(2)} - ${maxElev.toStringAsFixed(2)} masl'
        : '--';

    String fmtCoord(v) =>
        v == null ? '--' : (v as num).toDouble().toStringAsFixed(6);

    // ================= HEADER (SAME SA FLORA / FAUNA) =================
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
    sheet.appendRow(['Elevation', elevationText]);

    // Weather
    sheet.appendRow(['Weather Condition', transect['weather'] ?? '--']);

    // Observers (kuhaon gikan sa threats mismo)
    final observers = rows
        .map((e) => e['observerName'])
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .toSet()
        .join(', ');

    sheet.appendRow(['Observer(s)', observers.isEmpty ? '--' : observers]);

    sheet.appendRow([]);
    sheet.appendRow([]);

    // ================= TABLE HEADER =================
    sheet.appendRow([
      'Station',
      'Threat Type',
      'Severity',
      'Latitude',
      'Longitude',
      'Photos',
      'Remarks',
    ]);

    // ================= TABLE ROWS =================
    for (final t in rows) {
      final rowIndex = sheet.maxRows;

      String photosText = '--';
      final photos = t['photoUrls'];

      if (photos is List && photos.isNotEmpty) {
        photosText = photos.join('\n'); // one URL per line
      }

      sheet.appendRow([
        t['station'] ?? '--',
        t['threatType'] ?? '',
        t['threatSeverity'] ?? '',
        fmtCoord(t['latitude']),
        fmtCoord(t['longitude']),
        photosText,
        t['remarks'] ?? '',
      ]);

      // optional italic on threat type
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
              )
              .cellStyle =
          italic;
    }
  }
}
