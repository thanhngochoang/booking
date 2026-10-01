/// Why a photographer or post is recommended (spec 3e.1, "giải thích được").
enum ReasonCode {
  skillMatch('skill_match'),
  near('near'),
  freeOnDate('free_on_date'),
  topRated('top_rated'),
  fastReply('fast_reply'),
  newTalent('new_talent');

  const ReasonCode(this.code);
  final String code;

  static ReasonCode? fromCode(String? code) {
    for (final c in values) {
      if (c.code == code) {
        return c;
      }
    }
    return null;
  }
}

class Reason {
  const Reason({required this.code, required this.text});
  final ReasonCode code;

  /// Short Vietnamese sentence, ready to show.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is Reason && other.code == code && other.text == text;

  @override
  int get hashCode => Object.hash(code, text);
}
