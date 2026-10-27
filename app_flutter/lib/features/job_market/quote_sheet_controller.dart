// lib/features/job_market/quote_sheet_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/contact_filter.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/jobs/quote_draft.dart';
import 'package:photobooking/data/photographer/service_package.dart';

class QuoteSheetState {
  const QuoteSheetState({
    this.jobId = '',
    this.price = 0,
    this.editedCount = 0,
    this.deliveryDays = 7,
    this.revisions = 1,
    this.message = '',
    this.albumId,
    this.basedOnServiceId,
    this.proposal,
    this.isEditing = false,
    this.submitting = false,
    this.isDirty = false,
    this.errors = const {},
    this.generalError,
  });

  final String jobId;
  final int price;
  final int editedCount;
  final int deliveryDays;
  final int revisions;
  final String message;
  final String? albumId;
  final String? basedOnServiceId;
  final QuoteProposal? proposal;
  final bool isEditing;
  final bool submitting;
  final bool isDirty;
  final Map<String, String> errors;
  final String? generalError;

  ({int shoot, int delivery}) get milestones =>
      milestoneAmountsOf(price > 0 ? price : 0);

  bool get isValid =>
      price > 0 &&
      message.trim().length >= 20 &&
      message.trim().length <= 500 &&
      errors.isEmpty;

  QuoteSheetState copyWith({
    String? jobId,
    int? price,
    int? editedCount,
    int? deliveryDays,
    int? revisions,
    String? message,
    String? albumId,
    bool clearAlbum = false,
    String? basedOnServiceId,
    bool clearBasedOnService = false,
    QuoteProposal? proposal,
    bool clearProposal = false,
    bool? isEditing,
    bool? submitting,
    bool? isDirty,
    Map<String, String>? errors,
    String? generalError,
    bool clearGeneralError = false,
  }) {
    return QuoteSheetState(
      jobId: jobId ?? this.jobId,
      price: price ?? this.price,
      editedCount: editedCount ?? this.editedCount,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      revisions: revisions ?? this.revisions,
      message: message ?? this.message,
      albumId: clearAlbum ? null : (albumId ?? this.albumId),
      basedOnServiceId: clearBasedOnService
          ? null
          : (basedOnServiceId ?? this.basedOnServiceId),
      proposal: clearProposal ? null : (proposal ?? this.proposal),
      isEditing: isEditing ?? this.isEditing,
      submitting: submitting ?? this.submitting,
      isDirty: isDirty ?? this.isDirty,
      errors: errors ?? this.errors,
      generalError: clearGeneralError
          ? null
          : (generalError ?? this.generalError),
    );
  }
}

class QuoteSheetController extends Notifier<QuoteSheetState> {
  QuoteSheetController(this.jobId);
  final String jobId;

  @override
  QuoteSheetState build() {
    return QuoteSheetState(jobId: jobId);
  }

  void initFromQuote(Quote quote) {
    state = state.copyWith(
      price: quote.terms.price,
      editedCount: quote.terms.editedCount,
      deliveryDays: quote.terms.deliveryDays,
      revisions: quote.terms.revisions,
      message: quote.message,
      albumId: quote.albumId,
      basedOnServiceId: quote.basedOnServiceId,
      proposal: quote.proposal,
      isEditing: true,
      isDirty: false,
    );
  }

  void applyPackage(ServicePackage package) {
    final newErrors = Map<String, String>.from(state.errors)..remove('price');
    state = state.copyWith(
      basedOnServiceId: package.id,
      price: package.priceVnd,
      editedCount: package.editedCount ?? state.editedCount,
      deliveryDays: package.deliveryDays ?? state.deliveryDays,
      isDirty: true,
      errors: newErrors,
    );
  }

  void clearPackage() {
    state = state.copyWith(
      clearBasedOnService: true,
      isDirty: true,
    );
  }

  void setPrice(int price) {
    final newErrors = Map<String, String>.from(state.errors);
    if (price <= 0) {
      newErrors['price'] = 'quoteErrPrice';
    } else {
      newErrors.remove('price');
    }
    state = state.copyWith(
      price: price,
      isDirty: true,
      errors: newErrors,
    );
  }

