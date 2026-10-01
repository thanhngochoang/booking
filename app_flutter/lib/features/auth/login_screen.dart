import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'auth_form_validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

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
      final err = next.value;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(err, l))),
        );
      }
    });
    final notifier = ref.read(authControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.s10),
                Text(l.appName, style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: AppSpace.s8),
                TextFormField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: l.emailLabel),
                  validator: (v) => validateEmail(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l.passwordLabel),
                  validator: (v) => validatePassword(v, l),
                ),
                const SizedBox(height: AppSpace.s5),
                AppButton.primary(
                  l.loginButton,
                  key: const Key('login'),
                  loading: loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      notifier.signInEmail(_email.text, _password.text);
                    }
                  },
                ),
                const SizedBox(height: AppSpace.s3),
                AppButton.outline(
                  l.continueWithGoogle,
                  key: const Key('google'),
                  loading: loading,
                  onPressed: notifier.google,
                ),
                const SizedBox(height: AppSpace.s2),
                AppButton.outline(
                  l.continueWithFacebook,
                  key: const Key('facebook'),
                  loading: loading,
                  onPressed: notifier.facebook,
                ),
                const SizedBox(height: AppSpace.s4),
                AppButton.text(
                  l.noAccountRegister,
                  onPressed: () => context.push('/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
