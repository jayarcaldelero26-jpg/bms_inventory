// Fictional, compile-time-only data for exercising the view layer. Never use
// this as a fallback for failed API requests or as an authorization source.
import 'routing_models.dart';

class DemoDocument {
  const DemoDocument({
    required this.id,
    required this.title,
    required this.reference,
    required this.source,
    required this.queue,
    required this.status,
    required this.custody,
    required this.updatedAt,
    required this.events,
    this.review,
    this.attachmentName,
  });

  final int id;
  final String title;
  final String reference;
  final String source;
  final String queue;
  final String status;
  final String custody;
  final DateTime updatedAt;
  final List<DocumentRoutingEvent> events;
  final PambMovReviewEvent? review;
  final String? attachmentName;
}

class DemoNotification {
  DemoNotification({required this.id, required this.message, this.read = false});

  final int id;
  final String message;
  bool read;
}

final demoDocuments = <DemoDocument>[
  DemoDocument(
    id: 1,
    title: 'Protected area conservation report',
    reference: 'DEMO-2026-001',
    source: 'Conservation',
    queue: 'incoming',
    status: 'Awaiting office action',
    custody: 'PENRO Sample',
    updatedAt: DateTime.utc(2026, 10, 10),
    attachmentName: 'sample-report.pdf',
    events: [
      DocumentRoutingEvent(
        sourceType: 'conservation',
        sourceId: 1,
        workflowKey: 'pamb-meeting',
        eventKey: 'received',
        fromOffice: 'CENRO Sample',
        toOffice: 'PENRO Sample',
        occurredAt: DateTime.utc(2026, 10, 10),
      ),
    ],
    review: const PambMovReviewEvent(
      eventKey: 'needs_correction',
      remarks: 'Replace the sample MOV.',
    ),
  ),
  DemoDocument(
    id: 2,
    title: 'Biodiversity monitoring submission',
    reference: 'DEMO-2026-002',
    source: 'BMS',
    queue: 'outgoing',
    status: 'Forwarded',
    custody: 'Regional Office Sample',
    updatedAt: DateTime.utc(2026, 10, 8),
    events: [
      DocumentRoutingEvent(
        sourceType: 'bms',
        sourceId: 2,
        workflowKey: 'standard',
        eventKey: 'forwarded',
        fromOffice: 'PENRO Sample',
        toOffice: 'Regional Office Sample',
        occurredAt: DateTime.utc(2026, 10, 8),
      ),
    ],
  ),
  DemoDocument(
    id: 3,
    title: 'Technical assessment report',
    reference: 'DEMO-2026-003',
    source: 'Technical Report',
    queue: 'history',
    status: 'Completed',
    custody: 'Records Office Sample',
    updatedAt: DateTime.utc(2026, 10, 1),
    events: [
      DocumentRoutingEvent(
        sourceType: 'technical_report',
        sourceId: 3,
        workflowKey: 'standard',
        eventKey: 'completed',
        toOffice: 'Records Office Sample',
        occurredAt: DateTime.utc(2026, 10, 1),
      ),
    ],
  ),
  for (var number = 4; number <= 9; number++)
    DemoDocument(
      id: number,
      title: 'Sample conservation submission $number',
      reference: 'DEMO-2026-${number.toString().padLeft(3, '0')}',
      source: 'Conservation',
      queue: 'incoming',
      status: 'Awaiting office action',
      custody: 'PENRO Sample',
      updatedAt: DateTime.utc(2026, 10, 10),
      events: [
        DocumentRoutingEvent(
          sourceType: 'conservation',
          sourceId: number,
          workflowKey: 'pamb-meeting',
          eventKey: 'received',
          toOffice: 'PENRO Sample',
          occurredAt: DateTime.utc(2026, 10, 10),
        ),
      ],
    ),
];

List<DemoDocument> filterDemoDocuments({
  required String queue,
  String query = '',
  String source = 'All',
}) {
  final normalized = query.trim().toLowerCase();
  return demoDocuments.where((document) {
    return document.queue == queue &&
        (source == 'All' || document.source == source) &&
        (normalized.isEmpty ||
            '${document.title} ${document.reference} ${document.source}'
                .toLowerCase()
                .contains(normalized));
  }).toList(growable: false);
}
