import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/collab/collaboration.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

final _t0 = DateTime.utc(2026, 10, 21, 3);

RecruitApplication _app({
  String postId = 'p1',
  String studioId = 'cuc',
  String applicantId = 'hoa',
  RecruitKind kind = RecruitKind.collaborator,
  String postTitle = 'Tuyển CTV',
  String applicantName = 'Hòa',
  String? applicantAvatarUrl,
  ApplicationStatus status = ApplicationStatus.applied,
  String message = 'Chào studio',
  List<String> samplePostIds = const ['a'],
  DateTime? createdAt,
  DateTime? expiresAt,
  DateTime? respondedAt,
}) => RecruitApplication(
  id: '${postId}_$applicantId',
  postId: postId,
  studioId: studioId,
  applicantId: applicantId,
  kind: kind,
  postTitle: postTitle,
  applicantName: applicantName,
  applicantAvatarUrl: applicantAvatarUrl,
  status: status,
  message: message,
  samplePostIds: samplePostIds,
  createdAt: createdAt ?? _t0,
  expiresAt: expiresAt ?? _t0.add(const Duration(days: 7)),
  respondedAt: respondedAt,
);

Collaboration _collab({
  String studioName = 'Studio Cúc',
  String? studioAvatarUrl,
  String collaboratorName = 'Dũng',
  String? collaboratorAvatarUrl,
  CollabStatus status = CollabStatus.active,
  int? defaultFee = 600000,
  DateTime? expiresAt,
}) => Collaboration(
  id: 'cuc_dung',
  studioId: 'cuc',
  collaboratorId: 'dung',
  studioName: studioName,
  studioAvatarUrl: studioAvatarUrl,
  collaboratorName: collaboratorName,
  collaboratorAvatarUrl: collaboratorAvatarUrl,
  status: status,
  defaultFee: defaultFee,
  activeAt: _t0,
  expiresAt: expiresAt ?? _t0.add(const Duration(days: 7)),
  endedAt: null,
);

void main() {
  test('RecruitApplication equality covers every field, so a snapshot '
      'changing only the name, avatar, kind, title or dates rebuilds', () {
    final base = _app();
    expect(_app(), base);
    expect(_app().hashCode, base.hashCode);
    for (final changed in [
      _app(applicantName: 'Hòa Nguyễn'),
      _app(applicantAvatarUrl: 'https://x/a.jpg'),
      _app(kind: RecruitKind.member),
      _app(postTitle: 'Tuyển thợ'),
      _app(expiresAt: _t0.add(const Duration(days: 8))),
      _app(createdAt: _t0.subtract(const Duration(hours: 1))),
      _app(studioId: 'other'),
      _app(samplePostIds: const ['b']),
    ]) {
      expect(changed, isNot(base));
    }
  });

  test('Collaboration equality covers every field, avatars and expiry '
      'included', () {
    final base = _collab();
    expect(_collab(), base);
    expect(_collab().hashCode, base.hashCode);
    for (final changed in [
      _collab(studioAvatarUrl: 'https://x/s.jpg'),
      _collab(collaboratorAvatarUrl: 'https://x/c.jpg'),
      _collab(expiresAt: _t0.add(const Duration(days: 1))),
      _collab(studioName: 'Cúc'),
    ]) {
      expect(changed, isNot(base));
    }
  });
}
