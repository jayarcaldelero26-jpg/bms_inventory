import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract final class CdsTokens {
  static const brand = Color(0xff176b43);
  static const brandDark = Color(0xff105536);
  static const ink = Color(0xff182a22);
  static const mutedInk = Color(0xff53645b);
  static const canvas = Color(0xfff4f7f5);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xffedf2ef);
  static const border = Color(0xffdce5df);
  static const success = Color(0xff236b42);
  static const successSurface = Color(0xffe8f4eb);
  static const warning = Color(0xff795400);
  static const warningSurface = Color(0xfffff3d6);
  static const danger = Color(0xffa3342a);
  static const dangerSurface = Color(0xfffcebe8);
  static const info = Color(0xff285c7b);
  static const infoSurface = Color(0xffe8f2f8);

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const radiusSmall = 10.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 22.0;
}

class CdsPageHeader extends StatelessWidget {
  const CdsPageHeader({
    required this.title,
    this.description,
    this.eyebrow,
    super.key,
  });

  final String title;
  final String? description;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: CdsTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: textTheme.labelMedium?.copyWith(
                color: CdsTokens.brand,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CdsTokens.space1),
          ],
          Text(title, style: textTheme.headlineSmall),
          if (description != null) ...[
            const SizedBox(height: CdsTokens.space2),
            Text(description!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class CdsStatusBadge extends StatelessWidget {
  const CdsStatusBadge({required this.label, this.compact = false, super.key});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase().replaceAll('_', ' ');
    final (background, foreground) = switch (normalized) {
      final value
          when value.contains('complete') ||
              value.contains('approved') ||
              value.contains('forwarded') ||
              value == 'read' =>
        (CdsTokens.successSurface, CdsTokens.success),
      final value
          when value.contains('reject') ||
              value.contains('correction') ||
              value.contains('denied') ||
              value == 'unread' =>
        (CdsTokens.dangerSurface, CdsTokens.danger),
      final value
          when value.startsWith('demo') ||
              value.contains('await') ||
              value.contains('pending') ||
              value.contains('action') ||
              value.contains('incoming') =>
        (CdsTokens.warningSurface, CdsTokens.warning),
      final value
          when value.contains('transit') ||
              value.contains('review') ||
              value.contains('process') =>
        (CdsTokens.infoSurface, CdsTokens.info),
      _ => (CdsTokens.surfaceMuted, CdsTokens.mutedInk),
    };
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 88 : 240),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? CdsTokens.space2 : 10,
        vertical: compact ? CdsTokens.space1 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CdsDocumentCard extends StatelessWidget {
  const CdsDocumentCard({
    required this.title,
    required this.source,
    required this.status,
    required this.custody,
    this.reference,
    this.onTap,
    super.key,
  });

  final String title;
  final String source;
  final String status;
  final String custody;
  final String? reference;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: CdsTokens.space2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CdsTokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: CdsTokens.space2,
                runSpacing: CdsTokens.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    source,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: CdsTokens.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  CdsStatusBadge(label: status),
                ],
              ),
              const SizedBox(height: CdsTokens.space2),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              if (reference != null && reference!.isNotEmpty) ...[
                const SizedBox(height: CdsTokens.space1),
                Text(
                  reference!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: CdsTokens.space2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.account_balance_outlined,
                      size: 16,
                      color: CdsTokens.mutedInk,
                    ),
                  ),
                  const SizedBox(width: CdsTokens.space2),
                  Expanded(
                    child: Text(
                      'Current custody · $custody',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CdsTokens.mutedInk,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: CdsTokens.space2),
                    const Icon(Icons.chevron_right, color: CdsTokens.mutedInk),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CdsQueueSummaryCard extends StatelessWidget {
  const CdsQueueSummaryCard({
    required this.title,
    required this.description,
    required this.count,
    required this.icon,
    required this.onTap,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final String title;
  final String description;
  final String count;
  final IconData icon;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    child: InkWell(
      borderRadius: BorderRadius.circular(CdsTokens.radiusMedium),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(CdsTokens.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CdsTokens.successSurface,
                borderRadius: BorderRadius.circular(CdsTokens.radiusSmall),
              ),
              child: Icon(icon, color: CdsTokens.brand),
            ),
            const SizedBox(width: CdsTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: CdsTokens.space1),
                  Text(
                    description,
                    key: const ValueKey('queue-summary-description'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: CdsTokens.space3),
            Container(
              key: const ValueKey('queue-summary-count'),
              padding: const EdgeInsets.symmetric(
                horizontal: CdsTokens.space2,
                vertical: CdsTokens.space1,
              ),
              decoration: BoxDecoration(
                color: CdsTokens.successSurface,
                borderRadius: BorderRadius.circular(CdsTokens.radiusSmall),
              ),
              child: Text(
                count,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CdsTokens.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CdsEmptyState extends StatelessWidget {
  const CdsEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CdsTokens.space6),
      child: Column(
        children: [
          Icon(icon, size: 32, color: CdsTokens.mutedInk),
          const SizedBox(height: CdsTokens.space3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: CdsTokens.space1),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class CdsTimelineEntry extends StatelessWidget {
  const CdsTimelineEntry({
    required this.title,
    this.subtitle,
    this.timestamp,
    this.isLast = false,
    this.icon = Icons.circle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? timestamp;
  final bool isLast;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Icon(icon, size: 18, color: CdsTokens.brand),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: CdsTokens.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: CdsTokens.space3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: CdsTokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: CdsTokens.space1),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (timestamp != null && timestamp!.isNotEmpty) ...[
                  const SizedBox(height: CdsTokens.space1),
                  Text(
                    timestamp!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class CdsSectionCard extends StatelessWidget {
  const CdsSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(compact ? CdsTokens.space3 : CdsTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            SizedBox(height: compact ? CdsTokens.space1 : CdsTokens.space2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          SizedBox(height: compact ? CdsTokens.space2 : CdsTokens.space3),
          child,
        ],
      ),
    ),
  );
}

String formatCdsTimestamp(Object? value) {
  if (value is! String || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat.yMMMd().add_jm().format(parsed.toLocal());
}
