import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

final gstDetailsProvider = FutureProvider<GstDetails>(
  (ref) => ref.watch(apiContractProvider).gstDetails(),
);

final trustedContactsProvider = FutureProvider<List<TrustedContact>>(
  (ref) => ref.watch(apiContractProvider).trustedContacts(),
);

/// Business GST details for B2B goods transport invoices.
class GstDetailsScreen extends ConsumerStatefulWidget {
  const GstDetailsScreen({super.key});

  @override
  ConsumerState<GstDetailsScreen> createState() => _GstDetailsScreenState();
}

class _GstDetailsScreenState extends ConsumerState<GstDetailsScreen> {
  final _gstin = TextEditingController();
  final _business = TextEditingController();
  String? _error;
  bool _hydrated = false;
  bool _busy = false;

  @override
  void dispose() {
    _gstin.dispose();
    _business.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final gstin = _gstin.text.trim().toUpperCase();
    if (gstin.isNotEmpty && gstin.length != 15) {
      setState(() => _error = 'GSTIN must be 15 characters');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await ref.read(apiContractProvider).saveGstDetails(
            gstin: gstin,
            businessName: _business.text.trim(),
          );
      ref.invalidate(gstDetailsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GST details saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.message : 'Could not save GST details';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(gstDetailsProvider);
    return Scaffold(
      backgroundColor: ZColors.surface,
      appBar: const ZAppBar(title: 'Business GST details', showBack: true),
      body: details.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(ZSpacing.lg),
          child: ZSkeletonList(itemCount: 3),
        ),
        error: (_, _) => ZErrorState(
          title: 'Could not load GST details',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(gstDetailsProvider),
        ),
        data: (value) {
          if (!_hydrated) {
            _gstin.text = value.gstin ?? '';
            _business.text = value.businessName ?? '';
            _hydrated = true;
          }
          return ListView(
            padding: const EdgeInsets.all(ZSpacing.lg),
            children: [
              Text(
                'Add your GSTIN to include GST on B2B goods transport invoices.',
                style:
                    ZTypography.caption.copyWith(color: ZColors.textSecondary),
              ),
              const SizedBox(height: ZSpacing.xl),
              ZTextField(
                controller: _gstin,
                label: 'GSTIN (15 characters)',
                hint: '29ABCDE1234F1Z5',
                textCapitalization: TextCapitalization.characters,
                errorText: _error,
              ),
              const SizedBox(height: ZSpacing.lg),
              ZTextField(
                controller: _business,
                label: 'Business name',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: ZSpacing.xxl),
              ZButton(
                label: 'Save details',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Trusted contacts for night-ride safety sharing.
class TrustedContactsScreen extends ConsumerStatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  ConsumerState<TrustedContactsScreen> createState() =>
      _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends ConsumerState<TrustedContactsScreen> {
  void _add() {
    final name = TextEditingController();
    final phone = TextEditingController();
    var saving = false;
    ZSheet.show<void>(
      context: context,
      title: 'Add trusted contact',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
            setSheetState(() => saving = true);
            try {
              await ref.read(apiContractProvider).addTrustedContact(
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                  );
              ref.invalidate(trustedContactsProvider);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trusted contact added')),
              );
            } catch (e) {
              if (!sheetContext.mounted) return;
              setSheetState(() => saving = false);
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(
                    e is ApiException
                        ? e.message
                        : 'Could not add the contact',
                  ),
                ),
              );
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ZTextField(
                controller: name,
                label: 'Name',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: ZSpacing.lg),
              ZTextField(
                controller: phone,
                label: 'Mobile',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: ZSpacing.xl),
              ZButton(
                label: 'Add contact',
                loading: saving,
                onPressed: saving ? null : submit,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(TrustedContact contact) async {
    try {
      await ref.read(apiContractProvider).deleteTrustedContact(contact.id);
      ref.invalidate(trustedContactsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not remove the contact',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(trustedContactsProvider);
    return Scaffold(
      backgroundColor: ZColors.surface,
      appBar: const ZAppBar(title: 'Trusted contacts', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ZColors.primary,
        foregroundColor: ZColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.pill),
        ),
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add contact'),
      ),
      body: contacts.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(ZSpacing.lg),
          child: ZSkeletonList(itemCount: 3),
        ),
        error: (_, _) => ZErrorState(
          title: 'Could not load contacts',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(trustedContactsProvider),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: [
            Text(
              'Trusted contacts auto-receive your live trip link for '
              'night rides (10 PM–6 AM).',
              style:
                  ZTypography.caption.copyWith(color: ZColors.textSecondary),
            ),
            const SizedBox(height: ZSpacing.lg),
            if (list.isEmpty)
              const ZEmptyState(
                illustration: 'empty_metro',
                title: 'No trusted contacts yet',
                subtitle: 'Add family who should always know where you are.',
              )
            else
              for (final contact in list)
                ZListTile(
                  title: contact.name,
                  subtitle: contact.phone,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: ZColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: ZColors.primary,
                    ),
                  ),
                  showChevron: false,
                  trailing: ZIconButton(
                    icon: Icons.delete_outline_rounded,
                    foreground: ZColors.error,
                    onPressed: () => _delete(contact),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
