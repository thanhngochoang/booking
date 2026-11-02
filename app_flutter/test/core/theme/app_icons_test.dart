import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/app_icons.dart';

/// Meanings every mock `<symbol id="i-…">` and every old `Icons.*` use maps to.
const _entries = <String, IconData>{
  'home': AppIcons.home,
  'explore': AppIcons.explore,
  'search': AppIcons.search,
  'add': AppIcons.add,
  'remove': AppIcons.remove,
  'calendar': AppIcons.calendar,
  'calendarCheck': AppIcons.calendarCheck,
  'calendarRepeat': AppIcons.calendarRepeat,
  'profile': AppIcons.profile,
  'chat': AppIcons.chat,
  'notifications': AppIcons.notifications,
  'notificationsActive': AppIcons.notificationsActive,
  'notificationsOff': AppIcons.notificationsOff,
  'settings': AppIcons.settings,
  'favorite': AppIcons.favorite,
  'save': AppIcons.save,
  'share': AppIcons.share,
  'back': AppIcons.back,
  'forward': AppIcons.forward,
  'arrowUp': AppIcons.arrowUp,
  'arrowDown': AppIcons.arrowDown,
  'check': AppIcons.check,
  'checkCircle': AppIcons.checkCircle,
  'taskAlt': AppIcons.taskAlt,
  'doneAll': AppIcons.doneAll,
  'close': AppIcons.close,
  'undo': AppIcons.undo,
  'refresh': AppIcons.refresh,
  'more': AppIcons.more,
  'edit': AppIcons.edit,
  'swap': AppIcons.swap,
  'dragHandle': AppIcons.dragHandle,
  'chevron': AppIcons.chevron,
  'chevronLeft': AppIcons.chevronLeft,
  'expandMore': AppIcons.expandMore,
  'visibility': AppIcons.visibility,
  'visibilityOff': AppIcons.visibilityOff,
  'place': AppIcons.place,
  'nearMe': AppIcons.nearMe,
  'myLocation': AppIcons.myLocation,
  'city': AppIcons.city,
  'camera': AppIcons.camera,
  'addPhoto': AppIcons.addPhoto,
  'image': AppIcons.image,
  'album': AppIcons.album,
  'grid': AppIcons.grid,
  'list': AppIcons.list,
  'description': AppIcons.description,
  'schedule': AppIcons.schedule,
  'mail': AppIcons.mail,
  'alternateEmail': AppIcons.alternateEmail,
  'lock': AppIcons.lock,
  'lockReset': AppIcons.lockReset,
  'phone': AppIcons.phone,
  'payment': AppIcons.payment,
  'wallet': AppIcons.wallet,
  'receipt': AppIcons.receipt,
  'pin': AppIcons.pin,
  'darkMode': AppIcons.darkMode,
  'lightMode': AppIcons.lightMode,
  'autoMode': AppIcons.autoMode,
  'badge': AppIcons.badge,
  'tag': AppIcons.tag,
  'star': AppIcons.star,
  'instant': AppIcons.instant,
  'ticket': AppIcons.ticket,
  'award': AppIcons.award,
  'medal': AppIcons.medal,
  'verified': AppIcons.verified,
  'work': AppIcons.work,
  'store': AppIcons.store,
  'park': AppIcons.park,
  'handshake': AppIcons.handshake,
  'campaign': AppIcons.campaign,
  'people': AppIcons.people,
  'celebration': AppIcons.celebration,
  'trendingUp': AppIcons.trendingUp,
  'autoAwesome': AppIcons.autoAwesome,
  'gradient': AppIcons.gradient,
  'face': AppIcons.face,
  'info': AppIcons.info,
  'error': AppIcons.error,
  'warning': AppIcons.warning,
  'cloudOff': AppIcons.cloudOff,
  'pushPin': AppIcons.pushPin,
  'volumeOff': AppIcons.volumeOff,
  'delete': AppIcons.delete,
  'personRemove': AppIcons.personRemove,
  'personSearch': AppIcons.personSearch,
  'hourglass': AppIcons.hourglass,
  'flag': AppIcons.flag,
};

void main() {
  test('every AppIcons entry is a Material Symbols Rounded glyph', () {
    for (final e in _entries.entries) {
      expect(e.value.fontFamily, 'MaterialSymbolsRounded', reason: e.key);
      expect(e.value.fontPackage, 'material_symbols_icons', reason: e.key);
    }
  });

  test('the catalogue has no duplicate meaning-glyph pair by accident', () {
    // Distinct names may share a glyph on purpose only for state variants,
    // which are expressed with AppIcon(selected:), so every glyph is unique.
    final seen = <int, String>{};
    for (final e in _entries.entries) {
      final prior = seen[e.value.codePoint];
      expect(prior, isNull, reason: '${e.key} duplicates $prior');
      seen[e.value.codePoint] = e.key;
    }
  });

  test('icon sizes are 20 / 24 / 28', () {
    expect(
      [AppIconSize.sm, AppIconSize.md, AppIconSize.lg],
      [20.0, 24.0, 28.0],
    );
  });

  testWidgets('AppIcon is outline by default and fills when selected', (
    tester,
  ) async {
    Future<Icon> pump({required bool selected}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppIcon(
            AppIcons.home,
            selected: selected,
            size: AppIconSize.lg,
            semanticLabel: 'home',
          ),
        ),
      );
      return tester.widget<Icon>(find.byType(Icon));
    }

    final off = await pump(selected: false);
    expect(off.fill, 0);
    expect(off.size, AppIconSize.lg);
    expect(off.semanticLabel, 'home');
    final on = await pump(selected: true);
    expect(on.fill, 1);
    expect(on.icon, AppIcons.home);
  });
}
