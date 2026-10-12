import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'mobile_api.dart';
import 'routing_models.dart';

class CdsSmartHome extends StatefulWidget {
  const CdsSmartHome({super.key, this.baseUrl});

  final Uri? baseUrl;

  @override
  State<CdsSmartHome> createState() => _CdsSmartHomeState();
}

class _CdsSmartHomeState extends State<CdsSmartHome> {
  late final MobileApiClient? _api;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _filters = <String, TextEditingController>{
    for (final key in const [
      'search',
      'module',
      'protected_area_id',
      'target_office',
      'reporting_period',
      'reporting_year',
      'status',
    ])
      key: TextEditingController(),
  };

  bool _loading = true;
  bool _busy = false;
  int _section = 0;
  int _queueIndex = 0;
  int _page = 1;
  String? _error;
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _counts = const {};
  PaginatedData<Map<String, dynamic>>? _submissions;
  PaginatedData<Map<String, dynamic>>? _notifications;

  @override
  void initState() {
    super.initState();
    final baseUrl = widget.baseUrl;
    MobileApiClient? api;
    try {
      if (baseUrl != null) {
        api = MobileApiClient(baseUrl: baseUrl, tokenStore: SecureTokenStore());
      }
    } on ArgumentError {
      api = null;
    }
    _api = api;
    if (_api == null) {
      _loading = false;
    } else {
      _restore();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    for (final controller in _filters.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    final api = _api;
    if (api == null) return;
    try {
      await api.restoreSession();
      if (api.accountId != null) {
        _profile = await api.profile();
        await _loadDashboard();
      }
    } on SessionExpiredException catch (error) {
      _error = error.message;
      _clearAccountData();
    } on Exception catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is MobileApiException
      ? error.message
      : 'Could not reach the CDS-SMART service. Check your connection and try again.';

  Map<String, String> get _filterValues => {
    for (final entry in _filters.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.value.text.trim(),
  };

  void _clearAccountData() {
    _profile = null;
    _counts = const {};
    _submissions = null;
    _notifications = null;
    _page = 1;
    for (final controller in _filters.values) {
      controller.clear();
    }
  }

  Future<void> _signIn() async {
    if (_api == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _clearAccountData();
      _profile = await _api.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      _password.clear();
      try {
        await _loadDashboard();
      } on Exception catch (error) {
        _error = _message(error);
        if (error is SessionExpiredException) _clearAccountData();
      }
    } on Exception catch (error) {
      _error = _message(error);
      _clearAccountData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadDashboard() async {
    _counts = await _api!.dashboard(filters: _filterValues);
  }

  Future<void> _loadQueue({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _submissions = await _api!.submissions(
        queue: SubmissionQueue.values[_queueIndex].key,
        page: _page,
        filters: _filterValues,
      );
    } on Exception catch (error) {
      _error = _message(error);
      if (error is SessionExpiredException) _clearAccountData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadNotifications({int page = 1}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _notifications = await _api!.notifications(page: page);
    } on Exception catch (error) {
      _error = _message(error);
      if (error is SessionExpiredException) _clearAccountData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_section == 0) {
        await _loadDashboard();
      } else if (_section == 1) {
        _submissions = await _api!.submissions(
          queue: SubmissionQueue.values[_queueIndex].key,
          page: _page,
          filters: _filterValues,
        );
      } else if (_section == 2) {
        _notifications = await _api!.notifications(
          page: _notifications?.currentPage ?? 1,
        );
      } else {
        _profile = await _api!.profile();
      }
    } on Exception catch (error) {
      _error = _message(error);
      if (error is SessionExpiredException) _clearAccountData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _api!.logout();
    } on Exception catch (error) {
      _error = 'Signed out locally. ${_message(error)}';
    }
    _clearAccountData();
    if (mounted) setState(() {});
  }

  void _selectSection(int value) {
    setState(() {
      _section = value;
      _error = null;
    });
    if (value == 0) {
      _refresh();
    } else if (value == 1) {
      _loadQueue(resetPage: true);
    } else if (value == 2) {
      _loadNotifications();
    } else {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_api == null) return _configurationRequired();
    if (_profile == null) return _loginScreen();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CDS-SMART'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null) _errorBanner(_error!),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: switch (_section) {
              0 => _overview(),
              1 => _tracking(),
              2 => _notificationView(),
              _ => _profileView(),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: _selectSection,
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

  Widget _configurationRequired() => Scaffold(
    appBar: AppBar(title: const Text('CDS-SMART')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'API connection is not configured. Set CDS_API_BASE_URL to the HTTPS origin for the CDS-SMART installation, then restart the app.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _loginScreen() => Scaffold(
    appBar: AppBar(title: const Text('CDS-SMART · Sign in')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.eco_outlined, size: 64),
        const SizedBox(height: 12),
        Text(
          'Authorized mobile access',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use an active, approved, and email-verified CDS-SMART account.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_error != null) _errorBanner(_error!),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _busy ? null : _signIn(),
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: 12),
        const Text(
          'This client never uses demo records after a sign-in or service error.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _overview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Submission overview',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text('Signed in as ${_profile?['name'] ?? ''}'),
      const SizedBox(height: 16),
      for (final queue in SubmissionQueue.values)
        Card(
          child: ListTile(
            title: Text(queue.label),
            subtitle: Text(queue.description),
            trailing: Text(
              '${_counts[queue.key] ?? '—'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            onTap: () {
              setState(() {
                _section = 1;
                _queueIndex = SubmissionQueue.values.indexOf(queue);
              });
              _loadQueue(resetPage: true);
            },
          ),
        ),
      const SizedBox(height: 12),
      _filtersPanel(
        onApply: () async {
          setState(() => _busy = true);
          try {
            await _loadDashboard();
          } on Exception catch (error) {
            _error = _message(error);
            if (error is SessionExpiredException) _clearAccountData();
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
      ),
    ],
  );

  Widget _tracking() {
    final pageData = _submissions;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Submission tracking',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (var index = 0; index < SubmissionQueue.values.length; index++)
              ChoiceChip(
                label: Text(SubmissionQueue.values[index].label),
                selected: _queueIndex == index,
                onSelected: (_) {
                  setState(() => _queueIndex = index);
                  _loadQueue(resetPage: true);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        _filtersPanel(onApply: () => _loadQueue(resetPage: true)),
        const SizedBox(height: 12),
        if (_busy && pageData == null)
          const Center(child: CircularProgressIndicator())
        else if (pageData == null)
          const SizedBox.shrink()
        else if (pageData.items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No submissions match these filters.'),
            ),
          )
        else ...[
          Text('${pageData.total} records'),
          for (final item in pageData.items)
            Card(
              child: ListTile(
                title: Text(
                  '${item['tracking_number'] ?? item['activity_name'] ?? item['module'] ?? 'Submission'}',
                ),
                subtitle: Text(
                  [
                        item['module'],
                        item['submission_status'] ?? item['current_status'],
                        item['current_location'],
                      ]
                      .where((value) => value != null && '$value'.isNotEmpty)
                      .join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openDocument(item),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: pageData.currentPage > 1
                    ? () {
                        setState(() => _page--);
                        _loadQueue();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${pageData.currentPage} / ${pageData.lastPage}'),
              IconButton(
                tooltip: 'Next page',
                onPressed: pageData.currentPage < pageData.lastPage
                    ? () {
                        setState(() => _page++);
                        _loadQueue();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _filtersPanel({required VoidCallback onApply}) => ExpansionTile(
    title: const Text('Filters'),
    children: [
      for (final field in const [
        ('search', 'Search'),
        ('module', 'Module'),
        ('protected_area_id', 'Protected area ID'),
        ('target_office', 'Target office'),
        ('reporting_period', 'Reporting period'),
        ('reporting_year', 'Reporting year'),
        ('status', 'Status'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _filters[field.$1],
            keyboardType:
                const {'protected_area_id', 'reporting_year'}.contains(field.$1)
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: field.$2,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.tonal(
          onPressed: _busy ? null : onApply,
          child: const Text('Apply filters'),
        ),
      ),
    ],
  );

  Widget _notificationView() {
    final pageData = _notifications;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
        if (pageData == null && _busy)
          const Center(child: CircularProgressIndicator())
        else if (pageData == null)
          const SizedBox.shrink()
        else if (pageData.items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No notifications.'),
            ),
          )
        else ...[
          for (final notification in pageData.items)
            Card(
              child: ListTile(
                leading: Icon(
                  notification['read_at'] == null
                      ? Icons.mark_email_unread_outlined
                      : Icons.mark_email_read_outlined,
                ),
                title: Text('${notification['title'] ?? 'Notification'}'),
                subtitle: Text('${notification['message'] ?? ''}'),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _setNotificationRead(
                          notification,
                          notification['read_at'] == null,
                        ),
                  child: Text(
                    notification['read_at'] == null
                        ? 'Mark read'
                        : 'Mark unread',
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: pageData.currentPage > 1
                    ? () => _loadNotifications(page: pageData.currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${pageData.currentPage} / ${pageData.lastPage}'),
              IconButton(
                onPressed: pageData.currentPage < pageData.lastPage
                    ? () => _loadNotifications(page: pageData.currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _setNotificationRead(
    Map<String, dynamic> notification,
    bool read,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api!.setNotificationRead('${notification['id']}', read);
      await _loadNotifications(page: _notifications?.currentPage ?? 1);
    } on Exception catch (error) {
      _error = _message(error);
      if (error is SessionExpiredException) _clearAccountData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _profileView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
      Card(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text('${_profile?['name'] ?? ''}'),
          subtitle: Text(
            [
              _profile?['email'],
              _profile?['actor_category'],
              _profile?['office'],
            ].where((value) => value != null && '$value'.isNotEmpty).join('\n'),
          ),
          isThreeLine: true,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.tonal(
        onPressed: _busy ? null : _logout,
        child: const Text('Sign out'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Access and visible records are determined by the server for each request.',
      ),
    ],
  );

  Future<void> _openDocument(Map<String, dynamic> item) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await _api!.document(
        '${item['source']}',
        (item['source_record_id'] as num).toInt(),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _DocumentDetailPage(
            document: detail,
            api: _api,
            onExpired: () {
              _clearAccountData();
              if (mounted) {
                setState(() => _error = 'Session expired. Sign in again.');
              }
            },
          ),
        ),
      );
    } on Exception catch (error) {
      _error = _message(error);
      if (error is SessionExpiredException) _clearAccountData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _errorBanner(String message) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _DocumentDetailPage extends StatelessWidget {
  const _DocumentDetailPage({
    required this.document,
    required this.api,
    required this.onExpired,
  });

  final Map<String, dynamic> document;
  final MobileApiClient api;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Document details')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${document['tracking_number'] ?? document['activity_name'] ?? document['module'] ?? 'Submission'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        _detailField('Module', document['module']),
        _detailField('Status', document['submission_status']),
        _detailField('Current status', document['current_status']),
        _detailField('Current location', document['current_location']),
        _detailField('Read only', document['read_only'] == true ? 'Yes' : '—'),
        const SizedBox(height: 12),
        Text('Current custody', style: Theme.of(context).textTheme.titleLarge),
        _detailMap(document['current_custody']),
        const SizedBox(height: 12),
        Text('Routing history', style: Theme.of(context).textTheme.titleLarge),
        _eventList(document['routing_events'], false),
        const SizedBox(height: 12),
        Text('Review history', style: Theme.of(context).textTheme.titleLarge),
        _detailMap(document['review']),
        _eventList(document['review_events'], true),
        const SizedBox(height: 12),
        Text(
          'Protected attachments',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ..._attachments(context),
      ],
    ),
  );

  List<Widget> _attachments(BuildContext context) {
    final attachments = document['attachments'];
    if (attachments is! List || attachments.isEmpty) {
      return const [Text('No attachments available to this account.')];
    }
    return attachments
        .whereType<Map<String, dynamic>>()
        .map((attachment) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(
                '${attachment['filename'] ?? attachment['name'] ?? 'Protected file'}',
              ),
              subtitle: Text(
                '${attachment['mime_type'] ?? 'Protected attachment'}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) =>
                    _fetchAttachment(context, attachment, action == 'preview'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'preview', child: Text('Preview')),
                  PopupMenuItem(
                    value: 'download',
                    child: Text('Download / share'),
                  ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  Future<void> _fetchAttachment(
    BuildContext context,
    Map<String, dynamic> attachment,
    bool preview,
  ) async {
    try {
      final attachmentSource = api.attachmentSourceForDocument(
        '${document['source']}',
      );
      final key = attachment['key'];
      final recordId = document['source_record_id'];
      if (attachmentSource == null || key is! String || recordId is! num) {
        throw const MobileApiException(
          'Attachment metadata is incomplete for this document.',
        );
      }
      final metadata = await api.attachmentMetadata(
        source: attachmentSource,
        recordId: recordId.toInt(),
        attachmentKey: key,
      );
      final url = metadata[preview ? 'preview_url' : 'download_url'];
      if (url is! String) {
        throw const MobileApiException(
          'The server did not provide an attachment URL.',
        );
      }
      final http.Response response = await api.attachmentContent(url);
      final mimeType = response.headers['content-type']?.split(';').first;
      final filename =
          '${metadata['name'] ?? attachment['name'] ?? 'attachment'}';
      final bytes = response.bodyBytes;
      if (!context.mounted) return;
      if (preview && mimeType?.startsWith('image/') == true) {
        await showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(Uint8List.fromList(bytes)),
            ),
          ),
        );
      } else if (preview) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Protected preview'),
            content: Text(
              'The server authorized this ${mimeType ?? 'file'} (${bytes.length} bytes). This file type cannot be previewed in-app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _share(bytes, mimeType, filename);
                },
                child: const Text('Share file'),
              ),
            ],
          ),
        );
      } else {
        await _share(bytes, mimeType, filename);
      }
    } on SessionExpiredException {
      onExpired();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Sign in again.')),
        );
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is MobileApiException
                  ? error.message
                  : 'Unable to retrieve this protected attachment.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _share(List<int> bytes, String? mimeType, String filename) =>
      Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: mimeType,
          name: filename,
        ),
      ], subject: filename);

  Widget _detailField(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text('$label: ${value ?? '—'}'),
  );

  Widget _detailMap(Object? value) {
    if (value is! Map) return const Text('No recorded data.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in value.entries)
              if (entry.value != null && entry.value.toString().isNotEmpty)
                _detailField(
                  entry.key.toString().replaceAll('_', ' '),
                  entry.value,
                ),
          ],
        ),
      ),
    );
  }

  Widget _eventList(Object? value, bool review) {
    if (value is! List || value.isEmpty) {
      return const Text('No events recorded.');
    }
    return Column(
      children: value
          .whereType<Map>()
          .map((event) {
            final title =
                event[review ? 'event_label' : 'label'] ??
                event[review ? 'event_key' : 'event_type'] ??
                'Recorded event';
            final time = event['recorded_at'] ?? event['occurred_at'];
            final route = [
              event['from'],
              event['to'],
            ].where((value) => value != null).join(' → ');
            return Card(
              child: ListTile(
                title: Text('$title'),
                subtitle: Text(
                  [
                    if (route.isNotEmpty) route,
                    if (event['remarks'] != null) '${event['remarks']}',
                    if (time != null) '$time',
                  ].join('\n'),
                ),
                isThreeLine: true,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
