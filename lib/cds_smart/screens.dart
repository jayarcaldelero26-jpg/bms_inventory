import 'package:flutter/material.dart';

import 'routing_models.dart';

class CdsSmartHome extends StatelessWidget {
  const CdsSmartHome({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: SubmissionQueue.values.length,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'CDS-SMART',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .4),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Image.asset(
                'assets/images/cds_logo.png',
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.eco_outlined, size: 52),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'CDS-SMART Mobile',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'A mobile view for authorized submission tracking.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const _IntegrationStatusCard(),
            const SizedBox(height: 24),
            Text(
              'Submission Tracking',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Incoming'),
                Tab(text: 'Outgoing'),
                Tab(text: 'History'),
              ],
            ),
            SizedBox(
              height: 190,
              child: TabBarView(
                children: SubmissionQueue.values
                    .map((queue) => _QueuePendingCard(queue: queue))
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 12),
            const _PendingFeatureCard(
              icon: Icons.notifications_none,
              title: 'Notifications',
              message:
                  'Read/unread notifications will appear after a user-scoped mobile API is available.',
            ),
            const SizedBox(height: 12),
            const _PendingFeatureCard(
              icon: Icons.manage_search_outlined,
              title: 'Search, details, and attachments',
              message:
                  'Authorized search, custody details, separate review history, and protected previews require the mobile API.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Review verdicts and custody transfers are separate records. '
              'A review result does not by itself change a document office or location.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _IntegrationStatusCard extends StatelessWidget {
  const _IntegrationStatusCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend integration pending',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'The verified CDS-SMART source exposes session-authenticated '
                  'web/Inertia routes, not a mobile API. No sign-in or document '
                  'data is requested or shown by this build.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _QueuePendingCard extends StatelessWidget {
  const _QueuePendingCard({required this.queue});

  final SubmissionQueue queue;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(queue.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(queue.description),
          const Spacer(),
          const Text(
            'Records are unavailable until the server provides this authorized queue.',
          ),
        ],
      ),
    ),
  );
}

class _PendingFeatureCard extends StatelessWidget {
  const _PendingFeatureCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(message),
      ),
    ),
  );
}
