import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/addons/addon_edit_controller.dart';
import 'package:photobooking/features/addons/addon_format.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S08.07: the add/edit sheet over S08.06. Pass [addon] to edit it (adds the
/// red "Xoá dịch vụ"). A save or delete closes the sheet and says so in a
/// SnackBar of the screen below.
Future<void> showAddonEditSheet(
  BuildContext context, {
  ServiceAddon? addon,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showAppSheet<String>(
    context,
    builder: (_) =>
        ScreenCode(ScreenCodes.editAddon, child: AddonEditSheet(addon: addon)),
  );
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _Field { name, description, price, maxQty, packages }

class AddonEditSheet extends ConsumerStatefulWidget {
  const AddonEditSheet({super.key, this.addon});

  final ServiceAddon? addon;

  @override
  ConsumerState<AddonEditSheet> createState() => _AddonEditSheetState();
}

class _AddonEditSheetState extends ConsumerState<AddonEditSheet> {
  late final _name = TextEditingController(text: widget.addon?.name);
  late final _description = TextEditingController(
    text: widget.addon?.description,
  );
  late final _price = TextEditingController(
    text: widget.addon == null ? '' : groupVnd(widget.addon!.price),
  );
  late AddonKind _kind = widget.addon?.kind ?? AddonKind.makeup;
  late AddonUnit _unit = widget.addon?.unit ?? AddonUnit.perBooking;
  late final _max = TextEditingController(text: '${widget.addon?.maxQty ?? 1}');
  late bool _choosePackages = widget.addon?.serviceIds.isNotEmpty ?? false;
  late List<String> _serviceIds = [...?widget.addon?.serviceIds];
  final Map<_Field, String> _errors = {};

  /// A problem that is not one field's: the limit, a failed delete, a
  /// network error.
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _max.dispose();
    super.dispose();
  }

  bool get _editing => widget.addon != null;

  AddonInput get _input => AddonInput(
    kind: _kind,
    name: _name.text,
    description: _description.text,
    price: parseVnd(_price.text) ?? 0,
    unit: _unit,
    maxQty: _unit == AddonUnit.perBooking ? 1 : (int.tryParse(_max.text) ?? 0),
    choosePackages: _choosePackages,
    serviceIds: _serviceIds,
    active: widget.addon?.active ?? true,
  );

  void _clear(_Field f) {
    if (_errors.containsKey(f) || _formError != null) {
      setState(() {
        _errors.remove(f);
        _formError = null;
      });
    }
  }

  _Field _fieldOf(AddonInputError e) => switch (e) {
    AddonInputError.nameLength || AddonInputError.nameContact => _Field.name,
    AddonInputError.descriptionLength ||
    AddonInputError.descriptionContact => _Field.description,
    AddonInputError.priceRange => _Field.price,
    AddonInputError.maxQtyRange => _Field.maxQty,
    AddonInputError.packagesEmpty => _Field.packages,
  };

  String _messageOf(AppLocalizations l, AddonInputError e) => switch (e) {
    AddonInputError.nameLength => l.addonErrName,
    AddonInputError.descriptionLength => l.addonErrDescription,
    AddonInputError.priceRange => l.addonErrPrice,
    AddonInputError.maxQtyRange => l.addonErrMaxQty,
    AddonInputError.nameContact ||
    AddonInputError.descriptionContact => l.addonErrContact,
    AddonInputError.packagesEmpty => l.addonErrPackages,
  };

  Future<void> _save() async {
    final l = context.l10n;
    final input = _input;
    final problem = validateAddonInput(input);
    if (problem != null) {
      setState(() {
        _errors
          ..clear()
          ..[_fieldOf(problem)] = _messageOf(l, problem);
        _formError = null;
      });
      return;
    }
    setState(() {
      _errors.clear();
      _formError = null;
    });
    final error = await ref
        .read(addonEditControllerProvider.notifier)
        .save(input, addonId: widget.addon?.id);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(l.addonSaved);
      return;
    }
    _showServerError(l, error);
  }

  void _showServerError(AppLocalizations l, AddonError error) {
    setState(() {
      _errors.clear();
      _formError = null;
      switch (error.code) {
        case AddonErrorCode.contactLeak:
          final f = error.field == 'description'
              ? _Field.description
              : _Field.name;
          _errors[f] = l.addonErrContact;
        case AddonErrorCode.addonLimit:
          _formError = l.addonsLimitReached;
        case AddonErrorCode.invalidArgument:
          final f = switch (error.field) {
            'name' => _Field.name,
            'description' => _Field.description,
            'price' => _Field.price,
            'maxQty' => _Field.maxQty,
            'serviceIds' => _Field.packages,
            _ => null,
          };
          if (f == null) {
            _formError = l.addonsSaveFailed;
          } else {
            _errors[f] = switch (f) {
              _Field.name => l.addonErrName,
              _Field.description => l.addonErrDescription,
              _Field.price => l.addonErrPrice,
              _Field.maxQty => l.addonErrMaxQty,
              _Field.packages => l.addonErrPackages,
            };
          }
        default:
          _formError = l.addonsSaveFailed;
      }
    });
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final id = widget.addon!.id;
    final confirmed = await showConfirmSheet(
      context,
      title: l.addonDeleteTitle,
      body: l.addonDeleteBody,
      confirmLabel: l.addonDeleteConfirm,
      keepLabel: l.addonDeleteKeep,
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(addonEditControllerProvider.notifier)
        .delete(id);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(l.addonDeleted);
    } else {
      setState(() => _formError = l.addonsSaveFailed);
    }
  }

  Future<void> _pickPackages() async {
    final packages = ref.read(myPackagesProvider).value ?? const [];
    final picked = await showAppSheet<List<String>>(
      context,
      builder: (_) => _PackagePicker(packages: packages, selected: _serviceIds),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _serviceIds = picked;
      _errors.remove(_Field.packages);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final saving = ref.watch(addonEditControllerProvider).isLoading;
    final noun = addonUnitNoun(l, _kind, _unit);
    final packages = ref.watch(myPackagesProvider).value ?? const [];
    final chosenNames = [
      for (final p in packages)
        if (_serviceIds.contains(p.id)) p.name,
    ];

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s1),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
    );

    final maxField = _unit == AddonUnit.perBooking
        ? null
        : TextField(
            key: const Key('addon-max'),
            controller: _max,
            enabled: !saving,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: l.addonFieldMax,
              suffixText: noun,
              errorText: _errors[_Field.maxQty],
              errorMaxLines: 2,
            ),
            onChanged: (_) => _clear(_Field.maxQty),
          );

    final priceField = TextField(
      key: const Key('addon-price'),
      controller: _price,
      enabled: !saving,
      keyboardType: TextInputType.number,
      inputFormatters: const [VndInputFormatter()],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: _unit == AddonUnit.perBooking
            ? l.addonFieldPriceOnce
            : l.addonFieldPricePer(noun),
        errorText: _errors[_Field.price],
        errorMaxLines: 2,
      ),
      onChanged: (_) => _clear(_Field.price),
    );

    return PopScope(
      canPop: !saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _editing ? l.addonEditEditTitle : l.addonEditAddTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('addon-close'),
                  tooltip: l.addonEditClose,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            label(l.addonFieldKind),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final k in AddonKind.values) ...[
                    AppChip(
                      key: Key('addon-kind-${k.name}'),
                      label: addonKindLabel(l, k),
                      kind: AppChipKind.context,
                      selected: _kind == k,
                      onChanged: (_) {
                        if (!saving) setState(() => _kind = k);
                      },
                    ),
                    const SizedBox(width: AppSpace.s2),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('addon-name'),
              controller: _name,
              enabled: !saving,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.addonFieldName,
                errorText: _errors[_Field.name],
                errorMaxLines: 2,
              ),
              onChanged: (_) => _clear(_Field.name),
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('addon-description'),
              controller: _description,
              enabled: !saving,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l.addonFieldDescription,
                errorText: _errors[_Field.description],
                errorMaxLines: 2,
              ),
              onChanged: (_) => _clear(_Field.description),
            ),
            const SizedBox(height: AppSpace.s3),
            label(l.addonFieldUnit),
            SegmentedTabs<AddonUnit>(
              options: [
                for (final u in AddonUnit.values)
                  SegmentOption(value: u, label: addonUnitLabel(l, u)),
              ],
              value: _unit,
              onChanged: (u) {
                if (!saving) setState(() => _unit = u);
              },
            ),
            const SizedBox(height: AppSpace.s3),
            if (maxField == null)
              priceField
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: priceField),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(child: maxField),
                ],
              ),
            const SizedBox(height: AppSpace.s3),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.s2,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s2),
                  child: Text(
                    l.addonFieldApplies,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
                AppChip(
                  key: const Key('addon-applies-all'),
                  label: l.addonAppliesAllChip,
                  kind: AppChipKind.context,
                  selected: !_choosePackages,
                  onChanged: (_) {
                    if (!saving) {
                      setState(() {
                        _choosePackages = false;
                        _errors.remove(_Field.packages);
                      });
                    }
                  },
                ),
                AppChip(
                  key: const Key('addon-applies-pick'),
                  label: l.addonAppliesPickChip,
                  kind: AppChipKind.context,
                  selected: _choosePackages,
                  onChanged: (_) {
                    if (saving) return;
                    setState(() => _choosePackages = true);
                    _pickPackages();
                  },
                ),
              ],
            ),
            if (_choosePackages && chosenNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(
                  chosenNames.join(', '),
                  key: const Key('addon-chosen-packages'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            if (_errors[_Field.packages] case final text?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(
                  text,
                  key: const Key('addon-packages-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.info, color: muted, size: 18),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    l.addonResponsibility,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            if (_formError case final text?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s3),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    key: const Key('addon-form-error'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.addonSave,
              key: const Key('addon-save'),
              loading: saving,
              onPressed: saving ? null : _save,
            ),
            if (_editing)
              AppButton.text(
                l.addonDelete,
                key: const Key('addon-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: saving ? null : _delete,
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Chọn gói" checklist: ticks any of the provider's packages (hidden
/// ones only while already ticked), "Xong" returns the ids.
class _PackagePicker extends StatefulWidget {
  const _PackagePicker({required this.packages, required this.selected});

  final List<ServicePackage> packages;
  final List<String> selected;

  @override
  State<_PackagePicker> createState() => _PackagePickerState();
}

class _PackagePickerState extends State<_PackagePicker> {
  late final Set<String> _ticked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final shown = [
      for (final p in widget.packages)
        if (p.active || _ticked.contains(p.id)) p,
    ];
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
              l.addonPickPackagesTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final p in shown)
                  CheckboxListTile(
                    key: Key('addon-package-${p.id}'),
                    value: _ticked.contains(p.id),
                    title: Text(p.name),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(
                      () =>
                          v == true ? _ticked.add(p.id) : _ticked.remove(p.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          AppButton.outline(
            l.addonPickPackagesDone,
            key: const Key('addon-packages-done'),
            onPressed: () => Navigator.of(context).pop(_ticked.toList()),
          ),
        ],
      ),
    );
  }
}
