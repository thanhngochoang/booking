import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_controller.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_logic.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S34: setup step 4/4. Service area, main number, and which outside
/// channels customers may use after they have booked.
class ContactSetupScreen extends ConsumerWidget {
  const ContactSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final prefill = ref.watch(contactSetupPrefillProvider);
    return ScreenCode(
      ScreenCodes.setupContact,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.setupContactTitle)),
          body: SafeArea(
            top: false,
            child: prefill.when(
              data: (draft) => _ContactSetupForm(draft: draft),
              loading: () =>
                  Center(child: ApertureLoader(semanticsLabel: l.loadingLabel)),
              // A failed prefill must not block a first-time setup.
              error: (_, _) =>
                  const _ContactSetupForm(draft: ContactSetupDraft()),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactSetupForm extends ConsumerStatefulWidget {
  const _ContactSetupForm({required this.draft});
  final ContactSetupDraft draft;

  @override
  ConsumerState<_ContactSetupForm> createState() => _ContactSetupFormState();
}

class _ContactSetupFormState extends ConsumerState<_ContactSetupForm> {
  late final _city = TextEditingController(text: widget.draft.area?.city ?? '');
  late final _phone = TextEditingController(
    text: widget.draft.numbers == null
        ? ''
        : nationalFromE164(widget.draft.numbers!.phone),
  );
  late final _zaloOwn = TextEditingController(
    text: widget.draft.numbers?.zaloPhone == null
        ? ''
        : nationalFromE164(widget.draft.numbers!.zaloPhone!),
  );
  late final _whatsappOwn = TextEditingController(
    text: widget.draft.numbers?.whatsappPhone ?? '',
  );
  late int _radius = radiusOptionsKm.contains(widget.draft.area?.radiusKm)
      ? widget.draft.area!.radiusKm
      : defaultRadiusKm;
  late bool _call = widget.draft.channels?.call ?? false;
  late bool _zalo = widget.draft.channels?.zalo ?? false;
  late bool _whatsapp = widget.draft.channels?.whatsapp ?? false;
  // A saved profile with a number but no outside channel means "only in-app".
  late bool _inAppOnly =
      widget.draft.numbers != null &&
      !(widget.draft.channels?.hasExternal ?? false);
  bool _submitted = false;

  @override
  void dispose() {
    _city.dispose();
    _phone.dispose();
    _zaloOwn.dispose();
    _whatsappOwn.dispose();
    super.dispose();
  }

  ContactSetupInput get _input => ContactSetupInput(
    city: _city.text,
    radiusKm: _radius,
    phone: _phone.text,
    call: _call,
    zalo: _zalo,
    zaloOwn: _zaloOwn.text,
    whatsapp: _whatsapp,
    whatsappOwn: _whatsappOwn.text,
    inAppOnly: _inAppOnly,
    acceptInquiries: widget.draft.channels?.acceptInquiries ?? true,
  );

  String? _errorText(AppLocalizations l, ContactSetupError? e) => switch (e) {
    null => null,
    ContactSetupError.cityRequired => l.setupCityRequired,
    ContactSetupError.phoneRequired => l.phoneRequired,
    ContactSetupError.phoneInvalid => l.phoneInvalid,
    ContactSetupError.zaloInvalid => l.phoneInvalid,
    ContactSetupError.whatsappInvalid => l.phoneInvalidInternational,
    ContactSetupError.whatsappNeedsNumber => l.setupWhatsAppNeedsNumber,
    ContactSetupError.noChannel => l.setupNoChannel,
  };

  void _finish() {
    final r = validateContactSetup(_input);
    final area = r.area;
    final channels = r.channels;
    final numbers = r.numbers;
    if (!r.ok || area == null || channels == null || numbers == null) {
      setState(() => _submitted = true);
      return;
    }
    ref
        .read(setupContactControllerProvider.notifier)
        .save(area: area, channels: channels, numbers: numbers);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.profile.path);
    }
  }

  Widget _channel({
    required Key key,
    required Widget icon,
    required String title,
    required String hint,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          SwitchListTile(
            key: key,
            secondary: icon,
            title: Text(title),
            subtitle: Text(hint),
            value: value,
            onChanged: onChanged,
          ),
          if (value && extra != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s4,
              ),
              child: extra,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saving = ref.watch(setupContactControllerProvider).isLoading;
    ref.listen(setupContactControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.setupSaveError)));
      } else if (next.value ?? false) {
        context.go(AppTab.bookings.path);
      }
    });

    final errors = _submitted
        ? validateContactSetup(_input).errors
        : const <ContactSetupField, ContactSetupError>{};
    String? err(ContactSetupField f) => _errorText(l, errors[f]);
    final channelsError = err(ContactSetupField.channels);
    void changed() => setState(() {});
    Widget glyph(ContactChannel c) =>
        ChannelGlyph(c, size: 24, color: theme.colorScheme.onSurface);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s5),
      child: GlassCard(
        highlight: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(current: 4, total: 4),
              const SizedBox(height: AppSpace.s5),
              Text(l.setupContactArea, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.s2),
              TextFormField(
                key: const Key('setup-city'),
                controller: _city,
                enabled: !saving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.addressCity],
                onChanged: (_) => changed(),
                decoration: InputDecoration(
                  labelText: l.setupContactCity,
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  errorText: err(ContactSetupField.city),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              Text(l.setupContactRadius, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpace.s2),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final km in radiusOptionsKm)
                    ChoiceChip(
                      key: Key('radius-$km'),
                      label: Text(l.setupRadiusValue(km)),
                      selected: _radius == km,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => _radius = km),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s5),
              PhoneField(
                key: const Key('setup-phone'),
                controller: _phone,
                label: l.setupContactPhone,
                enabled: !saving,
                errorText: err(ContactSetupField.phone),
                onChanged: (_) => changed(),
              ),
              const SizedBox(height: AppSpace.s5),
              Text(l.setupContactChannels, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-call'),
                icon: glyph(ContactChannel.call),
                title: l.setupChannelCall,
                hint: l.setupChannelCallHint,
                value: _call,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _call = v;
                        if (v) _inAppOnly = false;
                      }),
              ),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-zalo'),
                icon: glyph(ContactChannel.zalo),
                title: l.setupChannelZalo,
                hint: l.setupChannelZaloHint,
                value: _zalo,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _zalo = v;
                        if (v) _inAppOnly = false;
                      }),
                extra: PhoneField(
                  key: const Key('zalo-own'),
                  controller: _zaloOwn,
                  label: l.setupZaloOwn,
                  enabled: !saving,
                  errorText: err(ContactSetupField.zalo),
                  validator: (_) => null,
                  onChanged: (_) => changed(),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-whatsapp'),
                icon: glyph(ContactChannel.whatsapp),
                title: l.setupChannelWhatsApp,
                hint: l.setupChannelWhatsAppHint,
                value: _whatsapp,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _whatsapp = v;
                        if (v) _inAppOnly = false;
                      }),
                extra: PhoneField(
                  key: const Key('whatsapp-own'),
                  controller: _whatsappOwn,
                  label: l.setupWhatsAppOwn,
                  international: true,
                  enabled: !saving,
                  errorText: err(ContactSetupField.whatsapp),
                  validator: (_) => null,
                  onChanged: (_) => changed(),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-inapp'),
                icon: glyph(ContactChannel.inApp),
                title: l.setupInAppOnly,
                hint: l.setupInAppOnlyHint,
                value: _inAppOnly,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _inAppOnly = v;
                        if (v) _call = _zalo = _whatsapp = false;
                      }),
              ),
              if (channelsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      channelsError,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      l.setupContactPrivacy,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s5),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      l.setupContactBack,
                      key: const Key('setup-back'),
                      onPressed: saving ? null : _back,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: AppButton.primary(
                      l.setupContactFinish,
                      key: const Key('setup-finish'),
                      loading: saving,
                      onPressed: _finish,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
