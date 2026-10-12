import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cds_smart_mobile/pagev2/human/human_activity_input_v2.dart';

class HumanActivityViewPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  static const Color kHumanYellow = Color(0xFFFFC107);

  const HumanActivityViewPage({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text('Human Activity Details'),
        backgroundColor: kHumanYellow,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HumanActivityInputV2(
                    docId: docId,
                    existingData: data,
                  ),
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

          /// ================= SUMMARY CARD =================
          _summaryCard(),

          const Divider(height: 28),

          /// ================= OBSERVER =================
          if (data['observerName'] != null)
            _detailItem('OBSERVER NAME', data['observerName'].toString()),

          /// ================= PHOTOS =================
          if (data['photoUrls'] != null &&
              data['photoUrls'] is List &&
              (data['photoUrls'] as List).isNotEmpty) ...[
            const Divider(height: 28),
            _photoSection(context, data['photoUrls']),
          ],

          const Divider(height: 28),

          /// ================= AUTO DETAILS =================
          ...data.entries
              .where((e) => !_hiddenFields.contains(e.key))
              .map((e) => _detailItem(
                    _beautifyKey(e.key),
                    _formatValue(e.value),
                  )),
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
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [

          /// Assessment
          Row(
            children: [
              Expanded(child: _miniInfo('ASSESSMENT', data['assessmentPeriod'] ?? '—')),
              Expanded(child: _miniInfo('YEAR', '${data['assessmentYear'] ?? '—'}')),
            ],
          ),

          const SizedBox(height: 12),

          /// GPS
          Row(
            children: [
              Expanded(child: _miniInfo('LATITUDE',
                data['latitude']?.toStringAsFixed?.call(6) ??
                data['latitude']?.toString() ?? '—')),
              Expanded(child: _miniInfo('LONGITUDE',
                data['longitude']?.toStringAsFixed?.call(6) ??
                data['longitude']?.toString() ?? '—')),
            ],
          ),

          const SizedBox(height: 12),

          /// Elevation & Time
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
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // =========================================================
  // DETAIL ITEM
  // =========================================================

  Widget _detailItem(String label, String value) {
    if (value.trim().isEmpty || value == 'N/A') return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // =========================================================
  // PHOTO SECTION
  // =========================================================

  Widget _photoSection(BuildContext context, List<dynamic> urls) {
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
          children: urls.map((url) {
            return GestureDetector(
              onTap: () => _showImageViewer(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
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

  void _showImageViewer(BuildContext context, String url) {
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
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
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
          'Are you sure you want to delete this human activity record?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('human_activity_records')
          .doc(docId)
          .delete();

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Deleted'),
          content:
              const Text('Human activity record was successfully deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      Navigator.pop(context, true);
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static const List<String> _hiddenFields = [
    'createdAt',
    'updatedAt',
    'uid',
    'id',
    'photoUrls',

    'assessmentPeriod',
    'assessmentYear',

    'latitude',
    'longitude',
    'elevation_m_asl',
    'observedAt',
    'observerName',
  ];

  String _beautifyKey(String key) =>
      key.replaceAll('_', ' ').toUpperCase();

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

  String _two(int n) => n.toString().padLeft(2, '0');

  String _month(int m) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[m - 1];
  }
}
