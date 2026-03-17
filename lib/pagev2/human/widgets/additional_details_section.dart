import 'package:flutter/material.dart';
import 'package:bms_inventory/widgets/glass_card_lite.dart';

class AdditionalDetailsSection extends StatefulWidget {
  final String initialLocation;
  final String initialRemarks;
  final void Function(String locationDescription, String remarks) onChanged;

  const AdditionalDetailsSection({
    super.key,
    this.initialLocation = '', // ✅ SAFE DEFAULT
    this.initialRemarks = '',  // ✅ SAFE DEFAULT
    required this.onChanged,
  });

  @override
  State<AdditionalDetailsSection> createState() =>
      _AdditionalDetailsSectionState();
}

class _AdditionalDetailsSectionState extends State<AdditionalDetailsSection> {
  late TextEditingController locationCtrl;
  late TextEditingController remarksCtrl;

  @override
  void initState() {
    super.initState();
    locationCtrl = TextEditingController(text: widget.initialLocation);
    remarksCtrl = TextEditingController(text: widget.initialRemarks);
  }

  @override
  void dispose() {
    locationCtrl.dispose();
    remarksCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF4CAF50),
            width: 1.4,
          ),
        ),
      );

  void _notifyParent() {
    widget.onChanged(
      locationCtrl.text.trim(),
      remarksCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCardLite(
      title: 'Additional Details',
      child: Column(
        children: [
          TextField(
            controller: locationCtrl,
            decoration: _dec('Location Description'),
            onChanged: (_) => _notifyParent(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: remarksCtrl,
            maxLines: 3,
            decoration: _dec('Remarks'),
            onChanged: (_) => _notifyParent(),
          ),
        ],
      ),
    );
  }
}
