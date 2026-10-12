import 'package:cds_smart_mobile/cds_smart/routing_models.dart';
import 'package:cds_smart_mobile/cds_smart/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test('submission queues use the verified web definitions', () {
    expect(
      SubmissionQueue.fromKey('incoming').description,
      'Documents currently requiring action from your office.',
    );
    expect(
      SubmissionQueue.fromKey('outgoing').description,
      'Documents your office has acted on and forwarded to the next office.',
    );
    expect(
      SubmissionQueue.fromKey('history').description,
      'Completed routing records within your authorized scope.',
    );
  });

  test(
    'routing events carry custody offices independently of review events',
    () {
      final routing = DocumentRoutingEvent.fromJson({
        'source_type': 'conservation',
        'source_id': 42,
        'workflow_key': 'pamb-meeting',
        'event_key': 'received_by_penro',
        'from_office': 'CENRO Sample',
        'to_office': 'PENRO Sample',
        'occurred_at': '2026-10-10T09:30:00Z',
        'recorded_by': 7,
      });
      final review = PambMovReviewEvent.fromJson({
        'event_key': 'needs_correction',
        'remarks': 'Update the MOV.',
        'recorded_by': 8,
      });

      expect(routing.toOffice, 'PENRO Sample');
      expect(routing.eventKey, 'received_by_penro');
      expect(review.eventKey, 'needs_correction');
      expect(review.remarks, 'Update the MOV.');
    },
  );

  test(
    'routing timestamps format locally and handle missing or invalid values',
    () {
      final event = DocumentRoutingEvent.fromJson({
        'source_type': 'conservation',
        'source_id': 43,
        'workflow_key': 'pamb-meeting',
        'event_key': 'received',
        'occurred_at': '2026-10-10T00:00:00Z',
      });
      final invalidEvent = DocumentRoutingEvent.fromJson({
        'source_type': 'conservation',
        'source_id': 44,
        'workflow_key': 'pamb-meeting',
        'event_key': 'received',
        'occurred_at': 'not-a-timestamp',
      });
      final missingEvent = DocumentRoutingEvent.fromJson({
        'source_type': 'conservation',
        'source_id': 45,
        'workflow_key': 'pamb-meeting',
        'event_key': 'received',
      });

      expect(
        formatRoutingEventTimestamp(event.occurredAt),
        DateFormat.yMMMd().add_jm().format(event.occurredAt!.toLocal()),
      );
      expect(
        formatRoutingEventTimestamp(event.occurredAt),
        isNot(contains('T00:00:00')),
      );
      expect(
        formatRoutingEventTimestamp(invalidEvent.occurredAt),
        'Date unavailable',
      );
      expect(
        formatRoutingEventTimestamp(missingEvent.occurredAt),
        'Date unavailable',
      );
    },
  );

  test('demo search stays within the selected queue and source', () {
    final incoming = filterDemoDocuments(
      queue: 'incoming',
      query: 'DEMO-2026-001',
    );
    expect(incoming.map((item) => item.reference), ['DEMO-2026-001']);
    expect(filterDemoDocuments(queue: 'incoming'), hasLength(7));
    expect(filterDemoDocuments(queue: 'incoming', source: 'BMS'), isEmpty);
    expect(
      filterDemoDocuments(queue: 'history', query: 'assessment').single.id,
      3,
    );
  });

  test('a review verdict does not change the sample custody office', () {
    final document = demoDocuments.first;
    expect(document.review?.eventKey, 'needs_correction');
    expect(document.custody, document.events.last.toOffice);
  });
}
