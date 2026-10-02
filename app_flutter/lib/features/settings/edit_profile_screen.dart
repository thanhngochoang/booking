import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/auth/auth_form_validators.dart';
import 'package:photobooking/features/settings/edit_profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(currentProfileProvider).value?.displayName ?? '',
  );
  final _phone = TextEditingController();
  bool _zalo = true;
  bool _whatsApp = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // Fill the phone section once, when the stored contact first arrives; a
    // later stream update must not overwrite what the person is typing.
    ref.listenManual(currentContactProvider, (_, next) {
      final c = next.value;
      if (_prefilled || c == null) return;
      _prefilled = true;
      setState(() {
        _phone.text = nationalFromE164(c.phone);
        _zalo = c.allowZalo;
        _whatsApp = c.allowWhatsApp;
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final saving = ref.watch(editProfileControllerProvider).isLoading;
    // Without a stored number the switches have nothing to be saved against,
    // so they wait for a valid one instead of looking saved when they are not.
    final hasNumber =
        ref.watch(currentContactProvider).value != null ||
        phoneFromField(_phone.text) != null;
    final canToggle = !saving && hasNumber;
    ref.listen(editProfileControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      final messenger = ScaffoldMessenger.of(context);
      if (next.hasError) {
        messenger.showSnackBar(SnackBar(content: Text(l.editProfileError)));
      } else if (next.value ?? false) {
        messenger.showSnackBar(SnackBar(content: Text(l.editProfileSaved)));
        context.pop();
      }
    });
    void save() {
      if (!_form.currentState!.validate()) return;
      // Empty field: keep any stored number (saving the toggles with it).
      final phone =
          phoneFromField(_phone.text) ??
          ref.read(currentContactProvider).value?.phone;
      ref
          .read(editProfileControllerProvider.notifier)
          .save(
            displayName: _name.text,
            phone: phone,
            allowZalo: _zalo,
            allowWhatsApp: _whatsApp,
          );
    }

    return ScreenCode(
      ScreenCodes.editProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.editProfileTitle)),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('edit-name'),
                          controller: _name,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.name],
                          onFieldSubmitted: (_) => save(),
                          decoration: InputDecoration(
                            labelText: l.displayNameLabel,
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                          ),
                          validator: (v) => validateName(v, l),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        PhoneField(
                          key: const Key('edit-phone'),
                          controller: _phone,
                          enabled: !saving,
                          onChanged: (_) => setState(() {}),
                          // Optional here: empty means "leave as is".
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? null
                              : validatePhone(v, l),
                        ),
                        SwitchListTile(
                          key: const Key('edit-allow-zalo'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.allowZaloLabel),
                          value: _zalo,
                          onChanged: !canToggle
                              ? null
                              : (v) => setState(() => _zalo = v),
                        ),
                        SwitchListTile(
                          key: const Key('edit-allow-whatsapp'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.allowWhatsAppLabel),
                          value: _whatsApp,
                          onChanged: !canToggle
                              ? null
                              : (v) => setState(() => _whatsApp = v),
                        ),
                        Text(
                          l.editProfilePhoneHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AppFooterBar(
                child: AppButton.primary(
                  l.editProfileSave,
                  key: const Key('edit-save'),
                  loading: saving,
                  onPressed: save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