  void setProposal(QuoteProposal proposal) {
    final newErrors = Map<String, String>.from(state.errors)..remove('proposal');
    state = state.copyWith(
      proposal: proposal,
      isDirty: true,
      errors: newErrors,
    );
  }

  void setEditedCount(int count) {
    state = state.copyWith(
      editedCount: count < 0 ? 0 : count,
      isDirty: true,
    );
  }

  void setDeliveryDays(int days) {
    state = state.copyWith(
      deliveryDays: days < 1 ? 1 : days,
      isDirty: true,
    );
  }

  void setRevisions(int revs) {
    state = state.copyWith(
      revisions: revs < 0 ? 0 : revs,
      isDirty: true,
    );
  }

  void setMessage(String msg) {
    final newErrors = Map<String, String>.from(state.errors);
    final trimmed = msg.trim();
    if (trimmed.length < 20 || trimmed.length > 500) {
      newErrors['message'] = 'quoteErrMessage';
    } else if (findContactLeak(trimmed) != null) {
      newErrors['message'] = 'quoteErrContact';
    } else {
      newErrors.remove('message');
    }
    state = state.copyWith(
      message: msg,
      isDirty: true,
      errors: newErrors,
    );
  }

  void setAlbumId(String? albumId) {
    state = state.copyWith(
      albumId: albumId,
      clearAlbum: albumId == null,
      isDirty: true,
    );
  }

  Future<bool> submit(Job job) async {
    final newErrors = Map<String, String>.from(state.errors);
    if (state.price <= 0) {
      newErrors['price'] = 'quoteErrPrice';
    }
    final trimmedMsg = state.message.trim();
    if (trimmedMsg.length < 20 || trimmedMsg.length > 500) {
      newErrors['message'] = 'quoteErrMessage';
    } else if (findContactLeak(trimmedMsg) != null) {
      newErrors['message'] = 'quoteErrContact';
    }
    if (job.schedule.kind == ScheduleKind.flexible && state.proposal == null) {
      newErrors['proposal'] = 'quoteErrProposal';
    }

    if (newErrors.isNotEmpty) {
      state = state.copyWith(errors: newErrors);
      return false;
    }

    state = state.copyWith(submitting: true, clearGeneralError: true);
    final repo = ref.read(jobRepositoryProvider);

    final draft = QuoteDraft(
      jobId: state.jobId,
      price: state.price,
      editedCount: state.editedCount,
      deliveryDays: state.deliveryDays,
      revisions: state.revisions,
      message: trimmedMsg,
      albumId: state.albumId,
      basedOnServiceId: state.basedOnServiceId,
      proposal: state.proposal,
    );

    try {
      await repo.submitQuote(draft);
      state = state.copyWith(submitting: false, isDirty: false);
      return true;
    } catch (e) {
      final err = jobErrorOf(e);
      final fieldErrors = Map<String, String>.from(state.errors);
      String? genError;

      if (err.field == 'message.contact') {
        fieldErrors['message'] = 'quoteErrContact';
      } else if (err.field == 'message') {
        fieldErrors['message'] = 'quoteErrMessage';
      } else if (err.field == 'price') {
        fieldErrors['price'] = 'quoteErrPrice';
      } else if (err.field == 'proposal') {
        fieldErrors['proposal'] = 'quoteErrProposal';
      } else {
        switch (err.code) {
          case 'limit_exceeded':
            genError = 'quoteErrLimit';
            break;
          case 'day_taken':
            genError = 'quoteErrDayTaken';
            break;
          case 'not_eligible':
            genError = 'quoteErrNotEligible';
            break;
          case 'conflict':
            genError = 'quoteErrInCheckout';
            break;
          case 'not_accepting_orders':
            genError = 'quoteNotAccepting';
            break;
          case 'deadline_passed':
            genError = 'quoteErrClosed';
            break;
          default:
            genError = err.code;
        }
      }

      state = state.copyWith(
        submitting: false,
        errors: fieldErrors,
        generalError: genError,
      );
      return false;
    }
  }
}

final quoteSheetControllerProvider = NotifierProvider.autoDispose
    .family<QuoteSheetController, QuoteSheetState, String>(
  QuoteSheetController.new,
);
