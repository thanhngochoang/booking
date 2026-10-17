import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/widgets/confirm_sheet.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<bool> confirmBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final l = AppLocalizations.of(context);
  final repo = ref.read(safetyRepositoryProvider);

  final confirmed = await showConfirmSheet(
    context,
    title: l.blockConfirmTitle(name),
    body: l.blockConfirmBody(name),
    confirmLabel: l.blockConfirm,
    keepLabel: l.blockKeep,
    danger: true,
    onConfirm: () async {
      try {
        await repo.block(userId, source: 'menu');
      } on SafetyError catch (e) {
        if (e.code == 'limit_exceeded') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.blockLimit)),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.blockFailed)),
            );
          }
        }
        rethrow;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.blockFailed)),
          );
        }
        rethrow;
      }
    },
  );

  if (confirmed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.blockDone(name))),
    );
  }
  return confirmed;
}

Future<bool> confirmUnblock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final l = AppLocalizations.of(context);
  final repo = ref.read(safetyRepositoryProvider);

  final confirmed = await showConfirmSheet(
    context,
    title: l.unblockConfirmTitle(name),
    body: l.unblockConfirmBody,
    confirmLabel: l.unblockConfirm,
    keepLabel: l.unblockKeep,
    danger: false,
    onConfirm: () async {
      try {
        await repo.unblock(userId);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.reportFailed)),
          );
        }
        rethrow;
      }
    },
  );

  if (confirmed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.unblockDone(name))),
    );
  }
  return confirmed;
}
