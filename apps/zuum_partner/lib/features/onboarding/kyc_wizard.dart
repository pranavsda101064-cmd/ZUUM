import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../../shared/widgets/error_banner.dart';

/// Partner onboarding — 5 steps: details → licence → vehicle → documents →
/// payout. Submits KYC for review; the router then holds the partner on the
/// pending screen until approval.
class KycWizard extends ConsumerStatefulWidget {
  const KycWizard({super.key});

  @override
  ConsumerState<KycWizard> createState() => _KycWizardState();
}

class _KycWizardState extends ConsumerState<KycWizard> {
  static const _steps = ['Details', 'Licence', 'Vehicle', 'Docs', 'Payout'];
  static const _rideCategories = ['auto', 'bike', 'sedan', 'suv'];
  static const _goodsCategories = ['ace', 'pickup', 'van', 'tempo'];

  int _step = 0;
  String? _error;
  bool _busy = false;
  bool _vehicleCreated = false;

  late final _firstName = TextEditingController(
    text: ref.read(partnerAuthProvider).user?.firstName ?? '',
  );
  late final _lastName = TextEditingController(
    text: ref.read(partnerAuthProvider).user?.lastName ?? '',
  );
  late final _phone = TextEditingController(
    text: ref.read(partnerAuthProvider).user?.phone ?? '',
  );
  final _languages = <String>{'Kannada', 'English'};

  final _licenceNumber = TextEditingController();
  late DateTime _licenceExpiry =
      DateTime.now().add(const Duration(days: 365 * 5));

  String? _category;
  final _regNo = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();

  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _phone,
      _licenceNumber,
      _regNo, _make, _model, _color,
      _holder, _account, _ifsc,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  PartnerApiContract get _api => ref.read(partnerApiProvider);

