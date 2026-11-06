import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/special_days.dart';

/// The mock's packages for `#S04.01-dayprice`: Mon-Fri 1,5M, Sat-Sun 1,8M and
/// 2,2M on special days.
const dayPricePortrait = ServiceSummary(
  id: 's1',
  photographerId: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  photoCount: 40,
  dayPrices: {
    Weekday.mon: 1500000,
    Weekday.tue: 1500000,
    Weekday.wed: 1500000,
    Weekday.thu: 1500000,
    Weekday.fri: 1500000,
    Weekday.sat: 1800000,
    Weekday.sun: 1800000,
  },
  specialPrice: 2200000,
);

/// A price per day: 3,2M on Monday to Friday, 4M on Saturday, 3,6M on Sunday.
const dayPriceCouple = ServiceSummary(
  id: 's2',
  photographerId: 'p1',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
  photoCount: 80,
  dayPrices: {
    Weekday.mon: 3200000,
    Weekday.tue: 3200000,
    Weekday.wed: 3200000,
    Weekday.thu: 3200000,
    Weekday.fri: 3200000,
    Weekday.sat: 4000000,
    Weekday.sun: 3600000,
  },
);

/// One price on every day.
const dayPriceClass = ServiceSummary(
  id: 's3',
  photographerId: 'p1',
  name: 'Kỷ yếu cả lớp',
  priceVnd: 6000000,
  durationMinutes: 480,
  photoCount: 120,
);

/// Tuesday 17/11/2026 is a special day of photographer `p1`.
const dayPriceSpecialRange = SpecialDayRange(
  id: 'sd1',
  name: 'Mùa cưới',
  from: '2026-11-17',
  to: '2026-11-17',
);
