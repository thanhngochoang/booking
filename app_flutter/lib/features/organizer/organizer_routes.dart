// lib/features/organizer/organizer_routes.dart
//
// S30 paths (#223). `scanPath` (S30.07) and `spotTicketsPath` (S30.05) are
// built by Tasks 9 and 10; the constants exist so the S30.03 and S12.03-entry
// buttons and the notification targets name one path.

/// S30.01 "Tổ chức sự kiện".
const organizerApplyPath = '/organizer/apply';

/// S30.02 "Nhận quản lý điểm".
const spotClaimPath = '/organizer/spots/claim';

/// S30.03 "Quản lý điểm".
String managedSpotPath(String spotId) => '/organizer/spots/$spotId';

/// S30.04 create, for the managed spot [spotId].
String entryNewPath(String spotId) => Uri(
  path: '/organizer/entry/new',
  queryParameters: {'spot': spotId},
).toString();

/// S30.04 edit.
String entryEditPath(String eventId) => '/organizer/entry/$eventId/edit';

/// S30.06 "Nhân viên soát vé" (also where `gate_staff_invited` leads).
const gateStaffPath = '/organizer/gate-staff';

/// S06.06 "Tài khoản nhận tiền" for an organizer (Task 1b): the provider
/// route `/work/earnings/account` stays photographer-only.
const organizerPayoutPath = '/organizer/payout-account';

/// S30.07 "Quét mã" (Task 9).
const scanPath = '/scan';

/// S30.05 "Mua vé vào cửa" (Task 10).
String spotTicketsPath(String spotId) => '/spots/$spotId/tickets';
