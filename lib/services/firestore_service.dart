import 'package:cloud_firestore/cloud_firestore.dart';
import '../transect/legacy/transect_service.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ================= UNIVERSAL SAVE =================
  static Future<void> saveRecord({
    required String collection,
    required Map<String, dynamic> payload,
    String? docId,
  }) async {
    final transect = TransectService();
    final missingContext = transect.missingRecordContextFields;

    if (missingContext.isNotEmpty) {
      throw 'Incomplete transect context: ${missingContext.join(', ')}';
    }

    // 🔥 Inject transect + BMS metadata
    payload['transectId'] ??= transect.activeTransectId;
    payload['bmsLocation'] ??= transect.bmsLocation;
    payload['assessmentPeriod'] ??= transect.assessmentPeriod;
    payload['assessmentYear'] ??= transect.assessmentYear;
    payload['transectStart'] = transect.transectStart?.toIso8601String();
    payload['distanceAtCapture'] = transect.distanceMeters;

    payload['updatedAt'] = FieldValue.serverTimestamp();

    payload.removeWhere((k, v) => v == null);

    if (docId == null) {
      await _db.collection(collection).add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db
          .collection(collection)
          .doc(docId)
          .set(payload, SetOptions(merge: true));
    }
  }

  // ================= DELETE TRANSECT =================
  static Future<void> deleteTransect(String transectId) async {
    Future<void> _deleteChildren(String col) async {
      final snap = await _db
          .collection(col)
          .where('transectId', isEqualTo: transectId)
          .get();

      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    final pointsSnap = await _db
        .collection('transects')
        .doc(transectId)
        .collection('points')
        .get();
    for (final doc in pointsSnap.docs) {
      await doc.reference.delete();
    }
    await _deleteChildren('species_records');
    await _deleteChildren('threat_records');
    await _deleteChildren('habitat_records');
    await _deleteChildren('human_activity_records');

    await _db.collection('transects').doc(transectId).delete();
  }

  // ================= COUNTS =================
  static Stream<int> count(String collection, {String? transectId}) {
    Query q = _db.collection(collection);
    if (transectId != null) {
      q = q.where('transectId', isEqualTo: transectId);
    }
    return q.snapshots().map((s) => s.docs.length);
  }
}
