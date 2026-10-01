// lib/features/contact/add_phone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/contact/return_to.dart';
import 'package:photobooking/features/contact/save_contact_controller.dart';

/// S33: add the phone number needed to book. Saves to the private contact and
/// goes back to [returnTo] (or the previous screen / home).
class AddPhoneScreen extends ConsumerStatefulWidget {
  const AddPhoneScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends ConsumerState<AddPhoneScreen> {
  final _phone = TextEditingController();
  bool _zalo = true;
  bool _whatsApp = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String? get _e164 => phoneFromField(_phone.text);

  void _done() {
    final to = safeReturnTo(widget.returnTo);
    if (to != null) {
      context.go(to);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.home.path);
    }
  }

  void _save() {
    final phone = _e164;
    if (phone == null) return;
    ref
        .read(saveContactControllerProvider.notifier)
        .save(phone: phone, allowZalo: _zalo, allowWhatsApp: _whatsApp);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saving = ref.watch(saveContactControllerProvider).isLoading;
    ref.listen(saveContactControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.phoneSaveError)));
      } else if (next.value ?? false) {
        _done();
      }
    });
    return ScreenCode(
      ScreenCodes.addPhone,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: GlassCard(
                highlight: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.addPhoneTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(l.addPhoneBody),
                      const SizedBox(height: AppSpace.s5),
                      PhoneField(
                        controller: _phone,
                        enabled: !saving,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(l.addPhoneExample, style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppSpace.s3),
                      SwitchListTile(
                        key: const Key('allow-zalo'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.allowZaloLabel),
                        value: _zalo,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => _zalo = v),
                      ),
                      SwitchListTile(
                        key: const Key('allow-whatsapp'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.allowWhatsAppLabel),
                        value: _whatsApp,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => _whatsApp = v),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16),
                          const SizedBox(width: AppSpace.s2),
                          Expanded(
                            child: Text(
                              l.phonePrivacy,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s5),
                      AppButton.primary(
                        l.addPhoneSave,
                        key: const Key('phone-save'),
                        loading: saving,
                        onPressed: _e164 == null ? null : _save,
                      ),
                    ],
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
