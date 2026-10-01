// lib/core/screen_codes.dart
/// One code per screen, `S01`..`S55`. The single source in Dart; the table in
/// `docs/superpowers/specs/2026-10-01-remaining-screens.md` (section 2) and the
/// mock `docs/design/ui-mock.html` use the same codes.
///
/// Never renumber. A new screen takes the next number and is added to the spec
/// table first (a test compares the two).
abstract final class ScreenCodes {
  static const home = 'S01';
  static const photoDetail = 'S02';
  static const photographerProfile = 'S03';
  static const findPhotographer = 'S04';
  static const bookService = 'S05';
  static const bookDateTime = 'S06';
  static const bookReview = 'S07';
  static const awaitingPayment = 'S08';
  static const bookingDetail = 'S09';
  static const cancelBooking = 'S10';
  static const chat = 'S11';
  static const reviewAndShare = 'S12';
  static const exploreNoLocation = 'S13';
  static const bookings = 'S14';
  static const events = 'S15';
  static const eventDetail = 'S16';
  static const eventRegister = 'S17';
  static const eventTickets = 'S18';
  static const work = 'S19';
  static const myCalendar = 'S20';
  static const createPost = 'S21';
  static const workEmpty = 'S22';
  static const declineRequest = 'S23';
  static const setupProfile = 'S24';
  static const createEventInfo = 'S25';
  static const createEventSchedule = 'S26';
  static const manageEvent = 'S27';
  static const login = 'S28';
  static const role = 'S29';
  static const profile = 'S30';
  static const settings = 'S31';
  static const contactAfterBooking = 'S32';
  static const addPhone = 'S33';
  static const setupContact = 'S34';
  static const exploreNearby = 'S35';
  static const pickArea = 'S36';
  static const badges = 'S37';
  static const skillsPart1 = 'S38';
  static const skillsPart2 = 'S39';
  static const skillEvidence = 'S40';
  static const register = 'S41';
  static const editProfile = 'S42';
  static const earnings = 'S43';
  static const payoutAccount = 'S44';
  static const eventTimeline = 'S45';
  static const eventChat = 'S46';
  // Instant booking (docs/superpowers/specs/2026-10-01-instant-booking-design.md).
  static const instantRequest = 'S47';
  static const instantSearching = 'S48';
  static const instantTracking = 'S49';
  static const instantInProgress = 'S50';
  static const instantNoMatch = 'S51';
  static const instantAvailability = 'S52';
  static const instantOffer = 'S53';
  static const instantJob = 'S54';
  static const instantCancel = 'S55';

  static const all = <String>[
    home,
    photoDetail,
    photographerProfile,
    findPhotographer,
    bookService,
    bookDateTime,
    bookReview,
    awaitingPayment,
    bookingDetail,
    cancelBooking,
    chat,
    reviewAndShare,
    exploreNoLocation,
    bookings,
    events,
    eventDetail,
    eventRegister,
    eventTickets,
    work,
    myCalendar,
    createPost,
    workEmpty,
    declineRequest,
    setupProfile,
    createEventInfo,
    createEventSchedule,
    manageEvent,
    login,
    role,
    profile,
    settings,
    contactAfterBooking,
    addPhone,
    setupContact,
    exploreNearby,
    pickArea,
    badges,
    skillsPart1,
    skillsPart2,
    skillEvidence,
    register,
    editProfile,
    earnings,
    payoutAccount,
    eventTimeline,
    eventChat,
    instantRequest,
    instantSearching,
    instantTracking,
    instantInProgress,
    instantNoMatch,
    instantAvailability,
    instantOffer,
    instantJob,
    instantCancel,
  ];
}
