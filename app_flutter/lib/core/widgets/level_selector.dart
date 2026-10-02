import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Three-step level picker for one genre (S08.02): Cơ bản · Thành thạo ·
/// Chuyên sâu. One tab stop; arrow keys step the level; screen readers get
/// one adjustable node ("Chân dung, mức Chuyên sâu").
class LevelSelector extends StatefulWidget {
  const LevelSelector({
    super.key,
    required this.title,
    required this.level,
    required this.onChanged,
    this.expertDisabled = false,
  });

  final String title;

  /// 1..3; other values are shown as the nearest level.
  final int level;
  final ValueChanged<int> onChanged;

  /// Three genres are already "Chuyên sâu": dim that option. Taps on it are
  /// still reported so the screen can explain the limit.
  final bool expertDisabled;

  @override
  State<LevelSelector> createState() => _LevelSelectorState();
}

class _LevelSelectorState extends State<LevelSelector> {
  final _focus = FocusNode(debugLabel: 'LevelSelector');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  int get _current => widget.level.clamp(1, 3);

  void _select(int v) {
    _focus.requestFocus();
    widget.onChanged(v);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && _current > 1) {
      widget.onChanged(_current - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && _current < 3) {
      widget.onChanged(_current + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String _label(AppLocalizations l, int v) => switch (v) {
    1 => l.skillsLevelBasic,
    2 => l.skillsLevelGood,
    _ => l.skillsLevelExpert,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final disabled = dark
        ? AppColorsDark.foregroundDisabled
        : AppColors.foregroundDisabled;
    final ring = dark ? AppColorsDark.focusRing : AppColors.focusRing;
    final current = _current;
    final radius = BorderRadius.circular(controlRadius);

    return Semantics(
      container: true,
      label: l.skillsLevelSemantics(widget.title, _label(l, current)),
      hint: widget.expertDisabled && current != 3 ? l.skillsExpertFull : null,
      onIncrease: current < 3 ? () => widget.onChanged(current + 1) : null,
      onDecrease: current > 1 ? () => widget.onChanged(current - 1) : null,
      excludeSemantics: true,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: _focus,
          builder: (context, _) => Row(
            children: [
              SizedBox(
                width: 74,
                child: Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: AppText.sm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      width: 2,
                      color: _focus.hasFocus ? ring : Colors.transparent,
                    ),
                  ),
                  child: Material(
                    color: scheme.secondary,
                    borderRadius: radius,
                    child: Row(
                      children: [
                        for (final v in const [1, 2, 3])
                          Expanded(
                            child: InkWell(
                              key: Key('level-option-$v'),
                              canRequestFocus: false,
                              borderRadius: radius,
                              onTap: () => _select(v),
                              child: SizedBox(
                                height: 48,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpace.s1),
                                  child: DecoratedBox(
                                    decoration: v == current
                                        ? BoxDecoration(
                                            color: subtle,
                                            borderRadius: BorderRadius.circular(
                                              controlRadius - AppSpace.s1,
                                            ),
                                            border: Border.all(
                                              color: scheme.primary,
                                            ),
                                          )
                                        : const BoxDecoration(),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpace.s1,
                                          ),
                                          child: Text(
                                            _label(l, v),
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: AppText.xs,
                                              fontWeight: FontWeight.w600,
                                              color: v == current
                                                  ? scheme.primary
                                                  : (v == 3 &&
                                                        widget.expertDisabled)
                                                  ? disabled
                                                  : secondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
