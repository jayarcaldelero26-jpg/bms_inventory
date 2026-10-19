import 'package:intl/intl.dart';

class SubmissionQueue {
  const SubmissionQueue({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;

  static const incoming = SubmissionQueue(
    key: 'incoming',
    label: 'Incoming',
    description: 'Documents currently requiring action from your office.',
  );

  static const outgoing = SubmissionQueue(
    key: 'outgoing',
    label: 'Outgoing',
    description:
        'Documents your office has acted on and forwarded to the next office.',
  );

  static const history = SubmissionQueue(
    key: 'history',
    label: 'History',
    description: 'Completed routing records within your authorized scope.',
  );

  static const values = [incoming, outgoing, history];

  static SubmissionQueue fromKey(String key) =>
      values.firstWhere((queue) => queue.key == key);
}

String formatRoutingEventTimestamp(DateTime? timestamp) {
  if (timestamp == null) return 'Date unavailable';
  return DateFormat.yMMMd().add_jm().format(timestamp.toLocal());
}

class DocumentRoutingEvent {
  const DocumentRoutingEvent({
    required this.sourceType,
    required this.sourceId,
    required this.workflowKey,
    required this.eventKey,
    this.fromStage,
    this.toStage,
    this.fromOffice,
    this.toOffice,
    this.occurredAt,
    this.recordedBy,
    this.remarks,
  });

  final String sourceType;
  final int sourceId;
  final String workflowKey;
  final String eventKey;
  final String? fromStage;
  final String? toStage;
  final String? fromOffice;
  final String? toOffice;
  final DateTime? occurredAt;
  final int? recordedBy;
  final String? remarks;

  factory DocumentRoutingEvent.fromJson(Map<String, dynamic> json) =>
      DocumentRoutingEvent(
        sourceType: json['source_type'] as String? ?? '',
        sourceId: (json['source_id'] as num).toInt(),
        workflowKey: json['workflow_key'] as String? ?? '',
        eventKey: json['event_key'] as String? ?? '',
        fromStage: json['from_stage'] as String?,
        toStage: json['to_stage'] as String?,
        fromOffice: json['from_office'] as String?,
        toOffice: json['to_office'] as String?,
        occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
        recordedBy: (json['recorded_by'] as num?)?.toInt(),
        remarks: json['remarks'] as String?,
      );
}

class PambMovReviewEvent {
  const PambMovReviewEvent({
    required this.eventKey,
    this.remarks,
    this.recordedBy,
  });

  final String eventKey;
  final String? remarks;
  final int? recordedBy;

  factory PambMovReviewEvent.fromJson(Map<String, dynamic> json) =>
      PambMovReviewEvent(
        eventKey: json['event_key'] as String? ?? '',
        remarks: json['remarks'] as String?,
        recordedBy: (json['recorded_by'] as num?)?.toInt(),
      );
}
