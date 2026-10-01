import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import 'auth_controller.dart';
import 'auth_form_validators.dart';

enum _Method { email, google, facebook }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  _Method? _pending;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
    final notifier = ref.read(authControllerProvider.notifier);
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.color;
    // Spinner on the button that started the attempt; the others go disabled.
    bool busy(_Method m) => loading && _pending == m;
    VoidCallback? start(_Method m, VoidCallback run) => loading
        ? null
        : () {
            setState(() => _pending = m);
            run();
          };
    void submit() {
      if (_form.currentState!.validate()) {
        setState(() => _pending = _Method.email);
        notifier.signInEmail(_email.text, _password.text);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s5,
              vertical: AppSpace.s6,
            ),
            child: ConstrainedBox(
              // Centre vertically on tall screens, scroll on short ones.
              constraints: BoxConstraints(
                minHeight: viewport.maxHeight - AppSpace.s6 * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo()),
                        const SizedBox(height: AppSpace.s5),
                        Text(
                          l.appName,
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          l.loginTagline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpace.s8),
                        AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                key: const Key('email'),
                                enabled: !loading,
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: l.emailLabel,
                                  prefixIcon: const Icon(Icons.mail_outline),
                                ),
                                validator: (v) => validateEmail(v, l),
                              ),
                              const SizedBox(height: AppSpace.s3),
                              TextFormField(
                                key: const Key('password'),
                                enabled: !loading,
                                controller: _password,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => submit(),
                                decoration: InputDecoration(
                                  labelText: l.passwordLabel,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? l.showPassword
                                        : l.hidePassword,
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => validatePassword(v, l),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.s5),
                        AppButton.primary(
                          l.loginButton,
                          key: const Key('login'),
                          loading: busy(_Method.email),
                          onPressed: loading ? null : submit,
                        ),
                        const SizedBox(height: AppSpace.s5),
                        _OrDivider(label: l.loginOrDivider),
                        const SizedBox(height: AppSpace.s5),
                        AppButton.outline(
                          l.continueWithGoogle,
                          key: const Key('google'),
                          loading: busy(_Method.google),
                          onPressed: start(_Method.google, notifier.google),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        AppButton.outline(
                          l.continueWithFacebook,
                          key: const Key('facebook'),
                          loading: busy(_Method.facebook),
                          onPressed: start(_Method.facebook, notifier.facebook),
                        ),
                        const SizedBox(height: AppSpace.s6),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l.noAccountPrompt,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondary,
                              ),
                            ),
                            TextButton(
                              key: const Key('register'),
                              onPressed: loading
                                  ? null
                                  : () => context.push('/register'),
                              child: Text(l.registerLink),
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

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
