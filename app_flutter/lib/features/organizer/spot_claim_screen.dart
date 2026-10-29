// lib/features/organizer/spot_claim_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// Rows shown for a search (the directory holds every active spot).
const _maxResults = 20;

/// S30.02 "Nhận quản lý điểm" at `/organizer/spots/claim` (mock `#S30.02`):
/// pick an S29 spot nobody manages (or propose a new place), add 1–3 proof
/// photos, send (`claimSpot`). The latest claim decides the state: pending is
/// read-only, rejected shows the reason and "Gửi lại". Proofs are JPEG photos
/// (the app has no document picker; PDFs stay a Storage-side option).
class SpotClaimScreen extends ConsumerStatefulWidget {
  const SpotClaimScreen({super.key});

  @override
  ConsumerState<SpotClaimScreen> createState() => _SpotClaimScreenState();
}

class _SpotClaimScreenState extends ConsumerState<SpotClaimScreen> {
  final _search = TextEditingController();
  String? _spotId;
  SpotProposal? _proposal;
  final List<PickedImage> _proofs = [];
  bool _needFile = false;
  bool _busy = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final left = claimProofsMax - _proofs.length;
    if (left <= 0) {
      orgSay(context, context.l10n.s3002_maxFiles);
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: left);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _proofs.addAll(picked.take(left));
      _needFile = false;
    });
  }

  Future<void> _propose() async {
    final p = await showAppSheet<SpotProposal>(
      context,
      builder: (_) => _ProposeSheet(initial: _proposal),
    );
    if (p != null && mounted) {
      setState(() {
        _proposal = p;
        _spotId = null;
      });
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() => _error = null);
    if (_spotId == null && _proposal == null) {
      orgSay(context, l.s3002_pickSpot);
      return;
    }
    if (_proofs.isEmpty) {
      setState(() => _needFile = true);
      return;
    }
    setState(() => _busy = true);
    final code = await ref
        .read(organizerActionsProvider)
        .run(
          (r) => r.claimSpot(
            spotId: _spotId,
            proposal: _spotId == null ? _proposal : null,
            proofs: List.of(_proofs),
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (code) {
      case null:
        setState(() {
          _resending = false;
          _proofs.clear();
        });
        orgSay(context, l.s3002_sent);
      case 'spot_managed':
        setState(() => _error = l.s3002_managedError);
      case 'limit_exceeded':
        setState(() => _error = l.s3002_limit);
      default:
        orgSay(context, organizerErrorText(l, code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final claims = ref.watch(mySpotClaimsProvider);
    return ScreenCode(
      ScreenCodes.spotClaim,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.s3002_title)),
          body: AsyncView<List<SpotClaim>>(
            value: claims,
            onRetry: () => ref.invalidate(mySpotClaimsProvider),
            data: (context, list) {
              final latest = list.firstOrNull;
              if (latest?.status == SpotClaimStatus.pending) {
                return _Decided(claim: latest!);
              }
              if (latest?.status == SpotClaimStatus.rejected && !_resending) {
                return _Decided(claim: latest!);
              }
              return _form(context);
            },
          ),
          bottomNavigationBar: AppFooterBar(child: _footer(claims.value)),
        ),
      ),
    );
  }

  Widget _footer(List<SpotClaim>? claims) {
    final l = context.l10n;
    final latest = claims?.firstOrNull;
    if (latest?.status == SpotClaimStatus.rejected && !_resending) {
      return AppButton.primary(
        l.s3002_resend,
        key: const Key('claim-resend'),
        onPressed: () => setState(() {
          _resending = true;
          _spotId = latest!.spotId;
          _proposal = latest.proposal;
        }),
      );
    }
    final pending = latest?.status == SpotClaimStatus.pending;
    return AppButton.primary(
      l.s3002_submit,
      key: const Key('claim-submit'),
      loading: _busy,
      onPressed: claims == null || pending || _busy ? null : _submit,
    );
  }

  Widget _form(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final directory = ref.watch(spotDirectoryProvider).value ?? const [];
    final q = foldVietnamese(_search.text.trim());
    final results = [
      for (final e in directory)
        if (q.isEmpty || foldVietnamese(e.name).contains(q)) e,
    ].take(_maxResults).toList();
    final proposal = _proposal;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        TextField(
          key: const Key('claim-search'),
          controller: _search,
          enabled: !_busy,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: l.s3002_search,
            prefixIcon: const AppIcon(AppIcons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.s3),
        for (final e in results) ...[
          _SpotRow(
            entry: e,
            selected: _spotId == e.spotId,
            onTap: () => setState(() {
              _spotId = e.spotId;
              _proposal = null;
              _error = null;
            }),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        if (proposal != null) ...[
          AppOptionTile(
            key: const Key('claim-proposal'),
            label: l.s3002_proposal(proposal.name),
            description: proposal.address,
            selected: _spotId == null,
            onTap: () => setState(() => _spotId = null),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('claim-propose'),
            onPressed: _busy ? null : _propose,
            child: Text(l.s3002_propose),
          ),
        ),
        OrgSection(l.s3002_proof),
        for (final (i, f) in _proofs.indexed) ...[
          GlassCard(
            highlight: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                key: Key('claim-file-$i'),
                children: [
                  AppIcon(AppIcons.description, color: context.mutedForeground),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          f.sizeBytes == null
                              ? l.s3002_filePrivate
                              : l.s3002_fileMeta(fileSizeLabel(f.sizeBytes!)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.s3002_removeFile,
                    icon: const AppIcon(AppIcons.close),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _proofs.removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        if (_proofs.length < claimProofsMax)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('claim-add-file'),
              onPressed: _busy ? null : _addFiles,
              child: Text(l.s3002_addFile, textAlign: TextAlign.start),
            ),
          ),
        if (_needFile)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Text(
              l.s3002_needFile,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (_error case final e?) ...[
          OrgBand(text: e, icon: AppIcons.warning, tone: OrgBandTone.error),
          const SizedBox(height: AppSpace.s2),
        ],
        const SizedBox(height: AppSpace.s2),
        OrgBand(text: l.s3002_review),
      ],
    );
  }
}

/// One spot of the search: dimmed with "đã có chủ quản lý" once its document
/// says it has a manager (the directory does not carry `managedBy`).
class _SpotRow extends ConsumerWidget {
  const _SpotRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final SpotEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final spot = ref.watch(spotProvider(entry.spotId));
    final loaded = spot.hasValue;
    final managed = spot.value?.isManaged ?? false;
    return AppOptionTile(
      key: Key('claim-spot-${entry.spotId}'),
      label: entry.name,
      description: loaded
          ? l.s3002_spotMeta(
              entry.city,
              managed ? l.s3002_managed : l.s3002_unmanaged,
            )
          : entry.city,
      enabled: loaded && !managed,
      selected: selected && !managed,
      onTap: onTap,
    );
  }
}

/// The pending or rejected claim (read-only).
class _Decided extends ConsumerWidget {
  const _Decided({required this.claim});

  final SpotClaim claim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final spotId = claim.spotId;
    final name = spotId == null
        ? claim.proposal?.name ?? ''
        : ref.watch(spotProvider(spotId)).value?.name ?? '';
    final rejected = claim.status == SpotClaimStatus.rejected;
    final reason = claim.reason;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        OrgBand(
          key: Key(rejected ? 'claim-rejected' : 'claim-pending'),
          text: rejected
              ? (reason == null
                    ? l.s3002_rejectedPlain
                    : l.s3002_rejected(reason))
              : l.s3002_pending,
          icon: rejected ? AppIcons.warning : AppIcons.hourglass,
          tone: rejected ? OrgBandTone.error : OrgBandTone.warning,
        ),
        const SizedBox(height: AppSpace.s4),
        if (name.isNotEmpty)
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (claim.proposal case final p? when spotId == null)
          Text(
            p.address,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.mutedForeground,
            ),
          ),
        const SizedBox(height: AppSpace.s4),
        OrgBand(text: l.s3002_review),
      ],
    );
  }
}

/// "Gửi đề xuất điểm mới": name and address of a place that is not a spot.
class _ProposeSheet extends StatefulWidget {
  const _ProposeSheet({this.initial});

  final SpotProposal? initial;

  @override
  State<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends State<_ProposeSheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _address = TextEditingController(text: widget.initial?.address);
  bool _missing = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _send() {
    final name = _name.text.trim();
    final address = _address.text.trim();
    if (name.isEmpty || address.isEmpty) {
      setState(() => _missing = true);
      return;
    }
    Navigator.of(context).pop(SpotProposal(name: name, address: address));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s2,
        AppSpace.s5,
        AppSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgSheetHeader(l.s3002_proposeTitle),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('propose-name'),
            controller: _name,
            maxLength: 80,
            decoration: InputDecoration(labelText: l.s3002_proposeName),
          ),
          const SizedBox(height: AppSpace.s2),
          TextField(
            key: const Key('propose-address'),
            controller: _address,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: l.s3002_proposeAddress,
              errorText: _missing ? l.s3002_proposeRequired : null,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.outline(
            l.s3002_proposeSend,
            key: const Key('propose-send'),
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
