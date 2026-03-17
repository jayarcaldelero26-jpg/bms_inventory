import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bms_inventory/pagev2/threat/threat_input_edit_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThreatViewPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  static const Color kThreatRed = Color(0xFFD32F2F);

  const ThreatViewPage({super.key, required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Threat Details'),
        backgroundColor: kThreatRed,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ThreatInputV2(docId: docId, existingData: data),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),

          const Divider(height: 28),

          if (_photos.isNotEmpty) ...[
            _photoSection(context),
            const Divider(height: 28),
          ],

          ...data.entries
              .where((e) => !_hiddenFields.contains(e.key))
              .map(
                (e) => _detailItem(_beautifyKey(e.key), _formatValue(e.value)),
              ),
        ],
      ),
    );
  }

  // ================= SUMMARY =================

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          /// ASSESSMENT + YEAR
          Row(
            children: [
              Expanded(
                child: _miniInfo('ASSESSMENT', data['assessmentPeriod'] ?? '—'),
              ),
              Expanded(
                child: _miniInfo('YEAR', '${data['assessmentYear'] ?? '—'}'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// GPS
          Row(
            children: [
              Expanded(
                child: _miniInfo('LATITUDE', _fmtCoord(data['latitude'])),
              ),
              Expanded(
                child: _miniInfo('LONGITUDE', _fmtCoord(data['longitude'])),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// ELEVATION + TIME
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  'ELEVATION (GPS)',
                  data['elevation_m_asl'] != null
                      ? '${(data['elevation_m_asl'] as num).toStringAsFixed(2)} m'
                      : '—',
                ),
              ),
              Expanded(
                child: _miniInfo(
                  'OBSERVED DATE & TIME',
                  data['observedAt'] != null
                      ? _formatObserved(data['observedAt'])
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ================= DETAIL ITEM =================

  Widget _detailItem(String label, String value) {
    if (value.trim().isEmpty || value == 'N/A') {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  // ================= PHOTOS (SAME AS SPECIES) =================

  List<String> get _photos {
    final urls = data['photoUrls'];
    if (urls is List && urls.isNotEmpty) {
      return urls.map((e) => e.toString()).toList();
    }

    final local = data['localPhotoPaths'];
    if (local is List && local.isNotEmpty) {
      return local.map((e) => e.toString()).toList();
    }

    return [];
  }

  Widget _photoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHOTO EVIDENCE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _photos.map((path) {
            return GestureDetector(
              onTap: () => _showImageViewer(context, path),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: path.startsWith('http')
                    ? Image.network(
                        path,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showImageViewer(BuildContext context, String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: path.startsWith('http')
                  ? Image.network(path, fit: BoxFit.contain)
                  : Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // ================= DELETE =================

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this threat record?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('threat_records')
        .doc(docId)
        .delete();

    final box = Hive.box('threats');
    final keys = box.keys.where((k) {
      final v = box.get(k);
      return v is Map && v['docId'] == docId;
    }).toList();

    for (final k in keys) {
      await box.delete(k);
    }

    if (!context.mounted) return;
    Navigator.pop(context, true);
  }

  // ================= HELPERS =================

  static const _hiddenFields = [
    // system
    'id',
    'docId',
    'type',
    'isEdit',

    // time
    'createdAt',
    'updatedAt',
    'observedAt',

    // gps internals
    'latitude',
    'longitude',
    'accuracy',
    'coordinateSource',
    'elevation_m_asl',

    // photos (handled separately)
    'photoUrls',
    'localPhotoPaths',
    'photosyncstatus',

    // transect internals
    'transectId',
    'transectStart',
    'distanceAtCapture',

    // duplicates already shown
    'assessmentPeriod',
    'assessmentYear',
  ];

  String _beautifyKey(String key) {
    const map = {
      'threatType': 'THREAT TYPE',
      'conditionOfEvidence': 'CONDITION OF EVIDENCE',
      'extentOfInvasion': 'EXTENT OF INVASION',
      'station': 'STATION',
      'bmsLocation': 'BMS LOCATION',
      'remarks': 'REMARKS',
    };

    return map[key] ?? key.replaceAll('_', ' ').toUpperCase();
  }

  String _formatValue(dynamic v) {
    if (v == null) return 'N/A';
    if (v is List) return v.join(', ');
    if (v is Timestamp) return _formatObserved(v);
    return v.toString();
  }

  String _formatObserved(dynamic v) {
    final d = v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v.toString()) ?? DateTime.now();

    return '${_month(d.month)} ${d.day}, ${d.year} '
        '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _fmtCoord(dynamic v) => v is num ? v.toStringAsFixed(6) : '—';

  String _two(int n) => n.toString().padLeft(2, '0');

  String _month(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];
}
