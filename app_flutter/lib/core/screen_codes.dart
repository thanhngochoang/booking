// lib/core/screen_codes.dart
/// One code per screen: `Sxx` is a use case (a complete user flow), `Sxx.yy` a
/// screen in it. The single source in Dart; the table in
/// `docs/superpowers/specs/2026-10-01-remaining-screens.md` (section 2) and the
/// mock `docs/design/ui-mock.html` use the same codes (a test compares them).
///
/// A new screen takes the next `.yy` in its use case, a new use case the next
/// `Sxx`; never renumber inside a use case. A use case number may be reserved
/// for screens outside the app (S28: studio web dashboard, #161). Old flat
/// codes (S01–S67, before 2026-10-02) are in the spec table's "Mã cũ" column.
abstract final class ScreenCodes {
  // S01 Vào app & tài khoản.
  static const splash = 'S01.01';
  static const sessionError = 'S01.02';
  static const login = 'S01.03';
  static const register = 'S01.04';
  static const role = 'S01.05';
  // S02 Khám phá & tìm thợ.
  static const home = 'S02.01';
  static const photoDetail = 'S02.02';
  static const exploreNoLocation = 'S02.03';
  static const exploreNearby = 'S02.04';
  static const pickArea = 'S02.05';
  static const findPhotographer = 'S02.06';
  static const exploreSearch = 'S02.07';
  // S03 Xem hồ sơ nhiếp ảnh gia.
  static const photographerProfile = 'S03.01';
  static const badges = 'S03.02';
  // S04 Đặt lịch.
  static const bookService = 'S04.01';
  static const bookDateTime = 'S04.02';
  static const bookReview = 'S04.03';
  static const awaitingPayment = 'S04.04';
  static const addPhone = 'S04.05';
  static const bookPlace = 'S04.06';
  // S05 Theo dõi buổi chụp (khách).
  static const bookings = 'S05.01';
  static const bookingDetail = 'S05.02';
  static const cancelBooking = 'S05.03';
  static const contactAfterBooking = 'S05.04';
  static const reviewAndShare = 'S05.05';
  static const deliveryReview = 'S05.06';
  static const requestRevision = 'S05.07';
  static const cancelLateDelivery = 'S05.08';
  // S06 Nhận việc (nhiếp ảnh gia).
  static const work = 'S06.01';
  static const workEmpty = 'S06.02';
  static const declineRequest = 'S06.03';
  static const myCalendar = 'S06.04';
  static const earnings = 'S06.05';
  static const payoutAccount = 'S06.06';
  static const submitDelivery = 'S06.07';
  // S07 Hội thoại.
  static const chat = 'S07.01';
  static const chats = 'S07.02';
  // S08 Thiết lập hồ sơ nhiếp ảnh gia.
  static const setupProfile = 'S08.01';
  static const skillsPart1 = 'S08.02';
  static const skillsPart2 = 'S08.03';
  static const skillEvidence = 'S08.04';
  static const setupContact = 'S08.05';
  static const myAddons = 'S08.06';
  static const editAddon = 'S08.07';
  // S09 Hồ sơ cá nhân & cài đặt.
  static const profile = 'S09.01';
  static const settings = 'S09.02';
  static const editProfile = 'S09.03';
  // S10 Đăng bài.
  static const createPost = 'S10.01';
  // S11 Tham gia sự kiện.
  static const events = 'S11.01';
  static const eventDetail = 'S11.02';
  static const eventRegister = 'S11.03';
  static const eventTickets = 'S11.04';
  static const eventTimeline = 'S11.05';
  static const eventChat = 'S11.06';
  // S12 Tổ chức sự kiện.
  static const createEventInfo = 'S12.01';
  static const createEventSchedule = 'S12.02';
  static const manageEvent = 'S12.03';
  // S13 Chụp ngay (khách).
  static const instantRequest = 'S13.01';
  static const instantChoose = 'S13.02';
  static const instantSearching = 'S13.03';
  static const instantMatched = 'S13.04';
  static const instantTracking = 'S13.05';
  static const instantInProgress = 'S13.06';
  static const instantNoMatch = 'S13.07';
  static const instantCancel = 'S13.08';
  // S14 Chụp ngay (nhiếp ảnh gia).
  static const instantAvailability = 'S14.01';
  static const instantOffer = 'S14.02';
  static const instantJob = 'S14.03';
  // S15 Đăng việc (khách).
  static const jobPost = 'S15.01';
  static const myJobs = 'S15.02';
  static const jobApplications = 'S15.03';
  static const applicationDetail = 'S15.04';
  // S16 Nhận việc đăng (nhiếp ảnh gia).
  static const jobDetailForPhotographer = 'S16.01';
  static const openJobs = 'S16.02';
  static const submitQuote = 'S16.03';
  // S17 Thông báo.
  static const notifications = 'S17.01';
  static const notificationSettings = 'S17.02';
  static const notificationPermission = 'S17.03';
  // S18 Khiếu nại & hỗ trợ.
  static const openDispute = 'S18.01';
  static const disputeDetail = 'S18.02';
  static const help = 'S18.03';
  // S19 Lưu & theo dõi.
  static const saved = 'S19.01';
  static const following = 'S19.02';
  static const followers = 'S19.03';
  // S20 Báo cáo & chặn.
  static const report = 'S20.01';
  static const blockedUsers = 'S20.02';
  // S21 Xác minh.
  static const verifyPhone = 'S21.01';
  static const verifyPhotographer = 'S21.02';
  static const verifyIdentity = 'S21.03';
  static const verifyBusiness = 'S21.04';
  // S22 Thanh toán & tài khoản.
  static const paymentHistory = 'S22.01';
  static const deleteAccount = 'S22.02';
  static const privacy = 'S22.03';
  static const refundAccount = 'S22.04';
  static const restoreAccount = 'S22.05';
  // S23 Vận hành nội bộ (staff).
  static const staffDisputes = 'S23.01';
  static const staffPayouts = 'S23.02';
  static const staffManualRefunds = 'S23.03';
  static const staffVerifications = 'S23.04';
  static const staffReports = 'S23.05';
  static const staffSupportInbox = 'S23.06';
  static const staffAwardReviews = 'S23.07';
  // S24 Portfolio album.
  static const albumDetail = 'S24.01';
  static const myAlbums = 'S24.02';
  static const editAlbum = 'S24.03';
  static const addPostsToAlbum = 'S24.04';
  static const pickAlbum = 'S24.05';
  // S25 Giải thưởng & hạng Nhiếp ảnh gia (NAG).
  static const myAwards = 'S25.01';
  static const editAward = 'S25.02';
  // S26 Studio và thành viên.
  static const studioMembers = 'S26.01';
  static const inviteMember = 'S26.02';
  static const myStudio = 'S26.03';
  static const assignPhotographer = 'S26.04';
  static const requestPhotographerChange = 'S26.05';
  // S27 Studio tuyển thợ.
  static const recruitList = 'S27.01';
  static const recruitDetail = 'S27.02';
  static const recruitApply = 'S27.03';
  static const recruitEdit = 'S27.04';
  static const studioRecruit = 'S27.05';
  static const collaboration = 'S27.06';
  static const collabOffer = 'S27.07';
  // S28 is reserved for the studio web dashboard (#161); no app screen.
  // S29 Điểm chụp đang hot.
  static const spots = 'S29.01';
  static const spotDetail = 'S29.02';
  static const mySpotSchedules = 'S29.03';
  static const spotScheduleEdit = 'S29.04';
  static const spotSlotOffer = 'S29.05';
  static const spotSlotPick = 'S29.06';
  // S30 Chủ sự kiện & vé vào cửa.
  static const organizerApply = 'S30.01';
  static const spotClaim = 'S30.02';
  static const managedSpot = 'S30.03';
  static const entryTicketsEdit = 'S30.04';
  static const entryTicketsBuy = 'S30.05';
  static const gateStaff = 'S30.06';
  static const scanPass = 'S30.07';

