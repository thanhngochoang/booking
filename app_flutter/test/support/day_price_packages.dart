import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

import 'day_pricing_world.dart' show tetRule, weddingRule, weekendRule;

/// The mock's packages for `#S04.01-dayprice`: Chân dung 1,5M with An's three
/// series (see [anSeries]), Cặp đôi 3,2M with one 5M season, Kỷ yếu 6M with
/// none.
const dayPricePortrait = ServiceSummary(
  id: 's1',
  photographerId: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  photoCount: 40,
);

const dayPriceCouple = ServiceSummary(
  id: 's2',
  photographerId: 'p1',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
  photoCount: 80,
);

/// One price on every day: no series.
const dayPriceClass = ServiceSummary(
  id: 's3',
  photographerId: 'p1',
  name: 'Kỷ yếu cả lớp',
  priceVnd: 6000000,
  durationMinutes: 480,
  photoCount: 120,
);

/// An's seed series of `s1`: Cuối tuần (weekly Sat + Sun) 1,8M; Mùa cưới
/// (yearly 14/11 – 22/11) 2M with 2026-11-15 at 1,5M; Tết Nguyên đán (yearly,
/// lunar 23 Chạp – 5 Giêng) 2,5M.
List<PriceRule> anSeries({String serviceId = 's1'}) => [
  weekendRule(serviceId: serviceId),
  weddingRule(serviceId: serviceId, exceptions: {'2026-11-15': 1500000}),
  tetRule(serviceId: serviceId),
];

/// The 5M season of `s2` (S04.01 reads "3,2M–5M · giá theo ngày").
PriceRule coupleSeason() => const PriceRule(
  id: 'r-couple',
  serviceId: 's2',
  price: 5000000,
  repeat: PriceRepeat.yearly,
  name: 'Mùa cưới',
  from: '11-14',
  to: '11-22',
);

/// Everything the S04.01–S04.03 tests seed.
List<PriceRule> dayPriceRules() => [...anSeries(), coupleSeason()];

/// A series without a name: 2M on 2026-11-18 only.
PriceRule unnamedRule() => const PriceRule(
  id: 'r-unnamed',
  serviceId: 's1',
  price: 2000000,
  repeat: PriceRepeat.none,
  from: '2026-11-18',
  to: '2026-11-18',
);
