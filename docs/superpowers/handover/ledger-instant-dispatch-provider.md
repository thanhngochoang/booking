# Sổ bàn giao — Chụp ngay: điều phối trên Functions và app thợ ảnh (#140, PR 1)

- **Issue:** [#140](https://github.com/thanhngochoang/booking/issues/140) (PR 1 của 2: Tasks 1–10 của plan này; PR 2 là Tasks 1–7 của plan khách `2026-10-07-s13-instant-customer.md` trên `plan/140-instant-customer`). Tiền là [#202](https://github.com/thanhngochoang/booking/issues/202) (Task 11 của plan này, rồi Task 8 của plan khách).
- **Plan:** [`../plans/2026-10-07-s13-s14-dispatch-provider.md`](../plans/2026-10-07-s13-s14-dispatch-provider.md) · **Spec:** [`../specs/2026-10-01-instant-booking-design.md`](../specs/2026-10-01-instant-booking-design.md) (hộp "Giai đoạn 1" ở §5, số vị trí ở §9) · **Màn:** [`../specs/screens/instant.md`](../specs/screens/instant.md).
- **Nhánh:** `plan/140-instant-dispatch`, từ `origin/develop` 6dd67891 + 85dd7f07 (script arm64 mang từ PR #283 đã đóng, chủ dự án 2026-10-22). PR vào `develop`.

## Đã làm

| Task | Commit | Kết quả |
|---|---|---|
| 1 Mock và chữ phía thợ | ccb557ab | Khung mới `#S06.01-instant`, `#S14.01-terms`, `#S14.01-locked`, `#S13.04-provider`, `#S14.03-arrived`, `-shooting`, `-done`, `#S13.08-provider`; ghi chú Live Shutter và chia sẻ vị trí theo Decisions 10, 11; thể loại thứ năm. |
| 2 Luật miền | 2aa498d9 | `packages/domain/src/instant.ts` (mô hình, cấu hình `parseInstantConfig`, giá, ETA, máy trạng thái `nextInstantStatus`, presence tươi), `instant_settle.ts` (`settleInstant`, `nextDeadlineOf`), `instant_match.ts` (xếp hạng 5 người, tầng ưu tiên/mở rộng, vòng 3 → 6 → 10 km), `instant_cancel.ts` (bảng huỷ Decision 9), `geo.ts` (`distanceKm`). |
| 3 Use case miền | 32aac55b, 6a4773e4, 972a5bef | `instant_requests.ts` (tạo, lượt, mời, huỷ, xác nhận, quét), `instant_jobs.ts` (Live Shutter, trả lời lời mời — ai nhận trước thì được, các bước việc), `instant_work.ts`, `instant_notices.ts` (`instantNotices`, `offerPushMessage`), `instant_ports.ts`, `memory_instant_store.ts`; `getContactLink` có chủ thể `instant_request`. Một vòng sửa. |
| 4 Functions | fc29ddf5, 9688d78c | Adapter Firestore (`instant_firestore.ts`, `instant_readers.ts`, `live_instant.ts`; `excludedIds` ở `private/dispatch`, khoá `instant_customers/{uid}`), 10 callable, bước `instantSweep` trong `bookingClock`, cấu hình seed, CLI `npm run instant`, 5 chỉ mục ghép. |
| 5 Trigger, rules | c70a8cbe, 7cec138d, d6d556be | `onInstantRequestWrite` (7 hook thông báo của #138, chat cặp, xoá vị trí), đọc liên hệ cho `getContactLink`, rules `instant_*` + test rules (viết, chưa chạy), khoá chống trùng theo lần nhận việc, chữ `no_match` khi chưa trả. Một vòng sửa. |
| 6 Dữ liệu app | bb267292, b3d8ce89 | `lib/data/instant/` (mô hình freezed, `InstantRepository`, `FirestoreInstantRepository`, mapping, providers); `instantTrackProvider` nghe lại khi `en_route`. Một vòng sửa. |
| 7 S14.01, S06.01 | 54e70739, 82b0593c | `LiveShutterScreen`/`Controller`, `LiveShutterCard`, `LiveShutterHeartbeat`, route `/work/instant*`; `LocationRepository.currentFix({highAccuracy})` với sai số thật (bỏ `kApproxFixAccuracyM`). Một vòng sửa. |
| 8 S14.02, S13.04 | 3ba2dc5c, 3d693cae | `OfferScreen`/`OfferController` (mỗi màn một khoá), `OfferStack`, `MatchOverlay`, `InstantOfferListener`, `offer_routes.dart`, mở từ push; `settledPendingOffers`. Một vòng sửa. |
| 9 S14.03, S13.08 | 0daa47f3, ccd9d418, 48843c12 | `InstantJobScreen`/`Controller`, `MapPreview` (token `map*`), `RouteTracker` (16 giây), sheet huỷ phía thợ. Một vòng sửa. |
| 10 Tài liệu | c5e9e629 | Spec (hộp §5, số §9), `screens/instant.md`, bảng mã và §3h.2 của spec chính, mô hình miền §2.13 + enum + máy trạng thái + bất biến 39–41, ánh xạ Firestore của lược đồ quan hệ, `shared-components.md`, `services/dispatch/README.md`, dòng "Superseded" ở 4 plan cũ, README seed, sửa plan (`?matched=1`, 0,65 km, bảng Contract) và plan #138 (khoá chống trùng). |
| Rà soát cuối | f418d184, a081ffdd, 63abf340, commit này | Server: thợ rảnh ngay khi `finished` (nút hoặc hết giờ gói), `CONTENDED_CALLABLE_OPTIONS` cho 4 callable tranh chấp, CLI huỷ yêu cầu mồ côi. App: S14.02 mở lạnh offline rời màn sau 10 giây với "Mất kết nối. Thử lại nhé.", một nút "Đồng ý bảng giá" ở S14.01, "… m" từ ARB, heartbeat quên vị trí khi tắt, chú thích. Tài liệu: ghim `self` và 16 giây ở mock S14.03, dòng S13.04, phán quyết vào plan/spec, sổ này. |

## Quyết định (Decisions 1–31 của plan, mỗi dòng một ý)

1. Giai đoạn 1 chạy trên Cloud Functions + Firestore, không phải `services/dispatch` (đích giai đoạn 2).
2. Luật nằm ở `packages/domain` (tệp `instant*`), không tạo `packages/dispatch-core`.
3. Hẹn giờ lười: `settleInstant` trong mỗi giao dịch, `tickInstantRequest` từ app, bước của `bookingClock` 15 phút; không job mới, không Cloud Tasks.
4. Ai nhận trước thì được: một giao dịch trên yêu cầu và presence của thợ; người thua nhận `already_assigned`.
5. Trả trước rồi mới gửi lời mời, trên mô hình thanh toán chung V1 — toàn bộ ở #202 (Task 11); #140 gửi ngay, không thu tiền.
6. Thợ nhận 100%, phí nền tảng là cấu hình `platformFeeBp` (mặc định 0), chụp lại trên yêu cầu (chủ dự án 2026-10-07).
7. Thả tiền một mốc (`endAt + 24 giờ`) qua bước 5 của `bookingClock` — #202.
8. Tập trạng thái = spec §3.1 + `finished`; bỏ `payment_failed`; `disputed` để S18; thợ huỷ đưa yêu cầu về `choosing`.
9. Bảng huỷ theo spec §4 và mock S13.08; `arrived` chia theo cấu hình `instantArrivedCancelPhotographerPercent` (mặc định 50); chưa trả thì luật `unpaid`, tiền 0.
10. Presence ở Firestore, chỉ tiền cảnh; heartbeat của app (> 60 giây/lần); tươi 30 phút.
11. Vị trí khi đang đến bị chặn trần: ghi khi ≥ 25 m hoặc 60 giây, rules ≥ 15 giây giữa hai lần (đã làm: lấy mẫu và ghi ≥ 16 giây).
12. Tìm ứng viên không dùng API bản đồ: geohash 5/4 + haversine `distanceKm` dùng chung (`geo.ts`); ETA = ceil(km × 1,4 / 20 × 60), tối thiểu 1.
13. Đường dẫn lời mời `instant_offers/{uid}/offers/{offerId}` (không `items`).
14. Trần 3 lời mời đang chờ tính trên `presence.pendingOffers` (chỉ mục chưa hết hạn).
15. Yêu cầu chỉ mang lượt hiện tại; xoá ứng viên và lời mời khi có người nhận.
16. Hết lượt rẻ: về `choosing` với `roundEnded`, app khách gọi lượt mới.
17. Cổng: `setLiveShutter(online)` dùng `ProviderOrderGate`; mời và nhận dùng `orderBlocker` của #198 (gồm chặn), `InstantDeps.blocks` luôn được nối.
18. Một yêu cầu đang chạy mỗi khách, một việc mỗi thợ.
19. Điểm hẹn = vị trí GPS + tên gõ (≤ 80); khu hiện trong lời mời là khu gần nhất trong 8 km, không geocoding.
20. Thông báo qua 7 hook của #138; lời mời là push riêng, không có dòng hộp thư.
21. Khi nhận việc, chat cặp thành `booking` (`bookingId` rỗng); kết thúc thì chỉ đọc sau 7 ngày.
22. Liên hệ chỉ mở khi yêu cầu có thợ, còn chạy **và đã trả**; bản sao liên hệ khách ở `private/contact` chỉ ghi khi đã trả.
23. Cà chua/gạch, không sao: snapshot `tomatoPct`, `reviewCount`; `MetaLine`.
24. Đánh giá sau chụp ngay để #130 (chưa có).
25. Từ chối không hỏi lý do.
26. "Thường có người nhận trong khoảng {n} phút" ẩn (chưa có dữ liệu).
27. Hệ số cao điểm: một hệ số mỗi thành phố (`surgeBp`), chưa theo giờ.
28. Cờ `instantEnabledProvider` (`kInstantEnabled = false`); #202 bật; cấu hình có `enabled` làm công tắc tắt phía server.
29. CLI `npm run instant` (chỉ emulator) để thử S14.02/S14.03 trước khi có app khách.
30. Bản đồ `MapPreview` sơ đồ, không tile, không SDK; "Chỉ đường" mở ứng dụng bản đồ.
31. Năm thể loại của spec §2.1 (`event` hiện "Sự kiện nhỏ").

## Phán quyết khi làm

- **Chung:** mang commit 2eebd1d (cherry-pick thành 85dd7f07; PR #283 đã đóng, chỉ script) trên nhánh này (chủ dự án 2026-10-22); phạm vi là Tasks 1–10, Task 11 thuộc #202.
- **Task 1:** ô trạng thái S14.01/S14.03 là link #140 (luật "trạng thái = link" thắng chữ trong brief). Giữ chữ tiền của trạng thái cuối trên khung thợ ("Tiền chuyển cho bạn 24 giờ sau khi hoàn thành.", "Khách được hoàn 100%.") cho tới khi #202 có tiền.
- **Task 2:** sự kiện `invite` (`choosing → searching`); `in_progress → completed` qua `complete`; `settleInstant` chỉ dựng lại khi có lời mời hết hạn; `nextDeadlineOf` rỗng cho `assigned`/`arrived`/`no_match`; presence tươi là `< 30 phút` (chặt); ví dụ khoảng cách của plan sai (≈ 0,65 km, đã sửa ở Task 10). Ứng viên loại ngày `spot`, `full` **và `booked`** (giữ theo ngày; `off` và `pending` vẫn được). Tỉ lệ huỷ của tầng ưu tiên = huỷ / đã nhận khi ≥ 10 lời mời. Hai mục "FIX IN FINAL WAVE" này đã làm trong vòng sửa của Task 3. `settleInstant` còn tự chữa một yêu cầu `searching` có lời mời mà không còn cái nào chờ; thiếu `freeCancelUntil` trên yêu cầu đã trả được coi là còn trong 2 phút miễn phí (an toàn cho khách).
- **Task 3:** `InstantDeps.days`; bỏ gateway tới #202; `runInstantSweep` trả lỗi; `InstantContactRecord.paidAt`; lời từ chối vẫn ghi phần đã settle; lời mời bị rút vì người khác thắng → `already_assigned`. `excludedIds` không được để thợ đã nhận đọc: domain giữ trường, adapter lưu ở `instant_requests/{id}/private/dispatch` (chỉ server), rules cấm client đọc `private/*` trừ `contact`. Cấu hình `enabled = false` từ chối mọi lời mời (kể cả lượt sau của yêu cầu đã gửi) với `not_eligible`; khách vẫn huỷ được; quét kết thúc ở `searchDeadlineAt` (ghi cho #202). Không có dòng `instant_round_ended` khi mọi người của lượt đều bận lúc gửi (khách biết ngay trong câu trả lời).
- **Task 4:** `handleBookingClock(bookingDeps?)` chỉ dùng deps thật khi chạy thật; khoá khách `instant_customers/{uid}.activeRequestId`; 5 chỉ mục ghép thêm ở đây; ảnh hồ sơ = ảnh đầu của 3 bài `work` mới nhất.
- **Task 5:** hook `instant_*` của #138 nhận thêm tham số phân biệt (lần nhận = `assignedAt` ms; `no_match` = lượt) nối vào khoá chống trùng (plan #138 đã sửa ở Task 10). `instant_no_match` khi chưa trả dùng đúng câu spec "Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn" (sửa `notification_render.ts`, lệch Decision 20, để không in "0₫ vẫn được giữ"). Rules dùng regex thay cắt chuỗi `d.geohash5[0:4]`. Rules chưa từng biên dịch ở máy: CI là lần biên dịch đầu.
- **Task 6:** thêm `InstantErrorKind`, `InstantCancelRule`, `InstantParticipant`, `startedRouteAt`, `cancelRule`, repository giả; bỏ `checkPayment` (#202); lý do lạ của `setLiveShutter` đọc là `notAcceptingOrders`; luồng bị từ chối quyền đọc trả `null` rồi kết thúc; callable tranh chấp chờ 40 giây phía client.
- **Task 7:** S06.01 theo mock (khoá `liveShutterJobTitle`/`liveShutterJobMeta` thay `liveShutterCardJob`); ngoài vùng không khoá công tắc. `LocationRepository.currentFix({highAccuracy})` trả sai số thật (máy chủ tin sai số này khi `force`). S14.01 bị khoá không có nút chân màn (mock); hàng lý do bảng giá có nút nhỏ "Đồng ý bảng giá". Test pin cho phép đúng một chỗ dùng `LocationAccuracy.high` (một lần, khi bấm "Đã đến").
- **Task 8:** `Notifier` + provider `autoDispose` (Riverpod 3); không có `offerSecondsUnit` (vòng tự vẽ "giây"); `blocked` khi nhận → chữ lỗi chung và bỏ thẻ; sang `/work/instant/{requestId}` không có `?matched=1`. Giữ thẻ trong lúc nhận; danh sách rỗng từ cache bị giữ tới khi server trả lời + chờ 2 giây khi mở lạnh; mỗi S14.02 một bộ điều khiển; push thay S14.02 đang ở trên cùng.
- **Task 9:** `start_route` thử lại mỗi 16 giây khi còn `assigned`, "Đã đến" gửi `start_route` trước nếu cần; kiểm lại quyền vị trí khi đang đi; lấy mẫu và ghi ≥ 16 giây (Decision 11 ghi 15: thêm 1 giây cho lệch đồng hồ). "Bạn" là ghim của mình (lớp `self` của mock đã chuyển sang "Bạn" ở rà soát cuối, 63abf340); đã đến thì không có "Huỷ việc" (mock); vẫn chia sẻ khi mở chat trên S14.03; nút liên hệ ẩn khi chưa trả.

- **Rà soát cuối (controller, 2026-10-22):**
  - **S1 — thợ rảnh ngay khi xong việc.** Spec §2.2 mục 5 ("Sau khi hoàn thành, trạng thái sẵn sàng trở lại như trước") là chuẩn hành vi; plan chỉ giải phóng presence lúc `completed` là lỗ hổng của plan (thợ bị chặn lời mời mới tới ~2 giờ 15 phút sau "Hoàn thành"). `finish` và hẹn giờ buổi chụp (`in_progress → finished`) xoá `presence.activeRequestId`; xác nhận và tự hoàn tất vẫn giải phóng, chỉ khi presence còn trỏ vào yêu cầu này (không ghi đè việc mới). Decision 8 của plan, bất biến 39 của mô hình miền và `screens/instant.md` đã ghi theo (f418d184, 63abf340).
  - **Hệ quả của S1 ở app (re-review):** thợ có thể có nhiều yêu cầu `active` cùng lúc (việc đang làm + việc `finished` chờ khách xác nhận). `watchMyActiveJob` (thẻ S06.01) không còn `limit(1)`: đọc tối đa 10 yêu cầu active, chọn việc chưa `finished` trước rồi việc được giao gần nhất (`pickActiveJob`), không cần index mới.
  - **S2 — quyền tối thiểu.** `inviteInstant`, `answerInstantOffer`, `cancelInstantRequest`, `confirmInstantComplete` chạy với `CONTENDED_CALLABLE_OPTIONS` (30 giây, không secret `PAYOUT_ACCOUNT_KEY`) vì #140 không chuyển tiền; **#202 chuyển `cancelInstantRequest` và `confirmInstantComplete` về `PAYMENT_CALLABLE_OPTIONS`** khi có hoàn tiền và thả tiền (`checkInstantPayment` cũng dùng `PAYMENT_CALLABLE_OPTIONS`). Plan (Contract, Task 11) đã ghi (f418d184, 63abf340).

## Bỏ qua theo quy tắc chung

- Test rules (`app_flutter/firebase/rules-test/rules.test.mjs`) và test tích hợp Functions (`test/integration/`): **viết, không chạy** (sandbox không chạy được emulator); CI chạy khi push. Rules chưa biên dịch lần nào ở máy.
- Không build lên thiết bị, không bước pin/hiệu năng, không iOS.
- Không foreground service, không vị trí nền, không full-screen intent (Decision 10; hoãn).
- Mock chưa xem trong trình duyệt (`file://` bị chặn ở Task 1); kiểm hình để sau.

## Thứ tự deploy

1. **Chỉ mục trước Functions**: 5 chỉ mục ghép (`instant_requests (customerId, active)`, `(photographerId, active)`, `(active, nextDeadlineAt)`, `instant_presence (online, geohash5)`, `(online, geohash4)`); bước `instantSweep` và tìm ứng viên cần chúng.
2. **Rules đi cùng Functions**: rules cho phép đúng hai lần ghi của app (heartbeat, điểm vị trí) và cấm `private/dispatch`, `instant_customers`.
3. **`instant_config/current` phải có trong từng dự án trước khi dùng `enabled`**: seed chỉ ghi trên emulator; dự án dev/prod cần một bản cấu hình (công cụ staff S23.22 khi có, hoặc ghi tay), nếu không mọi callable trả `not_eligible`.
4. **Công tắc Blaze**: Functions chỉ deploy khi `BLAZE_ENABLED=true` (đang tắt từ 2026-10-09), nên dự án dev chỉ nhận rules và chỉ mục; tính năng chạy trên emulator (`scripts/backend-local.sh`). Không thêm job Cloud Scheduler (bước nằm trong `bookingClock` có sẵn).
5. **App**: cờ `kInstantEnabled` vẫn `false`; bản app cũ không bị ảnh hưởng.

## Tách #140 / #202

- **#140 không có tiền**: lần "Gửi lời mời" đầu gửi lời mời ngay (không `pending_payment`), yêu cầu ghi `committedAt`; `paidAt` luôn rỗng nên mọi huỷ là `unpaid` (không có mặt là `no_show`), tiền 0; kênh liên hệ và bản sao liên hệ khách bị khoá (cần `paidAt`).
- **Không tới được khách thật**: `inviteInstant` từ chối `not_eligible` trừ khi `fakePaymentsAllowed()` (dự án dev hoặc emulator `demo-*`); `kInstantEnabled = false`; `instant_config/current` chỉ có trong seed.
- **#202 (Task 11, rồi Task 8 của plan khách)**: chèn bước thanh toán trước lời mời (`pending_payment`, `newSubjectPayment` chủ thể `instant_request`, `InstantPaymentSettler`), áp mọi kết quả huỷ đã ghi vào khoản tiền, thả một mốc, dòng thu nhập (`earnings` chủ thể `instant_request`), `checkInstantPayment`, số tiền của server cho sheet không có mặt; gỡ chốt `fakePaymentsAllowed()` và bật cờ. Ghi chú cho #202: bỏ `pending_payment` khỏi luật "bỏ dở 30 phút" khi cửa sổ thanh toán còn mở; công tắc `enabled = false` chặn cả lượt sau của yêu cầu đã trả (phán quyết Task 3). Chuyển `cancelInstantRequest` và `confirmInstantComplete` từ `CONTENDED_CALLABLE_OPTIONS` về `PAYMENT_CALLABLE_OPTIONS` (phán quyết S2 của rà soát cuối).

## #202 — tiền (Task 11 của plan này)

- **Đối chiếu tên (develop 3e3f3298):** V1 #200 và V2 #201 đều đã có. Dùng `newSubjectPayment`, `freshPaymentId`, `issuePaymentInstructions`, `instructionsOf`, `checkSubjectPayments` (`create_payment.ts`), `applyTransfer`, `expireUnpaid`, `transferRecordId`/`transferRecordOf`, `confirmFakePayment`, `SettlementDeps` (`payment_settlement.ts`), `SubjectSettler`/`PaymentInstructions` (`payment_ports.ts`), V2 `sendRefundOnce` + `mergeRefundOutcome` (`refunds.ts`) và sổ `RefundSubjects` (`refund_subjects.ts`, `liveRefundSubjects()`); không dùng đường dự phòng `dispatchRefunds` của #129. `applyRefundToPayment` sau #142 chỉ bắt `escrowRefunded` khi có `amount`: chụp ngay dùng đường phần trăm (số tiền khớp `computeRefund` của bảng huỷ).
- **Miền:** `instant_payments.ts` (`InstantPaymentSettler`, `instantRefundHandler`, `refundInstantShare`); `PAYMENT_SUBJECTS` có `instant_request`; `InstantDeps` thêm `gateway`, `payments`, `cipher`; `InstantTx` thêm `getTransferRecord`, `paymentsOfRequest`, `putTransferRecord`; `InstantWork` giữ khoản tiền như các tài liệu khác (mọi lần ghi vẫn dồn ở `flush`, đọc luôn trước ghi). Lần mời đầu mở khoản tiền (`pending_payment`), trả xong mới gửi lời mời; lần mời sau dùng tiền đang giữ. Huỷ, không có mặt, nhận việc, thợ huỷ, xác nhận và tự hoàn tất làm đúng Decision 5/7/9/22; `committedAt` chỉ đi cùng `paidAt`.
- **Phán quyết khi làm:** `pending_payment` không bị "bỏ dở 30 phút" khi cửa sổ thanh toán còn mở (ghi chú #202 ở trên). Huỷ thật có thể gửi `expectedRule`/`expectedRefundVnd` của bản tính thử, server trả `conflict` khi khác (cả hai sheet S13.08 gửi). "Khách không có mặt" lấy số của server (`updateInstantJob` `no_show` `dryRun`), app không tự tính 50%. Phí nền tảng của yêu cầu được chụp lên khoản tiền (`Payment.feeBp`), `payoutLineOf(..., feeBp)` và dòng thu nhập dùng nó (Decision 6). Đổi người nhận tiền (thợ huỷ) làm mới cả người nhận cũ để dòng thu nhập của họ biến mất.
- **Phán quyết rà soát (controller, #202 vòng sửa 1):** mock S06.05 thắng plan: dòng thu nhập chụp ngay mở ra phần Hoa hồng / Thuế khấu trừ / Thực nhận như dòng lịch thường, không mở `/work/instant/{id}`. Lời mời gửi sau khi trả dùng bảng giá khách đã trả (`priceListVersion`, `earningVnd` của yêu cầu), không dùng cấu hình mới; danh sách người được chọn đổi giữa lần đọc trước và giao dịch thì được kiểm lại. Dòng đã chi trả lấy mức phí của chính khoản tiền (`feeBp`).
- **Functions:** `checkInstantPayment` mới; `inviteInstant`, `checkInstantPayment`, `cancelInstantRequest`, `confirmInstantComplete`, `updateInstantJob` chạy với `PAYMENT_CALLABLE_OPTIONS` (hoàn tiền cần `PAYOUT_ACCOUNT_KEY`; `inviteInstant` và `updateInstantJob` thêm so với plan); `answerInstantOffer` vẫn `CONTENDED_CALLABLE_OPTIONS`. Chốt `fakePaymentsAllowed()` của #140 trên `inviteInstant` đã gỡ: tắt thanh toán là `not_eligible` qua `checkoutGatewayAvailable()`. CLI `npm run instant` trả tiền giả trước khi gửi lời mời. Test rules và test tích hợp: viết, không chạy.

## Câu hỏi cho chủ dự án

1. Bản đồ thật cho S13.05/S14.03 (Google Maps SDK, Goong) hay giữ bản đồ sơ đồ? Mặc định: sơ đồ (Decision 30).
2. Bảng giá v1 và thành phố đầu: mặc định 390.000 / 690.000 / 1.190.000 ₫ (30 phút · 15 ảnh, 1 giờ · 30 ảnh, 2 giờ · 60 ảnh), TP.HCM, Hà Nội, Đà Nẵng theo hộp bao, hệ số ×1,0 (chỉ là seed).
3. Presence và vị trí nền (foreground service, hỏi "Vẫn muốn nhận việc?", lời mời toàn màn có chuông): mặc định chỉ tiền cảnh.
4. Tiền giữ ở `no_match` khi khách không quay lại: mặc định giữ tới khi khách huỷ, một push lúc `no_match`, không nhắc thêm.
5. Hàng "Hoàn tất xác minh và hồ sơ để nhận đơn" ở S14.01 bị khoá chưa có nút: có nên mở S21.02?
6. Có giữ chữ tiền của trạng thái cuối trên màn thợ ở #140 (khi chưa có tiền) không, hay ẩn tới #202?
7. Cách đọc spec §3.2 về vòng và tầng: đã làm "vòng trước" (lấy vòng nhỏ nhất trong 3 / 6 / 10 km có đủ 5 người gợi ý được, không đủ thì mọi người trong 10 km), rồi trong vòng đó tầng ưu tiên trước, mỗi tầng theo điểm, khoảng cách. Vì thế một thợ tầng ưu tiên ở 5 km không được gợi ý khi vòng 3 km đã đủ 5 người: đúng ý không?
8. Đến nơi chính xác cần quyền vị trí chính xác (Android chỉ khai `COARSE`, được test pin giữ; iOS `NSLocationDefaultAccuracyReduced`): với vị trí thô, phần lớn lượt "Đã đến" sẽ đi đường `force`. Có xin quyền chính xác không?
9. Chữ xin quyền vị trí iOS "Vị trí không được lưu lên máy chủ" sai với Live Shutter (presence lưu vị trí): cần chữ mới trước khi bật tính năng.
10. Khi thợ đang có việc mà nhận lời mời khác, server trả `already_assigned` và app nói "Khách đã chọn được người khác": nên nói "Bạn đang có việc" và mở việc đó?
11. Đã đến thì thợ không còn "Huỷ việc" (chỉ "Khách không có mặt" hoặc hỗ trợ), dù domain vẫn cho huỷ ở `arrived`: có thêm nút không?

## Hoãn

Từ plan:
- App khách S13.01–S13.08 (phía khách), lối vào ở S02.01/S02.06, bật cờ → plan khách (#140 PR 2; bật cờ ở #202).
- Tổ chức trung gian thanh toán thật (#129) và chọn tài khoản nhận hoàn S22.04 (#141); tiền chụp ngay trên đường giả ở #202.
- Thả hai mốc cho chụp ngay và đánh giá sau chụp ngay (#130); khiếu nại trong 24 giờ (S18, #142).
- Presence và chia sẻ vị trí nền (foreground service Android `location`, chế độ nền iOS), hỏi "Vẫn muốn nhận việc?", nhắc pin, lời mời toàn màn có chuông.
- Bản đồ tile thật, ETA theo tuyến đường, gợi ý địa chỉ/geocoding.
- Thời gian có người nhận theo khu; hệ số cao điểm theo giờ; công cụ staff cho cấu hình chụp ngay và hoàn tiền kẹt (S23, #83).
- Gộp yêu cầu chụp ngay vào `bookings` (`source: instant`) và dịch vụ tự chạy của spec §5 (`services/dispatch`, backend Go #90); DDL `dispatch` của lược đồ quan hệ viết trước mô hình "match", cần chỉnh khi đó.
- Cloud Tasks cho hẹn giờ chính xác nếu bước 15 phút quá chậm khi đông.

Từ các task (nhỏ):
- Task 1: kiểm hình mock trong trình duyệt (dòng chỉ có khoảng trắng đã xoá ở 63abf340).
- Task 6: `checkPayment` của repository → #202 (Task 11). Task 5: chủ thể thu nhập `instant_request` → #202.
- Task 7: `position` và `lowAccuracyPosition` của gateway chồng nhau (heartbeat giữ `_lastPos`/`_lastWriteAt` cũ khi tắt: đã sửa ở a081ffdd).
- Task 9: vòng đếm buổi chụp hiện "38 phút / còn lại" thay vì "38:12" của mock (định dạng đồng hồ của `CountdownRing` sau); số tiền ở sheet "Khách không có mặt" tính lại 50% ở app (#202: lấy số của server); bản tính thử của sheet huỷ phía thợ chưa nối với chữ; `instant_job_screen.dart` ~850 dòng; cấp lại quyền vị trí chỉ chạy lại khi app `resumed` hoặc trạng thái đổi.
- (Đã xong ở rà soát cuối: chú thích mock S14.03 ghi 16 giây, sổ S17 trỏ tới khoá chống trùng mới, chú thích `route_tracker.dart` ≤ 80 cột — 63abf340, a081ffdd.)

Từ rà soát cuối (giữ hoãn):
- Server: presence cũ (quá 30 phút) vẫn chiếm chỗ trong 50 kết quả mỗi ô của truy vấn gần; thêm cận `heartbeatAt` hoặc tự tắt presence cũ sau. Gợi ý ứng viên không qua cổng nhận đơn (mời và nhận đã từ chối: chỉ phí một chỗ trong lượt). `createInstantRequest` tìm ứng viên trước khi xét khoá khách (chỉ tốn đọc).
- App: định dạng vòng đếm của Task 9 ("38 phút" thay "38:12"); số 50% ở sheet "Khách không có mặt" tính ở app (#202 lấy số của server); bản tính thử của sheet huỷ chưa nối với chữ; `instant_job_screen.dart` ~850 dòng; cấp lại quyền vị trí chỉ chạy lại khi `resumed` hoặc trạng thái đổi; `position`/`lowAccuracyPosition` của gateway chồng nhau.

Đợt rà soát cuối (kết quả):
- Task 4: CLI `offer` để lại một yêu cầu đang chạy khi bị từ chối (huỷ nó hoặc in gợi ý) — _kết quả: đã sửa ở f418d184: `npm run instant` gọi `cancelInstantRequest` của khách khi thợ không có trong ứng viên hoặc bị từ chối lúc mời, in trạng thái; 2 test mới trong `instant_cli.test.ts`._
- Task 4: các callable ghi `errorKind(e)` như hàm cùng loại — _kết quả: giữ hoãn; log hiện chỉ có mã và tên lỗi (không lộ dữ liệu), đổi cho đồng bộ khi dọn log chung._
- Task 4: `findDue` bỏ qua việc đọc `private/dispatch` — _kết quả: giữ hoãn; tối đa 100 lần đọc nhỏ mỗi 15 phút, chi phí không đáng kể._
- Task 4: test đơn vị cho việc gỡ khoá khách qua settle-abandon trong `create` và qua `runInstantSweep` — _kết quả: giữ hoãn; rà soát đã lần theo mã và thấy đúng (khoá gỡ trong cùng giao dịch kết thúc yêu cầu)._
- Task 4: `setLock` dùng đồng hồ được tiêm — _kết quả: giữ hoãn; `Timestamp.now()` chỉ cho `updatedAt` của khoá, không quyết định gì (ghi để biết)._
- Task 8: mở lạnh khi offline với cache rỗng đứng mãi ở skeleton (không có snapshot server, không nút Back) — _kết quả: đã sửa ở a081ffdd: giữ 2 giây chờ thẻ, thêm hẹn 10 giây; danh sách chưa tải được thì rời về `/work/instant` với "Mất kết nối. Thử lại nhé."; test mới trong `offer_screen_test.dart`._
