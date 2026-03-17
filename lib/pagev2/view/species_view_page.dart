import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bms_inventory/pagev2/species/species_input_edit_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SpeciesViewPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  static const Color kSpeciesGreen = Color(0xFF4CAF50);

  const SpeciesViewPage({super.key, required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Species Details'),
        backgroundColor: kSpeciesGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SpeciesInputEditPage(docId: docId, existingData: data),
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
          /// ================= SUMMARY =================
          _summaryCard(),

          const Divider(height: 28),

          /// ================= OBSERVER =================
          if (data['observerName'] != null &&
              data['observerName'].toString().trim().isNotEmpty)
            _detailItem('OBSERVER NAME', data['observerName'].toString()),

          /// ================= FLORA STATUS =================
          if (data['category'] == 'Flora' &&
              data['floraStatus'] != null &&
              data['floraStatus'] is List &&
              (data['floraStatus'] as List).isNotEmpty) ...[
            const Divider(height: 28),
            _detailItem(
              'FLORA STATUS',
              (data['floraStatus'] as List).join(', '),
            ),
          ],

          /// ================= PHOTOS =================
          if (_photos.isNotEmpty) ...[
            const Divider(height: 28),
            _photoSection(context),
          ],

          const Divider(height: 28),

          /// ================= OTHER DETAILS =================
          ...data.entries
              .where((e) => !_hiddenFields.contains(e.key))
              .map(
                (e) => _detailItem(_beautifyKey(e.key), _formatValue(e.value)),
              ),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          /// Assessment
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

          /// Elevation + Time
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

  // =========================================================
  // DETAIL ITEM
  // =========================================================

  Widget _detailItem(String label, String value) {
    if (value.trim().isEmpty || value == 'N/A') {
      return const SizedBox();
    }

    final isScientificName =
        label == 'SCIENTIFIC NAME' || label == 'SCIENTIFICNAME';

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
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontStyle: isScientificName ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PHOTOS
  // =========================================================

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
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 100,
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image),
                        ),
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
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: path.startsWith('http')
                    ? Image.network(
                        path,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 48,
                        ),
                      )
                    : Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this species record?\n\n'
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

    final speciesId = docId;

    // ================= FIRESTORE =================
    await FirebaseFirestore.instance
        .collection('species_records')
        .doc(speciesId)
        .delete();

    // ================= HIVE: species =================
    final speciesBox = Hive.box('species');
    if (speciesBox.containsKey(speciesId)) {
      await speciesBox.delete(speciesId);
    }

    // ================= HIVE: species_points =================
    final pointsBox = Hive.box('species_points');

    final keysToDelete = pointsBox.keys.where((k) {
      final v = pointsBox.get(k);
      return v is Map && (v['speciesId'] == speciesId || v['id'] == speciesId);
    }).toList();

    for (final k in keysToDelete) {
      await pointsBox.delete(k);
    }

    // ================= UI STATE CLEAN =================
    Hive.box('species').delete('selected_species_id');

    if (!context.mounted) return;

    Navigator.pop(context, true);
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static const List<String> _hiddenFields = [
    'createdAt',
    'updatedAt',
    'uid',
    'id',

    // already shown in summary
    'assessmentPeriod',
    'assessmentYear',
    'latitude',
    'longitude',
    'elevation_m_asl',
    'observedAt',

    // custom sections
    'observerName',
    'floraStatus',
    'photoUrls',
    'localPhotoPaths',

    // internals
    'transectId',
    'transectStart',
    'transectEnd',
    'distanceAtCapture',
    'coordinateSource',
    'accuracy',
  ];

  String _beautifyKey(String key) => key.replaceAll('_', ' ').toUpperCase();

  String _formatValue(dynamic v) {
    if (v == null) return 'N/A';
    if (v is List) return v.join(', ');
    if (v is Timestamp) return _formatObserved(v);
    return v.toString();
  }

  String _formatObserved(dynamic v) {
    DateTime d;
    if (v is Timestamp) {
      d = v.toDate();
    } else if (v is String) {
      d = DateTime.tryParse(v) ?? DateTime.now();
    } else {
      return v.toString();
    }

    return '${_month(d.month)} ${d.day}, ${d.year} '
        '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _fmtCoord(dynamic v) {
    if (v is num) return v.toStringAsFixed(6);
    return v?.toString() ?? '—';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _month(int m) {
    const months = [
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
    ];
    return months[m - 1];
  }
}
