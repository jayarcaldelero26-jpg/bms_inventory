import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThreatDetailsCard extends StatelessWidget {
  final String threatId;
  final VoidCallback onClose;

  const ThreatDetailsCard({
    super.key,
    required this.threatId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('threats');
    final t = box.get(threatId);

    if (t == null || t is! Map) {
      return const SizedBox();
    }

    return Card(
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================
            Row(
              children: [
                const Text(
                  'Threat Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(context, threatId),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),

            const Divider(),

            _item('Threat Type', t['threatType']),
            _item('Station', t['station']),
            _item('Condition', t['conditionOfEvidence']),
            _item('Actions Taken', t['actionsTaken']),
            _item('Reported To', t['reportedTo']),
            _item('Remarks', t['remarks']),

            if (_photos(t).isNotEmpty) ...[
              const SizedBox(height: 12),
              _photoStrip(_photos(t)),
            ],
          ],
        ),
      ),
    );
  }

  // ================= PHOTO PRIORITY (SPECIES STYLE) =================

  List<String> _photos(Map t) {
    final urls = t['photoUrls'];
    if (urls is List && urls.isNotEmpty) {
      return urls.map((e) => e.toString()).toList();
    }

    final local = t['localPhotoPaths'];
    if (local is List && local.isNotEmpty) {
      return local.map((e) => e.toString()).toList();
    }

    return [];
  }

  Widget _photoStrip(List<String> photos) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = photos[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: p.startsWith('http')
                ? Image.network(p, width: 90, height: 90, fit: BoxFit.cover)
                : Image.file(File(p), width: 90, height: 90, fit: BoxFit.cover),
          );
        },
      ),
    );
  }

  // ================= DELETE =================

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Threat'),
        content: const Text(
          'Are you sure you want to delete this threat?\n\n'
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

    if (ok != true) return;

    await _deleteThreat(id);

    if (!context.mounted) return;
    Navigator.pop(context);
    onClose();
  }

  Future<void> _deleteThreat(String id) async {
    final box = Hive.box('threats');
    final data = box.get(id);

    await box.delete(id);
    Hive.box('ui_state').delete('selected_threat_id');

    final docId = data?['docId'];
    if (docId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('threat_records')
            .doc(docId)
            .delete();
      } catch (_) {
        // offline safe
      }
    }
  }

  // ================= HELPERS =================

  Widget _item(String label, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }
}
