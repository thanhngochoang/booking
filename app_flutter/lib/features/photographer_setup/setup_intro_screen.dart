import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/features/photographer_setup/intro_logic.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_controller.dart';

/// S24, setup step 1/4: name, short bio, equipment (years and genres are
/// step 3, S38). Everything typed is kept as a device draft until
/// "Tiếp tục" saves it. Layout follows the other step screens (S34, S38) and
/// mock S24 step 2: AppBar "n / 4", progress, h3 + hint, fields, sticky footer.
class SetupIntroScreen extends ConsumerStatefulWidget {
  const SetupIntroScreen({super.key});

  @override
  ConsumerState<SetupIntroScreen> createState() => _SetupIntroScreenState();
}

class _SetupIntroScreenState extends ConsumerState<SetupIntroScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _equipmentField = TextEditingController();
  List<String> _equipment = const [];
  Map<IntroField, IntroError> _errors = const {};

  /// The person typed something: a late load must not overwrite it.
  bool _touched = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final uid = _uid;
    final draft = uid == null
        ? null
        : ref.read(setupDraftStoreProvider).intro(uid);
    if (draft != null) {
      _apply(draft);
      _touched = true;
    } else {
      _prefill();
    }
  }

  Future<void> _prefill() async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    var name = '';
    PhotographerIntro? intro;
    try {
      // Read once from the repository: a provider nobody listens to is
      // paused, so awaiting `currentProfileProvider.future` could hang.
      name =
          (await ref.read(userRepositoryProvider).watch(uid).first)
              ?.displayName ??
          '';
      intro = await ref.read(photographerIntroRepositoryProvider).get(uid);
    } catch (_) {
      // Offline or no document yet: start from what is known.
    }
    if (!mounted || _touched) {
      return;
    }
    setState(
      () => _apply(
        IntroDraft(
          displayName: name,
          bio: intro?.bio ?? '',
          equipment: intro?.equipment ?? const [],
        ),
      ),
    );
  }

  void _apply(IntroDraft d) {
    _name.text = d.displayName;
    _bio.text = d.bio;
    _equipment = [...d.equipment];
  }

  void _changed() {
    _touched = true;
    final uid = _uid;
    if (uid == null) {
      return;
    }
    ref
        .read(setupDraftStoreProvider)
        .saveIntro(
          uid,
          IntroDraft(
            displayName: _name.text,
            bio: _bio.text,
            equipment: _equipment,
          ),
        );
  }

  void _addEquipment() {
    final next = cleanEquipment([..._equipment, _equipmentField.text]);
    _equipmentField.clear();
    if (next.length == _equipment.length) {
      return;
    }
    setState(() => _equipment = next);
    _changed();
  }

  void _removeEquipment(String item) {
    setState(() => _equipment = [..._equipment]..remove(item));
    _changed();
  }

  void _next() {
    final r = validateIntro(
      IntroInput(
        displayName: _name.text,
        bio: _bio.text,
        equipment: _equipment,
      ),
    );
    setState(() => _errors = r.errors);
    if (r.ok) {
      ref.read(setupIntroControllerProvider.notifier).save(r);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _equipmentField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final secondaryInk = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final saving = ref.watch(setupIntroControllerProvider).isLoading;
    ref.listen(setupIntroControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) {
        return;
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.setupSaveError)));
      } else if (next.value ?? false) {
        context.push('/setup/2');
      }
    });
    String? err(IntroField f) =>
        _errors[f] == null ? null : introErrorText(_errors[f]!, l);
    final full = _equipment.length >= kEquipmentMax;

    return ScreenCode(
      ScreenCodes.setupProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Mock S24 `.bar`: back · "Hồ sơ nhiếp ảnh gia" · "1 / 4".
          appBar: AppBar(
            title: Text(l.setupFlowTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.s4),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      l.stepProgressCount(1, 4),
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
                  child: StepProgress(current: 1, total: 4, showCount: false),
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
                            l.setupIntroHeading,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          l.setupIntroHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        TextField(
                          key: const Key('setup-name'),
                          controller: _name,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: InputDecoration(
                            labelText: l.displayNameLabel,
                            errorText: err(IntroField.name),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        TextField(
                          key: const Key('setup-bio'),
                          controller: _bio,
                          enabled: !saving,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: kBioMaxLength,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: l.setupBioLabel,
                            hintText: l.setupBioHint,
                            alignLabelWithHint: true,
                            errorText: err(IntroField.bio),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        // Mock `.meta.x` label above a chip row (S25).
                        Text(
                          l.setupEquipmentLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        if (_equipment.isNotEmpty) ...[
                          Wrap(
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s2,
                            children: [
                              for (final e in _equipment)
                                // Removable chip, drawn like an unselected
                                // AppChip (glass fill, outline, pill).
                                InputChip(
                                  key: Key('equipment-$e'),
                                  label: Text(e),
                                  labelStyle: TextStyle(
                                    color: secondaryInk,
                                    fontSize: AppText.chip,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  backgroundColor: dark
                                      ? AppColorsDark.glass
                                      : AppColors.glass,
                                  side: BorderSide(color: scheme.outline),
                                  shape: const StadiumBorder(),
                                  deleteIconColor: secondaryInk,
                                  deleteButtonTooltipMessage: l
                                      .setupEquipmentRemove(e),
                                  onDeleted: saving
                                      ? null
                                      : () => _removeEquipment(e),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s3),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('setup-equipment-field'),
                                controller: _equipmentField,
                                enabled: !saving && !full,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  hintText: l.setupEquipmentHint,
                                ),
                                onSubmitted: (_) => _addEquipment(),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            IconButton.filledTonal(
                              key: const Key('setup-equipment-add'),
                              tooltip: l.setupEquipmentAdd,
                              style: IconButton.styleFrom(
                                minimumSize: const Size.square(controlHeight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              onPressed: saving || full ? null : _addEquipment,
                            ),
                          ],
                        ),
                        if (full) ...[
                          const SizedBox(height: AppSpace.s1),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l.setupEquipmentFull,
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
                // First step: one primary action, no "Quay lại" (R3).
                AppFooterBar(
                  child: SizedBox(
                    height: controlHeight,
                    child: AppButton.primary(
                      l.setupNext,
                      key: const Key('setup-next'),
                      loading: saving,
                      onPressed: _next,
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
