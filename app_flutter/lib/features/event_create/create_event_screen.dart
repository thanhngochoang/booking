// lib/features/event_create/create_event_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/event_create/create_event_controller.dart';
import 'package:photobooking/features/event_create/event_draft_store.dart';
import 'package:photobooking/features/event_create/place_field.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The card the customer will see in the list (S11.01), made from the form:
/// the preview of S12.02 is `eventCardDataOf` of this, so it can not drift
/// from the real card.
EventSummary previewSummaryOf(
  EventForm form, {
  required String hostName,
  required bool platform,
  required DateTime now,
}) => EventSummary(
  id: form.eventId ?? 'preview',
  title: form.title.trim(),
  hostName: platform ? '' : hostName,
  hostVerified: !platform,
  hostType: platform ? HostType.platform : HostType.photographer,
  type: form.type ?? EventType.other,
  startsAt: form.startsAt ?? now,
  endsAt: form.endsAt,
  locationName: form.placeName.trim().isEmpty ? null : form.placeName.trim(),
  lat: form.lat,
  lng: form.lng,
  priceVnd: form.priceVnd ?? 0,
  capacity: form.capacity ?? 0,
  registeredCount: 0,
  heldCount: 0,
  status: EventStatus.open,
  createdAt: now,
  coverUrl: form.coverUrl,
);

