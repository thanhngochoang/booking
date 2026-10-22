// S13.01: the Chụp ngay form, kept across the S04.05 phone detour.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// "Tên điểm hẹn" is required and at most this long (plan Decision 3).
const kInstantMeetPointMax = 80;

/// "Ghi chú cho nhiếp ảnh gia" (mock counter).
const kInstantNoteMax = 140;

/// What the customer chose on S13.01. [packageCode] null = the default
/// package of the price list ([defaultInstantPackage]).
class InstantDraft {
  const InstantDraft({
    this.packageCode,
    this.genre = InstantGenre.portrait,
    this.meetPointName = '',
    this.note = '',
  });

  final String? packageCode;
  final InstantGenre genre;
  final String meetPointName;
  final String note;

  /// The chosen package of [packages], or the default one when none was
  /// chosen or the price list no longer has it; null for an empty list.
  InstantPackage? packageOf(List<InstantPackage> packages) {
    for (final p in packages) {
      if (p.code == packageCode) return p;
    }
    return defaultInstantPackage(packages);
  }

  InstantDraft copyWith({
    String? packageCode,
    InstantGenre? genre,
    String? meetPointName,
    String? note,
  }) => InstantDraft(
    packageCode: packageCode ?? this.packageCode,
    genre: genre ?? this.genre,
    meetPointName: meetPointName ?? this.meetPointName,
    note: note ?? this.note,
  );
}

/// The 1-hour package (mock), else the middle one of the list.
InstantPackage? defaultInstantPackage(List<InstantPackage> packages) {
  if (packages.isEmpty) return null;
  for (final p in packages) {
    if (p.durationMin == 60) return p;
  }
  return packages[packages.length ~/ 2];
}

class InstantDraftNotifier extends Notifier<InstantDraft> {
  /// Signing out or in as someone else empties the form (the first uid
  /// arriving while auth loads does not).
  @override
  InstantDraft build() {
    ref.listen(authStateProvider.select((a) => a.value?.uid), (prev, next) {
      if (prev != null && prev != next) state = const InstantDraft();
    });
    return const InstantDraft();
  }

  void setPackage(String code) => state = state.copyWith(packageCode: code);

  void setGenre(InstantGenre genre) => state = state.copyWith(genre: genre);

  void setMeetPointName(String name) =>
      state = state.copyWith(meetPointName: name);

  void setNote(String note) => state = state.copyWith(note: note);

  /// After a request is created: the next one starts fresh.
  void reset() => state = const InstantDraft();
}

/// Keep-alive: S13.01 is closed while the customer adds a phone number
/// (S04.05) and comes back with everything still filled in. Signing in as
/// someone else empties it.
final instantDraftProvider =
    NotifierProvider<InstantDraftNotifier, InstantDraft>(
      InstantDraftNotifier.new,
    );
