import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'mobile_api.dart';
import 'protected_pdf_preview.dart';
import 'routing_models.dart';
import 'ui_components.dart';

class CdsSmartHome extends StatefulWidget {
  const CdsSmartHome({
    super.key,
    this.baseUrl,
    this.apiClient,
    this.tokenStore,
    this.transport,
  });

  final Uri? baseUrl;
  final MobileApiClient? apiClient;
  final TokenStore? tokenStore;
  final http.Client? transport;

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

  @override
  void initState() {
    super.initState();
    final baseUrl = widget.baseUrl;
    MobileApiClient? api = widget.apiClient;
    try {
      if (api == null && baseUrl != null) {
        api = MobileApiClient(
          baseUrl: baseUrl,
          tokenStore: widget.tokenStore ?? SecureTokenStore(),
          transport: widget.transport,
        );
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
    // The mobile tracking API does not expose a separate dashboard endpoint.
    _counts = const {};
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
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey(_section),
                child: switch (_section) {
                  0 => _overview(),
                  1 => _tracking(),
                  _ => _profileView(),
                },
              ),
            ),
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
        padding: EdgeInsets.all(CdsTokens.space6),
        child: CdsEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Service not configured',
          message:
              'Set CDS_API_BASE_URL to the authorized CDS-SMART service origin, then restart the app.',
        ),
      ),
    ),
  );

  Widget _loginScreen() => Scaffold(
    appBar: AppBar(title: const Text('CDS-SMART · Sign in')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: CdsTokens.successSurface,
              borderRadius: BorderRadius.circular(CdsTokens.radiusMedium),
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              color: CdsTokens.brand,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: CdsTokens.space5),
        const CdsPageHeader(
          title: 'Authorized mobile access',
          description:
              'Sign in with an active, approved, and email-verified CDS-SMART account.',
          eyebrow: 'CDS-SMART Mobile',
        ),
        if (_error != null) _errorBanner(_error!),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
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
            prefixIcon: Icon(Icons.lock_outline),
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
          'Your access and visible records are verified by CDS-SMART.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _overview() => ListView(
    key: const PageStorageKey('overview'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    children: [
      CdsPageHeader(
        title: 'Submission overview',
        description: 'A clear view of documents within your authorized scope.',
        eyebrow: 'Welcome, ${_profile?['name'] ?? ''}',
      ),
      CdsSectionCard(
        title: 'Your work queues',
        subtitle: 'Select a queue to review its submissions.',
        compact: true,
        child: Column(
          children: [
            for (final (index, queue) in SubmissionQueue.values.indexed)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == SubmissionQueue.values.length - 1
                      ? 0
                      : CdsTokens.space2,
                ),
                child: _queueSummary(queue),
              ),
          ],
        ),
      ),
      const SizedBox(height: CdsTokens.space2),
      _filtersPanel(
        includeSearch: true,
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

  Widget _queueSummary(SubmissionQueue queue) {
    final count = _counts[queue.key];
    return CdsQueueSummaryCard(
      title: queue.label,
      description: queue.description,
      count: '$count',
      icon: switch (queue.key) {
        'incoming' => Icons.move_to_inbox_outlined,
        'outgoing' => Icons.outbox_outlined,
        _ => Icons.history_outlined,
      },
      onTap: () {
        setState(() {
          _section = 1;
          _queueIndex = SubmissionQueue.values.indexOf(queue);
        });
        _loadQueue(resetPage: true);
      },
    );
  }

  Widget _tracking() {
    final pageData = _submissions;
    return ListView(
      key: const PageStorageKey('tracking'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const CdsPageHeader(
          title: 'Submission tracking',
          description:
              'Search, filter, and review documents in your work queues.',
          eyebrow: 'Records',
        ),
        Wrap(
          spacing: CdsTokens.space2,
          runSpacing: CdsTokens.space2,
          children: [
            for (var index = 0; index < SubmissionQueue.values.length; index++)
              ChoiceChip(
                label: Text(SubmissionQueue.values[index].label),
                selected: _queueIndex == index,
                onSelected: _busy
                    ? null
                    : (_) {
                        setState(() => _queueIndex = index);
                        _loadQueue(resetPage: true);
                      },
              ),
          ],
        ),
        const SizedBox(height: CdsTokens.space2),
        Text(
          SubmissionQueue.values[_queueIndex].description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: CdsTokens.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _filters['search'],
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadQueue(resetPage: true),
                decoration: InputDecoration(
                  hintText: 'Search documents',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filters['search']!.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _filters['search']!.clear();
                            _loadQueue(resetPage: true);
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: CdsTokens.space2),
            IconButton.filledTonal(
              tooltip: 'Search',
              onPressed: _busy ? null : () => _loadQueue(resetPage: true),
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        const SizedBox(height: CdsTokens.space2),
        _filtersPanel(onApply: () => _loadQueue(resetPage: true)),
        const SizedBox(height: CdsTokens.space2),
        if (_busy && pageData == null)
          const Center(child: CircularProgressIndicator())
        else if (pageData == null)
          const CdsEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Records are not available',
            message: 'Refresh or check your connection to try again.',
          )
        else if (pageData.items.isEmpty)
          const CdsEmptyState(
            title: 'No matching submissions',
            message: 'Try another search or clear one or more filters.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CdsTokens.space2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${pageData.total} ${pageData.total == 1 ? 'record' : 'records'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                CdsStatusBadge(
                  label: SubmissionQueue.values[_queueIndex].label,
                ),
              ],
            ),
          ),
          for (final item in pageData.items)
            CdsDocumentCard(
              title:
                  '${item['activity_name'] ?? item['document_type'] ?? item['module'] ?? 'Submission'}',
              source: '${item['module'] ?? _sourceLabel(item['source'])}',
              reference:
                  '${item['tracking_number'] ?? 'Reference ${item['source_record_id'] ?? item['id'] ?? '—'}'}',
              status:
                  '${item['submission_status'] ?? item['current_status'] ?? 'Status unavailable'}',
              custody:
                  '${item['current_location'] ?? item['target_office'] ?? 'Not recorded'}',
              onTap: () => _openDocument(item),
            ),
          _pageControls(
            currentPage: pageData.currentPage,
            lastPage: pageData.lastPage,
            onPrevious: pageData.currentPage > 1
                ? () {
                    setState(() => _page--);
                    _loadQueue();
                  }
                : null,
            onNext: pageData.currentPage < pageData.lastPage
                ? () {
                    setState(() => _page++);
                    _loadQueue();
                  }
                : null,
          ),
        ],
      ],
    );
  }

  Widget _filtersPanel({
    required VoidCallback onApply,
    bool includeSearch = false,
  }) {
    final fields = [
      if (includeSearch) ('search', 'Search'),
      ('module', 'Source / module'),
      ('protected_area_id', 'Protected area ID'),
      ('target_office', 'Target office'),
      ('reporting_period', 'Reporting period'),
      ('reporting_year', 'Reporting year'),
      ('status', 'Status'),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: CdsTokens.space4),
        childrenPadding: const EdgeInsets.fromLTRB(
          CdsTokens.space3,
          0,
          CdsTokens.space3,
          CdsTokens.space2,
        ),
        leading: const Icon(Icons.tune),
        title: const Text('More filters'),
        children: [
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: CdsTokens.space1),
              child: TextField(
                controller: _filters[field.$1],
                keyboardType:
                    const {
                      'protected_area_id',
                      'reporting_year',
                    }.contains(field.$1)
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: field.$2,
                  prefixIcon: Icon(switch (field.$1) {
                    'module' => Icons.folder_outlined,
                    'protected_area_id' => Icons.park_outlined,
                    'target_office' => Icons.account_balance_outlined,
                    'reporting_period' ||
                    'reporting_year' => Icons.calendar_today,
                    _ => Icons.flag_outlined,
                  }),
                  isDense: true,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          for (final controller in _filters.values) {
                            controller.clear();
                          }
                          setState(() {});
                          onApply();
                        },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: CdsTokens.space2),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : onApply,
                  child: const Text('Apply filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageControls({
    required int currentPage,
    required int lastPage,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
  }) => Card(
    margin: const EdgeInsets.only(top: CdsTokens.space1),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            'Page $currentPage of $lastPage',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  Widget _profileView() => ListView(
    key: const PageStorageKey('profile'),
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
    children: [
      const CdsPageHeader(
        title: 'Profile',
        description: 'Your authorized CDS-SMART account.',
        eyebrow: 'Account',
      ),
      CdsSectionCard(
        title: '${_profile?['name'] ?? 'Account'}',
        subtitle: '${_profile?['email'] ?? ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileInfo(
              Icons.badge_outlined,
              'Account type',
              '${_profile?['actor_category'] ?? 'Not provided'}',
            ),
            const SizedBox(height: CdsTokens.space3),
            _profileInfo(
              Icons.account_balance_outlined,
              'Office',
              '${_profile?['office'] ?? 'Not provided'}',
            ),
          ],
        ),
      ),
      const SizedBox(height: CdsTokens.space2),
      OutlinedButton.icon(
        onPressed: _busy ? null : _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out of this device'),
      ),
      const SizedBox(height: CdsTokens.space3),
      const CdsSectionCard(
        title: 'Access and privacy',
        child: Text(
          'Your access and visible records are determined by CDS-SMART for each request. Signing out also clears this device’s saved session.',
        ),
      ),
    ],
  );

  String _sourceLabel(Object? source) {
    if (source is! String || source.isEmpty) return 'Submission';
    return source
        .split(RegExp(r'[_-]+'))
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  Widget _profileInfo(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: CdsTokens.brand),
      const SizedBox(width: CdsTokens.space3),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: CdsTokens.space1),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
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
    color: CdsTokens.dangerSurface,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CdsTokens.space4,
        vertical: CdsTokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: CdsTokens.danger),
          const SizedBox(width: CdsTokens.space2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CdsTokens.danger),
            ),
          ),
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
  Widget build(BuildContext context) {
    final title =
        '${document['activity_name'] ?? document['document_type'] ?? document['module'] ?? 'Submission'}';
    final reference =
        '${document['tracking_number'] ?? 'Reference ${document['source_record_id'] ?? document['id'] ?? '—'}'}';
    final source =
        '${document['module'] ?? document['source'] ?? 'Submission'}';
    final status =
        '${document['submission_status'] ?? document['current_status'] ?? 'Status unavailable'}';
    final custody =
        '${document['current_location'] ?? document['target_office'] ?? 'Not recorded'}';
    return Scaffold(
      appBar: AppBar(title: const Text('Document details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          CdsSectionCard(
            title: title,
            subtitle: reference,
            child: Wrap(
              spacing: CdsTokens.space2,
              runSpacing: CdsTokens.space2,
              children: [
                CdsStatusBadge(label: status),
                CdsStatusBadge(label: source),
              ],
            ),
          ),
          CdsSectionCard(
            title: 'Current custody',
            subtitle: 'Last recorded office and routing state.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(custody, style: Theme.of(context).textTheme.titleMedium),
                if (document['current_custody'] is Map) ...[
                  const SizedBox(height: CdsTokens.space2),
                  _detailMap(context, document['current_custody']),
                ],
                if (document['read_only'] == true) ...[
                  const SizedBox(height: CdsTokens.space2),
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: CdsTokens.mutedInk,
                      ),
                      SizedBox(width: CdsTokens.space2),
                      Expanded(
                        child: Text(
                          'Read-only record · no custody changes here.',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          CdsSectionCard(
            title: 'Custody timeline',
            subtitle: 'Each entry represents a recorded routing event.',
            child: _eventList(context, document['routing_events'], false),
          ),
          CdsSectionCard(
            title: 'Review history',
            subtitle:
                'Review verdicts are separate from document custody movement.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reviewSummary(context, document['review']),
                const SizedBox(height: CdsTokens.space3),
                _eventList(context, document['review_events'], true),
              ],
            ),
          ),
          CdsSectionCard(
            title: 'Protected attachments',
            subtitle:
                'Files are retrieved only when authorized by the service.',
            child: Column(children: _attachments(context)),
          ),
        ],
      ),
    );
  }

  List<Widget> _attachments(BuildContext context) {
    final attachments = document['attachments'];
    if (attachments is! List || attachments.isEmpty) {
      return const [
        CdsEmptyState(
          icon: Icons.attach_file,
          title: 'No attachments available',
          message: 'There are no files available to this account.',
        ),
      ];
    }
    return attachments
        .whereType<Map<String, dynamic>>()
        .map((attachment) {
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: CdsTokens.space4,
                vertical: CdsTokens.space2,
              ),
              leading: const Icon(
                Icons.description_outlined,
                color: CdsTokens.brand,
              ),
              title: Text(
                '${attachment['filename'] ?? attachment['name'] ?? 'Protected file'}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${attachment['mime_type'] ?? 'Protected attachment'}',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Attachment actions',
                onSelected: (action) =>
                    _fetchAttachment(context, attachment, action == 'preview'),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'preview',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Preview'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Download / share'),
                    ),
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
      if (!context.mounted) return;
      final url = metadata[preview ? 'preview_url' : 'download_url'];
      if (url is! String) {
        throw const MobileApiException(
          'The server did not provide an attachment URL.',
        );
      }
      final filename =
          '${metadata['name'] ?? attachment['name'] ?? 'attachment'}';
      final declaredMimeType =
          '${metadata['mime_type'] ?? attachment['mime_type'] ?? ''}'
              .split(';')
              .first
              .toLowerCase();
      if (preview &&
          (declaredMimeType == 'application/pdf' ||
              filename.toLowerCase().endsWith('.pdf'))) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ProtectedPdfPreviewPage(
              title: filename,
              loadPdf: () async {
                final response = await api.attachmentContent(url);
                final responseMimeType = response.headers['content-type']
                    ?.split(';')
                    .first
                    .toLowerCase();
                if (responseMimeType != null &&
                    responseMimeType != 'application/pdf') {
                  throw const MobileApiException(
                    'The server did not return a PDF preview.',
                  );
                }
                return Uint8List.fromList(response.bodyBytes);
              },
              onSessionExpired: () {
                onExpired();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session expired. Sign in again.'),
                    ),
                  );
                }
              },
            ),
          ),
        );
        return;
      }
      final http.Response response = await api.attachmentContent(url);
      final mimeType = response.headers['content-type']?.split(';').first;
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

  Widget _detailField(BuildContext context, String label, Object? value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: CdsTokens.space1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: Text(
                _titleCase(label),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Text(
                '${value ?? '—'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );

  Widget _detailMap(BuildContext context, Object? value) {
    if (value is! Map) return const Text('No recorded data.');
    final entries = value.entries
        .where((entry) => entry.value != null && '${entry.value}'.isNotEmpty)
        .toList(growable: false);
    if (entries.isEmpty) return const Text('No recorded data.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          _detailField(context, entry.key.toString(), entry.value),
      ],
    );
  }

  Widget _reviewSummary(BuildContext context, Object? value) {
    if (value is! Map || value.isEmpty) {
      return const Text('No review verdict is recorded.');
    }
    final verdict =
        value['status_label'] ?? value['verdict'] ?? value['status'];
    final remarks = value['remarks'];
    final reviewedAt = formatCdsTimestamp(value['reviewed_at']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CdsTokens.space3),
      decoration: BoxDecoration(
        color: CdsTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(CdsTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (verdict != null) CdsStatusBadge(label: '$verdict'),
          if (remarks != null) ...[
            const SizedBox(height: CdsTokens.space2),
            Text('$remarks'),
          ],
          if (reviewedAt.isNotEmpty) ...[
            const SizedBox(height: CdsTokens.space2),
            Text(reviewedAt, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  String _titleCase(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Widget _eventList(BuildContext context, Object? value, bool review) {
    if (value is! List || value.isEmpty) {
      return Text(
        review ? 'No review events recorded.' : 'No custody events recorded.',
      );
    }
    final events = value.whereType<Map>().toList(growable: false);
    return Column(
      children: [
        for (final (index, event) in events.indexed)
          CdsTimelineEntry(
            title:
                '${event[review ? 'event_label' : 'label'] ?? event[review ? 'event_key' : 'event_type'] ?? 'Recorded event'}',
            subtitle: [
              if (!review)
                [
                  event['from'],
                  event['to'],
                ].where((value) => value != null).join(' → '),
              if (event['remarks'] != null) '${event['remarks']}',
              if (review && event['recorded_office'] != null)
                '${event['recorded_office']}',
            ].where((line) => line.isNotEmpty).join('\n'),
            timestamp: formatCdsTimestamp(
              event[review ? 'recorded_at' : 'occurred_at'] ??
                  event['recorded_at'],
            ),
            isLast: index == events.length - 1,
            icon: review ? Icons.fact_check_outlined : Icons.route_outlined,
          ),
      ],
    );
  }
}
