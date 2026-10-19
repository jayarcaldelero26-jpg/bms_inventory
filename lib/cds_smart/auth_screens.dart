import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_api.dart';
import 'mobile_api.dart' show SecureTokenStore, TokenStore;
import 'mobile_tracking_api.dart';
import 'ui_components.dart';

class CdsSmartHome extends StatefulWidget {
  const CdsSmartHome({
    super.key,
    this.baseUrl,
    this.apiClient,
    this.trackingClient,
    this.tokenStore,
    this.transport,
  });

  final Uri? baseUrl;
  final MobileAuthApiClient? apiClient;
  final MobileTrackingApiClient? trackingClient;
  final TokenStore? tokenStore;
  final http.Client? transport;

  @override
  State<CdsSmartHome> createState() => _CdsSmartHomeState();
}

class _CdsSmartHomeState extends State<CdsSmartHome> {
  late final MobileAuthApiClient? _api;
  final _email = TextEditingController();
  final _password = TextEditingController();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _restoreRetryAvailable = false;
  bool _busy = false;
  String? _error;
  late final MobileTrackingApiClient? _tracking;
  final _search = TextEditingController();
  final _filter = TextEditingController();
  String _queue = 'incoming';
  String _filterKey = 'module';
  int _page = 1;
  MobileTrackingPage? _trackingPage;
  bool _trackingBusy = false;
  String? _trackingError;

