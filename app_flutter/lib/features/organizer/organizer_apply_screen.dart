// lib/features/organizer/organizer_apply_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/organizer_routes.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// S30.01 "Tổ chức sự kiện" at `/organizer/apply` (mock `#S30.01`): one step
/// to become an organizer (`becomeOrganizer`), then S30.02. Without a
/// verified phone the primary opens S21.01 and comes back here; a suspended
/// organizer sees the band and no action.
class OrganizerApplyScreen extends ConsumerStatefulWidget {
  const OrganizerApplyScreen({super.key});

  @override
  ConsumerState<OrganizerApplyScreen> createState() =>
      _OrganizerApplyScreenState();
}

class _OrganizerApplyScreenState extends ConsumerState<OrganizerApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  PickedImage? _avatar;
  bool _busy = false;
  bool _serverNameError = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (picked.isNotEmpty && mounted) setState(() => _avatar = picked.first);
  }

  Future<void> _verifyPhone() => context.push(
    Uri(
      path: '/verify/phone',
      queryParameters: {'returnTo': organizerApplyPath},
    ).toString(),
  );

  Future<void> _submit() async {
    setState(() => _serverNameError = false);
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    setState(() => _busy = true);
    final code = await ref
        .read(organizerActionsProvider)
        .run(
          (r) => r.becomeOrganizer(
            name: _name.text.trim(),
            bio: _bio.text.trim(),
            avatar: _avatar,
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (code) {
      case null:
        context.pushReplacement(spotClaimPath);
      case 'phone_required':
        await _verifyPhone();
      case 'invalid_argument':
        setState(() => _serverNameError = true);
        _form.currentState!.validate();
      case 'conflict':
        orgSay(context, l.s3001_suspended);
      default:
        orgSay(context, organizerErrorText(l, code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final contact = ref.watch(currentContactProvider).value;
    final organizer = ref.watch(myOrganizerProvider).value;
    final verified = contact?.phoneVerified ?? false;
    final suspended = organizer?.status == OrganizerStatus.suspended;
    if (organizer != null && !_prefilled) {
      _prefilled = true;
      _name.text = organizer.name;
      _bio.text = organizer.bio;
    }
    final masked = contact == null ? null : maskedPhoneParts(contact.phone);

    return ScreenCode(
      ScreenCodes.organizerApply,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.s3001_title)),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.s5),
              children: [
                if (suspended) ...[
                  OrgBand(
                    key: const Key('org-apply-suspended'),
                    text: l.s3001_suspended,
                    icon: AppIcons.lock,
                    tone: OrgBandTone.error,
                  ),
                  const SizedBox(height: AppSpace.s4),
                ],
                const OrgIllustration(AppIcons.ticket),
                const SizedBox(height: AppSpace.s4),
                Text(l.s3001_headline, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.s3001_intro,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpace.s5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AvatarButton(
                      picked: _avatar,
                      url: organizer?.avatarUrl,
                      onTap: _busy || suspended ? null : _pickAvatar,
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: TextFormField(
                        key: const Key('org-apply-name'),
                        controller: _name,
                        enabled: !_busy && !suspended,
                        maxLength: organizerNameMax,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(labelText: l.s3001_name),
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            _serverNameError || !organizerNameOk(v ?? '')
                            ? l.s3001_nameLength
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('org-apply-bio'),
                  controller: _bio,
                  enabled: !_busy && !suspended,
                  maxLength: organizerBioMax,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: l.s3001_bio),
                  validator: (v) => (v ?? '').trim().length > organizerBioMax
                      ? l.s3001_bioLength
                      : null,
                ),
                const SizedBox(height: AppSpace.s3),
                OrgInfoRow(
                  key: const Key('org-apply-phone'),
                  icon: verified ? AppIcons.verified : AppIcons.phone,
                  title: verified
                      ? l.s3001_phoneVerified
                      : l.s3001_phoneUnverified,
                  subtitle: verified && masked != null
                      ? l.s3001_phoneMasked(masked.head, masked.tail)
                      : null,
                ),
                OrgInfoRow(
                  icon: AppIcons.store,
                  title: l.s3001_businessNote,
                  subtitle: l.s3001_businessSub,
                ),
              ],
            ),
          ),
          bottomNavigationBar: AppFooterBar(
            child: AppButton.primary(
              verified ? l.s3001_submit : l.s3001_verifyPhone,
              key: const Key('org-apply-submit'),
              loading: _busy,
              onPressed: suspended || _busy
                  ? null
                  : verified
                  ? _submit
                  : _verifyPhone,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.picked, this.url, this.onTap});

  final PickedImage? picked;
  final String? url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final has = picked != null || url != null;
    return Semantics(
      button: true,
      label: context.l10n.s3001_avatar,
      child: InkWell(
        key: const Key('org-apply-avatar'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
          ),
          child: Center(
            child: AppIcon(
              has ? AppIcons.check : AppIcons.addPhoto,
              color: context.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
