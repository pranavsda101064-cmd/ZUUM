import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';

/// Settings — profile, addresses, preferences, legal.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Settings', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          ZCard(
            child: Row(
              children: [
                ZAvatar(initials: user?.initials ?? '?', size: 52),
                const SizedBox(width: ZSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? '—', style: ZTypography.titleMd),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: ZTypography.caption
                            .copyWith(color: ZColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ZButton(
                  label: 'Edit',
                  variant: ZButtonVariant.secondary,
                  size: ZButtonSize.sm,
                  expand: false,
                  onPressed: () => context.push('/settings/profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          Text('Account', style: ZTypography.overline),
          ZListTile(
            title: 'Saved addresses',
            leading: const Icon(Icons.bookmark_outline_rounded,
                color: ZColors.textSecondary),
            onTap: () => context.push('/settings/addresses'),
          ),
          ZListTile(
            title: 'Payment methods',
            leading: const Icon(Icons.credit_card_outlined,
                color: ZColors.textSecondary),
            onTap: () => context.push('/settings/payments'),
          ),
          const Divider(indent: 16, endIndent: 16),
          Text('Preferences', style: ZTypography.overline),
          const ZListTile(
            title: 'Language',
            subtitle: 'English (Kannada brand accents)',
            leading:
                Icon(Icons.translate_rounded, color: ZColors.textSecondary),
            showChevron: false,
          ),
          ZListTile(
            title: 'Safety',
            leading:
                const Icon(Icons.shield_outlined, color: ZColors.textSecondary),
            onTap: () => context.push('/safety'),
          ),
          const Divider(indent: 16, endIndent: 16),
          Text('About', style: ZTypography.overline),
          const ZListTile(
            title: 'Terms & privacy',
            leading: Icon(Icons.description_outlined, color: ZColors.textSecondary),
            showChevron: false,
          ),
          const ZListTile(
            title: 'App version',
            subtitle: 'Zuum 0.1.0 (mock API build)',
            leading: Icon(Icons.info_outline_rounded, color: ZColors.textSecondary),
            showChevron: false,
          ),
          const SizedBox(height: ZSpacing.xl),
          Center(
            child: Text(
              'Old Bengaluru soul. New Bengaluru movement.',
              style: ZTypography.kannada(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile editing.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _firstName.text = user?.firstName ?? '';
    _lastName.text = user?.lastName ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final user = await ref.read(apiContractProvider).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      ref.read(authControllerProvider.notifier).updateUser(user);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Edit profile', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: ZTextField(
                  controller: _firstName,
                  label: 'First name',
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: ZSpacing.md),
              Expanded(
                child: ZTextField(
                  controller: _lastName,
                  label: 'Last name',
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.lg),
          ZTextField(
            controller: _phone,
            label: 'Phone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: ZSpacing.xxl),
          ZButton(
            label: 'Save changes',
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// Saved addresses — list + add + delete.
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(_addressesProvider);
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Saved addresses', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ZColors.primary,
        foregroundColor: ZColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.pill),
        ),
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add address'),
      ),
      body: addresses.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(ZSpacing.lg),
          child: ZSkeletonList(itemCount: 3),
        ),
        error: (_, _) => ZErrorState(
          title: 'Could not load addresses',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(_addressesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const ZEmptyState(
              title: 'No saved addresses',
              subtitle: 'Save home and work for faster bookings.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(ZSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: ZSpacing.sm),
            itemBuilder: (_, i) {
              final a = list[i];
              return ZCard(
                padding: const EdgeInsets.all(ZSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      a.label == 'home'
                          ? Icons.home_outlined
                          : a.label == 'work'
                              ? Icons.work_outline_rounded
                              : Icons.bookmark_outline_rounded,
                      color: ZColors.primary,
                    ),
                    const SizedBox(width: ZSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name.isEmpty ? a.label : a.name,
                            style: ZTypography.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.address,
                            style: ZTypography.caption
                                .copyWith(color: ZColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ZIconButton(
                      icon: Icons.delete_outline_rounded,
                      foreground: ZColors.error,
                      tooltip: 'Delete',
                      onPressed: () async {
                        await ref
                            .read(apiContractProvider)
                            .deleteSavedAddress(a.id);
                        ref.invalidate(_addressesProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final address = TextEditingController();
    var label = 'home';
    ZSheet.show<void>(
      context: context,
      title: 'Add address',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final l in const ['home', 'work', 'other'])
                  Padding(
                    padding: const EdgeInsets.only(right: ZSpacing.sm),
                    child: ZChip(
                      label: l[0].toUpperCase() + l.substring(1),
                      selected: label == l,
                      onTap: () => setSheetState(() => label = l),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZSpacing.lg),
            ZTextField(
              controller: name,
              label: 'Name (e.g. Home)',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: ZSpacing.lg),
            ZTextField(
              controller: address,
              label: 'Full address',
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: ZSpacing.xl),
            ZButton(
              label: 'Save address',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(sheetContext);
                if (address.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Enter an address')),
                  );
                  return;
                }
                // Coordinates default to central Bengaluru until the map
                // picker lands with the Mapbox/OSM location flow.
                await ref.read(apiContractProvider).createSavedAddress(
                      label: label,
                      name: name.text.trim().isEmpty ? label : name.text.trim(),
                      lat: 12.9716,
                      lng: 77.5946,
                      address: address.text.trim(),
                    );
                ref.invalidate(_addressesProvider);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Address saved')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment methods management (display + mock wallet/UPI info).
class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Payment methods', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          const ZListTile(
            title: 'Cash',
            subtitle: 'Pay drivers directly',
            leading: Icon(Icons.payments_outlined, color: ZColors.textSecondary),
            showChevron: false,
          ),
          const ZListTile(
            title: 'UPI',
            subtitle: 'Paid at the end of the trip',
            leading: Icon(Icons.account_balance_outlined,
                color: ZColors.textSecondary),
            showChevron: false,
          ),
          ZListTile(
            title: 'Zuum Wallet',
            subtitle: 'Manage in the Wallet tab',
            leading: const Icon(Icons.account_balance_wallet_outlined,
                color: ZColors.textSecondary),
            onTap: () => context.go('/wallet'),
          ),
          const Divider(indent: 16, endIndent: 16),
          const ZBadge(label: 'Saved UPI IDs & cards arrive with Razorpay keys'),
        ],
      ),
    );
  }
}

final _addressesProvider = FutureProvider<List<SavedAddress>>(
  (ref) => ref.watch(apiContractProvider).savedAddresses(),
);
