import 'package:flutter/material.dart';
import 'package:cds_smart_mobile/widgets/glass_card_lite.dart';

class ActivitySection extends StatefulWidget {
  final String initialActivityType;
  final String initialIntensity;
  final String initialFrequency;

  final void Function(
    String activityType,
    String intensity,
    String frequency,
  ) onChanged;

  const ActivitySection({
    super.key,
    this.initialActivityType = '',
    this.initialIntensity = '',
    this.initialFrequency = '',
    required this.onChanged,
  });

  @override
  State<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<ActivitySection> {
  final activityTypes = [
    'Farming / Agriculture',
    'Fishing',
    'Hunting',
    'Logging',
    'Charcoal Making',
    'Settlement / Housing',
    'Tourism Activity',
    'Trail Use / Trekking',
    'Others',
  ];

  final intensities = ['Low', 'Moderate', 'High'];
  final frequencies = ['Occasional', 'Regular', 'Seasonal'];

  late String activityType;
  late String intensity;
  late String frequency;

  @override
  void initState() {
    super.initState();
    activityType = widget.initialActivityType;
    intensity = widget.initialIntensity;
    frequency = widget.initialFrequency;
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
      isExpanded: true,
      initialValue: value.isEmpty ? null : value,
      decoration: _dec(label),
      hint: Text(
        'Please select $label',
        style: TextStyle(color: Colors.grey.shade500),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => onChanged(v));
        widget.onChanged(activityType, intensity, frequency);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCardLite(
      title: 'Activity Details',
      child: Column(
        children: [
          _dropdown(
            label: 'Activity Type',
            value: activityType,
            items: activityTypes,
            onChanged: (v) => activityType = v,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Intensity',
            value: intensity,
            items: intensities,
            onChanged: (v) => intensity = v,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Frequency',
            value: frequency,
            items: frequencies,
            onChanged: (v) => frequency = v,
          ),
        ],
      ),
    );
  }
}