/// The words for an error code of [EventField].
String eventFieldErrorText(AppLocalizations l, EventField field, String code) {
  if (code == 'day_taken') {
    return l.createEventDayTaken;
  }
  if (code == 'taken') {
    return l.createEventHashtagTaken;
  }
  return switch ((field, code)) {
    (EventField.cover, _) => l.createEventErrCover,
    (EventField.title, 'too_long') => l.createEventErrTitleLong,
    (EventField.title, _) => l.createEventErrTitle,
    (EventField.type, _) => l.createEventErrType,
    (EventField.description, _) => l.createEventErrDescLong,
    (EventField.day, _) => l.createEventErrDay,
    (EventField.start, 'start_soon') => l.createEventErrStartSoon,
    (EventField.start, _) => l.createEventErrStart,
    (EventField.end, 'end_before_start') => l.createEventErrEndBeforeStart,
    (EventField.end, 'same_day') => l.createEventErrSameDay,
    (EventField.end, _) => l.createEventErrEnd,
    (EventField.capacity, _) => l.createEventErrCapacity,
    (EventField.place, 'point') => l.createEventErrPlacePoint,
    (EventField.place, _) => l.createEventErrPlace,
    (EventField.hashtag, _) => l.createEventErrHashtag,
    (EventField.price, 'required') => l.createEventErrPriceRequired,
    (EventField.price, _) => l.createEventErrPrice,
    (EventField.deadline, _) => l.createEventErrDeadline,
  };
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hm(int minute) => '${_two(minute ~/ 60)}:${_two(minute % 60)}';

/// S12.01 and S12.02: create an event in two steps, at `/events/new`
/// (`?draft=<id>` resumes a draft saved on the server).
class CreateEventScreen extends ConsumerWidget {
  const CreateEventScreen({super.key, this.draftId});

  final String? draftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final staffA = ref.watch(staffRoleProvider);
    final profileA = ref.watch(currentProfileProvider);
    final introA = ref.watch(myIntroProvider);
    final authA = ref.watch(authStateProvider);
    final loading = [
      authA,
      staffA,
      profileA,
      introA,
    ].any((a) => a.isLoading && !a.hasValue);
    final role = profileA.value?.role;
    final isStaff = staffA.value != null;
    final onboarded = introA.value?.onboardingComplete ?? false;
    final allowed = isStaff || (role == UserRole.photographer && onboarded);

    Widget gate(Widget body) => ScreenCode(
      ScreenCodes.createEventInfo,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              tooltip: l.back,
              icon: const AppIcon(AppIcons.back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/events'),
            ),
            title: Text(l.createEventTitle),
          ),
          body: body,
        ),
      ),
    );

    if (loading) {
      return gate(
        AsyncView<bool>(
          value: const AsyncLoading(),
          data: (_, _) => const SizedBox.shrink(),
        ),
      );
    }
    if (!allowed) {
      final photographer = role == UserRole.photographer;
      return gate(
        photographer
            ? EmptyState(
                title: l.createEventSetupTitle,
                body: l.createEventSetupBody,
                actionLabel: l.createEventSetupCta,
                onAction: () => context.push('/setup'),
              )
            : EmptyState(title: l.createEventNotAllowed, body: ''),
      );
    }
    final id = draftId;
    if (id == null) {
      return _CreateEventForm(
        key: const ValueKey('new'),
        args: const CreateEventArgs(),
        platform: isStaff,
        hostName: profileA.value?.displayName ?? '',
      );
    }
    final event = ref.watch(eventProvider(id));
    final loaded = event.value;
    if (loaded != null) {
      // The form brings its own bar ("1 / 2", "Lưu nháp?" on back); the gate
      // is only for loading, missing and failed reads.
      if (loaded.summary.status != EventStatus.draft) {
        return EventRouteRedirect('/events/${loaded.id}/manage');
      }
      return _CreateEventForm(
        key: ValueKey('draft-$id'),
        args: CreateEventArgs(
          resumeId: id,
          seed: EventDraft.fromDetail(loaded),
        ),
        platform: loaded.summary.isPlatformHosted,
        hostName: loaded.summary.hostName,
      );
    }
    return gate(
      AsyncView<EventDetail?>(
        value: event,
        onRetry: () => ref.invalidate(eventProvider(id)),
        isEmpty: (e) => e == null,
        empty: (_) => EmptyState(title: l.manageGone, body: ''),
        data: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Replaces the route once built (a published event goes to its manage page).
class EventRouteRedirect extends StatefulWidget {
  const EventRouteRedirect(this.path, {super.key});
  final String path;

  @override
  State<EventRouteRedirect> createState() => _EventRouteRedirectState();
}

class _EventRouteRedirectState extends State<EventRouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.replace(widget.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CreateEventForm extends ConsumerStatefulWidget {
  const _CreateEventForm({
    super.key,
    required this.args,
    required this.platform,
    required this.hostName,
  });

  final CreateEventArgs args;

  /// Staff create platform-hosted events (Decision 1).
  final bool platform;
  final String hostName;

  @override
  ConsumerState<_CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends ConsumerState<_CreateEventForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _price;
  late final TextEditingController _hashtag;
  final _scroll = ScrollController();
  final _summaryFocus = FocusNode(debugLabel: 'create-event-summary');
  final _nodes = {
    for (final f in EventField.values) f: FocusNode(debugLabel: f.name),
  };
  final _keys = {for (final f in EventField.values) f: GlobalKey()};
  bool _leaving = false;

  CreateEventController get _ctl =>
      ref.read(createEventControllerProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    final f = ref.read(createEventControllerProvider(widget.args)).form;
    _title = TextEditingController(text: f.title);
    _description = TextEditingController(text: f.description);
    _capacity = TextEditingController(text: f.capacity?.toString() ?? '');
    _price = TextEditingController(
      text: f.priceVnd == null ? '' : groupVnd(f.priceVnd!),
    );
    _hashtag = TextEditingController(text: f.hashtag ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _capacity, _price, _hashtag]) {
      c.dispose();
    }
    _scroll.dispose();
    _summaryFocus.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _failureText(CreateEventFailure f) {
    final l = context.l10n;
    return switch (f) {
      CreateEventFailure.publish => l.createEventFailed,
      CreateEventFailure.cover => l.createEventCoverFailed,
      _ => l.createEventSaveFailed,
    };
  }

  void _leave() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.canPop() ? context.pop() : context.go('/events');
    });
  }

  Future<void> _onBack() async {
    final s = ref.read(createEventControllerProvider(widget.args));
    if (s.busy) {
      return;
    }
    if (s.step == 2) {
      _ctl.goToStep(1);
      return;
    }
    if (s.form.isBlank && s.pendingCover == null) {
      _leave();
      return;
    }
    final answer = await showAppSheet<bool>(
      context,
      enableDrag: false,
      builder: (sheet) => _SaveDraftSheet(sheet: sheet),
    );
    if (answer == null || !mounted) {
      return;
    }
    if (answer) {
      final ok = await _ctl.saveDraft();
      if (!mounted) {
        return;
      }
      if (!ok) {
        _say(
          _failureText(
            ref.read(createEventControllerProvider(widget.args)).failure,
          ),
        );
        return;
      }
    } else {
      await _ctl.discard();
      if (!mounted) {
        return;
      }
    }
    _leave();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    final ok = await _ctl.next();
    if (!mounted) {
      return;
    }
    if (ok) {
      _scrollTop();
    } else {
      _say(
        _failureText(
          ref.read(createEventControllerProvider(widget.args)).failure,
        ),
      );
    }
  }

  void _scrollTop() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _saveDraft() async {
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final ok = await _ctl.saveDraft();
    if (!mounted) {
      return;
    }
    final s = ref.read(createEventControllerProvider(widget.args));
    if (ok) {
      _say(l.createEventDraftSaved);
    } else if (s.serverErrors.isEmpty) {
      _say(_failureText(s.failure));
    }
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    final id = await _ctl.publish();
    if (!mounted) {
      return;
    }
    if (id != null) {
      _say(l.createEventPublished);
      context.replace('/events/$id/manage');
      return;
    }
    final s = ref.read(createEventControllerProvider(widget.args));
    if (s.summary) {
      // Focus moves to the summary so a screen reader reads it first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollTop();
        _summaryFocus.requestFocus();
      });
    } else if (s.failure != CreateEventFailure.none) {
      _say(_failureText(s.failure));
    }
  }

  /// A summary line: go to the field's step, scroll to it and focus it.
  void _jumpTo(EventField field) {
    if (field.step !=
        ref.read(createEventControllerProvider(widget.args)).step) {
      _ctl.goToStep(field.step);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ctx = _keys[field]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          alignment: 0.1,
        );
      }
      _nodes[field]?.requestFocus();
    });
  }

  DateTime get _today => vnToday(ref.read(clockProvider)());

  Future<void> _pickDay(DateTime? current) async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today)
          ? DateTime(current.year, current.month, current.day)
          : DateTime(today.year, today.month, today.day + 1),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) {
      _ctl.setDay(picked);
    }
  }

  Future<int?> _pickTime(int? current, int fallback) async {
    final initial = current ?? fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _pickDeadline(EventForm form) async {
    final today = _today;
    final last =
        form.day ?? DateTime.utc(today.year + 1, today.month, today.day);
    final first = DateTime(today.year, today.month, today.day);
    var initial = form.deadlineDay ?? form.day ?? today;
    if (initial.isBefore(first)) {
      initial = first;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: first,
      lastDate: DateTime(last.year, last.month, last.day).isBefore(first)
          ? first
          : DateTime(last.year, last.month, last.day),
    );
    if (picked != null && mounted) {
      _ctl.setDeadline(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = createEventControllerProvider(widget.args);
    final s = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    // The server made (or the person edited) the hashtag: show it unless it is
    // being typed.
    ref.listen(provider.select((s) => s.form.hashtag), (_, next) {
      if (!_nodes[EventField.hashtag]!.hasFocus &&
          _hashtag.text != (next ?? '')) {
        _hashtag.text = next ?? '';
      }
    });
    final errors = ctl.shownErrors;
    String? errorOf(EventField f) =>
        errors[f] == null ? null : eventFieldErrorText(l, f, errors[f]!);
    final step = s.step;
    final canPopNow =
        _leaving || (step == 1 && s.form.isBlank && s.pendingCover == null);

    final body = ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        StepProgress(current: step, total: 2, showCount: false),
        const SizedBox(height: AppSpace.s3),
        if (s.failure != CreateEventFailure.none) ...[
          _Banner(_failureText(s.failure)),
          const SizedBox(height: AppSpace.s3),
        ],
        if (step == 1)
          ..._stepOne(context, s, ctl, errorOf)
        else
          ..._stepTwo(context, s, ctl, errors, errorOf),
      ],
    );

    final footer = AppFooterBar(
      child: step == 1
          ? SizedBox(
              height: controlHeight,
              child: AppButton.primary(
                l.createEventContinue,
                key: const Key('create-event-next'),
                loading: s.busy,
                onPressed: s.stepOneReady && !s.busy ? _next : null,
              ),
            )
          : SizedBox(
              height: controlHeight,
              child: Row(
                children: [
                  Expanded(
                    flex: 36,
                    child: AppButton.outline(
                      l.createEventSaveDraft,
                      key: const Key('create-event-save'),
                      onPressed: s.busy ? null : _saveDraft,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    flex: 64,
                    child: AppButton.primary(
                      l.createEventPublish,
                      key: const Key('create-event-publish'),
                      loading: s.busy,
                      onPressed: s.busy ? null : _publish,
                    ),
                  ),
                ],
              ),
            ),
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          key: const Key('create-event-back'),
          tooltip: l.back,
          icon: const AppIcon(AppIcons.back),
          onPressed: _onBack,
        ),
        title: Text(l.createEventTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
            child: Center(
              child: Text(
                l.stepProgressCount(step, 2),
                key: const Key('create-event-count'),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: footer,
    );

    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _onBack();
        }
      },
      child: ScreenCode(
        step == 1
            ? ScreenCodes.createEventInfo
            : ScreenCodes.createEventSchedule,
        child: AuroraBackground(child: scaffold),
      ),
    );
  }

  // ---- step 1 -------------------------------------------------------------

  List<Widget> _stepOne(
    BuildContext context,
    CreateEventState s,
    CreateEventController ctl,
    String? Function(EventField) errorOf,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final busy = s.busy;
    return [
      Semantics(
        header: true,
        child: Text(l.createEventInfo, style: theme.textTheme.titleLarge),
      ),
      const SizedBox(height: AppSpace.s3),
      KeyedSubtree(
        key: _keys[EventField.cover],
        child: _CoverTile(
          pending: s.pendingCover,
          url: s.form.coverUrl,
          focusNode: _nodes[EventField.cover]!,
          enabled: !busy,
          onTap: ctl.pickCover,
        ),
      ),
      if (errorOf(EventField.cover) case final e?) _FieldError(e),
      const SizedBox(height: AppSpace.s3),
      if (widget.platform) ...[_HostRow(), const SizedBox(height: AppSpace.s3)],
      KeyedSubtree(
        key: _keys[EventField.title],
        child: TextField(
          key: const Key('create-event-title'),
          controller: _title,
          focusNode: _nodes[EventField.title],
          enabled: !busy,
          maxLength: eventTitleMax,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: ctl.setTitle,
          decoration: InputDecoration(
            labelText: l.createEventNameRequired,
            errorText: errorOf(EventField.title),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.s3),
      KeyedSubtree(
        key: _keys[EventField.type],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.createEventType, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpace.s2),
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                for (final t in EventType.values)
                  AppChip(
                    key: Key('create-event-type-${t.code}'),
                    label: t.label(l),
                    selected: s.form.type == t,
                    onChanged: busy ? (_) {} : (_) => ctl.setType(t),
                  ),
              ],
            ),
            if (errorOf(EventField.type) case final e?) _FieldError(e),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.s3),
      KeyedSubtree(
        key: _keys[EventField.description],
        child: TextField(
          key: const Key('create-event-description'),
          controller: _description,
          focusNode: _nodes[EventField.description],
          enabled: !busy,
          minLines: 3,
          maxLines: 8,
          maxLength: eventDescriptionMax,
          textCapitalization: TextCapitalization.sentences,
          onChanged: ctl.setDescription,
          decoration: InputDecoration(
            labelText: l.createEventDesc,
            alignLabelWithHint: true,
            errorText: errorOf(EventField.description),
          ),
        ),
      ),
    ];
  }

  // ---- step 2 -------------------------------------------------------------

  List<Widget> _stepTwo(
    BuildContext context,
    CreateEventState s,
    CreateEventController ctl,
    Map<EventField, String> errors,
    String? Function(EventField) errorOf,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final f = s.form;
    final busy = s.busy;
    final vnDay = f.day;
    final stack =
        MediaQuery.textScalerOf(context).scale(AppText.md) > AppText.md * 1.15;

    Widget pair(Widget a, Widget b) => stack
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: AppSpace.s2),
              b,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpace.s2),
              Expanded(child: b),
            ],
          );

    final dayTile = KeyedSubtree(
      key: _keys[EventField.day],
      child: _PickTile(
        key: const Key('create-event-day'),
        label: l.createEventDay,
        value: vnDay == null ? null : formatDay(vnDay),
        placeholder: l.createEventPickDay,
        focusNode: _nodes[EventField.day]!,
        error: errorOf(EventField.day),
        onTap: busy ? null : () => _pickDay(vnDay),
      ),
    );
    final startTile = KeyedSubtree(
      key: _keys[EventField.start],
      child: _PickTile(
        key: const Key('create-event-start'),
        label: l.createEventStart,
        value: f.startMinute == null ? null : _hm(f.startMinute!),
        placeholder: l.createEventPickTime,
        focusNode: _nodes[EventField.start]!,
        error: errorOf(EventField.start),
        onTap: busy
            ? null
            : () async {
                final m = await _pickTime(f.startMinute, 6 * 60);
                if (m != null && mounted) {
                  ctl.setStart(m);
                }
              },
      ),
    );
    final endTile = KeyedSubtree(
      key: _keys[EventField.end],
      child: _PickTile(
        key: const Key('create-event-end'),
        label: l.createEventEnd,
        value: f.endMinute == null ? null : _hm(f.endMinute!),
        placeholder: l.createEventPickTime,
        focusNode: _nodes[EventField.end]!,
        error: errorOf(EventField.end),
        onTap: busy
            ? null
            : () async {
                final m = await _pickTime(
                  f.endMinute,
                  (f.startMinute ?? 6 * 60) + 180,
                );
                if (m != null && mounted) {
                  ctl.setEnd(m);
                }
              },
      ),
    );
    final capacityField = KeyedSubtree(
      key: _keys[EventField.capacity],
      child: TextField(
        key: const Key('create-event-capacity'),
        controller: _capacity,
        focusNode: _nodes[EventField.capacity],
        enabled: !busy,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        onChanged: (v) => ctl.setCapacity(int.tryParse(v)),
        decoration: InputDecoration(
          labelText: l.createEventCapacity,
          suffixText: l.createEventCapacityUnit,
          errorText: errorOf(EventField.capacity),
          errorMaxLines: 2,
        ),
      ),
    );
    final priceField = KeyedSubtree(
      key: _keys[EventField.price],
      child: TextField(
        key: const Key('create-event-price'),
        controller: _price,
        focusNode: _nodes[EventField.price],
        enabled: !busy,
        keyboardType: TextInputType.number,
        inputFormatters: const [VndInputFormatter()],
        onChanged: (v) => ctl.setPrice(parseVnd(v)),
        decoration: InputDecoration(
          labelText: l.createEventPrice,
          errorText: errorOf(EventField.price),
          errorMaxLines: 3,
        ),
      ),
    );
    final deadlineTile = KeyedSubtree(
      key: _keys[EventField.deadline],
      child: _PickTile(
        key: const Key('create-event-deadline'),
        label: l.createEventDeadline,
        value: f.deadlineDay == null ? null : formatDayMonth(f.deadlineDay!),
        placeholder: l.createEventDeadlineAuto,
        focusNode: _nodes[EventField.deadline]!,
        error: errorOf(EventField.deadline),
        onClear: f.deadlineDay == null || busy
            ? null
            : () => ctl.setDeadline(null),
        clearTooltip: l.createEventDeadlineReset,
        onTap: busy ? null : () => _pickDeadline(f),
      ),
    );

    final showPreview =
        f.title.trim().isNotEmpty && f.capacity != null && f.day != null;
    final allErrors = errors;
    return [
      if (s.summary && allErrors.isNotEmpty) ...[
        _ErrorSummary(
          focusNode: _summaryFocus,
          title: l.createEventErrorSummary(allErrors.length),
          lines: [
            for (final e in allErrors.entries)
              (e.key, eventFieldErrorText(l, e.key, e.value)),
          ],
          onJump: _jumpTo,
        ),
        const SizedBox(height: AppSpace.s3),
      ],
      Semantics(
        header: true,
        child: Text(l.createEventSchedule, style: theme.textTheme.titleLarge),
      ),
      const SizedBox(height: AppSpace.s3),
      pair(dayTile, startTile),
      const SizedBox(height: AppSpace.s2),
      pair(endTile, capacityField),
      const SizedBox(height: AppSpace.s3),
      KeyedSubtree(
        key: _keys[EventField.place],
        child: PlaceField(
          name: f.placeName,
          meetingPoint: f.meetingPoint,
          areaId: f.areaId,
          hasDevicePoint: f.lat != null && f.areaId == null,
          error: errorOf(EventField.place),
          nameFocus: _nodes[EventField.place],
          enabled: !busy,
          onText: ({name, meetingPoint}) =>
              ctl.setPlaceText(name: name, meetingPoint: meetingPoint),
          onArea: (a) => ctl.chooseArea(a.id, lat: a.lat, lng: a.lng),
          onDevicePoint: (lat, lng) => ctl.useDevicePoint(lat: lat, lng: lng),
        ),
      ),
      const SizedBox(height: AppSpace.s3),
      KeyedSubtree(
        key: _keys[EventField.hashtag],
        child: TextField(
          key: const Key('create-event-hashtag'),
          controller: _hashtag,
          focusNode: _nodes[EventField.hashtag],
          enabled: !busy,
          maxLength: 40,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9#]')),
          ],
          onChanged: ctl.setHashtag,
          decoration: InputDecoration(
            labelText: l.createEventHashtag,
            prefixText: '#',
            counterText: '',
            errorText: errorOf(EventField.hashtag),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.s3),
      pair(priceField, deadlineTile),
      const SizedBox(height: AppSpace.s2),
      Text(
        l.createEventFreeHint,
        key: const Key('create-event-free-hint'),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpace.s1),
      Text(l.createEventEscrowHint, style: theme.textTheme.bodySmall),
      if (showPreview) ...[
        const SizedBox(height: AppSpace.s4),
        Text(l.createEventPreview, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpace.s2),
        EventCard(
          key: const Key('create-event-preview'),
          data: eventCardDataOf(
            previewSummaryOf(
              f,
              hostName: widget.hostName,
              platform: widget.platform,
              now: ref.read(clockProvider)(),
            ),
            l,
          ),
        ),
      ],
    ];
  }
}