  static const all = <String>[
    splash,
    sessionError,
    login,
    register,
    role,
    home,
    photoDetail,
    exploreNoLocation,
    exploreNearby,
    pickArea,
    findPhotographer,
    exploreSearch,
    photographerProfile,
    badges,
    bookService,
    bookDateTime,
    bookReview,
    awaitingPayment,
    addPhone,
    bookPlace,
    bookings,
    bookingDetail,
    cancelBooking,
    contactAfterBooking,
    reviewAndShare,
    deliveryReview,
    requestRevision,
    cancelLateDelivery,
    work,
    workEmpty,
    declineRequest,
    myCalendar,
    earnings,
    payoutAccount,
    submitDelivery,
    chat,
    chats,
    setupProfile,
    skillsPart1,
    skillsPart2,
    skillEvidence,
    setupContact,
    myAddons,
    editAddon,
    profile,
    settings,
    editProfile,
    createPost,
    events,
    eventDetail,
    eventRegister,
    eventTickets,
    eventTimeline,
    eventChat,
    createEventInfo,
    createEventSchedule,
    manageEvent,
    instantRequest,
    instantChoose,
    instantSearching,
    instantMatched,
    instantTracking,
    instantInProgress,
    instantNoMatch,
    instantCancel,
    instantAvailability,
    instantOffer,
    instantJob,
    jobPost,
    myJobs,
    jobApplications,
    applicationDetail,
    jobDetailForPhotographer,
    openJobs,
    submitQuote,
    notifications,
    notificationSettings,
    notificationPermission,
    openDispute,
    disputeDetail,
    help,
    saved,
    following,
    followers,
    report,
    blockedUsers,
    verifyPhone,
    verifyPhotographer,
    verifyIdentity,
    verifyBusiness,
    paymentHistory,
    deleteAccount,
    privacy,
    refundAccount,
    restoreAccount,
    staffDisputes,
    staffPayouts,
    staffManualRefunds,
    staffVerifications,
    staffReports,
    staffSupportInbox,
    staffAwardReviews,
    albumDetail,
    myAlbums,
    editAlbum,
    addPostsToAlbum,
    pickAlbum,
    myAwards,
    editAward,
    studioMembers,
    inviteMember,
    myStudio,
    assignPhotographer,
    requestPhotographerChange,
    recruitList,
    recruitDetail,
    recruitApply,
    recruitEdit,
    studioRecruit,
    collaboration,
    collabOffer,
    spots,
    spotDetail,
    mySpotSchedules,
    spotScheduleEdit,
    spotSlotOffer,
    spotSlotPick,
    organizerApply,
    spotClaim,
    managedSpot,
    entryTicketsEdit,
    entryTicketsBuy,
    gateStaff,
    scanPass,
  ];
}
