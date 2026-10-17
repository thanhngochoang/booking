import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/screen_codes.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/reason_picker.dart';
import 'package:photobooking/core/widgets/screen_code.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/features/safety/report_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<ReportResult?> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
}) {
  return showAppSheet<ReportResult>(
    context,
    builder: (sheetContext) => ScreenCode(
      ScreenCodes.report,
      child: ReportSheet(target: target),
    ),
  );
}

class ReportSheet extends ConsumerWidget {
  const ReportSheet({super.key, required this.target});

  final ReportTarget target;

  static const _reasonsInOrder = [
    ReportReason.spam,
    ReportReason.scam,
    ReportReason.harassment,
    ReportReason.inappropriate,
    ReportReason.stolenPhotos,
    ReportReason.impersonation,
    ReportReason.other,
  ];

  String _titleFor(AppLocalizations l) {
    return switch (target.type) {
      ReportTargetType.user => l.reportTitleUser(target.ownerName ?? ''),
      ReportTargetType.post => l.reportTitlePost,
      ReportTargetType.message => l.reportTitleMessage,
      ReportTargetType.event => l.reportTitleEvent,
    };
  }

  String _reasonLabel(AppLocalizations l, ReportReason r) {
    return switch (r) {
      ReportReason.spam => l.reportReasonSpam,
      ReportReason.scam => l.reportReasonScam,
      ReportReason.harassment => l.reportReasonHarassment,
      ReportReason.inappropriate => l.reportReasonInappropriate,
      ReportReason.stolenPhotos => l.reportReasonStolen,
      ReportReason.impersonation => l.reportReasonImpersonation,
      ReportReason.other => l.reportReasonOther,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(reportControllerProvider);
    final controller = ref.read(reportControllerProvider.notifier);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    final reasonLabels = _reasonsInOrder.map((r) => _reasonLabel(l, r)).toList();
    final selectedIndex = state.reason != null
        ? _reasonsInOrder.indexOf(state.reason!)
        : null;

    final bool isOwn = target.ownerId != null && target.ownerId == currentUid;
    final bool isPlatformEvent =
        target.type == ReportTargetType.event && target.ownerId == null;
    final bool showBlockCheckbox =
        !isOwn && !isPlatformEvent && target.ownerId != null;

    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _titleFor(l),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.reportAnonymous,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.foregroundSecondary,
            ),
          ),
          if (target.type == ReportTargetType.message &&
              target.excerpt != null &&
              target.excerpt!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (target.ownerName != null)
                    Text(
                      target.ownerName!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    target.excerpt!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.foregroundSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l.reportReasonTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ReasonPicker(
            style: ReasonPickerStyle.radio,
            reasons: reasonLabels,
            selected: selectedIndex != -1 ? selectedIndex : null,
            onSelected: (idx) {
              controller.selectReason(_reasonsInOrder[idx]);
            },
            otherLabel: l.reportReasonOther,
            otherMinLength: 10,
            onOtherText: (text) {
              controller.setText(text);
            },
          ),
          if (state.reason != null && state.reason != ReportReason.other) ...[
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: l.reportTextLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 2,
              onChanged: controller.setText,
            ),
          ],
          if (showBlockCheckbox) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: state.block,
              onChanged: (val) => controller.toggleBlock(val ?? false),
              title: Text(
                l.reportBlockAlso(target.ownerName ?? ''),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                l.reportBlockAlsoBody,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.foregroundSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppButton.primary(
            l.reportSubmit,
            key: const Key('report-submit'),
            onPressed: state.canSubmit
                ? () async {
                    try {
                      final res = await controller.submit(target);
                      if (context.mounted && res != null) {
                        Navigator.of(context).pop(res);
                        final msg = res.blocked
                            ? l.reportSentBlocked(target.ownerName ?? '')
                            : (res.duplicate ? l.reportDuplicate : l.reportSent);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    } on SafetyError catch (e) {
                      if (!context.mounted) return;
                      final text = switch (e.code) {
                        'limit_exceeded' => l.reportLimit,
                        _ => l.reportFailed,
                      };
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(text)),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.reportFailed)),
                        );
                      }
                    }
                  }
                : null,
            loading: state.submitting,
          ),
        ],
      ),
    ),
    );
  }
}
