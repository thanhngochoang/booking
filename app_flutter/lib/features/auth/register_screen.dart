import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'auth_form_validators.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(l.registerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('name'),
                  controller: _name,
                  decoration: InputDecoration(labelText: l.displayNameLabel),
                  validator: (v) => validateName(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l.emailLabel),
                  validator: (v) => validateEmail(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l.passwordLabel),
                  validator: (v) => validatePassword(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('confirm'),
                  controller: _confirm,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l.passwordConfirmLabel,
                  ),
                  validator: (v) => validateConfirm(v, _password.text, l),
                ),
                const SizedBox(height: AppSpace.s5),
                AppButton.primary(
                  l.registerButton,
                  key: const Key('register'),
                  loading: loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      ref
                          .read(authControllerProvider.notifier)
                          .register(_email.text, _password.text, _name.text);
                    }
                  },
                ),
                const SizedBox(height: AppSpace.s3),
                AppButton.text(
                  l.haveAccountLogin,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
