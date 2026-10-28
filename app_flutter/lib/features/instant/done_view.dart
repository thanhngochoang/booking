// `#S13.06-done`: the request is `completed` (the customer confirmed, or the
// clock did 2 hours after the photographer finished). The photos come within
// 48 hours; no review entry (reviews are booking-bound until #130) and no
// dispute link (S18, #142) here (Decision 12).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_icon_disc.dart';

class DoneView extends StatelessWidget {
  const DoneView({super.key, required this.request});

  final InstantRequest request;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.instantInProgress,
      label: 'done',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(l.instantTitle),
          ),
          body: EmptyState(
            title: l.doneTitle,
            body: l.doneBody(request.photographer?.name ?? '', request.photos),
            illustration: const InstantIconDisc(AppIcons.taskAlt),
          ),
          bottomNavigationBar: AppFooterBar(
            child: AppButton.outline(
              l.doneHome,
              key: const Key('done-home'),
              onPressed: () => context.go('/home'),
            ),
          ),
        ),
      ),
    );
  }
}