  bool _validateStep() {
    switch (_step) {
      case 0:
        final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
          _error = 'Enter your first and last name';
          return false;
        }
        if (digits.length < 10) {
          _error = 'Enter a valid 10-digit mobile number';
          return false;
        }
        if (_languages.isEmpty) {
          _error = 'Select at least one language you speak';
          return false;
        }
        return true;
      case 1:
        if (_licenceNumber.text.trim().length < 6) {
          _error = 'Enter your driving licence number';
          return false;
        }
        if (_licenceExpiry.isBefore(DateTime.now())) {
          _error = 'Licence has expired';
          return false;
        }
        return true;
      case 2:
        if (_category == null) {
          _error = 'Choose your vehicle category';
          return false;
        }
        if (_regNo.text.trim().length < 6 ||
            _make.text.trim().isEmpty ||
            _model.text.trim().isEmpty ||
            _color.text.trim().isEmpty) {
          _error = 'Fill in the vehicle registration and details';
          return false;
        }
        return true;
      case 3:
        final docs = ref.read(partnerDocumentsProvider).value ?? const [];
        final missing = [
          for (final t in const [
            KycDocType.licence,
            KycDocType.rc,
            KycDocType.insurance,
          ])
            if (!docs.any((d) => d.type == t)) t.name,
        ];
        if (missing.isNotEmpty) {
          _error = 'Upload all three documents to continue';
          return false;
        }
        return true;
      case 4:
        final account = _account.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (_holder.text.trim().isEmpty) {
          _error = 'Enter the account holder name';
          return false;
        }
        if (account.length < 9) {
          _error = 'Enter a valid account number';
          return false;
        }
        if (_ifsc.text.trim().length != 11) {
          _error = 'Enter a valid 11-character IFSC code';
          return false;
        }
        return true;
    }
    return true;
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_validateStep()) {
      setState(() {});
      return;
    }

    if (_step == 2 && !_vehicleCreated) {
      setState(() => _busy = true);
      try {
        await _api.createVehicle(
          categoryCode: _category!,
          registrationNumber: _regNo.text,
          make: _make.text,
          model: _model.text,
          color: _color.text,
        );
        _vehicleCreated = true;
        ref.invalidate(partnerVehiclesProvider);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = e.message;
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Could not save the vehicle. Try again.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }

    if (_step == 4) {
      setState(() => _busy = true);
      try {
        await _api.savePayoutAccount(
          holderName: _holder.text.trim(),
          accountNumber: _account.text.trim(),
          ifsc: _ifsc.text.trim().toUpperCase(),
        );
        await _api.submitKyc();
        ref.invalidate(partnerDocumentsProvider);
        ref.invalidate(partnerVehiclesProvider);
        await ref.read(partnerAuthProvider.notifier).refreshProfile();
        // Router redirect takes over → /onboarding/pending.
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Could not submit your application. Try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _error = null;
      _step--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(partnerDocumentsProvider).value ?? const [];
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Partner onboarding',
        subtitle: 'Step ${_step + 1} of ${_steps.length}',
        showBack: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZSpacing.lg),
            child: ZStepper(steps: _steps, currentIndex: _step),
          ),
          const SizedBox(height: ZSpacing.md),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.lg,
                0,
                ZSpacing.lg,
                ZSpacing.xxl,
              ),
              children: [
                if (_error != null) ...[
                  ZErrorBanner(message: _error!),
                  const SizedBox(height: ZSpacing.lg),
                ],
                switch (_step) {
                  0 => _detailsStep(),
                  1 => _licenceStep(),
                  2 => _vehicleStep(),
                  3 => _documentsStep(docs),
                  _ => _payoutStep(),
                },
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            ZSpacing.lg,
            ZSpacing.md,
            ZSpacing.lg,
            ZSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: ZColors.surface,
            border: Border(top: BorderSide(color: ZColors.divider)),
          ),
          child: Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: _busy ? null : _back,
                  child: Text(
                    'Back',
                    style: ZTypography.bodyStrong
                        .copyWith(color: ZColors.textSecondary),
                  ),
                ),
              const SizedBox(width: ZSpacing.sm),
              Expanded(
                child: ZButton(
                  label: _step == 4 ? 'Submit for review' : 'Continue',
                  loading: _busy,
                  onPressed: _busy ? null : _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Personal details', style: ZTypography.titleMd),
        const SizedBox(height: ZSpacing.xs),
        Text(
          'This appears on your partner profile. Your phone is used for trip '
          'coordination.',
          style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        ),
        const SizedBox(height: ZSpacing.xl),
        Row(
          children: [
            Expanded(
              child: ZTextField(controller: _firstName, label: 'First name'),
            ),
            const SizedBox(width: ZSpacing.md),
            Expanded(
              child: ZTextField(controller: _lastName, label: 'Last name'),
            ),
          ],
        ),
        const SizedBox(height: ZSpacing.lg),
        ZTextField(
          controller: _phone,
          label: 'Mobile number',
          hint: '98450 12345',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
        ),
        const SizedBox(height: ZSpacing.xl),
        Text('Languages you speak', style: ZTypography.overline),
        const SizedBox(height: ZSpacing.sm),
        Wrap(
          spacing: ZSpacing.sm,
          runSpacing: ZSpacing.sm,
          children: [
            for (final language in const ['Kannada', 'English', 'Hindi', 'Tamil'])
              ZChip(
                label: language,
                selected: _languages.contains(language),
                onTap: () => setState(() {
                  if (!_languages.remove(language)) _languages.add(language);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _licenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Driving licence', style: ZTypography.titleMd),
        const SizedBox(height: ZSpacing.xs),
        Text(
          'Your licence is verified against the documents you upload next.',
          style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        ),
        const SizedBox(height: ZSpacing.xl),
        ZTextField(
          controller: _licenceNumber,
          label: 'Licence number',
          hint: 'KA0120180012345',
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: ZSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpacing.lg,
            vertical: ZSpacing.md,
          ),
          decoration: BoxDecoration(
            color: ZColors.surface,
            borderRadius: BorderRadius.circular(ZRadii.md),
            border: Border.all(color: ZColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, color: ZColors.textSecondary),
              const SizedBox(width: ZSpacing.md),
              Expanded(
                child: Text(
                  'Valid till ${ZFormat.shortDate(_licenceExpiry)}',
                  style: ZTypography.body,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _licenceExpiry,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
                  );
                  if (picked != null) {
                    setState(() => _licenceExpiry = picked);
                  }
                },
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vehicleStep() {
    String labelFor(String code) => const {
          'auto': 'Auto',
          'bike': 'Bike',
          'sedan': 'Sedan',
          'suv': 'SUV',
          'ace': 'Tata Ace',
          'pickup': 'Pickup',
          'van': 'Van',
          'tempo': 'Tempo',
        }[code] ??
        code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your vehicle', style: ZTypography.titleMd),
        const SizedBox(height: ZSpacing.xs),
        Text(
          'You can add more vehicles later from the Vehicles tab.',
          style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        ),
        const SizedBox(height: ZSpacing.xl),
        Text('Passenger', style: ZTypography.overline),
        const SizedBox(height: ZSpacing.sm),
        Wrap(
          spacing: ZSpacing.sm,
          runSpacing: ZSpacing.sm,
          children: [
            for (final code in _rideCategories)
              ZChip(
                label: labelFor(code),
                selected: _category == code,
                onTap: () => setState(() => _category = code),
              ),
          ],
        ),
        const SizedBox(height: ZSpacing.md),
        Text('Goods', style: ZTypography.overline),
        const SizedBox(height: ZSpacing.sm),
        Wrap(
          spacing: ZSpacing.sm,
          runSpacing: ZSpacing.sm,
          children: [
            for (final code in _goodsCategories)
              ZChip(
                label: labelFor(code),
                selected: _category == code,
                onTap: () => setState(() => _category = code),
              ),
          ],
        ),
        const SizedBox(height: ZSpacing.xl),
        ZTextField(
          controller: _regNo,
          label: 'Registration number',
          hint: 'KA 05 AB 1234',
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: ZSpacing.lg),
        Row(
          children: [
            Expanded(child: ZTextField(controller: _make, label: 'Make')),
            const SizedBox(width: ZSpacing.md),
            Expanded(child: ZTextField(controller: _model, label: 'Model')),
          ],
        ),
        const SizedBox(height: ZSpacing.lg),
        ZTextField(controller: _color, label: 'Colour'),
      ],
    );
  }

  Widget _documentsStep(List<KycDocumentInfo> docs) {
    ZDocStatus statusFor(KycDocType type, DateTime? expiresAt) {
      final doc = docs.where((d) => d.type == type).firstOrNull;
      if (doc == null) return ZDocStatus.missing;
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        return ZDocStatus.expired;
      }
      return ZDocStatus.pending;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Documents', style: ZTypography.titleMd),
        const SizedBox(height: ZSpacing.xs),
        Text(
          'Clear photos, no glare. All three are required before review.',
          style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        ),
        const SizedBox(height: ZSpacing.xl),
        ZDocumentTile(
          label: 'Driving licence',
          status: statusFor(KycDocType.licence, null),
          fileName: docs
              .where((d) => d.type == KycDocType.licence)
              .firstOrNull
              ?.filePath,
          onTap: () => _pickDocument(KycDocType.licence),
        ),
        const SizedBox(height: ZSpacing.sm),
        ZDocumentTile(
          label: 'Vehicle RC',
          status: statusFor(KycDocType.rc, null),
          fileName:
              docs.where((d) => d.type == KycDocType.rc).firstOrNull?.filePath,
          onTap: () => _pickDocument(KycDocType.rc),
        ),
        const SizedBox(height: ZSpacing.sm),
        ZDocumentTile(
          label: 'Insurance',
          status: statusFor(KycDocType.insurance, null),
          fileName: docs
              .where((d) => d.type == KycDocType.insurance)
              .firstOrNull
              ?.filePath,
          onTap: () => _pickDocument(KycDocType.insurance),
        ),
        const SizedBox(height: ZSpacing.lg),
        const ZBadge(label: 'Uploaded securely to Zuum'),
      ],
    );
  }

  Widget _payoutStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Payout account', style: ZTypography.titleMd),
        const SizedBox(height: ZSpacing.xs),
        Text(
          'Earnings are settled weekly to this bank account. Zuum keeps a 20% '
          'commission per completed trip.',
          style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        ),
        const SizedBox(height: ZSpacing.xl),
        ZTextField(controller: _holder, label: 'Account holder name'),
        const SizedBox(height: ZSpacing.lg),
        ZTextField(
          controller: _account,
          label: 'Account number',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: ZSpacing.lg),
        ZTextField(
          controller: _ifsc,
          label: 'IFSC code',
          hint: 'HDFC0001234',
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: ZSpacing.xl),
        Container(
          padding: const EdgeInsets.all(ZSpacing.md),
          decoration: BoxDecoration(
            color: ZColors.accent,
            borderRadius: BorderRadius.circular(ZRadii.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: ZColors.primary),
              const SizedBox(width: ZSpacing.sm),
              Expanded(
                child: Text(
                  'The account is verified by the ops team during KYC review.',
                  style: ZTypography.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDocument(KycDocType type) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    String? path;
    try {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      path = picked?.path;
    } catch (_) {
      path = null;
    }
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera or gallery unavailable. Check permissions and try again.',
          ),
        ),
      );
      return;
    }

    try {
      await _api.uploadDocument(
        type: type,
        filePath: path,
        expiresAt: type == KycDocType.insurance
            ? DateTime.now().add(const Duration(days: 365))
            : null,
      );
      ref.invalidate(partnerDocumentsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }
}
