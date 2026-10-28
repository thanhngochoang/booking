import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/album/my_albums_controller.dart';
import 'package:photobooking/features/recruit/collab_terms_card.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/features/recruit/recruit_text.dart';

/// Message length the server accepts (`APPLICATION_MESSAGE_MAX`), in code
/// points ([recruitTextLength]).
const kRecruitMessageMax = 400;

/// Own posts an application may show (`APPLICATION_SAMPLES_MAX`).
const kRecruitSamplesMax = 3;

/// S27.03 "Ứng tuyển" for [post]: a message (≤ 400), up to three own posts,
/// the collaboration terms (a collaborator post; "Gửi ứng tuyển" stays off
/// until agreed) or the member note, and the no-contact line. On success
/// the sheet closes and "Đã gửi ứng tuyển" shows; true then.
Future<bool> showRecruitApplySheet(
  BuildContext context,
  RecruitPost post,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = context.l10n.recruitSentToast;
  final ok = await showAppSheet<bool>(
    context,
    builder: (_) =>
        ScreenCode(ScreenCodes.recruitApply, child: _ApplySheet(post: post)),
  );
  if (ok == true) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(sent)));
  }
  return ok == true;
}

class _ApplySheet extends ConsumerStatefulWidget {
  const _ApplySheet({required this.post});

  final RecruitPost post;

  @override
  ConsumerState<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<_ApplySheet> {
  final _message = TextEditingController();
  final _samples = <String>[];
  bool _agreed = false;
  bool _sending = false;

  /// "Bỏ số điện thoại…" under the message (`message.contact`).
  String? _messageError;

  /// Any other refusal, above the button.
  String? _error;

  bool get _collaborator => widget.post.kind == RecruitKind.collaborator;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _toggle(String postId) => setState(() {
    if (!_samples.remove(postId) && _samples.length < kRecruitSamplesMax) {
      _samples.add(postId);
    }
  });

  Future<void> _send() async {
    final l = context.l10n;
    setState(() {
      _sending = true;
      _messageError = null;
      _error = null;
    });
    try {
      await ref
          .read(recruitRepositoryProvider)
          .apply(
            widget.post.id,
            message: _message.text.trim(),
            samplePostIds: List.of(_samples),
            acceptTerms: _collaborator && _agreed,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final err = recruitErrorOf(e);
      setState(() {
        _sending = false;
        if (err.isContact) {
          _messageError = l.recruitContactError;
        } else if (err.field == 'message') {
          _messageError = l.recruitMessageInvalid;
        } else if (err.field == 'samplePostIds') {
          _error = l.recruitSamplesInvalid;
        } else {
          _error = recruitApplyErrorText(e, l);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final post = widget.post;
    final canSend = !_sending && (!_collaborator || _agreed);
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.recruitApplyTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('recruit-apply-close'),
                  tooltip: l.recruitSheetClose,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _sending
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            Text(
              l.recruitApplySubtitle(post.title, post.studioName),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpace.s3),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('recruit-message'),
                      controller: _message,
                      enabled: !_sending,
                      minLines: 2,
                      maxLines: 5,
                      inputFormatters: const [
                        RecruitTextLimit(kRecruitMessageMax),
                      ],
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) {
                        if (_messageError != null) {
                          setState(() => _messageError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: l.recruitMessageLabel,
                        hintText: l.recruitMessageHint,
                        errorText: _messageError,
                        errorMaxLines: 2,
                        counter: RecruitTextCounter(
                          controller: _message,
                          max: kRecruitMessageMax,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.recruitSamplesLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                l.recruitSamplesHint,
                                style: TextStyle(
                                  fontSize: AppText.xs2,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          l.recruitSamplesCount(_samples.length),
                          key: const Key('recruit-samples-count'),
                          style: TextStyle(
                            fontSize: AppText.sm,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s2),
                    _Samples(
                      selected: _samples,
                      onToggle: _sending ? (_) {} : _toggle,
                    ),
                    const SizedBox(height: AppSpace.s3),
                    if (_collaborator)
                      CollabTermsCard(
                        agreed: _agreed,
                        onChanged: _sending
                            ? null
                            : (v) => setState(() => _agreed = v),
                      )
                    else
                      RecruitNote(
                        l.recruitMemberNote(post.studioName),
                        icon: AppIcons.info,
                      ),
                    const SizedBox(height: AppSpace.s2),
                    RecruitNote(l.recruitNoContactNote, icon: AppIcons.info),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.s2),
              Text(
                _error!,
                key: const Key('recruit-apply-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              l.recruitSend,
              key: const Key('recruit-send'),
              loading: _sending,
              onPressed: canSend ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The applicant's own portfolio posts, five small tiles per row (mock
/// S27.03), at most three picked.
class _Samples extends ConsumerWidget {
  const _Samples({required this.selected, required this.onToggle});

  final List<String> selected;
  final ValueChanged<String> onToggle;

  static const _perRow = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final posts = ref.watch(myPostsProvider(MyPostsFilter.all));
    return AsyncView<MyPostsState>(
      value: posts,
      loaderSize: LoaderSize.inline,
      onRetry: () => ref.invalidate(myPostsProvider(MyPostsFilter.all)),
      skeleton: (_) => Row(
        children: [
          for (var c = 0; c < _perRow; c++) ...[
            if (c > 0) const SizedBox(width: AppSpace.s1),
            Expanded(child: AppSkeleton.box(height: AppSpace.s12)),
          ],
        ],
      ),
      isEmpty: (s) => s.posts.isEmpty,
      empty: (_) => RecruitNote(l.recruitSamplesEmpty, icon: AppIcons.image),
      data: (context, s) => PostPickerGrid(
        crossAxisCount: _perRow,
        maxSelected: kRecruitSamplesMax,
        selected: selected,
        onToggle: onToggle,
        items: [
          for (final p in s.posts)
            PostPickItem(postId: p.id, thumbUrl: p.cover.url, label: p.caption),
        ],
      ),
    );
  }
}
