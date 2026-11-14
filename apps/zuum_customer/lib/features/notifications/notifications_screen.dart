import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

final notificationsProvider = FutureProvider<Paged<ZNotification>>(
  (ref) => ref.watch(apiContractProvider).notifications(),
);

/// Notifications feed with read-state.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Notifications', showBack: true),
      body: notifications.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(ZSpacing.lg),
          child: ZSkeletonList(itemCount: 4),
        ),
        error: (_, _) => ZErrorState(
          title: 'Could not load notifications',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (page) {
          if (page.results.isEmpty) {
            return const ZEmptyState(
              title: 'All caught up',
              subtitle: 'Trip updates and offers will appear here.',
            );
          }
          return RefreshIndicator(
            color: ZColors.primary,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(ZSpacing.lg),
              itemCount: page.results.length,
              separatorBuilder: (_, _) => const SizedBox(height: ZSpacing.sm),
              itemBuilder: (_, i) {
                final n = page.results[i];
                return ZCard(
                  onTap: n.isUnread
                      ? () {
                          ref.read(apiContractProvider).markNotificationRead(n.id);
                          ref.invalidate(notificationsProvider);
                        }
                      : null,
                  padding: const EdgeInsets.all(ZSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        switch (n.type) {
                          'promo' => Icons.local_offer_outlined,
                          'trip' => Icons.local_taxi_outlined,
                          _ => Icons.notifications_none_rounded,
                        },
                        color: n.isUnread ? ZColors.primary : ZColors.textTertiary,
                      ),
                      const SizedBox(width: ZSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: ZTypography.bodyStrong,
                                  ),
                                ),
                                if (n.isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: ZColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n.body,
                              style: ZTypography.caption
                                  .copyWith(color: ZColors.textSecondary),
                            ),
                            const SizedBox(height: ZSpacing.xs),
                            Text(
                              ZFormat.dayDateTime(n.createdAt.toLocal()),
                              style: ZTypography.overline.copyWith(
                                color: ZColors.textTertiary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
