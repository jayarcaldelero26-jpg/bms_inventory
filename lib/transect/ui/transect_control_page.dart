import 'dart:async';
import 'package:flutter/material.dart';
import '../legacy/transect_service.dart';
import 'package:geolocator/geolocator.dart';

class TransectControlPage extends StatefulWidget {
  const TransectControlPage({super.key});

  @override
  State<TransectControlPage> createState() => _TransectControlPageState();
}

class _TransectControlPageState extends State<TransectControlPage> {
  final TextEditingController weatherCtrl = TextEditingController();
  final TransectService transect = TransectService();
  Timer? _uiTimer;

  // 🔥 TRANSECT METADATA
  String selectedBmsLocation = '';
  String selectedAssessmentPeriod = '';
  String selectedAssessmentYear = '';

  final bmsLocations = ['San Isidro', 'Governor Generoso', 'Mati City'];
  final assessmentPeriods = ['1st Assessment', '2nd Assessment'];

  late final List<String> assessmentYears = [
    DateTime.now().year.toString(),
    (DateTime.now().year - 1).toString(),
  ];

  @override
  void initState() {
    super.initState();
    transect.startPreviewLocation();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    weatherCtrl.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    final bool active = transect.hasActiveTransect;
    final DateTime? start = transect.transectStart;

    final Duration elapsed = (active && start != null)
        ? DateTime.now().difference(start)
        : Duration.zero;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text("Transect Mode"),
        backgroundColor: Colors.green.shade700,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _statusCard(active),
                  const SizedBox(height: 16),

                  // ================= WEATHER =================
                  TextField(
                    controller: weatherCtrl,
                    enabled: !active,
                    decoration: _dec(
                      "Weather",
                      "e.g. Sunny, Cloudy, Light rain",
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ================= BMS LOCATION =================
                  _dropdown(
                    label: "BMS Location",
                    value: selectedBmsLocation,
                    items: bmsLocations,
                    enabled: !active,
                    onChanged: (v) => setState(() => selectedBmsLocation = v),
                  ),

                  // ================= ASSESSMENT PERIOD =================
                  _dropdown(
                    label: "Assessment Period",
                    value: selectedAssessmentPeriod,
                    items: assessmentPeriods,
                    enabled: !active,
                    onChanged: (v) =>
                        setState(() => selectedAssessmentPeriod = v),
                  ),

                  // ================= ASSESSMENT YEAR =================
                  _dropdown(
                    label: "Assessment Year",
                    value: selectedAssessmentYear,
                    items: assessmentYears,
                    enabled: !active,
                    onChanged: (v) =>
                        setState(() => selectedAssessmentYear = v),
                  ),

                  const SizedBox(height: 20),

                  _dataCard(
                    "Start GPS",
                    active
                        ? "${transect.startLat.toStringAsFixed(5)}, ${transect.startLng.toStringAsFixed(5)}"
                        : "--",
                  ),
                  _dataCard(
                    "Current GPS",
                    "${transect.currentLat.toStringAsFixed(5)}, ${transect.currentLng.toStringAsFixed(5)}",
                  ),
                  _dataCard(
                    "Distance",
                    "${(transect.distanceMeters / 1000).toStringAsFixed(2)} km",
                  ),
                  _dataCard(
                    "Elevation",
                    "${transect.minElevation.toStringAsFixed(1)} – ${transect.maxElevation.toStringAsFixed(1)} m",
                  ),
                  _dataCard("Time Elapsed", _formatTime(elapsed)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: active ? _endButton() : _startButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  InputDecoration _dec(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        onChanged: enabled ? (v) => onChanged(v!) : null,
        decoration: _dec(label, "Select $label"),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }

  Widget _statusCard(bool active) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active ? Colors.green.shade700 : Colors.grey.shade400,
      ),
      child: Text(
        active ? "🟢 TRANSECT ACTIVE" : "⚪ NO ACTIVE TRANSECT",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _dataCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ================= BUTTONS =================

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
        icon: const Icon(Icons.play_arrow),
        label: const Text("START TRANSECT"),

        onPressed: () async {
          await Geolocator.requestPermission();
          if (weatherCtrl.text.trim().isEmpty ||
              selectedBmsLocation.isEmpty ||
              selectedAssessmentPeriod.isEmpty ||
              selectedAssessmentYear.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Fill all transect fields")),
            );
            return;
          }

          try {
            await transect.startTransect(
              weather: weatherCtrl.text.trim(),
              bmsLocation: selectedBmsLocation,
              assessmentPeriod: selectedAssessmentPeriod,
              assessmentYear: int.parse(selectedAssessmentYear),
            );

            // 🔥 AUTO ENABLE COMPASS
            transect.setCompassEnabled(true);

            // 🔙 BALIK SA MAP
            Navigator.pop(context);
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        },
      ),
    );
  }

  Widget _endButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        icon: const Icon(Icons.stop),
        label: const Text("END TRANSECT"),
        onPressed: () async {
          try {
            await transect.endTransect();
          } catch (e) {
            // ignore error
          }

          Navigator.pushReplacementNamed(context, '/transect-summary');
        },
      ),
    );
  }
}
