import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

final _topicsProvider = FutureProvider<List<SupportTopic>>(
  (ref) => ref.watch(apiContractProvider).supportTopics(),
);

final _ticketsProvider = FutureProvider<Paged<SupportTicket>>(
  (ref) => ref.watch(apiContractProvider).supportTickets(),
);

/// Help & support — topics + ticket creation.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(_topicsProvider);
    final tickets = ref.watch(_ticketsProvider);

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Help & support', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          ZButton(
            label: 'Raise a ticket',
            icon: Icons.support_agent_rounded,
            onPressed: () => _showTicketSheet(context, ref),
          ),
          const SizedBox(height: ZSpacing.xl),
          Text('Common topics', style: ZTypography.overline),
          const SizedBox(height: ZSpacing.sm),
          topics.when(
            loading: () => const ZSkeletonList(itemCount: 3),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => Column(
              children: [
                for (final topic in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZSpacing.md),
                    child: ZCard(
                      onTap: () => _showTopic(context, topic),
                      padding: const EdgeInsets.all(ZSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(topic.title, style: ZTypography.bodyStrong),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: ZColors.textTertiary),
                          ],
                        ),
                        const SizedBox(height: ZSpacing.xs),
                        Text(
                          topic.body,
                          style: ZTypography.caption
                              .copyWith(color: ZColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Text('Your tickets', style: ZTypography.overline),
          const SizedBox(height: ZSpacing.sm),
          tickets.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (page) => page.results.isEmpty
                ? const ZEmptyState(
                    title: 'No tickets yet',
                    subtitle: 'Tickets you raise will appear here.',
                  )
                : Column(
                    children: [
                      for (final t in page.results)
                        ZCard(
                          padding: const EdgeInsets.all(ZSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(t.subject,
                                        style: ZTypography.bodyStrong),
                                  ),
                                  ZBadge(
                                    label: t.status.toUpperCase(),
                                    tone: t.status == 'open'
                                        ? ZBadgeTone.highlight
                                        : ZBadgeTone.success,
                                  ),
                                ],
                              ),
                              const SizedBox(height: ZSpacing.xs),
                              Text(
                                t.category,
                                style: ZTypography.caption
                                    .copyWith(color: ZColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showTopic(BuildContext context, SupportTopic topic) {
    ZSheet.show<void>(
      context: context,
      title: topic.title,
      child: Text(
        topic.body,
        style: ZTypography.body.copyWith(color: ZColors.textSecondary),
      ),
    );
  }

  void _showTicketSheet(BuildContext context, WidgetRef ref) {
    final subject = TextEditingController();
    final body = TextEditingController();
    var category = 'general';
    final categories = const {
      'general': 'General',
      'lost-item': 'Lost item',
      'fare-issue': 'Fare or payment',
      'driver-behaviour': 'Driver behaviour',
      'delivery-issue': 'Goods delivery',
    };
    ZSheet.show<void>(
      context: context,
      title: 'Raise a ticket',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: ZSpacing.sm,
              children: [
                for (final entry in categories.entries)
                  ZChip(
                    label: entry.value,
                    selected: category == entry.key,
                    onTap: () => setSheetState(() => category = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: ZSpacing.lg),
            ZTextField(controller: subject, label: 'Subject'),
            const SizedBox(height: ZSpacing.lg),
            ZTextField(
              controller: body,
              label: 'Describe the issue',
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: ZSpacing.xl),
            ZButton(
              label: 'Submit ticket',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(sheetContext);
                if (subject.text.trim().isEmpty || body.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Add a subject and description'),
                    ),
                  );
                  return;
                }
                try {
                  await ref.read(apiContractProvider).createSupportTicket(
                        subject: subject.text.trim(),
                        category: category,
                        body: body.text.trim(),
                      );
                  ref.invalidate(_ticketsProvider);
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ticket submitted')),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not submit. Try again.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
