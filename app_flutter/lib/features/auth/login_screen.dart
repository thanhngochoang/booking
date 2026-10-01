import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/auth/auth_controller.dart';
import 'package:photobooking/features/auth/auth_form_validators.dart';

enum _Method { email, google, facebook }

// Provider colours from the Google and Meta sign-in brand guidelines.
const _googleText = Color(0xFF1F1F1F);
const _facebookBlue = Color(0xFF0866FF); // white text 4.8:1

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

    final google = Tooltip(
      message: l.continueWithGoogle,
      child: AppButton.outline(
        l.socialGoogle,
        key: const Key('google'),
        icon: SvgPicture.asset(
          'assets/social/google_g.svg',
          width: 18,
          height: 18,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _googleText,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
          disabledForegroundColor: _googleText.withValues(alpha: 0.6),
          side: BorderSide.none,
        ),
        loading: busy(_Method.google),
        onPressed: start(_Method.google, notifier.google),
      ),
    );
    final facebook = Tooltip(
      message: l.continueWithFacebook,
      child: AppButton.outline(
        l.socialFacebook,
        key: const Key('facebook'),
        icon: SvgPicture.asset(
          'assets/social/facebook_f.svg',
          width: 20,
          height: 20,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: _facebookBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _facebookBlue.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          side: BorderSide.none,
        ),
        loading: busy(_Method.facebook),
        onPressed: start(_Method.facebook, notifier.facebook),
      ),
    );

    // The card is glass over the dark canvas in either app theme.
    final cardTheme = buildDarkTheme();
    final card = Theme(
      data: cardTheme,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.loginWelcome, style: cardTheme.textTheme.titleLarge),
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.loginWelcomeBody,
                  style: cardTheme.textTheme.bodySmall?.copyWith(
                    color: onHeroSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => submit(),
                        decoration: InputDecoration(
                          labelText: l.passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? l.showPassword : l.hidePassword,
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
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  loading: busy(_Method.email),
                  onPressed: loading ? null : submit,
                ),
                const SizedBox(height: AppSpace.s4),
                _OrDivider(label: l.loginOrDivider),
                const SizedBox(height: AppSpace.s3),
                LayoutBuilder(
                  // Side by side when both labels fit, stacked otherwise.
                  builder: (context, box) => box.maxWidth >= 280
                      ? Row(
                          children: [
                            Expanded(child: google),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(child: facebook),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            google,
                            const SizedBox(height: AppSpace.s3),
                            facebook,
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.heroCanvas,
        body: Stack(
          children: [
            const Positioned.fill(child: AuroraBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s5,
                    AppSpace.s3,
                    AppSpace.s5,
                    AppSpace.s1,
                  ),
                  child: ConstrainedBox(
                    // Centre vertically on tall screens, scroll on short ones.
                    constraints: BoxConstraints(
                      minHeight: viewport.maxHeight - AppSpace.s3 - AppSpace.s1,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuroraHero(
                              lead: l.loginHeadlineLead,
                              accent: l.loginHeadlineAccent,
                              tagline: l.loginTagline,
                            ),
                            const SizedBox(height: AppSpace.s5),
                            card,
                            const SizedBox(height: AppSpace.s2),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  l.noAccountPrompt,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: onHeroSecondary,
                                  ),
                                ),
                                TextButton(
                                  key: const Key('register'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.spectrumCyan,
                                  ),
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
          ],
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
