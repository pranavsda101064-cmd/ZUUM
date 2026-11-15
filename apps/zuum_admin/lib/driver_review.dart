import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

import 'admin_api.dart';
import 'admin_widgets.dart';

class DriverReviewDialog extends StatefulWidget {
  const DriverReviewDialog({
    super.key,
    required this.driverId,
    required this.api,
    required this.onChanged,
  });

  final String driverId;
  final AdminApi api;
  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required String driverId,
    required AdminApi api,
    required VoidCallback onChanged,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: ZColors.dark.withValues(alpha: 0.8),
      builder: (_) => DriverReviewDialog(
        driverId: driverId,
        api: api,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<DriverReviewDialog> createState() => _DriverReviewDialogState();
}

class _DriverReviewDialogState extends State<DriverReviewDialog> {
  late Future<OpsDriverDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.driverDetail(widget.driverId);
  }

  void _reload() {
    setState(() => _future = widget.api.driverDetail(widget.driverId));
    widget.onChanged();
  }

  Future<void> _review(OpsDocument document, String status) async {
    var note = '';
    if (status == 'rejected') {
      final controller = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: ZColors.darkRaised,
          title: const Text(
            'Reject document',
            style: TextStyle(color: ZColors.onDark),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(color: ZColors.onDark),
            decoration: InputDecoration(
              hintText: 'What is wrong with this ${document.label.toLowerCase()}?',
              hintStyle: const TextStyle(color: ZColors.onDarkSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialog).pop(controller.text.trim()),
              child: const Text(
                'Reject document',
                style: TextStyle(color: ZColors.error),
              ),
            ),
          ],
        ),
      );
      if (reason == null || reason.isEmpty) return;
      note = reason;
    }
    setState(() => _busy = true);
    try {
      await widget.api.reviewDocument(
        id: document.id,
        status: status,
        note: note,
      );
      if (!mounted) return;
      _reload();
    } on AdminApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not update the document');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveDriver() async {
    setState(() => _busy = true);
    try {
      await widget.api.approveDriver(widget.driverId);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } on AdminApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectDriver() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: ZColors.darkRaised,
        title: const Text(
          'Reject application',
          style: TextStyle(color: ZColors.onDark),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          style: const TextStyle(color: ZColors.onDark),
          decoration: const InputDecoration(
            hintText: 'Reason shared with the captain',
            hintStyle: TextStyle(color: ZColors.onDarkSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: const Text(
              'Reject application',
              style: TextStyle(color: ZColors.error),
            ),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.api.rejectDriver(widget.driverId, reason);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } on AdminApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _view(OpsDocument document, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: ZColors.dark.withValues(alpha: 0.92),
      builder: (_) => Dialog(
        backgroundColor: ZColors.darkRaised,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.label,
                        style: ZTypography.titleMd.copyWith(
                          color: ZColors.onDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: ZColors.onDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(child: Image.memory(bytes)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ZColors.darkRaised,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZRadii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 620),
        child: FutureBuilder<OpsDriverDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SizedBox(
                height: 340,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ZColors.onDarkSecondary,
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(ZSpacing.xxl),
                child: AdminError(
                  message: snapshot.error is AdminApiException
                      ? (snapshot.error as AdminApiException).message
                      : 'Could not load this captain',
                  onRetry: _reload,
                ),
              );
            }
            final detail = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(ZSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(detail),
                  const SizedBox(height: ZSpacing.lg),
                  const Divider(height: 1, color: ZColors.darkOutline),
                  const SizedBox(height: ZSpacing.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 440),
                    child: MediaQuery.sizeOf(context).width >= 1000
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: _documents(detail)),
                              const SizedBox(width: ZSpacing.xl),
                              SizedBox(width: 300, child: _decision(detail)),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _documents(detail),
                                const SizedBox(height: ZSpacing.lg),
                                _decision(detail),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(OpsDriverDetail detail) {
    final driver = detail.driver;
    return Row(
      children: [
        AdminAvatar(label: driver.name, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminEyebrow('KYC review · ${_shortId(detail.driver.id)}'),
              const SizedBox(height: 4),
              Text(
                driver.name,
                style: ZTypography.titleLg.copyWith(color: ZColors.onDark),
              ),
              Text(
                '${driver.email}  ·  ${driver.phone.isEmpty ? 'No phone' : driver.phone}',
                style: ZTypography.caption.copyWith(
                  color: ZColors.onDarkSecondary,
                ),
              ),
            ],
          ),
        ),
        AdminPill(
          label: _title(driver.kycStatus),
          tone: AdminPill.toneFor(driver.kycStatus),
          dot: true,
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close_rounded,
            color: ZColors.onDarkSecondary,
          ),
        ),
      ],
    );
  }

  Widget _documents(OpsDriverDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminEyebrow('Documents'),
        const SizedBox(height: 10),
        for (final document in detail.documents) ...[
          _DocumentCard(
            key: ValueKey(document.id),
            document: document,
            api: widget.api,
            busy: _busy,
            onView: (bytes) => _view(document, bytes),
            onApprove: () => _review(document, 'verified'),
            onReject: () => _review(document, 'rejected'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _decision(OpsDriverDetail detail) {
    final driver = detail.driver;
    final verified = detail.documents
        .where((document) => document.status == 'verified')
        .length;
    final rejected = detail.documents
        .where((document) => document.status == 'rejected')
        .length;
    final required = detail.documents
        .where((document) =>
            const {'licence', 'rc', 'insurance'}.contains(document.type))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminEyebrow('Decision'),
        const SizedBox(height: 10),
        AdminPanel(
          color: ZColors.darkSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CheckLine(
                label: 'Documents verified',
                value: '$verified / $required',
                ok: detail.documentsVerified,
              ),
              const SizedBox(height: 10),
              _CheckLine(
                label: 'Rejected documents',
                value: '$rejected',
                ok: rejected == 0,
              ),
              const SizedBox(height: 10),
              _CheckLine(
                label: 'Vehicle',
                value: driver.vehicles.isEmpty
                    ? 'None'
                    : driver.vehicles.first,
                ok: driver.vehicles.isNotEmpty,
              ),
              const SizedBox(height: ZSpacing.lg),
              if (driver.isApproved) ...[
                Text(
                  'This captain is already approved.',
                  style: ZTypography.caption.copyWith(
                    color: ZColors.onDarkSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                AdminButton(
                  label: 'Suspend captain',
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await widget.api.suspendDriver(driver.id);
                            widget.onChanged();
                            if (mounted) Navigator.of(context).pop();
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                ),
              ] else ...[
                AdminButton(
                  label: 'Approve captain',
                  primary: true,
                  icon: Icons.verified_user_outlined,
                  busy: _busy,
                  onPressed: detail.documentsVerified ? _approveDriver : null,
                ),
                if (!detail.documentsVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Verify all three required documents first.',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onDarkSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                AdminButton(
                  label: 'Reject application',
                  danger: true,
                  onPressed: _busy ? null : _rejectDriver,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentCard extends StatefulWidget {
  const _DocumentCard({
    super.key,
    required this.document,
    required this.api,
    required this.busy,
    required this.onView,
    required this.onApprove,
    required this.onReject,
  });

  final OpsDocument document;
  final AdminApi api;
  final bool busy;
  final ValueChanged<Uint8List> onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.document.fileAvailable
        ? widget.api.documentBytes(widget.document.id)
        : Future.value(null);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZColors.darkSurface,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(
          color: doc.status == 'rejected'
              ? ZColors.error.withValues(alpha: 0.4)
              : ZColors.darkOutline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return GestureDetector(
                onTap: bytes == null ? null : () => widget.onView(bytes),
                child: Container(
                  width: 142,
                  height: 96,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: ZColors.darkRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZColors.darkOutline),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: ZColors.onDarkSecondary,
                            ),
                          ),
                        )
                      : bytes == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 22,
                                    color: ZColors.onDarkSecondary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doc.fileAvailable
                                        ? 'Preview unavailable'
                                        : 'No file uploaded',
                                    style: ZTypography.overline.copyWith(
                                      color: ZColors.onDarkSecondary,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: ZColors.onDarkSecondary,
                                ),
                              ),
                            ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.label,
                        style: ZTypography.captionStrong.copyWith(
                          color: ZColors.onDark,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    AdminPill(
                      label: _title(doc.status),
                      tone: AdminPill.toneFor(doc.status),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  doc.expiresAt == null
                      ? 'No expiry on file'
                      : 'Expires ${ZFormat.shortDate(doc.expiresAt!)}',
                  style: ZTypography.overline.copyWith(
                    color: ZColors.onDarkSecondary,
                    fontSize: 9,
                  ),
                ),
                if (doc.reviewNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    doc.reviewNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ZTypography.caption.copyWith(
                      color: ZColors.error,
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (doc.status != 'verified')
                      AdminButton(
                        label: 'Verify',
                        compact: true,
                        primary: true,
                        onPressed: widget.busy ? null : widget.onApprove,
                      ),
                    if (doc.status != 'rejected')
                      AdminButton(
                        label: 'Reject',
                        compact: true,
                        danger: true,
                        onPressed: widget.busy ? null : widget.onReject,
                      ),
                    if (doc.status == 'rejected')
                      AdminButton(
                        label: 'Re-verify',
                        compact: true,
                        onPressed: widget.busy ? null : widget.onApprove,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          size: 14,
          color: ok ? ZColors.success : ZColors.warning,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: ZTypography.caption.copyWith(
              color: ZColors.onDarkSecondary,
              fontSize: 10,
            ),
          ),
        ),
        Text(
          value,
          style: ZTypography.captionStrong.copyWith(
            color: ok ? ZColors.onDark : ZColors.warning,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

String _title(String value) {
  final text = value.replaceAll('_', ' ').toLowerCase();
  if (text.isEmpty) return value;
  return text
      .split(' ')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;
