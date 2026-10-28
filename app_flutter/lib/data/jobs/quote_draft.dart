// lib/data/jobs/quote_draft.dart
//
// QuoteDraft for submitting quotes (S16.03).
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/jobs/quote.dart';

@immutable
class QuoteDraft {
  const QuoteDraft({
    required this.jobId,
    required this.price,
    this.editedCount = 0,
    this.deliveryDays = 7,
    this.revisions = 1,
    required this.message,
    this.albumId,
    this.basedOnServiceId,
    this.proposal,
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

  Map<String, dynamic> toPayload() => {
    'jobId': jobId,
    'price': price,
    'editedCount': editedCount,
    'deliveryDays': deliveryDays,
    'revisions': revisions,
    'message': message,
    if (albumId != null) 'albumId': albumId,
    if (basedOnServiceId != null) 'basedOnServiceId': basedOnServiceId,
    if (proposal != null) 'proposal': {
      'day': proposal!.day,
      'start': proposal!.start,
    },
  };
}
