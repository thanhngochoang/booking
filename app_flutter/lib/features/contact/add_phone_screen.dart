// lib/features/contact/add_phone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/contact/return_to.dart';
import 'package:photobooking/features/contact/save_contact_controller.dart';

/// S33 as a bottom sheet over the screen the customer was booking from.
/// Resolves to true once the number is saved; closing without saving resolves
/// to null and leaves no number, so the booking gate stays closed.
Future<bool?> showAddPhoneSheet(BuildContext context, {String? returnTo}) {
  return showAppSheet<bool>(
    context,
    builder: (sheetContext) => ScreenCode(
      ScreenCodes.addPhone,
      child: Material(
        type: MaterialType.transparency,
        child: AddPhoneContent(
          onSaved: () {
            Navigator.of(sheetContext).pop(true);
            final to = safeReturnTo(returnTo);
            if (to != null) context.go(to);
          },
        ),
      ),
    ),
  );
}

/// Deep-link fallback for `/profile/phone?returnTo=`: the same content as the
/// sheet on a plain page. Saves, then goes to [returnTo] (or back / home).
class AddPhoneScreen extends StatelessWidget {
  const AddPhoneScreen({super.key, this.returnTo});

  final String? returnTo;

  void _done(BuildContext context) {
    final to = safeReturnTo(returnTo);
    if (to != null) {
      context.go(to);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.home.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenCode(
      ScreenCodes.addPhone,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: SafeArea(
            top: false,
            child: AddPhoneContent(onSaved: () => _done(context)),
          ),
        ),
      ),
    );
  }
}

/// The S33 form: title, body, phone, example, Zalo/WhatsApp, privacy, save.
class AddPhoneContent extends ConsumerStatefulWidget {
  const AddPhoneContent({super.key, required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<AddPhoneContent> createState() => _AddPhoneContentState();
}

class _AddPhoneContentState extends ConsumerState<AddPhoneContent> {
  final _phone = TextEditingController();
  bool _zalo = true;
  bool _whatsApp = false;

  /// Shown inside the form, not as a SnackBar: in the sheet a SnackBar would
  /// sit under the barrier, out of sight.
  bool _saveFailed = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String? get _e164 => phoneFromField(_phone.text);

  void _save() {
    final phone = _e164;
    if (phone == null) return;
    setState(() => _saveFailed = false);
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
        setState(() => _saveFailed = true);
      } else if (next.value ?? false) {
        widget.onSaved();
      }
    });
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l.addPhoneTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(l.addPhoneBody),
          const SizedBox(height: AppSpace.s5),
          PhoneField(
            controller: _phone,
            enabled: !saving,
            autofocus: true,
            onChanged: (_) => setState(() => _saveFailed = false),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(l.addPhoneExample, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpace.s3),
          SwitchListTile(
            key: const Key('allow-zalo'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.allowZaloLabel),
            value: _zalo,
            onChanged: saving ? null : (v) => setState(() => _zalo = v),
          ),
          SwitchListTile(
            key: const Key('allow-whatsapp'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.allowWhatsAppLabel),
            value: _whatsApp,
            onChanged: saving ? null : (v) => setState(() => _whatsApp = v),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(l.phonePrivacy, style: theme.textTheme.bodySmall),
          if (_saveFailed) ...[
            const SizedBox(height: AppSpace.s3),
            Semantics(
              liveRegion: true,
              child: Text(
                l.phoneSaveError,
                key: const Key('phone-save-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s5),
          AppButton.primary(
            l.addPhoneSave,
            key: const Key('phone-save'),
            loading: saving,
            onPressed: _e164 == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
