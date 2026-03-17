import 'package:flutter/material.dart';
import 'package:bms_inventory/widgets/glass_card_lite.dart';

class AssessmentSection extends StatefulWidget {
  final String? initialPeriod;
  final String? initialYear;
  final String? initialStation;
   final String initialBmsLocation;

  final void Function(
    String assessmentPeriod,
    String assessmentYear,
    String station,
    String bmsLocation,
  ) onChanged;

  const AssessmentSection({
    super.key,
    this.initialPeriod,
    this.initialYear,
    this.initialStation,
    required this.initialBmsLocation,
    required this.onChanged,
  });

  @override
  State<AssessmentSection> createState() => _AssessmentSectionState();
}

class _AssessmentSectionState extends State<AssessmentSection> {
  final assessmentPeriods = ['1st Assessment', '2nd Assessment'];
  final stations = [
    'Station 0','Station 1','Station 2','Station 3','Station 4',
    'Station 5','Station 6','Station 7','Station 8',
  ];
  final List<String> bmsLocations = [
  'San Isidro',
  'Governor Generoso',
  'Mati City',
];

  late String assessmentPeriod;
  late String assessmentYear;
  late String station;
  late String bmsLocation;

  @override
  void initState() {
    super.initState();
    assessmentPeriod = widget.initialPeriod ?? '';
    assessmentYear = widget.initialYear ?? '';
    station = widget.initialStation ?? '';
    bmsLocation = widget.initialBmsLocation;
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

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: _dec(label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => onChanged(v));
        widget.onChanged(
          assessmentPeriod,
          assessmentYear,
          station,
          bmsLocation,
        );
      },
    );
  }

  @override
Widget build(BuildContext context) {
  return GlassCardLite(
    title: 'Assessment Details',
    child: Column(
      children: [
        _dropdown(
          label: 'Assessment Period',
          value: assessmentPeriod,
          items: assessmentPeriods,
          onChanged: (v) => assessmentPeriod = v,
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Assessment Year',
          value: assessmentYear,
          items: List.generate(
            5,
            (i) => (DateTime.now().year - i).toString(),
          ),
          onChanged: (v) => assessmentYear = v,
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Station',
          value: station,
          items: stations,
          onChanged: (v) => station = v,
        ),
         const SizedBox(height: 12),
        _dropdown(
          label: 'BMS Location',
          value: bmsLocation,
          items: bmsLocations,              // ✅ SAKTO
          onChanged: (v) => bmsLocation = v, // ✅ SAKTO
        ),
      ],
    ),
  );
}
}

