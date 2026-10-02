import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// Shown while Firebase restores the session and the profile loads.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.appName,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s5),
                  ApertureLoader(semanticsLabel: context.l10n.loadingLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
