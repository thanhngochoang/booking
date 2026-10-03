import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/package_logic.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_controller.dart';

/// S08.01, setup step 2/4: the packages customers book. At least one active
/// package is needed to go on. The form is kept as a device draft until a
/// package is added. Layout follows mock S08.01: package cards, then the form
/// (name; price + duration; edited count + delivery days; small outline
/// "Thêm gói này"), sticky footer "Quay lại" + "Tiếp tục".
class SetupPackagesScreen extends ConsumerStatefulWidget {
  const SetupPackagesScreen({super.key});

  @override
  ConsumerState<SetupPackagesScreen> createState() =>
      _SetupPackagesScreenState();
}

class _SetupPackagesScreenState extends ConsumerState<SetupPackagesScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _edited = TextEditingController();
  final _delivery = TextEditingController();
  int? _duration;
  String? _editingId;
  Map<PackageField, PackageError> _errors = const {};
  String? _uid;

  /// "Tiếp tục" is being handled (until step 3 is popped): a second tap
  /// does nothing, so `/setup/3` is pushed once.
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final uid = _uid;
    final d = uid == null
        ? null
        : ref.read(setupDraftStoreProvider).package(uid);
    if (d != null) {
      _name.text = d.name;
      _price.text = d.price;
      _duration = d.durationMinutes;
      _edited.text = d.edited;
      _delivery.text = d.delivery;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _edited.dispose();
    _delivery.dispose();
    super.dispose();
  }

  PackageForm get _form => PackageForm(
    name: _name.text,
    priceText: _price.text,
    durationMinutes: _duration,
    editedText: _edited.text,
    deliveryText: _delivery.text,
  );

  void _changed() {
    final uid = _uid;
    if (uid == null || _editingId != null) {
      return; // edits of a saved package are not drafts
    }
    final f = _form;
    ref
        .read(setupDraftStoreProvider)
        .savePackage(
          uid,
          PackageDraft(
            name: f.name,
            price: f.priceText,
            durationMinutes: f.durationMinutes,
            edited: f.editedText,
            delivery: f.deliveryText,
          ),
        );
  }

  void _clearForm() {
    setState(() {
      _name.clear();
      _price.clear();
      _edited.clear();
      _delivery.clear();
      _duration = null;
      _editingId = null;
      _errors = const {};
    });
  }

  void _edit(ServicePackage p) {
    final f = packageFormOf(p);
    setState(() {
      _editingId = p.id;
      _name.text = f.name;
      _price.text = f.priceText;
      _duration = f.durationMinutes;
      _edited.text = f.editedText;
      _delivery.text = f.deliveryText;
      _errors = const {};
    });
  }

  Future<void> _pickDuration() async {
    final picked = await showAppSheet<int>(
      context,
      builder: (_) => _DurationSheet(selected: _duration),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _duration = picked);
    _changed();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final check = validatePackage(_form);
    setState(() => _errors = check.errors);
    final input = check.input;
    if (input == null) {
      return;
    }
    final c = ref.read(setupPackagesControllerProvider.notifier);
    final editing = _editingId;
    final ok = editing == null
        ? await c.add(input)
        : await c.save(editing, input);
    if (!mounted) {
      return;
    }
    _snack(
      ok
          ? (editing == null ? l.packageAdded : l.packageSaved)
          : l.setupSaveError,
    );
    if (ok) {
      _clearForm();
    }
  }

  Future<void> _confirmHide(ServicePackage p) async {
    final l = context.l10n;
    await showConfirmSheet(
      context,
      title: l.packageHideTitle,
      body: l.packageHideBody,
      confirmLabel: l.packageHideConfirm,
      keepLabel: l.packageKeep,
      danger: true,
      onConfirm: () async {
        final ok = await ref
            .read(setupPackagesControllerProvider.notifier)
            .hide(p.id);
        if (!mounted) {
          return;
        }
        _snack(ok ? l.packageHidden : l.setupSaveError);
        if (ok && _editingId == p.id) {
          _clearForm();
        }
      },
    );
  }

  Future<void> _next() async {
    final uid = _uid;
    if (uid == null || _going) {
      return;
    }
    setState(() => _going = true);
    final store = ref.read(setupDraftStoreProvider);
    if (store.step(uid) < 3) {
      await store.setStep(uid, 3);
    }
    if (!mounted) {
      return;
    }
    await context.push('/setup/3');
    if (mounted) {
      setState(() => _going = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/setup/1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final packages = ref.watch(myPackagesProvider);
    final active = [
      for (final p in packages.value ?? const <ServicePackage>[])
        if (p.active) p,
    ];
    final saving = ref.watch(setupPackagesControllerProvider).isLoading;
    String? err(PackageField f) =>
        _errors[f] == null ? null : packageErrorText(_errors[f]!, l);
    final editing = _editingId != null;
    final duration = _duration;

    final list = AsyncView<List<ServicePackage>>(
      value: packages,
      onRetry: () => ref.invalidate(myPackagesProvider),
      skeleton: (_) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PackageSkeleton(),
          SizedBox(height: AppSpace.s2),
          _PackageSkeleton(),
          SizedBox(height: AppSpace.s2),
          _PackageSkeleton(),
        ],
      ),
      error: (context, _, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.setupPackagesLoadError),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.text(
              l.retry,
              size: AppButtonSize.small,
              onPressed: () => ref.invalidate(myPackagesProvider),
            ),
          ),
        ],
      ),
      data: (context, _) => active.isEmpty
          ? Text(
              l.setupNoPackages,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s2),
                  _PackageCard(
                    package: active[i],
                    editing: active[i].id == _editingId,
                    onEdit: saving ? null : () => _edit(active[i]),
                    onHide: saving ? null : () => _confirmHide(active[i]),
                  ),
                ],
              ],
            ),
    );

    InputDecoration numberField(String label, PackageField f) =>
        InputDecoration(labelText: label, errorText: err(f), errorMaxLines: 2);

    return ScreenCode(
      ScreenCodes.setupProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Mock S08.01 `.bar`: back · "Hồ sơ nhiếp ảnh gia" · "2 / 4".
          appBar: AppBar(
            title: Text(l.setupFlowTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.s4),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      l.stepProgressCount(2, 4),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // The bottom inset belongs to the sticky AppFooterBar.
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpace.s5),
                  child: StepProgress(current: 2, total: 4, showCount: false),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l.setupServicesHeading,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          l.setupServiceHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        list,
                        const SizedBox(height: AppSpace.s4),
                        if (editing) ...[
                          Semantics(
                            header: true,
                            child: Text(
                              l.packageEditHeading,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s3),
                        ],
                        TextField(
                          key: const Key('package-name'),
                          controller: _name,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l.packageNameLabel,
                            hintText: l.packageNameHint,
                            errorText: err(PackageField.name),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('package-price'),
                                controller: _price,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: const [VndInputFormatter()],
                                style: const TextStyle(
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                decoration: numberField(
                                  l.packagePriceLabel,
                                  PackageField.price,
                                ),
                                onChanged: (_) => _changed(),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            Expanded(
                              child: _DurationField(
                                label: l.packageDurationLabel,
                                hint: l.packageDurationHint,
                                value: duration == null
                                    ? null
                                    : durationLabel(duration, l),
                                error: err(PackageField.duration),
                                onTap: saving ? null : _pickDuration,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('package-edited'),
                                controller: _edited,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: numberField(
                                  l.packageEditedLabel,
                                  PackageField.edited,
                                ),
                                onChanged: (_) => _changed(),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            Expanded(
                              child: TextField(
                                key: const Key('package-delivery'),
                                controller: _delivery,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: numberField(
                                  l.packageDeliveryLabel,
                                  PackageField.delivery,
                                ),
                                onChanged: (_) => _changed(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s2),
                        AppButton.outline(
                          editing ? l.packageSave : l.packageAdd,
                          key: const Key('package-submit'),
                          size: AppButtonSize.small,
                          loading: saving,
                          onPressed: _submit,
                        ),
                        if (editing)
                          AppButton.text(
                            l.packageCancelEdit,
                            key: const Key('package-cancel-edit'),
                            size: AppButtonSize.small,
                            onPressed: saving ? null : _clearForm,
                          ),
                        if (active.isEmpty && packages.hasValue) ...[
                          const SizedBox(height: AppSpace.s2),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l.setupNeedPackage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                AppFooterBar(
                  child: LayoutBuilder(
                    builder: (context, box) => Row(
                      children: [
                        SizedBox(
                          width: box.maxWidth * 0.36,
                          child: AppButton.outline(
                            l.setupContactBack,
                            key: const Key('setup-back'),
                            onPressed: saving ? null : _back,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: AppButton.primary(
                            l.setupNext,
                            key: const Key('setup-next'),
                            onPressed: active.isEmpty || saving || _going
                                ? null
                                : _next,
                          ),
                        ),
                      ],
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

/// Mock `.field` "Thời lượng": reads like the text fields, opens the
/// duration sheet.
class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.label,
    required this.hint,
    required this.value,
    required this.error,
    required this.onTap,
  });

  final String label;
  final String hint;
  final String? value;
  final String? error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl);
    return Semantics(
      button: true,
      label: label,
      value: value ?? hint,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: const Key('package-duration'),
        borderRadius: radius,
        onTap: onTap,
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            enabled: onTap != null,
            labelText: label,
            hintText: hint,
            errorText: error,
            errorMaxLines: 2,
            suffixIcon: const Icon(Icons.expand_more_rounded),
          ),
          child: Text(
            value ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// One option per allowed duration; pops the chosen minutes.
class _DurationSheet extends StatelessWidget {
  const _DurationSheet({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s1,
        AppSpace.s5,
        AppSpace.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.packageDurationLabel,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          for (final m in kPackageDurationsMinutes) ...[
            AppOptionTile(
              key: Key('duration-$m'),
              label: durationLabel(m, l),
              selected: selected == m,
              onTap: () => Navigator.of(context).pop(m),
            ),
            const SizedBox(height: AppSpace.s2),
          ],
        ],
      ),
    );
  }
}

/// Mock S08.01 `.card`: name, meta line and the short price; tap to edit.
class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.editing,
    required this.onEdit,
    required this.onHide,
  });

  final ServicePackage package;
  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final p = package;
    final fill = editing
        ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: editing ? scheme.primary : scheme.outlineVariant),
    );
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: ShapeDecoration(color: fill, shape: shape),
        child: InkWell(
          key: Key('package-${p.id}'),
          customBorder: shape,
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s3,
              AppSpace.s2h,
              AppSpace.s1,
              AppSpace.s2h,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      Text(
                        packageMeta(
                          l,
                          durationMinutes: p.durationMinutes,
                          editedCount: p.editedCount,
                          deliveryDays: p.deliveryDays,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Text(
                  formatMoney(p.priceVnd, short: true),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  key: Key('package-hide-${p.id}'),
                  tooltip: l.packageHideTooltip(p.name),
                  icon: const Icon(Icons.visibility_off_outlined),
                  onPressed: onHide,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _PackageSkeleton extends StatelessWidget {
  const _PackageSkeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.card(height: 64);
}

