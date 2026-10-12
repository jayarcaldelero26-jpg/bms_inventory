import 'package:flutter/material.dart';

import 'demo_data.dart';
import 'routing_models.dart';
import 'screens.dart';

/// An opt-in, fictional preview. It never sends requests or writes device data.
class CdsDemoHome extends StatefulWidget {
  const CdsDemoHome({super.key});

  @override
  State<CdsDemoHome> createState() => _CdsDemoHomeState();
}

class _CdsDemoHomeState extends State<CdsDemoHome> {
  int section = 0;
  int queueIndex = 0;
  int page = 0;
  String query = '';
  String source = 'All';
  final notifications = <DemoNotification>[
    DemoNotification(
      id: 1,
      message: 'A sample submission is awaiting office action.',
    ),
    DemoNotification(id: 2, message: 'A sample document was forwarded.'),
  ];

  void chooseQueue(int value) => setState(() {
    queueIndex = value;
    page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((item) => !item.read).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CDS-SMART · DEMO'),
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('$unread unread')),
            ),
        ],
      ),
      body: Column(
        children: [
          MaterialBanner(
            content: const Text(
              'Fictional demo data. No account is signed in or connected to CDS-SMART.',
            ),
            leading: const Icon(Icons.science_outlined),
            actions: [TextButton(onPressed: () {}, child: const Text('DEMO'))],
          ),
          Expanded(
            child: switch (section) {
              0 => _dashboard(),
              1 => _tracking(),
              2 => _notificationList(),
              _ => _profile(),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: section,
        onDestinationSelected: (value) => setState(() => section = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Tracking',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _dashboard() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Submission overview',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Example counts only. Real counts require server authorization.',
      ),
      const SizedBox(height: 16),
      for (final queue in SubmissionQueue.values)
        Card(
          child: ListTile(
            title: Text(queue.label),
            subtitle: Text(queue.description),
            trailing: Text(
              '${demoDocuments.where((item) => item.queue == queue.key).length}',
            ),
            onTap: () => setState(() {
              section = 1;
              queueIndex = SubmissionQueue.values.indexOf(queue);
              page = 0;
            }),
          ),
        ),
    ],
  );

  Widget _tracking() {
    final queue = SubmissionQueue.values[queueIndex];
    final results = filterDemoDocuments(
      queue: queue.key,
      query: query,
      source: source,
    );
    const pageSize = 5;
    final pageCount = results.isEmpty
        ? 1
        : (results.length + pageSize - 1) ~/ pageSize;
    final safePage = page < 0 ? 0 : (page >= pageCount ? pageCount - 1 : page);
    final visible = results.skip(safePage * pageSize).take(pageSize);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Submission Tracking',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (var index = 0; index < SubmissionQueue.values.length; index++)
              ChoiceChip(
                label: Text(SubmissionQueue.values[index].label),
                selected: index == queueIndex,
                onSelected: (_) => chooseQueue(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(queue.description),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search title or reference',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {
            query = value;
            page = 0;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: source,
          decoration: const InputDecoration(
            labelText: 'Source',
            border: OutlineInputBorder(),
          ),
          items:
              [
                    'All',
                    ...{for (final item in demoDocuments) item.source},
                  ]
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: (value) => setState(() {
            source = value ?? 'All';
            page = 0;
          }),
        ),
        const SizedBox(height: 16),
        if (results.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No matching sample documents.'),
            ),
          )
        else
          for (final item in visible)
            Card(
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(
                  '${item.reference} · ${item.status}\nCustody: ${item.custody}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _DemoDetail(document: item),
                  ),
                ),
              ),
            ),
        if (results.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: safePage > 0 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${safePage + 1} / $pageCount'),
              IconButton(
                tooltip: 'Next page',
                onPressed: safePage + 1 < pageCount
                    ? () => setState(() => page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }

  Widget _notificationList() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Read state is held in memory for this demo only.'),
      for (final item in notifications)
        Card(
          child: ListTile(
            leading: Icon(
              item.read
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
            ),
            title: Text(item.message),
            subtitle: Text(item.read ? 'Read' : 'Unread'),
            trailing: TextButton(
              onPressed: () => setState(() => item.read = !item.read),
              child: Text(item.read ? 'Mark unread' : 'Mark read'),
            ),
          ),
        ),
    ],
  );

  Widget _profile() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
      const Card(
        child: ListTile(
          leading: Icon(Icons.person_outline),
          title: Text('Demo visitor'),
          subtitle: Text('No authenticated account or permissions'),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.tonal(
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) {
              final origin = const String.fromEnvironment('CDS_API_BASE_URL');
              return CdsSmartHome(
                baseUrl: origin.isEmpty ? null : Uri.tryParse(origin),
              );
            },
          ),
        ),
        child: const Text('Exit demo'),
      ),
    ],
  );
}

class _DemoDetail extends StatelessWidget {
  const _DemoDetail({required this.document});

  final DemoDocument document;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Document details · DEMO')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(document.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _field('Reference', document.reference),
        _field('Source', document.source),
        _field('Status', document.status),
        _field('Current custody', document.custody),
        const SizedBox(height: 18),
        Text('Routing history', style: Theme.of(context).textTheme.titleLarge),
        for (final event in document.events)
          Card(
            child: ListTile(
              title: Text(event.eventKey),
              subtitle: Text(
                '${event.fromOffice ?? 'Origin'} → ${event.toOffice ?? 'Destination'}\n${formatRoutingEventTimestamp(event.occurredAt)}',
              ),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: 16),
        Text('Review history', style: Theme.of(context).textTheme.titleLarge),
        if (document.review != null)
          Card(
            child: ListTile(
              title: Text(document.review!.eventKey.replaceAll('_', ' ')),
              subtitle: Text(document.review!.remarks ?? 'No remarks'),
            ),
          )
        else
          const Text('No sample review events.'),
        const SizedBox(height: 12),
        const Text(
          'A review verdict does not move custody. Only a routing event changes the recorded office.',
        ),
        const SizedBox(height: 18),
        Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
        if (document.attachmentName != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(document.attachmentName!),
              subtitle: const Text(
                'Preview unavailable in demo; protected API required.',
              ),
            ),
          )
        else
          const Text('No sample attachment.'),
      ],
    ),
  );

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$label: $value'),
  );
}
