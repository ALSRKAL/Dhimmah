import 'package:flutter/widgets.dart';

/// Every icon the app draws, named once.
///
/// No screen writes an icon itself: it names an entry here. The family is
/// chosen in this one file, and two screens cannot pick two different pictures
/// for the same idea. See DESIGN.md, "Iconography".
///
/// The family is **Phosphor**, regular weight, from the `phosphor_flutter`
/// package's own fonts. `Filled` names are the fill weight, and only the
/// selected state uses them.
///
/// Built here from code points rather than taken from the package's own
/// constants, for one reason: the package marks every icon as mirroring in a
/// right-to-left layout. In Arabic that would flip a bell, a wallet, a calendar
/// and the tick on a paid debt. Here only the icons that point mirror — the
/// same seven the Material set mirrored, so nothing changes direction because
/// the family changed. Each line names the Phosphor icon it is, so a code point
/// can be checked against the package.
///
/// The names are still those of the Material pictures they replaced, so this
/// change touched no screen.
abstract final class AppIcons {
  const AppIcons._();

  /// Phosphor bank
  static const IconData accountBalance = IconData(
    0xe0b4,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor plus
  static const IconData add = IconData(
    0xe3d4,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor plusCircle
  static const IconData addCircle = IconData(
    0xe3d6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor archive
  static const IconData archive = IconData(
    0xe00c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowDown
  static const IconData arrowDownward = IconData(
    0xe03e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowUp
  static const IconData arrowUpward = IconData(
    0xe08e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowsClockwise
  static const IconData autorenew = IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowsClockwise
  static const IconData autorenewFilled = IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor backspace · mirrors in RTL
  static const IconData backspace = IconData(
    0xe0ae,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor identificationBadge
  static const IconData badge = IconData(
    0xe6f6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor scales
  static const IconData balance = IconData(
    0xe750,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor lightning
  static const IconData bolt = IconData(
    0xe2de,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor circleHalf
  static const IconData brightnessAuto = IconData(
    0xe18c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor calendar
  static const IconData calendarMonth = IconData(
    0xe108,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor calendarBlank
  static const IconData calendarToday = IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowsSplit · mirrors in RTL
  static const IconData callSplit = IconData(
    0xed3c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor xCircle
  static const IconData cancel = IconData(
    0xe4f8,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor squaresFour
  static const IconData category = IconData(
    0xe464,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor check
  static const IconData check = IconData(
    0xe182,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor checkCircle
  static const IconData checkCircle = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fill checkCircle
  static const IconData checkCircleFilled = IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor caretLeft · mirrors in RTL
  static const IconData chevronLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor caretRight · mirrors in RTL
  static const IconData chevronRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor circle
  static const IconData circle = IconData(
    0xe18a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor x
  static const IconData close = IconData(
    0xe4f6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor cloudSlash
  static const IconData cloudOff = IconData(
    0xe1b6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor moon
  static const IconData darkMode = IconData(
    0xe330,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor bracketsCurly
  static const IconData dataObject = IconData(
    0xe860,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor trash
  static const IconData delete = IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor trash
  static const IconData deleteForever = IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fileText
  static const IconData description = IconData(
    0xe23a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor checks
  static const IconData doneAll = IconData(
    0xe53a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor pencilSimple
  static const IconData edit = IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor warningCircle
  static const IconData error = IconData(
    0xe4e2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor calendarDot
  static const IconData event = IconData(
    0xe7b2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor calendarX
  static const IconData eventBusy = IconData(
    0xe10c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor calendarDots
  static const IconData eventRepeat = IconData(
    0xe7b4,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fill calendarDots
  static const IconData eventRepeatFilled = IconData(
    0xe7b4,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor caretDown
  static const IconData expandMore = IconData(
    0xe136,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor downloadSimple
  static const IconData fileDownload = IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor uploadSimple
  static const IconData fileUpload = IconData(
    0xe4c0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fingerprint
  static const IconData fingerprint = IconData(
    0xe23e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor folder
  static const IconData folder = IconData(
    0xe24a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor folderDashed
  static const IconData folderOff = IconData(
    0xe8f8,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor shieldWarning
  static const IconData gppMaybe = IconData(
    0xe412,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor users
  static const IconData group = IconData(
    0xe4d6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor clockCounterClockwise
  static const IconData history = IconData(
    0xe1a0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor house
  static const IconData home = IconData(
    0xe2c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fill house
  static const IconData homeFilled = IconData(
    0xe2c2,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor hourglassMedium
  static const IconData hourglassBottom = IconData(
    0xe2b8,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor info
  static const IconData info = IconData(
    0xe2ce,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor chartLineUp
  static const IconData insights = IconData(
    0xe156,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor archive
  static const IconData inventory2 = IconData(
    0xe00c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor export
  static const IconData iosShare = IconData(
    0xeaf0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor tag · mirrors in RTL
  static const IconData label = IconData(
    0xe478,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor sun
  static const IconData lightMode = IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor listBullets · mirrors in RTL
  static const IconData listAlt = IconData(
    0xe2f2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor lock
  static const IconData lock = IconData(
    0xe2fa,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor prohibit
  static const IconData moneyOff = IconData(
    0xe3de,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor dotsThreeOutline
  static const IconData moreHoriz = IconData(
    0xe204,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fill dotsThreeOutline
  static const IconData moreHorizFilled = IconData(
    0xe204,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor dotsThreeVertical
  static const IconData moreVert = IconData(
    0xe208,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor notepad
  static const IconData notes = IconData(
    0xe63e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor notepad
  static const IconData notesFilled = IconData(
    0xe63e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor bellRinging
  static const IconData notificationsActive = IconData(
    0xe5e8,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor bell
  static const IconData notificationsNone = IconData(
    0xe0ce,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor bellSlash
  static const IconData notificationsOff = IconData(
    0xe0d4,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor password
  static const IconData password = IconData(
    0xe752,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor pauseCircle
  static const IconData pauseCircle = IconData(
    0xe3a0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor money
  static const IconData payments = IconData(
    0xe588,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor dotsThreeCircle
  static const IconData pending = IconData(
    0xe200,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor users
  static const IconData people = IconData(
    0xe4d6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fill users
  static const IconData peopleFilled = IconData(
    0xe4d6,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor user
  static const IconData person = IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor userPlus
  static const IconData personAddAlt = IconData(
    0xe4d0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor userMinus
  static const IconData personRemove = IconData(
    0xe4ce,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor userFocus
  static const IconData personSearch = IconData(
    0xe6fc,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor phone
  static const IconData phone = IconData(
    0xe3b8,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor filePdf
  static const IconData pictureAsPdf = IconData(
    0xe702,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor numpad
  static const IconData pin = IconData(
    0xe3c8,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor playCircle
  static const IconData playCircle = IconData(
    0xe3d2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor printer
  static const IconData print = IconData(
    0xe3dc,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor shieldCheck
  static const IconData privacyTip = IconData(
    0xe40c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor circle
  static const IconData radioButtonUnchecked = IconData(
    0xe18a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor receipt
  static const IconData receiptLong = IconData(
    0xe3ec,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor fill receipt
  static const IconData receiptLongFilled = IconData(
    0xe3ec,
    fontFamily: 'PhosphorFill',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowClockwise
  static const IconData refresh = IconData(
    0xe036,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor clockCounterClockwise
  static const IconData restore = IconData(
    0xe1a0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor downloadSimple
  static const IconData saveAlt = IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor piggyBank
  static const IconData savings = IconData(
    0xea04,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor clock
  static const IconData schedule = IconData(
    0xe19a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor hardDrives
  static const IconData sdCardAlert = IconData(
    0xe2a0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor magnifyingGlass
  static const IconData search = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor magnifyingGlass
  static const IconData searchFilled = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor magnifyingGlassMinus
  static const IconData searchOff = IconData(
    0xe30e,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor gearSix
  static const IconData settings = IconData(
    0xe272,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor shield
  static const IconData shield = IconData(
    0xe40a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor skipForward
  static const IconData skipNext = IconData(
    0xe5a6,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowsDownUp
  static const IconData swapVert = IconData(
    0xe098,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowsClockwise
  static const IconData sync = IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor table
  static const IconData tableChart = IconData(
    0xe476,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor checkCircle
  static const IconData taskAlt = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor calendarCheck
  static const IconData today = IconData(
    0xe712,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor translate
  static const IconData translate = IconData(
    0xe4a2,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor slidersHorizontal
  static const IconData tune = IconData(
    0xe434,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor boxArrowUp
  static const IconData unarchive = IconData(
    0xee54,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor arrowUUpLeft · mirrors in RTL
  static const IconData undo = IconData(
    0xe08a,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );

  /// Phosphor sealCheck
  static const IconData verified = IconData(
    0xe606,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor shieldCheck
  static const IconData verifiedUser = IconData(
    0xe40c,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor eye
  static const IconData visibility = IconData(
    0xe220,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor eyeSlash
  static const IconData visibilityOff = IconData(
    0xe224,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor warning
  static const IconData warningAmber = IconData(
    0xe4e0,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );

  /// Phosphor wifiHigh
  static const IconData wifi = IconData(
    0xe4ea,
    fontFamily: 'PhosphorRegular',
    fontPackage: 'phosphor_flutter',
  );
}
