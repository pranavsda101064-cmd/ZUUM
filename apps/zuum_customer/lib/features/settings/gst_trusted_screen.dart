import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_design_system/design_system.dart';

/// Local, session-persisted GST details (mock — the Phase 2 backend
/// stores these server-side on the customer profile).
class GstDetails {
  const GstDetails({this.gstin, this.businessName});

  final String? gstin;
  final String? businessName;
}

class GstController extends Notifier<GstDetails> {
  @override
  GstDetails build() => const GstDetails();

  void update(GstDetails details) => state = details;
}

final gstDetailsProvider =
    NotifierProvider<GstController, GstDetails>(GstController.new);

/// Business GST details — B2B invoicing for goods transport (spec §2o).
class GstDetailsScreen extends ConsumerStatefulWidget {
  const GstDetailsScreen({super.key});

  @override
  ConsumerState<GstDetailsScreen> createState() => _GstDetailsScreenState();
}

class _GstDetailsScreenState extends ConsumerState<GstDetailsScreen> {
  late final _gstin = TextEditingController(
    text: ref.read(gstDetailsProvider).gstin ?? '',
  );
  late final _business = TextEditingController(
    text: ref.read(gstDetailsProvider).businessName ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _gstin.dispose();
    _business.dispose();
    super.dispose();
  }

  void _save() {
    final gstin = _gstin.text.trim();
    if (gstin.isNotEmpty && gstin.length != 15) {
      setState(() => _error = 'GSTIN must be 15 characters');
      return;
    }
    ref.read(gstDetailsProvider.notifier).update(GstDetails(
          gstin: gstin.isEmpty ? null : gstin,
          businessName: _business.text.trim().isEmpty
              ? null
              : _business.text.trim(),
        ));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GST details saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.surface,
      appBar: const ZAppBar(title: 'Business GST details', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          Text(
            'Add your GSTIN to include GST on B2B goods transport invoices.',
            style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
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
          ZButton(label: 'Save details', onPressed: _save),
        ],
      ),
    );
  }
}

/// Trusted contacts (mock, session-local) — spec §2o safety block.
class TrustedContactsScreen extends ConsumerStatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  ConsumerState<TrustedContactsScreen> createState() =>
      _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends ConsumerState<TrustedContactsScreen> {
  final _contacts = <(String, String)>[
    ('Amma', '+91 98450 00001'),
    ('Appa', '+91 98450 00002'),
  ];

  void _add() {
    final name = TextEditingController();
    final phone = TextEditingController();
    ZSheet.show<void>(
      context: context,
      title: 'Add trusted contact',
      child: Column(
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
            onPressed: () {
              if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                return;
              }
              setState(() =>
                  _contacts.add((name.text.trim(), phone.text.trim())));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        padding: const EdgeInsets.all(ZSpacing.lg),
        children: [
          Text(
            'Trusted contacts auto-receive your live trip link for '
            'night rides (10 PM–6 AM).',
            style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
          ),
          const SizedBox(height: ZSpacing.lg),
          if (_contacts.isEmpty)
            const ZEmptyState(
              illustration: 'empty_metro',
              title: 'No trusted contacts yet',
              subtitle: 'Add family who should always know where you are.',
            )
          else
            for (final (name, phone) in _contacts)
              ZListTile(
                title: name,
                subtitle: phone,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: ZColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: ZColors.primary,
                  ),
                ),
                showChevron: false,
                trailing: ZIconButton(
                  icon: Icons.delete_outline_rounded,
                  foreground: ZColors.error,
                  onPressed: () =>
                      setState(() => _contacts.remove((name, phone))),
                ),
              ),
        ],
      ),
    );
  }
}
