// S13.01 (`#S13.01`, `#S13.01-noloc`): package, kind of shoot and a named
// meet point at the customer's position; "Xem nhiếp ảnh gia phù hợp".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/instant_request_controller.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';

/// Where S04.05 comes back to.
const _here = '/instant';

/// "Đặt lịch thường" (Decision 13): Tìm thợ ảnh.
const _bookNormally = '/action';

/// Mock `#S13.01` map height.
const _mapHeight = 170.0;

class InstantRequestScreen extends ConsumerStatefulWidget {
  const InstantRequestScreen({super.key});

  @override
  ConsumerState<InstantRequestScreen> createState() =>
      _InstantRequestScreenState();
}

class _InstantRequestScreenState extends ConsumerState<InstantRequestScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _name;
  late final TextEditingController _note;
  final _nameFocus = FocusNode();

  InstantRequestController get _controller =>
      ref.read(instantRequestControllerProvider.notifier);

  InstantDraftNotifier get _draft => ref.read(instantDraftProvider.notifier);

  @override
  void initState() {
    super.initState();
    final draft = ref.read(instantDraftProvider);
    _name = TextEditingController(text: draft.meetPointName);
    _note = TextEditingController(text: draft.note);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _note.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Back from the Settings app: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.resumed();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final result = await _controller.submit();
    if (!mounted || result == null) return;
    switch (result) {
      case InstantSubmitCreated(:final requestId):
        context.go('/instant/$requestId');
      case InstantSubmitNeedsPhone():
        context.push('/profile/phone?returnTo=${Uri.encodeComponent(_here)}');
      case InstantSubmitHasActive(:final requestId):
        _say(l.instantHasActive);
        if (requestId != null) context.go('/instant/$requestId');
      case InstantSubmitRefused():
        if (_name.text.trim().isEmpty) _nameFocus.requestFocus();
      case InstantSubmitFailed(:final error):
        _say(instantErrorText(l, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final value = ref.watch(instantRequestControllerProvider);
    final v = value.value;
    return ScreenCode(
      ScreenCodes.instantRequest,
      label: v != null && v.position == null ? 'noloc' : null,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const AppIcon(AppIcons.back),
                    onPressed: () => context.go(AppTab.home.path),
                  ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.instantTitle),
                Text(
                  l.instantSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? AppColorsDark.foregroundMuted
                        : AppColors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          body: AsyncView<InstantRequestView>(
            value: value,
            skeleton: (_) => const _Skeleton(),
            onRetry: () {
              ref.invalidate(instantConfigProvider);
              ref.invalidate(instantRequestControllerProvider);
            },
            data: (context, v) => v.position == null
                ? _NoLocation(
                    onAllow: _controller.allowLocation,
                    onBookNormally: () => context.go(_bookNormally),
                  )
                : _form(context, v, v.position!),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, InstantRequestView v, LocationFix at) {
    final l = context.l10n;
    final draft = ref.watch(instantDraftProvider);
    final name = draft.meetPointName.trim();
    final selected = draft.packageOf(v.config.packages);
    final problem = v.error;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              MapPreview(
                height: _mapHeight,
                pins: [
                  MapPin(
                    lat: at.lat,
                    lng: at.lng,
                    label: name.isEmpty
                        ? l.instantMeetPointSelf
                        : l.instantMeetPointPin(name),
                    self: true,
                  ),
                ],
                onRecenter: _controller.refreshLocation,
              ),
              const SizedBox(height: AppSpace.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, p) in v.config.packages.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: _PackageTile(
                        package: p,
                        selected: p.code == selected?.code,
                        onTap: () => _draft.setPackage(p.code),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.s3),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, g) in InstantGenre.values.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpace.s2),
                      AppChip(
                        key: Key('instant-genre-${g.code}'),
                        kind: AppChipKind.context,
                        label: instantGenreText(l, g),
                        selected: draft.genre == g,
                        onChanged: (_) => _draft.setGenre(g),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              TextField(
                key: const Key('instant-meet-point'),
                controller: _name,
                focusNode: _nameFocus,
                maxLength: kInstantMeetPointMax,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (s) {
                  _draft.setMeetPointName(s);
                  if (s.trim().isNotEmpty) _controller.clearError();
                },
                decoration: InputDecoration(
                  labelText: l.instantMeetPointLabel,
                  hintText: l.instantMeetPointHint,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  counterText: '',
                  errorText: problem == InstantRequestProblem.meetPointRequired
                      ? l.instantMeetPointRequired
                      : null,
                  errorMaxLines: 2,
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              TextField(
                key: const Key('instant-note'),
                controller: _note,
                minLines: 1,
                maxLines: 3,
                maxLength: kInstantNoteMax,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _draft.setNote,
                decoration: InputDecoration(
                  labelText: l.instantNoteLabel,
                  hintText: l.instantNoteHint,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              if (problem == InstantRequestProblem.outsideArea ||
                  problem == InstantRequestProblem.disabled) ...[
                const SizedBox(height: AppSpace.s2),
                _ProblemNote(
                  text: problem == InstantRequestProblem.outsideArea
                      ? l.instantOutsideArea
                      : l.instantDisabled,
                  onBookNormally: problem == InstantRequestProblem.outsideArea
                      ? () => context.go(_bookNormally)
                      : null,
                ),
              ],
              const SizedBox(height: AppSpace.s3),
              EscrowNotice(text: l.instantEscrowNote, maxLines: null),
            ],
          ),
        ),
        AppFooterBar(
          child: AppButton.primary(
            l.instantSeeMatches,
            key: const Key('instant-see-matches'),
            loading: v.busy,
            onPressed: v.busy ? null : _submit,
          ),
        ),
      ],
    );
  }
}

/// Mock `.pkg div` (`.on` when chosen): duration, photos, short price.
class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final InstantPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = selected
        ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      side: BorderSide(color: selected ? scheme.primary : scheme.outline),
    );
    final small = theme.textTheme.bodySmall;
    return Semantics(
      key: Key('instant-package-${package.code}'),
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label:
          '${instantPackageText(l, package.durationMin, package.photos)}, '
          '${formatMoney(package.priceVnd)}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: ShapeDecoration(color: fill, shape: shape),
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpace.s12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s1,
                  vertical: AppSpace.s2,
                ),
                child: Column(
                  children: [
                    Text(
                      instantDurationText(l, package.durationMin),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l.instantPhotosCount(package.photos),
                      textAlign: TextAlign.center,
                      style: small,
                    ),
                    Text(
                      instantShortMoney(package.priceVnd),
                      textAlign: TextAlign.center,
                      style: small?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: selected ? scheme.primary : null,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `outside_service_area` / `not_eligible`, in place above the escrow note.
class _ProblemNote extends StatelessWidget {
  const _ProblemNote({required this.text, this.onBookNormally});

  final String text;
  final VoidCallback? onBookNormally;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final onBook = onBookNormally;
    return DecoratedBox(
      key: const Key('instant-problem'),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s3,
          AppSpace.s2h,
          AppSpace.s3,
          AppSpace.s2h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(text, style: theme.textTheme.bodySmall),
            ),
            if (onBook != null)
              AppButton.text(
                context.l10n.instantBookNormally,
                key: const Key('instant-book-normally'),
                size: AppButtonSize.small,
                tapAlignment: Alignment.centerLeft,
                onPressed: onBook,
              ),
          ],
        ),
      ),
    );
  }
}

/// `#S13.01-noloc`: replaces the whole form; one primary.
class _NoLocation extends StatelessWidget {
  const _NoLocation({required this.onAllow, required this.onBookNormally});

  final VoidCallback onAllow;
  final VoidCallback onBookNormally;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.placeOff,
                  size: 40,
                  color: dark
                      ? AppColorsDark.foregroundSecondary
                      : AppColors.foregroundSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              l.instantLocationTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              l.instantLocationBody,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.instantLocationAllow,
              key: const Key('instant-allow-location'),
              size: AppButtonSize.small,
              onPressed: onAllow,
            ),
            AppButton.text(
              l.instantBookNormally,
              key: const Key('instant-book-normally'),
              size: AppButtonSize.small,
              onPressed: onBookNormally,
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.group(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        AppSkeleton.box(height: _mapHeight, radius: AppRadius.xl),
        const SizedBox(height: AppSpace.s3),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.s2),
              Expanded(
                child: AppSkeleton.box(height: 64, radius: AppRadius.control),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.line(widthFactor: 0.8, height: 34),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.box(height: 56, radius: AppRadius.control),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.box(height: 56, radius: AppRadius.control),
      ],
    ),
  );
}
