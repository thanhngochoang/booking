import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final saving = ref.watch(editProfileControllerProvider).isLoading;
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
      if (_form.currentState!.validate()) {
        ref
            .read(editProfileControllerProvider.notifier)
            .save(displayName: _name.text);
      }
    }

    return ScreenCode(
      ScreenCodes.editProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.editProfileTitle)),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: GlassCard(
                highlight: false,
                child: Padding(
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
                        const SizedBox(height: AppSpace.s5),
                        AppButton.primary(
                          l.editProfileSave,
                          key: const Key('edit-save'),
                          loading: saving,
                          onPressed: save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
