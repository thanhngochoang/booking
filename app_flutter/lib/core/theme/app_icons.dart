import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Icon catalogue on Material Symbols Rounded (weight 400, optical size 24).
///
/// Entries name the meaning, not the glyph; the table in
/// `docs/superpowers/specs/components/shared-components.md` ("Icons") is the
/// single list shared with the UI mock. Features use these entries only; the
/// outline glyph is the default and [AppIcon] fills it when selected.
abstract final class AppIcons {
  // Navigation and tabs.
  static const IconData home = Symbols.home_rounded;
  static const IconData explore = Symbols.explore_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData add = Symbols.add_rounded;
  static const IconData remove = Symbols.remove_rounded;
  static const IconData calendar = Symbols.calendar_today_rounded;
  static const IconData calendarCheck = Symbols.event_available_rounded;
  static const IconData calendarRepeat = Symbols.event_repeat_rounded;
  static const IconData profile = Symbols.person_rounded;
  static const IconData chat = Symbols.chat_bubble_rounded;
  static const IconData notifications = Symbols.notifications_rounded;
  static const IconData notificationsActive =
      Symbols.notifications_active_rounded;
  static const IconData notificationsOff = Symbols.notifications_off_rounded;
  static const IconData settings = Symbols.settings_rounded;

  // Actions.
  static const IconData favorite = Symbols.favorite_rounded;
  static const IconData save = Symbols.bookmark_rounded;
  static const IconData share = Symbols.ios_share_rounded;
  static const IconData back = Symbols.arrow_back_rounded;
  static const IconData forward = Symbols.arrow_forward_rounded;
  static const IconData arrowUp = Symbols.arrow_upward_rounded;
  static const IconData arrowDown = Symbols.arrow_downward_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData checkCircle = Symbols.check_circle_rounded;
  static const IconData doneAll = Symbols.done_all_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData undo = Symbols.undo_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData more = Symbols.more_horiz_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData swap = Symbols.swap_horiz_rounded;
  static const IconData dragHandle = Symbols.drag_handle_rounded;
  static const IconData chevron = Symbols.chevron_right_rounded;
  static const IconData chevronLeft = Symbols.chevron_left_rounded;
  static const IconData expandMore = Symbols.expand_more_rounded;
  static const IconData visibility = Symbols.visibility_rounded;
  static const IconData visibilityOff = Symbols.visibility_off_rounded;

  // Places.
  static const IconData place = Symbols.location_on_rounded;
  static const IconData nearMe = Symbols.near_me_rounded;
  static const IconData myLocation = Symbols.my_location_rounded;
  static const IconData city = Symbols.location_city_rounded;

  // Content.
  static const IconData camera = Symbols.photo_camera_rounded;
  static const IconData addPhoto = Symbols.add_a_photo_rounded;
  static const IconData image = Symbols.image_rounded;
  static const IconData album = Symbols.photo_library_rounded;
  static const IconData grid = Symbols.grid_view_rounded;
  static const IconData list = Symbols.format_list_bulleted_rounded;
  static const IconData description = Symbols.description_rounded;
  static const IconData schedule = Symbols.schedule_rounded;

  // Account and contact.
  static const IconData mail = Symbols.mail_rounded;
  static const IconData alternateEmail = Symbols.alternate_email_rounded;
  static const IconData lock = Symbols.lock_rounded;
  static const IconData lockReset = Symbols.lock_reset_rounded;
  static const IconData phone = Symbols.call_rounded;
  static const IconData payment = Symbols.credit_card_rounded;
  static const IconData wallet = Symbols.account_balance_wallet_rounded;
  static const IconData qrCode = Symbols.qr_code_2_rounded;
  static const IconData receipt = Symbols.receipt_long_rounded;
  static const IconData pin = Symbols.pin_rounded;
  static const IconData darkMode = Symbols.dark_mode_rounded;
  static const IconData lightMode = Symbols.light_mode_rounded;
  static const IconData autoMode = Symbols.brightness_auto_rounded;
  static const IconData badge = Symbols.badge_rounded;
  static const IconData tag = Symbols.sell_rounded;

  // Marks, status and brand-neutral glyphs.
  static const IconData star = Symbols.star_rounded;
  static const IconData instant = Symbols.bolt_rounded;
  static const IconData ticket = Symbols.confirmation_number_rounded;
  static const IconData award = Symbols.workspace_premium_rounded;
  static const IconData medal = Symbols.military_tech_rounded;
  static const IconData verified = Symbols.verified_rounded;
  static const IconData work = Symbols.work_rounded;
  static const IconData store = Symbols.storefront_rounded;
  static const IconData verifiedUser = Symbols.verified_user_rounded;
  static const IconData businessVerify = Symbols.domain_verification_rounded;
  static const IconData people = Symbols.group_rounded;
  static const IconData celebration = Symbols.celebration_rounded;
  static const IconData trendingUp = Symbols.trending_up_rounded;
  static const IconData autoAwesome = Symbols.auto_awesome_rounded;
  static const IconData gradient = Symbols.gradient_rounded;
  static const IconData face = Symbols.face_retouching_natural_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData error = Symbols.error_rounded;
  static const IconData warning = Symbols.warning_rounded;
  static const IconData cloudOff = Symbols.cloud_off_rounded;
  static const IconData pushPin = Symbols.push_pin_rounded;
  static const IconData volumeOff = Symbols.volume_off_rounded;
  static const IconData delete = Symbols.delete_rounded;
  static const IconData personRemove = Symbols.person_remove_rounded;
  static const IconData flag = Symbols.flag_rounded;
  static const IconData help = Symbols.help_rounded;
  static const IconData supportAgent = Symbols.support_agent_rounded;
}

/// Icon sizes (logical pixels).
abstract final class AppIconSize {
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 28;
}

/// Material Symbols icon: outline by default, filled (FILL 1) when [selected]
/// (active tab, saved or liked, selected option).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.selected = false,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final bool selected;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    fill: selected ? 1 : 0,
    weight: 400,
    opticalSize: 24,
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}