/// "Lưu nháp?" with "Lưu" (true) and "Bỏ" (false); closing it any other way
/// stays on the form (null).
class _SaveDraftSheet extends StatelessWidget {
  const _SaveDraftSheet({required this.sheet});
  final BuildContext sheet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.createEventSaveDraftAsk,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.s4),
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  l.createEventDraftDiscard,
                  key: const Key('create-event-discard'),
                  onPressed: () => Navigator.of(sheet).pop(false),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: AppButton.primary(
                  l.createEventDraftKeep,
                  key: const Key('create-event-keep'),
                  onPressed: () => Navigator.of(sheet).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mock `.field .e`: a short error under a field.
class _FieldError extends StatelessWidget {
  const _FieldError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const Key('create-event-banner'),
        decoration: BoxDecoration(
          color: error.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Text(text, style: TextStyle(color: error)),
        ),
      ),
    );
  }
}

/// The list of what to fix after a failed publish; it takes focus, and each
/// line jumps to its field.
class _ErrorSummary extends StatelessWidget {
  const _ErrorSummary({
    required this.focusNode,
    required this.title,
    required this.lines,
    required this.onJump,
  });

  final FocusNode focusNode;
  final String title;
  final List<(EventField, String)> lines;
  final ValueChanged<EventField> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return Focus(
      focusNode: focusNode,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: title,
        child: DecoratedBox(
          key: const Key('create-event-summary'),
          decoration: BoxDecoration(
            color: error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: error),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: error),
                ),
                for (final (field, text) in lines)
                  InkWell(
                    key: Key('create-event-summary-${field.name}'),
                    onTap: () => onJump(field),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Staff only: "Tổ chức bởi" with the one choice, "Nền tảng" (Decision 24).
class _HostRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      key: const Key('create-event-host'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.createEventHost, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpace.s2),
        AppChip(
          label: l.createEventHostPlatform,
          selected: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: AppSpace.s1),
        Text(l.createEventHostLater, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// The 16:10 cover tile of the mock: a camera and "Thêm ảnh bìa 16:10", or the
/// chosen photo.
class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.pending,
    required this.url,
    required this.focusNode,
    required this.enabled,
    required this.onTap,
  });

