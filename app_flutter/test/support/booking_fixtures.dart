import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';

const testServiceSnapshot = BookingServiceSnapshot(
  name: 'Gói chụp ngoại cảnh',
  price: 1000000,
  durationMinutes: 120,
);

const testPlace = BookingPlace(
  name: 'Hồ Hoàn Kiếm, Hà Nội',
  lat: 21.0285,
  lng: 105.8542,
);

const testContactSnapshot = BookingContactSnapshot(
  name: 'Nguyễn Văn A',
  phone: '+84903123456',
  allowZalo: true,
  allowWhatsApp: false,
);

Booking makeTestBooking({
  String id = 'b_test',
  String customerId = 'c1',
  String photographerId = 'p1',
  String serviceId = 's1',
  BookingServiceSnapshot serviceSnapshot = testServiceSnapshot,
  String day = '2026-10-20',
  String start = '09:00',
  String end = '11:00',
  BookingPlace place = testPlace,
  String? note = 'Chụp ảnh kỷ niệm',
  BookingStatus status = BookingStatus.requested,
  int deposit = 300000,
  int remaining = 700000,
  EscrowStatus? escrowStatus = EscrowStatus.held,
  DateTime? depositPaidAt,
  DateTime? completedAt,
  BookingCancel? cancel,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.utc(2026, 10, 1, 10, 0);
  return Booking(
    id: id,
    customerId: customerId,
    photographerId: photographerId,
    serviceId: serviceId,
    serviceSnapshot: serviceSnapshot,
    day: day,
    start: start,
    end: end,
    place: place,
    note: note,
    status: status,
    deposit: deposit,
    remaining: remaining,
    escrowStatus: escrowStatus,
    depositPaidAt:
        depositPaidAt ?? (status != BookingStatus.draft ? now : null),
    completedAt: completedAt,
    cancel: cancel,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}
