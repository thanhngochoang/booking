import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/auth/auth_controller.dart';
import 'package:photobooking/features/auth/auth_form_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.color;
    final loading = ref.watch(authControllerProvider).isLoading;
    ref.listen(authControllerProvider, (_, next) {
      // A loading state still carries the previous error; only react to a
      // finished attempt, and only on the route the user is looking at.
      if (next.isLoading || !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      final err = next.value;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(err, l))));
      }
    });
    void submit() {
      if (_form.currentState!.validate()) {
        ref
            .read(authControllerProvider.notifier)
            .register(_email.text, _password.text, _name.text);
      }
    }

    final toggle = IconButton(
      tooltip: _obscure ? l.showPassword : l.hidePassword,
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    final card = GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.registerTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.registerWelcomeBody,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpace.s4),
                TextFormField(
                  key: const Key('name'),
                  enabled: !loading,
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: l.displayNameLabel,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => validateName(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('email'),
                  enabled: !loading,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l.emailLabel,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) => validateEmail(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('password'),
                  enabled: !loading,
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: l.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: toggle,
                  ),
                  validator: (v) => validatePassword(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('confirm'),
                  enabled: !loading,
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: l.passwordConfirmLabel,
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (v) => validateConfirm(v, _password.text, l),
                ),
                const SizedBox(height: AppSpace.s5),
                AppButton.primary(
                  l.registerButton,
                  key: const Key('register'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  loading: loading,
                  onPressed: submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return ScreenCode(
      ScreenCodes.register,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyleFor(theme),
        child: AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s5,
                  0,
                  AppSpace.s5,
                  AppSpace.s2,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuroraHero(
                          lead: l.registerHeadlineLead,
                          accent: l.registerHeadlineAccent,
                          tagline: l.registerTagline,
                        ),
                        const SizedBox(height: AppSpace.s5),
                        card,
                        const SizedBox(height: AppSpace.s2),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l.haveAccountPrompt,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondary,
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                              ),
                              onPressed: loading ? null : () => context.pop(),
                              child: Text(l.loginButton),
                            ),
                          ],
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
