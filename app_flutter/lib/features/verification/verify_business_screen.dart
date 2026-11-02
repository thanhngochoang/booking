// lib/features/verification/verify_business_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// A tax code the lookup accepts (Decision 16): 10 digits (company), 10
/// digits + `-` + 3 digits (branch) or 12 digits (household: the owner's
/// personal id).
final _taxCodePattern = RegExp(r'^(\d{10}(-\d{3})?|\d{12})$');

bool isValidTaxCode(String code) => _taxCodePattern.hasMatch(code);

/// Where the registration photo goes (`businessDocs/{uid}/{ulid}.jpg`; the
/// rules let the owner create each file once).
String businessDocPath(String uid, String fileId) =>
    'businessDocs/$uid/$fileId.jpg';

/// S21.04 "Xác minh doanh nghiệp" (mock `#S21.04`): only for a studio whose
/// owner is verified. The owner types the tax code, the app looks up name,
/// address and status; a company adds a photo of its registration (staff
/// decide), a household matches the owner's id by itself. Pending, approved
/// and rejected come from the `verifications/{uid}.business` listener.
class VerifyBusinessScreen extends ConsumerWidget {
  const VerifyBusinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final intro = ref.watch(myIntroProvider);
    // Task 1b (Decision 3): an active organizer verifies the business it
    // sells tickets as, without a studio or an identity.
    final organizer = ref.watch(myOrganizerProvider).value?.isActive ?? false;
    return ScreenCode(
      ScreenCodes.verifyBusiness,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.verifyBizTitle)),
          body: SafeArea(
            top: false,
            bottom: false,
            child: AsyncView<PhotographerIntro?>(
              value: intro,
              loadingLabel: l.loadingLabel,
              onRetry: () => ref.invalidate(myIntroProvider),
              data: (context, intro) =>
                  intro != null &&
                      intro.verified &&
                      intro.providerType == ProviderType.studio
                  ? const _BusinessBody()
                  : organizer
                  ? const _BusinessBody(organizer: true)
                  : _Scroll(
                      children: [
                        VerifyMeta(l.verifyBizIntro),
                        const SizedBox(height: AppSpace.s3),
                        VerifyAlert(
                          l.verifyBizNeedsIdentity,
                          key: const Key('verify-biz-needs-identity'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessBody extends ConsumerWidget {
  const _BusinessBody({this.organizer = false});

  /// An organizer (not a verified studio) verifies its business.
  final bool organizer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myVerificationProvider);
    return AsyncView<VerificationState>(
      value: async,
      loadingLabel: l.loadingLabel,
      onRetry: () => ref.invalidate(myVerificationProvider),
      data: (context, s) {
        final b = s.business;
        return switch (b?.status) {
          BusinessStatus.submitted => _Decided(
            business: b!,
            heading: l.verifyBizPending,
            icon: AppIcons.verifiedUser,
          ),
          BusinessStatus.approved => _Decided(
            business: b!,
            heading: l.verifyBizApproved,
            icon: AppIcons.businessVerify,
          ),
          BusinessStatus.rejected ||
          null => _BusinessForm(rejected: b, organizer: organizer),
        };
      },
    );
  }
}

/// Scrolling content with an optional sticky footer action.
class _Scroll extends StatelessWidget {
  const _Scroll({required this.children, this.action});

  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final act = action;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        if (act != null) AppFooterBar(child: act),
      ],
    );
  }
}

/// Sent (waiting for staff) or approved: the record as the registry has it.
class _Decided extends StatelessWidget {
  const _Decided({
    required this.business,
    required this.heading,
    required this.icon,
  });

  final BusinessVerification business;
  final String heading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Scroll(
      children: [
        const SizedBox(height: AppSpace.s2),
        VerifyIllustration(icon),
        const SizedBox(height: AppSpace.s3),
        Semantics(liveRegion: true, child: VerifyHeading(title: heading)),
        const SizedBox(height: AppSpace.s4),
        _KeyValueBox(
          rows: [
            _KeyValueRow(label: l.verifyBizTaxCode, value: business.taxCode),
            _KeyValueRow(label: l.verifyBizName, value: business.name),
            _KeyValueRow(
              label: l.verifyBizAddress,
              value: business.address,
              strong: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _BusinessForm extends ConsumerStatefulWidget {
  const _BusinessForm({this.rejected, this.organizer = false});

  final bool organizer;

  /// The last record when staff (or the household match) rejected it.
  final BusinessVerification? rejected;

  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  final _code = TextEditingController();

  /// The code [_info] belongs to.
  String? _lookedUp;
  TaxCodeInfo? _info;
  String? _error;
  bool _looking = false;
  bool _sending = false;

  PickedImage? _photo;
  String? _docPath;

  /// Upload progress while the photo uploads; null otherwise.
  double? _progress;
  StreamSubscription<UploadEvent>? _upload;

  @override
  void dispose() {
    _upload?.cancel();
    _code.dispose();
    super.dispose();
  }

  bool get _household => _info?.kind == 'household';

  bool get _needsDoc => _info != null && _info!.active && !_household;

  bool get _canSend =>
      _info != null &&
      _info!.active &&
      (_household || _docPath != null) &&
      !_sending &&
      _progress == null;

  void _onChanged(String text) {
    final otherCode = _lookedUp != null && text.trim() != _lookedUp;
    if (_error != null || otherCode) {
      setState(() {
        _error = null;
        if (otherCode) {
          // The result and the registration photo belong to the old code.
          _info = null;
          _lookedUp = null;
          _clearDoc();
        }
      });
    }
  }

  /// Forgets the registration photo and stops its upload (call in setState).
  void _clearDoc() {
    _upload?.cancel();
    _upload = null;
    _photo = null;
    _docPath = null;
    _progress = null;
  }

  String _lookupError(AppLocalizations l, String code) => switch (code) {
    'not_found' => l.verifyBizNotFound,
    'invalid_argument' => l.verifyBizInvalid,
    'not_eligible' => l.verifyBizNeedsIdentity,
    _ => l.engagementError,
  };

  Future<void> _lookup() async {
    final l = context.l10n;
    final code = _code.text.trim();
    if (!isValidTaxCode(code)) {
      setState(() {
        _error = l.verifyBizInvalid;
        _info = null;
        _lookedUp = null;
      });
      return;
    }
    if (_looking) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _looking = true;
      _error = null;
    });
    try {
      final info = await ref
          .read(verificationRepositoryProvider)
          .lookupTaxCode(code);
      if (mounted) {
        setState(() {
          _info = info;
          _lookedUp = code;
        });
      }
    } on VerificationError catch (e) {
      if (mounted) {
        setState(() {
          _info = null;
          _lookedUp = null;
          _error = _lookupError(l, e.code);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _looking = false);
      }
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.engagementError)));
  }

  Future<void> _pickDoc() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _progress != null) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (!mounted || picked.isEmpty) {
      return;
    }
    final image = picked.first;
    // A fresh file id every time: storage refuses overwrites.
    final path = businessDocPath(uid, newUlid());
    setState(() {
      _photo = image;
      _docPath = null;
      _progress = 0;
    });
    await _upload?.cancel();
    _upload = ref
        .read(mediaUploaderProvider)
        .upload(image, storagePath: path, purpose: ImagePurpose.document)
        .listen(
          (event) {
            if (!mounted) {
              return;
            }
            final media = event.media;
            setState(() {
              if (media != null) {
                _docPath = media.storagePath;
                _progress = null;
              } else {
                _progress = event.fraction;
              }
            });
          },
          onError: (Object _) {
            if (mounted) {
              setState(() {
                _photo = null;
                _progress = null;
              });
              _showError();
            }
          },
          onDone: () {
            if (mounted && _progress != null) {
              setState(() => _progress = null);
            }
          },
        );
  }

  Future<void> _send() async {
    final code = _lookedUp;
    if (code == null || !_canSend) {
      return;
    }
    setState(() => _sending = true);
    try {
      // The listener on `verifications/{uid}` shows the outcome.
      await ref
          .read(verificationRepositoryProvider)
          .submitBusiness(taxCode: code, docPath: _household ? null : _docPath);
    } on VerificationError catch (e) {
      if (mounted) {
        if (e.code == 'invalid_argument') {
          setState(() => _error = context.l10n.verifyBizInvalid);
        } else {
          _showError();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String? _rejectText(AppLocalizations l, BusinessVerification b) =>
      switch (b.rejectCode) {
        'inactive' => l.verifyBizReject_inactive,
        'representative_mismatch' => l.verifyBizReject_representative_mismatch,
        'doc_unreadable' => l.verifyBizReject_doc_unreadable,
        _ => b.rejectText,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final rejected = widget.rejected;
    final reason = rejected == null ? null : _rejectText(l, rejected);
    final info = _info;
    return _Scroll(
      action: AppButton.primary(
        l.verifyBizSubmit,
        key: const Key('verify-biz-submit'),
        loading: _sending,
        onPressed: _canSend ? _send : null,
      ),
      children: [
        if (rejected != null) ...[
          VerifyAlert(
            reason == null
                ? l.settingsVerifyRejected
                : l.verifyBizRejected(reason),
            key: const Key('verify-biz-rejected'),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        VerifyMeta(
          widget.organizer ? l.s2104_organizerIntro : l.verifyBizIntro,
        ),
        const SizedBox(height: AppSpace.s3),
        TextField(
          key: const Key('verify-biz-tax-code'),
          controller: _code,
          enabled: !_sending,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          textInputAction: TextInputAction.search,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
            LengthLimitingTextInputFormatter(14),
          ],
          onChanged: _onChanged,
          onSubmitted: (_) => _lookup(),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            labelText: l.verifyBizTaxCode,
            errorText: _error,
            errorMaxLines: 3,
            suffixIcon: IconButton(
              key: const Key('verify-biz-lookup'),
              tooltip: l.verifyBizLookup,
              onPressed: _looking || _sending ? null : _lookup,
              icon: _looking
                  ? const DotRingLoader(size: LoaderSize.inline)
                  : const AppIcon(AppIcons.search),
            ),
          ),
        ),
        if (info != null) ...[
          const SizedBox(height: AppSpace.s3),
          _KeyValueBox(
            key: const Key('verify-biz-result'),
            rows: [
              _KeyValueRow(label: l.verifyBizName, value: info.name),
              _KeyValueRow(
                label: l.verifyBizAddress,
                value: info.address,
                strong: false,
              ),
              _KeyValueRow(
                label: l.verifyBizStatus,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: VerifyStatusPill(
                    info.active ? l.verifyBizActive : l.verifyBizInactive,
                    ok: info.active,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_needsDoc) ...[
          const SizedBox(height: AppSpace.s3),
          Row(
            children: [
              _DocTile(
                photo: _photo,
                progress: _progress,
                done: _docPath != null,
                label: l.verifyBizDocTitle,
                onTap: _sending ? null : _pickDoc,
              ),
              const SizedBox(width: AppSpace.s2h),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.verifyBizDocTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    VerifyMeta(l.verifyBizDocBody),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s3),
        VerifyNote(icon: AppIcons.info, text: l.verifyBizHouseholdNote),
      ],
    );
  }
}

/// Mock `.ph.add`: the registration photo tile; the picked photo with its
/// upload progress, then a check once stored.
class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.photo,
    required this.progress,
    required this.done,
    required this.label,
    required this.onTap,
  });

  final PickedImage? photo;
  final double? progress;
  final bool done;
  final String label;
  final VoidCallback? onTap;

  /// Mock tile 56×56.
  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final local = photo;
    final value = progress;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: _size,
        child: Material(
          color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: dark ? AppColorsDark.borderStrong : AppColors.borderStrong,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('verify-biz-doc'),
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (local != null)
                  Image.file(
                    File(local.path),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                else
                  Center(
                    child: AppIcon(AppIcons.add, color: verifyMuted(theme)),
                  ),
                if (value != null) ...[
                  const ColoredBox(color: AppColors.overlay),
                  Center(
                    child: UploadProgressRing(
                      fraction: value,
                      size: AppSpace.s6,
                    ),
                  ),
                ],
                if (done)
                  Align(
                    alignment: AlignmentDirectional.bottomEnd,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark
                              ? AppColorsDark.success
                              : AppColors.success,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpace.s1 / 2),
                          child: AppIcon(
                            AppIcons.check,
                            size: AppText.sm,
                            color: AppColors.foregroundInverse,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered box of label/value rows (mock `.kv`).
class _KeyValueBox extends StatelessWidget {
  const _KeyValueBox({super.key, required this.rows});

  final List<_KeyValueRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final line = dark ? AppColorsDark.border : AppColors.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: line),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    this.value,
    this.child,
    this.strong = true,
  });

  final String label;
  final String? value;
  final Widget? child;

  /// The value in semibold (the address is regular, as in the mock).
  final bool strong;

  /// Mock `.kv small` column.
  static const _labelWidth = 78.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = value;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpace.s12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Row(
            children: [
              SizedBox(
                width: _labelWidth,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: verifyMuted(theme),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child:
                    child ??
                    Text(
                      text ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
