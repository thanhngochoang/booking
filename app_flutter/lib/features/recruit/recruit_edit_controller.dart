import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_text.dart';
import 'package:photobooking/features/recruit/studio_recruit_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Server limits of a post (`recruit.ts`): title 8–80 code points,
/// requirements ≤ 600, 1–4 specialties, 1–5 areas, a per-shoot fee of
/// 1.000–100.000.000₫ in steps of 1.000.
const kRecruitTitleMin = 8;
const kRecruitTitleMax = 80;
const kRecruitRequirementsMax = 600;
const kRecruitSpecialtiesMax = 4;
const kRecruitAreasMax = 5;
const kRecruitFeeMin = 1000;
const kRecruitFeeMax = 100000000;
const kRecruitFeeStep = 1000;

/// The S27.04 fields an error line sits under.
enum RecruitField { title, specialties, areas, fee, requirements }

/// The S27.04 form: the choices, the three text fields, the line under each
/// field, the refusal above the button, and the submit (create, or update
/// of [postId] where the kind stays as it was, Decision 22).
class RecruitEditController extends ChangeNotifier {
  RecruitEditController({this.postId, RecruitPost? initial})
    : kind = initial?.kind ?? RecruitKind.collaborator,
      specialties = [...?initial?.specialties],
      areas = [...?initial?.areas],
      frequency = initial?.frequency ?? RecruitFrequency.occasional,
      perShoot = initial == null || initial.fee is PerShootFee,
      title = TextEditingController(text: initial?.title ?? ''),
      amount = TextEditingController(
        text: switch (initial?.fee) {
          PerShootFee(:final amount) => groupVnd(amount),
          _ => '',
        },
      ),
      requirements = TextEditingController(text: initial?.requirements ?? '');

  /// Null when creating.
  final String? postId;

  bool get editing => postId != null;

  RecruitKind kind;

  /// `kSpecialties` / `builtInAreas` ids in the order they were picked.
  final List<String> specialties;
  final List<String> areas;
  RecruitFrequency frequency;

  /// "Theo buổi" (with an amount) or "Thoả thuận".
  bool perShoot;

  final TextEditingController title;
  final TextEditingController amount;
  final TextEditingController requirements;

  /// The line under each field.
  final errors = <RecruitField, String>{};

  /// A refusal that belongs to no field, shown above the button.
  String? formError;

  bool sending = false;

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    requirements.dispose();
    super.dispose();
  }

  void _changed([RecruitField? field]) {
    if (field != null) errors.remove(field);
    formError = null;
    notifyListeners();
  }

  /// Kind is fixed once the post exists.
  void setKind(RecruitKind k) {
    if (editing || k == kind) return;
    kind = k;
    _changed();
  }

  bool canPickSpecialty(String id) =>
      specialties.contains(id) || specialties.length < kRecruitSpecialtiesMax;

  bool canPickArea(String id) =>
      areas.contains(id) || areas.length < kRecruitAreasMax;

  void toggleSpecialty(String id) {
    if (!specialties.remove(id)) {
      if (!canPickSpecialty(id)) return;
      specialties.add(id);
    }
    _changed(RecruitField.specialties);
  }

  void toggleArea(String id) {
    if (!areas.remove(id)) {
      if (!canPickArea(id)) return;
      areas.add(id);
    }
    _changed(RecruitField.areas);
  }

  void setFrequency(RecruitFrequency f) {
    frequency = f;
    _changed();
  }

  void setPerShoot(bool v) {
    perShoot = v;
    _changed(RecruitField.fee);
  }

  /// A text field was edited: its line goes away.
  void edited(RecruitField field) => _changed(field);

  int? get _fee {
    final v = parseVnd(amount.text);
    if (v == null ||
        v < kRecruitFeeMin ||
        v > kRecruitFeeMax ||
        v % kRecruitFeeStep != 0) {
      return null;
    }
    return v;
  }

  /// Puts a line under every invalid field; true when there is none.
  bool validate(AppLocalizations l) {
    errors.clear();
    formError = null;
    final t = recruitTextLength(title.text.trim());
    if (t < kRecruitTitleMin || t > kRecruitTitleMax) {
      errors[RecruitField.title] = l.recruitTitleError;
    }
    if (specialties.isEmpty) {
      errors[RecruitField.specialties] = l.recruitSpecialtiesError;
    }
    if (areas.isEmpty) errors[RecruitField.areas] = l.recruitAreasError;
    if (perShoot && _fee == null) errors[RecruitField.fee] = l.recruitFeeError;
    if (recruitTextLength(requirements.text.trim()) > kRecruitRequirementsMax) {
      errors[RecruitField.requirements] = l.recruitRequirementsError;
    }
    notifyListeners();
    return errors.isEmpty;
  }

  /// The callable's draft; call after [validate].
  RecruitDraft draft() => RecruitDraft(
    kind: kind,
    title: title.text.trim(),
    specialties: List.unmodifiable(specialties),
    areas: List.unmodifiable(areas),
    frequency: frequency,
    fee: perShoot ? PerShootFee(_fee!) : const NegotiableFee(),
    requirements: requirements.text.trim(),
  );

  /// Validates and sends; true once the server took it. A refusal goes under
  /// its field (`details.field`) or above the button.
  Future<bool> submit(
    RecruitRepository repo,
    AppLocalizations l, {
    DateTime? blockedUntil,
  }) async {
    if (sending || !validate(l)) return false;
    sending = true;
    notifyListeners();
    try {
      final d = draft();
      final id = postId;
      if (id == null) {
        await repo.create(d);
      } else {
        await repo.update(id, d);
      }
      return true;
    } catch (e) {
      final err = recruitErrorOf(e);
      final field = recruitFieldOf(err.field);
      if (field != null) {
        errors[field] = err.isContact
            ? l.recruitContactError
            : _fieldError(field, l);
      } else {
        formError = recruitPostErrorText(err, l, blockedUntil: blockedUntil);
      }
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  String _fieldError(RecruitField f, AppLocalizations l) => switch (f) {
    RecruitField.title => l.recruitTitleError,
    RecruitField.specialties => l.recruitSpecialtiesError,
    RecruitField.areas => l.recruitAreasError,
    RecruitField.fee => l.recruitFeeError,
    RecruitField.requirements => l.recruitRequirementsError,
  };
}

/// The S27.04 field of a server `details.field` (`title`, `title.contact`,
/// `feeHint`, …); null for none.
RecruitField? recruitFieldOf(String? serverField) =>
    switch (serverField?.split('.').first) {
      'title' => RecruitField.title,
      'specialties' => RecruitField.specialties,
      'areas' => RecruitField.areas,
      'feeHint' => RecruitField.fee,
      'requirements' => RecruitField.requirements,
      _ => null,
    };

/// What to say when creating or saving a post is refused for no field.
String recruitPostErrorText(
  RecruitError e,
  AppLocalizations l, {
  DateTime? blockedUntil,
}) => switch (e.code) {
  RecruitErrorCode.limitExceeded => l.recruitErrorPostLimit,
  RecruitErrorCode.rateLimited => l.recruitErrorRateLimited,
  RecruitErrorCode.recruitBlocked when blockedUntil != null => l.recruitBlocked(
    recruitBlockedDate(blockedUntil),
  ),
  RecruitErrorCode.deadlinePassed => l.recruitErrorClosed,
  RecruitErrorCode.notAcceptingOrders => l.recruitVerifyToPostNote,
  RecruitErrorCode.network => l.authErrorNetwork,
  _ => l.recruitErrorGeneric,
};
