import 'package:flutter/material.dart';

/// Every icon the app draws, named once.
///
/// No screen writes `Icons.something` itself: it names an entry here. The family
/// can then be changed in this one file, and two screens cannot pick two
/// different pictures for the same idea. See DESIGN.md, "Iconography".
///
/// The names are those of the pictures for now — `calendarToday`, `chevronRight`
/// — carried over one for one from the Material set they replace, so that
/// introducing this file changed nothing on screen. `Filled` marks the solid
/// form of an icon that also has a regular one: the selected state.
abstract final class AppIcons {
  const AppIcons._();

  static const IconData accountBalance = Icons.account_balance_outlined;
  static const IconData add = Icons.add;
  static const IconData addCircle = Icons.add_circle_outline;
  static const IconData archive = Icons.archive_outlined;
  static const IconData arrowDownward = Icons.arrow_downward_rounded;
  static const IconData arrowUpward = Icons.arrow_upward_rounded;
  static const IconData autorenew = Icons.autorenew_outlined;
  static const IconData autorenewFilled = Icons.autorenew;
  static const IconData backspace = Icons.backspace_outlined;
  static const IconData badge = Icons.badge_outlined;
  static const IconData balance = Icons.balance;
  static const IconData bolt = Icons.bolt_outlined;
  static const IconData brightnessAuto = Icons.brightness_auto_outlined;
  static const IconData calendarMonth = Icons.calendar_month_outlined;
  static const IconData calendarToday = Icons.calendar_today_outlined;
  static const IconData callSplit = Icons.call_split;
  static const IconData cancel = Icons.cancel_outlined;
  static const IconData category = Icons.category_outlined;
  static const IconData check = Icons.check;
  static const IconData checkCircle = Icons.check_circle_outline;
  static const IconData checkCircleFilled = Icons.check_circle;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData circle = Icons.circle_outlined;
  static const IconData close = Icons.close;
  static const IconData cloudOff = Icons.cloud_off_outlined;
  static const IconData darkMode = Icons.dark_mode_outlined;
  static const IconData dataObject = Icons.data_object;
  static const IconData delete = Icons.delete_outline;
  static const IconData deleteForever = Icons.delete_forever_outlined;
  static const IconData description = Icons.description_outlined;
  static const IconData doneAll = Icons.done_all;
  static const IconData edit = Icons.edit_outlined;
  static const IconData error = Icons.error_outline;
  static const IconData event = Icons.event_outlined;
  static const IconData eventBusy = Icons.event_busy_outlined;
  static const IconData eventRepeat = Icons.event_repeat_outlined;
  static const IconData eventRepeatFilled = Icons.event_repeat;
  static const IconData expandMore = Icons.expand_more;
  static const IconData fileDownload = Icons.file_download_outlined;
  static const IconData fileUpload = Icons.file_upload_outlined;
  static const IconData fingerprint = Icons.fingerprint;
  static const IconData folder = Icons.folder_outlined;
  static const IconData folderOff = Icons.folder_off_outlined;
  static const IconData gppMaybe = Icons.gpp_maybe_outlined;
  static const IconData group = Icons.group_outlined;
  static const IconData history = Icons.history;
  static const IconData home = Icons.home_outlined;
  static const IconData homeFilled = Icons.home;
  static const IconData hourglassBottom = Icons.hourglass_bottom_outlined;
  static const IconData info = Icons.info_outline;
  static const IconData insights = Icons.insights_outlined;
  static const IconData inventory2 = Icons.inventory_2_outlined;
  static const IconData iosShare = Icons.ios_share;
  static const IconData label = Icons.label_outline;
  static const IconData lightMode = Icons.light_mode_outlined;
  static const IconData listAlt = Icons.list_alt_outlined;
  static const IconData lock = Icons.lock_outline;
  static const IconData moneyOff = Icons.money_off_outlined;
  static const IconData moreHoriz = Icons.more_horiz_outlined;
  static const IconData moreHorizFilled = Icons.more_horiz;
  static const IconData moreVert = Icons.more_vert;
  static const IconData notes = Icons.notes_outlined;
  static const IconData notesFilled = Icons.notes;
  static const IconData notificationsActive = Icons.notifications_active_outlined;
  static const IconData notificationsNone = Icons.notifications_none;
  static const IconData notificationsOff = Icons.notifications_off_outlined;
  static const IconData password = Icons.password_outlined;
  static const IconData pauseCircle = Icons.pause_circle_outline;
  static const IconData payments = Icons.payments_outlined;
  static const IconData pending = Icons.pending_outlined;
  static const IconData people = Icons.people_outline;
  static const IconData peopleFilled = Icons.people;
  static const IconData person = Icons.person_outline;
  static const IconData personAddAlt = Icons.person_add_alt;
  static const IconData personRemove = Icons.person_remove_outlined;
  static const IconData personSearch = Icons.person_search_outlined;
  static const IconData phone = Icons.phone_outlined;
  static const IconData pictureAsPdf = Icons.picture_as_pdf_outlined;
  static const IconData pin = Icons.pin_outlined;
  static const IconData playCircle = Icons.play_circle_outline;
  static const IconData print = Icons.print_outlined;
  static const IconData privacyTip = Icons.privacy_tip_outlined;
  static const IconData radioButtonUnchecked = Icons.radio_button_unchecked;
  static const IconData receiptLong = Icons.receipt_long_outlined;
  static const IconData receiptLongFilled = Icons.receipt_long;
  static const IconData refresh = Icons.refresh;
  static const IconData restore = Icons.restore_outlined;
  static const IconData saveAlt = Icons.save_alt_outlined;
  static const IconData savings = Icons.savings_outlined;
  static const IconData schedule = Icons.schedule_outlined;
  static const IconData sdCardAlert = Icons.sd_card_alert_outlined;
  static const IconData search = Icons.search_outlined;
  static const IconData searchFilled = Icons.search;
  static const IconData searchOff = Icons.search_off;
  static const IconData settings = Icons.settings_outlined;
  static const IconData shield = Icons.shield_outlined;
  static const IconData skipNext = Icons.skip_next_outlined;
  static const IconData swapVert = Icons.swap_vert;
  static const IconData sync = Icons.sync_outlined;
  static const IconData tableChart = Icons.table_chart_outlined;
  static const IconData taskAlt = Icons.task_alt;
  static const IconData today = Icons.today_outlined;
  static const IconData translate = Icons.translate;
  static const IconData tune = Icons.tune;
  static const IconData unarchive = Icons.unarchive_outlined;
  static const IconData undo = Icons.undo;
  static const IconData verified = Icons.verified_outlined;
  static const IconData verifiedUser = Icons.verified_user_outlined;
  static const IconData visibility = Icons.visibility_outlined;
  static const IconData visibilityOff = Icons.visibility_off_outlined;
  static const IconData warningAmber = Icons.warning_amber_outlined;
  static const IconData wifi = Icons.wifi_outlined;
}
