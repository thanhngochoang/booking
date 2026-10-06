import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/provider_providers.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';

/// S09.02 "Hình thức nhận việc": Cá nhân or Studio. Resolves to the type the
/// server stored after a successful switch, null when nothing changed.
Future<ProviderType?> showProviderTypeSheet(
  BuildContext context, {
  required ProviderType current,
}) => showAppSheet<ProviderType>(
  context,
  builder: (_) => ProviderTypeSheet(current: current),
);

class ProviderTypeSheet extends ConsumerStatefulWidget {
  const ProviderTypeSheet({super.key, required this.current});

  final ProviderType current;

  @override
  ConsumerState<ProviderTypeSheet> createState() => _ProviderTypeSheetState();
}

class _ProviderTypeSheetState extends ConsumerState<ProviderTypeSheet> {
  late ProviderChoice _choice = widget.current.choice;
  bool _busy = false;
  bool _notEligible = false;
  bool _failed = false;

  Future<void> _save() async {
    final l = context.l10n;
    if (_choice == widget.current.choice) {
      Navigator.of(context).pop();
      return;
    }
    // Studio drops the NAG tier: ask first.
    if (widget.current == ProviderType.artist &&
        _choice == ProviderChoice.studio) {
      final ok = await showConfirmSheet(
        context,
        title: l.providerLoseArtistConfirm,
        body: l.providerLoseArtistBody,
        confirmLabel: l.providerLoseArtistConfirm,
        keepLabel: l.providerTypeKeep,
        danger: true,
      );
      if (!ok || !mounted) {
        return;
      }
    }
    setState(() {
      _busy = true;
      _notEligible = false;
      _failed = false;
    });
    try {
      final type = await ref.read(providerRepositoryProvider).setType(_choice);
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid != null) {
        ref.invalidate(photographerProfileProvider(uid));
      }
      ref.invalidate(myIntroProvider);
      if (mounted) {
        Navigator.of(context).pop(type);
      }
    } on ProviderError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _notEligible = e.code == 'not_eligible';
          _failed = !_notEligible;
        });
      }
    } catch (_) {
      // Network and anything the repository did not wrap.
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final error = _notEligible
        ? l.providerNotEligible
        : _failed
        ? l.setupSaveError
        : null;
    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            0,
            AppSpace.s4,
            AppSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.settingsProviderType,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              AppOptionTile(
                key: const Key('type-individual'),
                label: l.setupTypeIndividual,
                description: l.setupTypeIndividualBody,
                leading: const AppIcon(AppIcons.profile),
                selected: _choice == ProviderChoice.individual,
                onTap: () {
                  if (!_busy) {
                    setState(() => _choice = ProviderChoice.individual);
                  }
                },
              ),
              const SizedBox(height: AppSpace.s2),
              AppOptionTile(
                key: const Key('type-studio'),
                label: l.setupTypeStudio,
                description: l.setupTypeStudioBody,
                leading: const AppIcon(AppIcons.work),
                selected: _choice == ProviderChoice.studio,
                onTap: () {
                  if (!_busy) {
                    setState(() => _choice = ProviderChoice.studio);
                  }
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      key: const Key('type-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s4),
              AppButton.primary(
                l.providerTypeSave,
                key: const Key('type-save'),
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
