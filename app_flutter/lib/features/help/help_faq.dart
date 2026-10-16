import 'package:photobooking/l10n/app_localizations.dart';

class FaqTopic {
  const FaqTopic({
    required this.id,
    required this.label,
    required this.items,
  });

  final String id;
  final String label;
  final List<FaqItem> items;
}

class FaqItem {
  const FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

List<FaqTopic> faqTopics(AppLocalizations l) {
  return [
    FaqTopic(
      id: 'payments',
      label: l.helpTopicPayments,
      items: [
        FaqItem(question: l.helpPayFullQ, answer: l.helpPayFullA),
        FaqItem(question: l.helpPayHeldQ, answer: l.helpPayHeldA),
        FaqItem(question: l.helpPayQrQ, answer: l.helpPayQrA),
      ],
    ),
    FaqTopic(
      id: 'cancel',
      label: l.helpTopicCancel,
      items: [
        FaqItem(question: l.helpCancelRefundQ, answer: l.helpCancelRefundA),
        FaqItem(question: l.helpCancelWhereQ, answer: l.helpCancelWhereA),
        FaqItem(question: l.helpCancelLateQ, answer: l.helpCancelLateA),
      ],
    ),
    FaqTopic(
      id: 'delivery',
      label: l.helpTopicDelivery,
      items: [
        FaqItem(question: l.helpDeliverySampleQ, answer: l.helpDeliverySampleA),
        FaqItem(question: l.helpDeliveryEditQ, answer: l.helpDeliveryEditA),
      ],
    ),
    FaqTopic(
      id: 'disputes',
      label: l.helpTopicDisputes,
      items: [
        FaqItem(question: l.helpDisputeWhenQ, answer: l.helpDisputeWhenA),
        FaqItem(question: l.helpDisputeMoneyQ, answer: l.helpDisputeMoneyA),
        FaqItem(question: l.helpDisputeEvidenceQ, answer: l.helpDisputeEvidenceA),
      ],
    ),
    FaqTopic(
      id: 'contact',
      label: l.helpTopicContact,
      items: [
        FaqItem(question: l.helpContactQ, answer: l.helpContactA),
      ],
    ),
    FaqTopic(
      id: 'reviews',
      label: l.helpTopicReviews,
      items: [
        FaqItem(question: l.helpReviewQ, answer: l.helpReviewA),
      ],
    ),
    FaqTopic(
      id: 'providers',
      label: l.helpTopicProviders,
      items: [
        FaqItem(question: l.helpProviderStartQ, answer: l.helpProviderStartA),
        FaqItem(question: l.helpProviderPaidQ, answer: l.helpProviderPaidA),
      ],
    ),
  ];
}