  @override
  void initState() {
    super.initState();
    _api =
        widget.apiClient ??
        (widget.baseUrl == null
            ? null
            : MobileAuthApiClient(
                baseUrl: widget.baseUrl!,
                tokenStore: widget.tokenStore ?? SecureTokenStore(),
                transport: widget.transport,
              ));
    _tracking =
        widget.trackingClient ??
        (widget.baseUrl == null
            ? null
            : MobileTrackingApiClient(
                baseUrl: widget.baseUrl!,
                tokenStore: widget.tokenStore ?? SecureTokenStore(),
                transport: widget.transport,
              ));
    _restoreSession();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _search.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    if (_api == null) {
      setState(() {
        _loading = false;
        _error = 'Sign-in is not configured for this build.';
      });
      return;
    }
    try {
      final tokenStore = widget.tokenStore ?? SecureTokenStore();
      final token = await tokenStore.read();
      if (token != null && token.isNotEmpty) {
        _restoreRetryAvailable = true;
        _profile = await _api.profile();
        _restoreRetryAvailable = false;
        _error = null;
        await _loadTracking();
      }
    } on Exception catch (error) {
      if (error is MobileAuthException && error.statusCode == 401) {
        await _api.clearSession();
        _restoreRetryAvailable = false;
        _profile = null;
      } else {
        _restoreRetryAvailable = true;
      }
      _error = _messageFor(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retrySessionRestore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _restoreSession();
  }

  Future<void> _login() async {
    if (_api == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _profile = await _api.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _loadTracking();
    } on Exception catch (error) {
      _profile = null;
      _error = _messageFor(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_api == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.logout();
    } on Exception catch (error) {
      _error = _messageFor(error);
    } finally {
      if (mounted) {
        setState(() {
          _profile = null;
          _trackingPage = null;
          _trackingError = null;
          _busy = false;
        });
      }
    }
  }

  Future<void> _loadTracking({int? page}) async {
    if (_tracking == null || _profile == null) return;
    setState(() {
      _trackingBusy = true;
      _trackingError = null;
    });
    try {
      _page = page ?? _page;
      final filters = <String, String>{};
      if (_search.text.trim().isNotEmpty) {
        filters['search'] = _search.text.trim();
      }
      if (_filter.text.trim().isNotEmpty) {
        filters[_filterKey] = _filter.text.trim();
      }
      _trackingPage = await _tracking.queue(
        queue: _queue,
        page: _page,
        filters: filters,
      );
    } on Exception catch (error) {
      _trackingPage = null;
      if (error is MobileTrackingException && error.statusCode == 401) {
        _profile = null;
      }
      _trackingError = error is MobileTrackingException
          ? error.message
          : 'Could not reach submission tracking. Please try again.';
    } finally {
      if (mounted) setState(() => _trackingBusy = false);
    }
  }

  Future<void> _showDocument(Map<String, dynamic> row) async {
    final tracking = _tracking;
    if (tracking == null) return;
    setState(() {
      _trackingBusy = true;
      _trackingError = null;
    });
    try {
      final source = row['source'];
      final id = row['source_id'];
      if (source is! String || id is! num) {
        throw const MobileTrackingException(
          'This record has an invalid identity.',
        );
      }
      final data = await tracking.document(source, id.toInt());
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _MobileDocumentDetail(data: data),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _trackingError = error is MobileTrackingException
              ? error.message
              : 'Could not load document details. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _trackingBusy = false);
    }
  }

  String _messageFor(Object error) {
    if (error is MobileAuthException) return error.message;
    return 'Could not reach the sign-in service. Please try again.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('CDS-SMART Mobile'),
      actions: [
        if (_profile != null)
          IconButton(
            tooltip: 'Sign out',
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _profile == null
        ? _loginView()
        : _profileView(_profile!),
  );

  Widget _loginView() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(CdsTokens.space5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.eco_outlined, size: 48, color: CdsTokens.brand),
            const SizedBox(height: CdsTokens.space3),
            Text('Sign in', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CdsTokens.space2),
            const Text('Use your existing CDS-SMART web account.'),
            const SizedBox(height: CdsTokens.space4),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: CdsTokens.space3),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _busy ? null : _login(),
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: CdsTokens.space3),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_restoreRetryAvailable)
              TextButton.icon(
                onPressed: _loading ? null : _retrySessionRestore,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry session restore'),
              ),
            const SizedBox(height: CdsTokens.space4),
            FilledButton(
              onPressed: _busy || _api == null ? null : _login,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: CdsTokens.space4),
            const Text(
              'Sign in to view submission tracking available to your account.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _profileView(Map<String, dynamic> profile) => ListView(
    padding: const EdgeInsets.all(CdsTokens.space4),
    children: [
      Text('Your profile', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CdsTokens.space3),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(CdsTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile['name'] ?? ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: CdsTokens.space2),
              Text('${profile['email'] ?? ''}'),
            ],
          ),
        ),
      ),
      const SizedBox(height: CdsTokens.space3),
      Text(
        'Submission tracking',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: CdsTokens.space2),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'incoming', label: Text('Incoming')),
          ButtonSegment(value: 'outgoing', label: Text('Outgoing')),
          ButtonSegment(value: 'history', label: Text('History')),
        ],
        selected: {_queue},
        onSelectionChanged: _trackingBusy
            ? null
            : (value) {
                setState(() {
                  _queue = value.first;
                  _page = 1;
                });
                _loadTracking(page: 1);
              },
      ),
      const SizedBox(height: CdsTokens.space2),
      TextField(
        controller: _search,
        decoration: InputDecoration(
          labelText: 'Search',
          suffixIcon: IconButton(
            tooltip: 'Search tracking',
            onPressed: _trackingBusy ? null : () => _loadTracking(page: 1),
            icon: const Icon(Icons.search),
          ),
        ),
        onSubmitted: (_) => _loadTracking(page: 1),
      ),
      const SizedBox(height: CdsTokens.space2),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterKey,
              decoration: const InputDecoration(labelText: 'Filter field'),
              items: const [
                DropdownMenuItem(value: 'module', child: Text('Module')),
                DropdownMenuItem(
                  value: 'protected_area_id',
                  child: Text('Protected area ID'),
                ),
                DropdownMenuItem(
                  value: 'target_office',
                  child: Text('Target office'),
                ),
                DropdownMenuItem(
                  value: 'reporting_period',
                  child: Text('Reporting period'),
                ),
                DropdownMenuItem(
                  value: 'reporting_year',
                  child: Text('Reporting year'),
                ),
                DropdownMenuItem(value: 'status', child: Text('Status')),
              ],
              onChanged: _trackingBusy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _filterKey = value);
                    },
            ),
          ),
          const SizedBox(width: CdsTokens.space2),
          Expanded(
            child: TextField(
              controller: _filter,
              decoration: const InputDecoration(labelText: 'Filter value'),
              onSubmitted: (_) => _loadTracking(page: 1),
            ),
          ),
        ],
      ),
      const SizedBox(height: CdsTokens.space2),
      if (_trackingBusy)
        Semantics(
          liveRegion: true,
          label: 'Loading tracking',
          child: Column(
            children: [
              Center(child: CircularProgressIndicator()),
              SizedBox(height: CdsTokens.space2),
              Text('Loading tracking...'),
            ],
          ),
        )
      else if (_trackingError != null) ...[
        Text(
          _trackingError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: () => _loadTracking(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ] else if (_trackingPage == null || _trackingPage!.items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: CdsTokens.space3),
          child: Text('No submissions found.'),
        )
      else ...[
        Text(
          '${_trackingPage!.total} records · Page ${_trackingPage!.currentPage} of ${_trackingPage!.lastPage}',
        ),
        for (final row in _trackingPage!.items)
          Card(
            child: ListTile(
              title: Text(
                '${row['tracking_number'] ?? row['activity_name'] ?? 'Submission'}',
              ),
              subtitle: Text(
                '${row['module'] ?? row['document_type'] ?? ''} · ${row['target_office'] ?? ''} · ${row['submission_status'] ?? row['stage'] ?? ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _trackingBusy ? null : () => _showDocument(row),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: _page > 1 && !_trackingBusy
                  ? () => _loadTracking(page: _page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_trackingPage!.currentPage} / ${_trackingPage!.lastPage}'),
            IconButton(
              tooltip: 'Next page',
              onPressed: _page < _trackingPage!.lastPage && !_trackingBusy
                  ? () => _loadTracking(page: _page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: CdsTokens.space3),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: CdsTokens.space3),
      OutlinedButton.icon(
        onPressed: _busy ? null : _logout,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class _MobileDocumentDetail extends StatelessWidget {
  const _MobileDocumentDetail({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Document details')),
    body: ListView(
      padding: const EdgeInsets.all(CdsTokens.space4),
      children: [
        Text(
          '${data['tracking_number'] ?? data['activity_name'] ?? 'Submission'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        for (final key in const [
          'module',
          'document_type',
          'target_office',
          'protected_area',
          'reporting_period',
          'reporting_year',
          'submission_status',
          'stage',
        ])
          if (data[key] != null)
            ListTile(
              title: Text(key.replaceAll('_', ' ')),
              subtitle: Text('${data[key]}'),
            ),
        const Divider(),
        const Text(
          'Routing summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (data['routing_summary'] is Map<String, dynamic>)
          for (final entry
              in (data['routing_summary'] as Map<String, dynamic>).entries)
            if (entry.value != null)
              ListTile(
                title: Text(entry.key.replaceAll('_', ' ')),
                subtitle: Text('${entry.value}'),
              ),
        const Text(
          'Routing history',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (data['routing_timeline'] is List)
          for (final event in data['routing_timeline'] as List)
            if (event is Map<String, dynamic>)
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: Text(
                  '${event['label'] ?? event['action_label'] ?? event['key'] ?? 'Routing event'}',
                ),
                subtitle: Text(
                  [
                        event['office'],
                        event['from'],
                        event['to'],
                        event['occurred_at'],
                      ]
                      .where((value) => value != null && '$value'.isNotEmpty)
                      .join(' · '),
                ),
              ),
      ],
    ),
  );
}
