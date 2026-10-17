import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';

@immutable
class ReportState {
  const ReportState({
    this.reason,
    this.text,
    this.block = false,
    this.submitting = false,
    this.error,
  });

  final ReportReason? reason;
  final String? text;
  final bool block;
  final bool submitting;
  final SafetyError? error;

  bool get canSubmit {
    if (submitting) return false;
    if (reason == null) return false;
    if (reason == ReportReason.other) {
      final trimmed = text?.trim() ?? '';
      return trimmed.length >= 10;
    }
    return true;
  }

  ReportState copyWith({
    ReportReason? reason,
    String? text,
    bool? block,
    bool? submitting,
    SafetyError? error,
  }) {
    return ReportState(
      reason: reason ?? this.reason,
      text: text ?? this.text,
      block: block ?? this.block,
      submitting: submitting ?? this.submitting,
      error: error,
    );
  }
}

class ReportController extends Notifier<ReportState> {
  @override
  ReportState build() => const ReportState();

  void selectReason(ReportReason reason) {
    state = state.copyWith(reason: reason);
  }

  void setText(String text) {
    state = state.copyWith(text: text);
  }

  void toggleBlock(bool block) {
    state = state.copyWith(block: block);
  }

  Future<ReportResult?> submit(ReportTarget target) async {
    if (!state.canSubmit) return null;
    state = state.copyWith(submitting: true, error: null);

    try {
      final repo = ref.read(safetyRepositoryProvider);
      final draft = ReportDraft(
        target: target,
        reason: state.reason!,
        text: state.text,
        block: state.block,
      );
      final result = await repo.report(draft);
      state = state.copyWith(submitting: false);
      return result;
    } on SafetyError catch (e) {
      state = state.copyWith(submitting: false, error: e);
      rethrow;
    } catch (e) {
      final err = SafetyError('unknown', e.toString());
      state = state.copyWith(submitting: false, error: err);
      rethrow;
    }
  }
}

final reportControllerProvider =
    NotifierProvider.autoDispose<ReportController, ReportState>(
  ReportController.new,
);
