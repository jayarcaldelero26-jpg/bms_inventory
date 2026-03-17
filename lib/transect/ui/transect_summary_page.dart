import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../legacy/transect_service.dart';
import '../../services/firestore_service.dart';

class TransectSummaryPage extends StatefulWidget {
  const TransectSummaryPage({super.key});

  @override
  State<TransectSummaryPage> createState() => _TransectSummaryPageState();
}

class _TransectSummaryPageState extends State<TransectSummaryPage> {
  final TransectService transect = TransectService();

  final TextEditingController notesCtrl = TextEditingController();

  DateTime conductedDate = DateTime.now();
  String selectedEcosystem = '';
  String observerName = '';

  bool isSaving = false;
  // ================= FORMAT TIME =================
  String _fmtTime(DateTime? d) {
    if (d == null) return "--";
    return DateFormat('HH:mm:ss').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF4),
      appBar: AppBar(
        title: const Text("Transect Summary"),
        backgroundColor: Colors.green.shade700,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ================= METADATA =================
            _section("Survey Metadata"),
            _data("BMS Location", transect.bmsLocation ?? "--"),
            _data("Assessment Period", transect.assessmentPeriod ?? "--"),
            _data(
              "Assessment Year",
              transect.assessmentYear?.toString() ?? "--",
            ),

            const SizedBox(height: 12),

            // ================= SURVEY INFO =================
            _section("Survey Info"),
            _data(
              "Date Conducted",
              DateFormat('yyyy-MM-dd').format(conductedDate),
            ),
            _data("Time Started", _fmtTime(transect.transectStart)),
            _data("Time Ended", _fmtTime(transect.transectEnd)),

            const SizedBox(height: 12),

            // ================= LOCATION =================
            _section("Location"),
            _data(
              "Start GPS",
              "${transect.startLat.toStringAsFixed(6)}, "
                  "${transect.startLng.toStringAsFixed(6)}",
            ),
            _data(
              "End GPS",
              "${transect.endLat.toStringAsFixed(6)}, "
                  "${transect.endLng.toStringAsFixed(6)}",
            ),

            const SizedBox(height: 12),

            // ================= STATS =================
            _section("Transect Stats"),
            _data(
              "Distance",
              "${(transect.distanceMeters / 1000).toStringAsFixed(2)} km",
            ),
            _data(
              "Elevation Min",
              "${transect.minElevation.toStringAsFixed(1)} m",
            ),
            _data(
              "Elevation Max",
              "${transect.maxElevation.toStringAsFixed(1)} m",
            ),

            const SizedBox(height: 12),

            // ================= FIELD NOTES =================
            _section("Field Conditions"),
            _data("Weather", transect.weather ?? "--"),
            _input("Notes", notesCtrl, maxLines: 3),

            const SizedBox(height: 24),

            // ================= SAVE =================
            _saveButton(),

            const SizedBox(height: 12),

            // ================= DELETE =================
            _deleteButton(),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _section(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(
        t,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _data(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
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

  Widget _input(String label, TextEditingController c, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ================= SAVE BUTTON =================

  Widget _saveButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSaving ? Colors.grey : Colors.green.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(isSaving ? "SAVING..." : "SAVE TRANSECT SUMMARY"),
        onPressed: isSaving
            ? null
            : () async {
                if (transect.activeTransectId == null) return;

                setState(() => isSaving = true);

                try {
                  final pendingLogs = await transect.pendingChildSyncLogs();
                  if (pendingLogs.isNotEmpty) {
                    final shouldContinue = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Unsynced Child Records'),
                        content: Text(
                          'This transect still has ${pendingLogs.length} pending or failed child sync item(s).\n\n'
                          'Finalize anyway and keep them queued for later sync?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Finalize Anyway'),
                          ),
                        ],
                      ),
                    );

                    if (shouldContinue != true) {
                      return;
                    }
                  }

                  // SET SUMMARY VALUES HERE (ONE TIME)
                  final t = TransectService();

                  // TEMPORARY FIX (para mawala ang null ug error)
                  t.ecosystemType = 'Mossy Forest';
                  t.observers = ['Francis Jerry B. Caldelero Jr.'];
                  t.speciesGroup = 'Flora';

                  await transect.saveSummary(
                    notes: notesCtrl.text,
                    conductedDate: conductedDate,
                  );

                  if (!mounted) return;

                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AlertDialog(
                      title: const Text("Success"),
                      content: const Text(
                        "Transect summary successfully saved.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // close dialog
                          },
                          child: const Text("Stay"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // close dialog
                            Navigator.popUntil(context, (r) => r.isFirst);
                          },
                          child: const Text("Back to Home"),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Save failed: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setState(() => isSaving = false);
                  }
                }
              },
      ),
    );
  }

  // ================= DELETE BUTTON =================

  Widget _deleteButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.delete),
        label: const Text("DELETE TRANSECT"),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Delete Transect"),
              content: const Text(
                "This will permanently delete the transect "
                "and all map data (route & species). Continue?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Delete"),
                ),
              ],
            ),
          );

          if (ok != true) return;

          final transectId = transect.activeTransectId;
          if (transectId == null) return;

          await FirestoreService.deleteTransect(transectId);
          await transect.deleteTransectFully(
            transectId,
            deleteRemote: false,
          );

          if (mounted) {
            Navigator.popUntil(context, (r) => r.isFirst);
          }
        },
      ),
    );
  }
}