  final PickedImage? pending;
  final String? url;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final radius = BorderRadius.circular(AppRadius.control);
    final has = pending != null || (url != null && url!.isNotEmpty);
    final Widget content;
    if (pending != null) {
      content = Image.file(
        File(pending!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(color: scheme.secondary),
      );
    } else if (url != null && url!.isNotEmpty) {
      content = NetworkPhoto(url: url!, fit: BoxFit.cover);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(AppIcons.camera, color: muted),
          const SizedBox(height: AppSpace.s1),
          Text(
            l.createEventCover,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: has ? l.createEventCoverChange : l.createEventCover,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Material(
          color: scheme.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: scheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('create-event-cover'),
            focusNode: focusNode,
            onTap: enabled ? onTap : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                content,
                if (has)
                  Positioned(
                    right: AppSpace.s2,
                    bottom: AppSpace.s2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.overlay,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s3,
                          vertical: AppSpace.s1,
                        ),
                        child: Text(
                          l.createEventCoverChange,
                          style: const TextStyle(
                            color: AppColors.foregroundInverse,
                            fontSize: AppText.sm,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tap-to-choose field in the mock's `.field` look: small label over the
/// value, an error under it.
class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.focusNode,
    required this.onTap,
    this.error,
    this.onClear,
    this.clearTooltip,
  });

  final String label;
  final String? value;
  final String placeholder;
  final FocusNode focusNode;
  final String? error;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final radius = BorderRadius.circular(controlRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: error == null
          ? BorderSide.none
          : BorderSide(color: scheme.error, width: 2),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: onTap != null,
          label: '$label, ${value ?? placeholder}',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: scheme.secondary,
            shape: shape,
            child: InkWell(
              focusNode: focusNode,
              customBorder: shape,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpace.s12 + AppSpace.s2,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: theme.textTheme.labelSmall),
                            Text(
                              value ?? placeholder,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: value == null ? muted : null,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onClear != null)
                        IconButton(
                          tooltip: clearTooltip,
                          icon: AppIcon(AppIcons.close, color: muted),
                          onPressed: onClear,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null) _FieldError(error!),
      ],
    );
  }
}
