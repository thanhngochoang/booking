/// Who offers the service. `artist` is an individual with an approved award
/// (the NAG tier); the server sets it, the user only chooses [ProviderChoice].
enum ProviderType {
  individual('individual'),
  artist('artist'),
  studio('studio');

  const ProviderType(this.code);
  final String code;

  /// Missing or unknown → individual.
  static ProviderType fromCode(Object? raw) {
    for (final t in values) {
      if (t.code == raw) {
        return t;
      }
    }
    return individual;
  }

  /// artist is an individual for choices.
  ProviderChoice get choice =>
      this == studio ? ProviderChoice.studio : ProviderChoice.individual;
}

enum ProviderChoice { individual, studio }
