import 'package:flutter/material.dart';
import 'package:bms_inventory/widgets/glass_card_lite.dart';

class HabitatDetailsSection extends StatefulWidget {
  final String initialHabitatType;
  final String initialForestCover;
  final String initialWaterCondition;
  final bool initialInvasivePresent;
  final String initialInvasiveDetails;

  final void Function(
    String habitatType,
    String forestCover,
    String waterCondition,
    bool invasivePresent,
    String invasiveDetails,
  ) onChanged;

  const HabitatDetailsSection({
    super.key,
    required this.initialHabitatType,
    required this.initialForestCover,
    required this.initialWaterCondition,
    required this.initialInvasivePresent,
    required this.initialInvasiveDetails,
    required this.onChanged,
  });

  @override
  State<HabitatDetailsSection> createState() =>
      _HabitatDetailsSectionState();
}

class _HabitatDetailsSectionState
    extends State<HabitatDetailsSection> {
  // ================= OPTIONS =================
  final List<String> habitatTypes = [
    'Lowland Forest',
    'Montane Forest',
    'Riparian',
    'Grassland',
    'Agroforest',
    'Others',
  ];

  final List<String> forestCovers = [
    'Dense',
    'Moderate',
    'Sparse',
    'Open',
  ];

  final List<String> waterConditions = [
    'Clear',
    'Slightly Turbid',
    'Turbid',
    'Dry',
  ];

  // ================= STATE =================
  String? habitatType;
  String? forestCover;
  String? waterCondition;
  bool invasivePresent = false;
  String invasiveDetails = '';

  final invasiveCtrl = TextEditingController();

  // ================= MAPPERS =================

  String? _mapHabitatType(String raw) {
    switch (raw) {
      case 'Forest':
        return 'Lowland Forest';
      default:
        return habitatTypes.contains(raw) ? raw : null;
    }
  }

  String? _mapForestCover(String raw) {
    switch (raw) {
      case 'Good':
        return 'Dense';
      case 'Moderate':
        return 'Moderate';
      case 'Poor':
        return 'Sparse';
      case 'Open':
        return 'Open';
      default:
        return forestCovers.contains(raw) ? raw : null;
    }
  }

  String? _mapWaterCondition(String raw) {
    return waterConditions.contains(raw) ? raw : null;
  }

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    habitatType = _mapHabitatType(widget.initialHabitatType);
    forestCover = _mapForestCover(widget.initialForestCover);
    waterCondition = _mapWaterCondition(widget.initialWaterCondition);

    invasivePresent = widget.initialInvasivePresent;
    invasiveDetails = widget.initialInvasiveDetails;
    invasiveCtrl.text = invasiveDetails;
  }

  // ================= NOTIFY =================
  void _notify() {
    widget.onChanged(
      habitatType ?? '',
      forestCover ?? '',
      waterCondition ?? '',
      invasivePresent,
      invasiveDetails,
    );
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return GlassCardLite(
      title: 'Habitat Details',
      child: Column(
        children: [
          /// 🌿 HABITAT TYPE
          DropdownButtonFormField<String>(
            decoration: _dec('Habitat Type'),
            initialValue: habitatType,
            items: habitatTypes
                .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              setState(() => habitatType = v);
              _notify();
            },
          ),

          const SizedBox(height: 12),

          /// 🌲 FOREST COVER
          DropdownButtonFormField<String>(
            decoration: _dec('Forest Cover'),
            initialValue: forestCover,
            items: forestCovers
                .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              setState(() => forestCover = v);
              _notify();
            },
          ),

          const SizedBox(height: 12),

          /// 💧 WATER CONDITION
          DropdownButtonFormField<String>(
            decoration: _dec('Water Condition'),
            initialValue: waterCondition,
            items: waterConditions
                .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              setState(() => waterCondition = v);
              _notify();
            },
          ),

          const SizedBox(height: 12),

          /// 🚨 INVASIVE SPECIES
          SwitchListTile(
            title: const Text('Invasive Species Present'),
            value: invasivePresent,
            onChanged: (v) {
              setState(() => invasivePresent = v);
              _notify();
            },
          ),

          if (invasivePresent) ...[
            const SizedBox(height: 8),
            TextField(
              controller: invasiveCtrl,
              decoration: _dec('Invasive Species Details'),
              onChanged: (v) {
                invasiveDetails = v;
                _notify();
              },
            ),
          ],
        ],
      ),
    );
  }
}
