// lib/features/chat/inquiry_entry.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_parties.dart';

class InquiryEntry extends ConsumerStatefulWidget {
  const InquiryEntry({
    super.key,
    required this.photographerId,
    this.serviceId,
  });

  final String photographerId;
  final String? serviceId;

  @override
  ConsumerState<InquiryEntry> createState() => _InquiryEntryState();
}

class _InquiryEntryState extends ConsumerState<InquiryEntry> {
  bool _notEligible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    try {
      final chatId = await ref
          .read(chatRepositoryProvider)
          .openInquiry(widget.photographerId);
      if (!mounted) return;
      final q = widget.serviceId != null
          ? '?serviceId=${Uri.encodeQueryComponent(widget.serviceId!)}'
          : '';
      context.replace('/chat/$chatId$q');
    } catch (e) {
      if (!mounted) return;
      if (e is ChatException && e.code == ChatErrorCode.notEligible) {
        setState(() => _notEligible = true);
      } else {
        setState(() => _error = e.toString());
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/u/${widget.photographerId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notEligible) {
      final name =
          ref.watch(partyProfileProvider(widget.photographerId)).value?.displayName ??
          ref
              .watch(photographerProfileProvider(widget.photographerId))
              .value
              ?.summary
              .displayName ??
          '';
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: EmptyState(
            title: context.l10n.inquiryNotEligible(name),
            body: '',
            actionLabel: context.l10n.back,
            onAction: _back,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: EmptyState(
            title: _error!,
            body: '',
            actionLabel: context.l10n.back,
            onAction: _back,
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SignatureLoader(
          size: LoaderSize.screen,
          wave: LoaderWave.ripple,
        ),
      ),
    );
  }
}
