import 'package:flutter/material.dart';
import 'package:bms_inventory/widgets/glass_card_lite.dart';

class HabitatDisturbanceSection extends StatefulWidget {
  final List<String> initialDisturbances;
  final ValueChanged<List<String>> onChanged;

  const HabitatDisturbanceSection({
    super.key,
    required this.initialDisturbances,
    required this.onChanged,
  });

  @override
  State<HabitatDisturbanceSection> createState() =>
      _HabitatDisturbanceSectionState();
}

class _HabitatDisturbanceSectionState
    extends State<HabitatDisturbanceSection> {
  final List<String> disturbanceOptions = [
    'Logging',
    'Kaingin',
    'Mining',
    'Settlement',
    'Trail Use',
    'Tourism',
    'Others',
  ];

  List<String> selectedDisturbances = [];

  // 🔥 SINGLE SOURCE OF TRUTH
  void _syncFromParent() {
    selectedDisturbances = widget.initialDisturbances
        .where((d) => disturbanceOptions.contains(d))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _syncFromParent();
  }

  // 🔥 THIS IS THE FIX
  @override
  void didUpdateWidget(covariant HabitatDisturbanceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromParent();
  }

  void _toggle(String option, bool checked) {
    setState(() {
      if (checked) {
        if (!selectedDisturbances.contains(option)) {
          selectedDisturbances.add(option);
        }
      } else {
        selectedDisturbances.remove(option);
      }
    });

    widget.onChanged(List<String>.from(selectedDisturbances));
  }

  @override
  Widget build(BuildContext context) {
    return GlassCardLite(
      title: 'Disturbance Observed',
      child: Column(
        children: disturbanceOptions.map((option) {
          return CheckboxListTile(
            title: Text(option),
            value: selectedDisturbances.contains(option),
            onChanged: (checked) =>
                _toggle(option, checked ?? false),
          );
        }).toList(),
      ),
    );
  }
}
