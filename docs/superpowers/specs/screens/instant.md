# Chụp ngay (S13–S14)

Màn của use case S13 (khách) và S14 (thợ ảnh) trong [`../2026-10-01-instant-booking-design.md`](../2026-10-01-instant-booking-design.md) (gọi là "spec Chụp ngay"; luồng §2, trạng thái và lời mời §3, tiền §4, giai đoạn 1 ở hộp đầu §5, vị trí §9). Mẫu mục và quy ước chung ở [`README.md`](README.md). Mock: `docs/design/ui-mock.html`, khung phía thợ `#S06.01-instant`, `#S13.04-provider`, `#S13.08-provider`, `#S14.01`, `#S14.01-terms`, `#S14.01-locked`, `#S14.02`, `#S14.03`, `#S14.03-arrived`, `#S14.03-shooting`, `#S14.03-done`; phía khách `#S02.01-instant`, `#S02.06-instant`, `#S13.01`, `#S13.01-noloc`, `#S13.02`, `#S13.02-summary`, `#S13.02-round`, `#S13.02-empty`, `#S13.03`, `#S13.04`, `#S13.05`, `#S13.05-arrived`, `#S13.05-stale`, `#S13.06`, `#S13.06-confirm`, `#S13.06-done`, `#S13.07`, `#S13.08`, `#S13.08-done`. Plan phía thợ: [`../../plans/2026-10-07-s13-s14-dispatch-provider.md`](../../plans/2026-10-07-s13-s14-dispatch-provider.md) (gọi là "plan", Decisions 1–31); sổ bàn giao [`../../handover/ledger-instant-dispatch-provider.md`](../../handover/ledger-instant-dispatch-provider.md). Plan phía khách: [`../../plans/2026-10-07-s13-instant-customer.md`](../../plans/2026-10-07-s13-instant-customer.md) (gọi là "plan khách", Decisions 1–14); sổ bàn giao [`../../handover/ledger-instant-customer.md`](../../handover/ledger-instant-customer.md).

Phần thợ ảnh dưới đây mô tả **đúng như đã làm ở #140** (PR 1); mục "S13 khách" ở cuối (S13.01–S13.08 phía khách, lối vào ở S02.01 và S02.06) mô tả đúng như đã làm ở #140 PR 2.

## Quy ước riêng của Chụp ngay (phía thợ)

- **Cờ tính năng**: `instantEnabledProvider` (mặc định `kInstantEnabled = false`) ẩn thẻ ở S06.01 và tắt heartbeat, bộ nghe lời mời; các route vẫn có và có test. #202 bật cờ khi có thanh toán; #140 không bao giờ bật.
- **Không có tiền ở #140**: mọi yêu cầu chưa trả (`paidAt` rỗng), mọi huỷ ghi số tiền 0. Chữ về tiền trên màn thợ ("Tiền chuyển cho bạn 24 giờ sau khi hoàn thành.", "Khách được hoàn 100%.", "Khách được hoàn 50%, bạn nhận {amount}.") là **chữ của trạng thái cuối** khi #202 có tiền (quyết định ở Task 1), giữ nguyên ở #140. Kênh gọi/Zalo/WhatsApp của khách bị khoá vì chưa trả: nút "Liên hệ" của mock không hiện, chỉ còn chat trong app.
- **Máy chủ là trọng tài**: mọi chuyển trạng thái là một callable (`setLiveShutter`, `saveInstantSettings`, `answerInstantOffer`, `updateInstantJob`, `cancelInstantRequest`, `tickInstantRequest`); app chỉ ghi trực tiếp hai thứ: heartbeat của presence và điểm vị trí khi đang đến. Đồng hồ máy chủ quyết định hết hạn (nhận ở giây 60,5 là `offer_expired`).
- **Chỉ ở tiền cảnh** (Decision 10, 11): không foreground service, không vị trí nền, không full-screen intent. App ở nền: heartbeat và việc chia sẻ vị trí dừng; lời mời vẫn tới bằng push trong 30 phút sau heartbeat cuối.
- **Lỗi thao tác**: toast một dòng: `instantErrorNetwork` "Mất kết nối. Thử lại nhé." khi mất mạng, còn lại `instantErrorGeneric` "Chưa thực hiện được. Thử lại nhé."; vài mã có chữ riêng (ghi ở từng màn).
- **Chuỗi**: khoá ARB của Chụp ngay không theo tiền tố `sNN_` (đặt theo plan): `instant*`, `liveShutter*`, `helpReady*`, `priceList*`, `offer*`, `match*`, `job*`, `providerCancel*`, `map*`.
- **Phân tích**: chưa ghi sự kiện riêng ở #140 (chỉ quy ước chung).

---

## S06.01 · Thẻ Live Shutter ở Công việc (biến thể `#S06.01-instant`)

- **Thông tin**: `/bookings` (tab Công việc) · thợ ảnh · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), ẩn khi cờ tắt.
- **Mục đích**: vào Live Shutter và quay lại việc chụp ngay đang làm.
- **Điểm vào → ra**: đầu danh sách Công việc → thẻ Live Shutter mở S14.01 (`/work/instant`); thẻ việc mở S14.03 (`/work/instant/{id}`).
- **Bố cục**: `LiveShutterCard`: thẻ nổi (mock `.card.hi`) với ô biểu tượng `AppIcons.instant` (bolt), "Live Shutter" và dòng trạng thái, mũi tên; dưới đó, khi có việc đang làm, thẻ kính: avatar khách, "Việc chụp ngay · {tên}", "{kiểu chụp} {thời lượng} · {điểm hẹn}", `StatusBadge` trạng thái.
- **Dữ liệu**: `livePresenceProvider` (presence của mình), `myActiveInstantJobProvider` (yêu cầu `active` có `photographerId` = mình).
- **Trạng thái**: đang tải → skeleton thẻ 64; lỗi đọc presence → thẻ không có dòng trạng thái (vẫn mở S14.01, màn đó nói lỗi); không có việc → không có thẻ việc.
- **Chuỗi**: `liveShutterTitle` "Live Shutter", `liveShutterCardOn` "Đang bật · nhận lời mời ở gần bạn", `liveShutterCardOff` "Đang tắt · bật để nhận việc chụp ngay", `liveShutterJobTitle` "Việc chụp ngay · {name}", `liveShutterJobMeta` "{service} · {place}", nhãn trạng thái `instantStatusAssigned` "Đã nhận", `instantStatusEnRoute` "Đang đến", `instantStatusArrived` "Đã đến", `instantStatusInProgress` "Đang chụp", `instantStatusFinished` "Chờ khách xác nhận". Mock: "Việc chụp ngay · Lan Anh", "Chân dung 1 giờ · Công viên Tao Đàn", "Đang đến".
- **Chấp nhận**: cờ tắt thì không có thẻ và không nghe gì; dòng trạng thái đổi ngay khi bật/tắt ở S14.01.

## S14.01 · Live Shutter (bật/tắt, bảng giá)

- **Thông tin**: `/work/instant` · thợ ảnh (vai khác bị chuyển đi) · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)). Mã gắn nhãn `terms` / `locked` theo trạng thái (mock `#S14.01-terms`, `#S14.01-locked`).
- **Mục đích**: đồng ý bảng giá của nền tảng và bật nhận lời mời ở gần.
- **Điểm vào → ra**: thẻ S06.01, thông báo `instant_missed`, đường quay về của S14.02/S14.03 → Back (không có trang dưới thì về `/bookings`); "Thêm số" → `/profile/phone?returnTo=/work/instant`; "Mở cài đặt" → cài đặt vị trí của máy.
- **Bố cục** (theo mock): thanh "Chụp ngay" có Back; thẻ nổi "Live Shutter" + dòng mô tả + công tắc; (khi bị khoá) thẻ "Chưa bật được Live Shutter" mỗi điều kiện một hàng (ô biểu tượng, chữ, nút viền nhỏ nếu app làm được: "Thêm số", "Mở cài đặt", "Đồng ý bảng giá"); (khi đã đồng ý bảng giá và không bị khoá) thẻ "Sẵn sàng hỗ trợ" + công tắc; tiêu đề mục "Bảng giá gói" + "Bản {n} · đã đồng ý / chưa đồng ý"; mỗi gói một hàng: "{thời lượng} · {số ảnh} ảnh", "Khách trả {giá}" bên trái, "Bạn nhận" + số bên phải (số ngắn kiểu S06.05: "390K", "1,19M"); ghi chú cuối; chân màn:
  - đang bật: nút viền "Tắt khi xong việc hôm nay";
  - chưa đồng ý bản hiện hành (`terms`): nút chính "Đồng ý bảng giá", ghi chú là `priceListTermsNote`;
  - bị khoá (`locked`): **không có ghi chú và không có nút ở chân màn** (mock thắng plan); khi bảng giá cũng chưa đồng ý, nó là một hàng lý do có nút nhỏ "Đồng ý bảng giá";
  - đang tắt, đủ điều kiện: không có nút ở chân (công tắc là hành động).
- **Dữ liệu**: `liveShutterControllerProvider` (`AsyncNotifier`): đọc `instantConfigProvider`, `livePresenceProvider`, gọi `setLiveShutter(online: true, dryRun: true)` khi mở để lấy lý do của server, cộng lý do vị trí của app (quyền bị từ chối hẳn hoặc tắt dịch vụ vị trí). Presence đổi thì màn đổi theo. "Bạn nhận" = `InstantConfig.earningOf(giá)` (phí nền tảng `platformFeeBp`, giai đoạn 1 là 0 nên hai số bằng nhau; 312K/552K/952K của mock là số ví dụ).
- **Trạng thái**:
  - **Khoá** (công tắc vô hiệu): `not_accepting_orders` (chưa xác minh hoặc hồ sơ chưa xong), `phone_required`, quyền vị trí bị từ chối hẳn hoặc tắt vị trí. Ngoài vùng có Chụp ngay (`outside_service_area`) **được liệt kê nhưng không khoá** (thợ có thể di chuyển; server vẫn từ chối khi bật). Đang bật thì không hiện thẻ lý do.
  - **Chưa đồng ý bảng giá** (`terms`): công tắc vô hiệu tới khi đồng ý bản hiện hành; bảng giá đổi bản thì hỏi lại. Bảng giá chỉ là một hàng lý do khi đi cùng lý do khác.
  - Đang gọi: mọi nút chờ (`AppButton.loading`), không gọi chồng.
  - Đang tải: skeleton (thẻ 76, thẻ 68, dòng, 3 hàng giá); lỗi tải: `ErrorState` "Thử lại" (tải lại cấu hình và màn).
- **Tương tác**:
  - Bật: hỏi quyền vị trí nếu chưa hỏi hoặc mới từ chối một lần → lấy một vị trí tiết kiệm pin (`currentFix()`, kèm sai số thật) → `setLiveShutter(online: true, location)`. Bị từ chối hẳn: thêm hàng lý do vị trí, công tắc vẫn tắt. Không lấy được vị trí: toast `liveShutterReasonLocation`. Server trả lý do: hiện các hàng, công tắc tắt. Bật thành công lần đầu trong phiên: hỏi quyền thông báo bằng `PhotographerPrimer` (S17.03).
  - Tắt (công tắc hoặc "Tắt khi xong việc hôm nay"): `setLiveShutter(online: false)`.
  - "Sẵn sàng hỗ trợ": `saveInstantSettings(helpReady)`.
  - "Đồng ý bảng giá": `saveInstantSettings(acceptPriceListVersion: bản đang hiện)`; server có bản mới hơn (`price_changed`) thì tải lại cấu hình để hiện bản mới, kèm toast lỗi chung.
  - Quay lại từ Cài đặt (app `resumed`): đọc lại quyền vị trí.
- **Chuỗi**: `instantTitle` "Chụp ngay", `liveShutterTitle` "Live Shutter", `liveShutterBody` "Nhận lời mời ở gần bạn. Vị trí được dùng khi bật.", `helpReadyTitle` "Sẵn sàng hỗ trợ", `helpReadyBody` "Được ưu tiên mời cả việc gấp, xa hơn một chút.", `priceListTitle` "Bảng giá gói", `priceListAccepted` "Bản {version} · đã đồng ý", `priceListNotAccepted` "Bản {version} · chưa đồng ý", `instantPackageLabel` "{duration} · {photos} ảnh" (với `instantDurationMinutes` "{n} phút" / `instantDurationHours` "{n} giờ"), `priceListCustomerPays` "Khách trả", `priceListYouGet` "Bạn nhận", `priceListTermsNote` "Giá do nền tảng đặt, giống nhau cho mọi nhiếp ảnh gia trong một lượt gợi ý. Đồng ý để bật Live Shutter.", `priceListAccept` "Đồng ý bảng giá", `liveShutterNote` "Không mở app trong 30 phút thì tạm ngừng nhận lời mời; mở lại app là nhận tiếp. Huỷ sau khi nhận làm giảm điểm tin cậy.", `liveShutterOffToday` "Tắt khi xong việc hôm nay", `liveShutterLockedTitle` "Chưa bật được Live Shutter", `liveShutterReasonNotAccepting` "Hoàn tất xác minh và hồ sơ để nhận đơn", `liveShutterReasonPhone` "Thêm số điện thoại", `liveShutterReasonPriceList` "Đồng ý bảng giá gói", `liveShutterReasonOutside` "Bạn đang ở ngoài khu vực có Chụp ngay", `liveShutterReasonLocation` "Cho phép dùng vị trí để nhận lời mời ở gần", `liveShutterAddPhone` "Thêm số", `liveShutterOpenSettings` "Mở cài đặt".
- **Chấp nhận**: không bật được khi còn lý do khoá hoặc chưa đồng ý bản hiện hành; hàng "Hoàn tất xác minh và hồ sơ để nhận đơn" không có nút (câu hỏi cho chủ dự án: có nên mở S21.02); công tắc đọc màn hình theo tên thẻ; "Bạn nhận" luôn bằng số mà chi trả sẽ trả.

## S14.02 · Lời mời chụp ngay

- **Thông tin**: `/work/instant/offer/:offerId` · thợ ảnh · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)).
- **Mục đích**: nhận hoặc từ chối tối đa 3 lời mời trong 60 giây; ai nhận trước thì được việc.
- **Điểm vào → ra**: lời mời mới khi app ở tiền cảnh và Live Shutter bật (`InstantOfferListener` tự mở); chạm push lời mời (`openNotificationTarget`). Nhận thắng → S13.04 trên chính màn này → S14.03 **thay** S14.02 (`pushReplacement('/work/instant/{requestId}')`, không có query; Back từ S14.03 không về lời mời). Hết lời mời → Back về nơi mở (hoặc S14.01 nếu không có trang dưới).
- **Bố cục** (theo mock): thanh giữa "Lời mời chụp ngay" + dòng phụ "{n} lời mời đang chờ", không có nút Back; `CountdownRing` 96dp của thẻ trên cùng (60 giây, đếm theo `expiresAt` của server, đơn vị "giây" do vòng tự vẽ); số tiền thợ nhận (chữ display lớn, số đều) và "Bạn nhận · {kiểu chụp} {thời lượng} · {số ảnh} ảnh"; `OfferStack`: thẻ trên đầy đủ, mép tối đa hai thẻ sau lộ phía trên; thẻ: ô biểu tượng vị trí, **khu** (in đậm) và "{km} · khoảng {phút} phút · địa chỉ hiện khi bạn nhận" (không bao giờ có điểm hẹn), "Khách đã chọn bạn trong **{n}** người. Ai nhận trước sẽ được việc." (không nêu tên ai), ghi chú của khách trong ngoặc kép, nghiêng; chân: nút viền "Từ chối" (34%) + nút chính "Nhận việc" cao 56dp (66%).
- **Dữ liệu**: `pendingOffersProvider` (các lời mời `pending` của mình, hạn gần trước), qua `settledPendingOffers` của adapter: danh sách rỗng từ cache bị giữ lại tới khi server trả lời một lần (mở lạnh từ push); `offerControllerProvider(OfferScreenKey)`: mỗi S14.02 trên stack có bộ điều khiển riêng (không dùng chung thẻ đã bỏ hay lệnh đang chạy).
- **Thứ tự thẻ**: lời mời đã mở màn đứng đầu khi còn chờ, sau đó theo hạn gần nhất. Lời mời quá `expiresAt` biến khỏi chồng ngay cả trước khi server ghi `expired` (hẹn giờ theo hạn gần nhất).
- **Trạng thái**:
  - Đang tải hoặc mở lạnh chưa thấy thẻ nào: skeleton (vòng, hai dòng, thẻ 150). Chỉ nói "Lời mời đã hết hạn" khi đã từng thấy thẻ hoặc sau **2 giây** chờ (mở lạnh không báo hết hạn sai vì cache rỗng).
  - Đang nhận: **thẻ giữ nguyên** tới khi callable trả lời (server rút mọi lời mời khác của mình trước khi trả lời, nên luồng lời mời có thể rỗng sớm); mọi nút chờ, nút đang chạy hiện loader.
  - Hết thẻ (đã trả lời hết, hết hạn): rời màn; toast "Lời mời đã hết hạn" chỉ khi chưa từng thấy thẻ.
  - Lỗi tải: `ErrorState` "Thử lại".
- **Tương tác**:
  - "Nhận việc": `answerInstantOffer(accept)`. Thắng → đọc yêu cầu (tối đa 5 giây) để lấy tên khách, ảnh và điểm hẹn cho S13.04; đọc không kịp → vào thẳng S14.03. Thua: `already_assigned` → toast "Khách đã chọn được người khác" và bỏ thẻ; `offer_expired` → "Lời mời đã hết hạn", bỏ thẻ; `not_accepting_orders` → "Bạn chưa nhận đơn được lúc này"; `blocked` → toast lỗi chung và bỏ thẻ (không nói ai chặn ai); lỗi khác → toast, thẻ giữ.
  - "Từ chối": từ chối ngay, không hỏi lý do (Decision 25); lời mời đã hết hạn hoặc đã có người nhận thì bỏ thẻ lặng lẽ.
  - Chỉ một S14.02: bộ nghe không mở thêm khi đã có một S14.02 ở bất kỳ đâu trong stack (màn đang mở tự xếp thẻ mới); push lời mời thứ hai khi S14.02 đang ở trên cùng thì **thay** màn đó; một lời mời chỉ tự mở một lần (Back không mở lại).
- **Chuỗi**: `offerTitle` "Lời mời chụp ngay", `offerPendingCount` "{n} lời mời đang chờ", `offerYouGet` "Bạn nhận · {genre} {duration} · {photos} ảnh", `offerDistance` "{distance} · khoảng {minutes} phút · địa chỉ hiện khi bạn nhận", `offerChosenAmong` "Khách đã chọn bạn trong {n} người. Ai nhận trước sẽ được việc.", `offerNote` "\"{note}\"", `offerDecline` "Từ chối", `offerAccept` "Nhận việc", `offerAlreadyAssigned` "Khách đã chọn được người khác", `offerExpired` "Lời mời đã hết hạn", `offerNotAccepting` "Bạn chưa nhận đơn được lúc này", kiểu chụp `instantGenrePortrait` "Chân dung", `instantGenreCouple` "Cặp đôi", `instantGenreFamily` "Gia đình", `instantGenreEvent` "Sự kiện nhỏ", `instantGenreProduct` "Sản phẩm". Push lời mời (server, không có dòng hộp thư): "Lời mời chụp ngay" / "{kiểu chụp} {thời lượng} · {khu} · bạn nhận {số tiền}. Còn 60 giây."
- **Chấp nhận**: hai thợ cùng bấm thì chỉ một người thắng (giao dịch trên yêu cầu và presence); thẻ không bao giờ hiện điểm hẹn; màn không trắng trong lúc nhận; mở từ push không báo hết hạn sai; không có hai S14.02 chồng nhau.

## S13.04 · Đã match (phía thợ, `#S13.04-provider`)

- **Thông tin**: không có route; hiện trên S14.02 sau khi nhận thắng · thợ ảnh · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), mã S13.04 nhãn `provider`. Phía khách ở mục S13.04 của "S13 khách".
- **Mục đích**: khoảnh khắc ngắn "đã match", rồi sang việc.
- **Bố cục**: `MatchOverlay` trên nền aurora: máy ảnh một nét, hai avatar (của mình từ hồ sơ, của khách) đáp vào ống kính, "Đã match với {tên}" (tên màu `primary`), dòng phụ, nút "Tiếp tục".
- **Tương tác**: tự sang S14.03 sau khoảng 3 giây hoặc khi bấm "Tiếp tục" (S14.03 thay S14.02); chạm bất kỳ đâu nhảy tới khung cuối; giảm chuyển động thì hiện ngay khung cuối. Nơi chờ là tên điểm hẹn khách gõ, không có thì khu.
- **Chuỗi**: `matchTitle` "Đã match với {name}", `matchBodyPhotographer` "{name} đang chờ ở {place}. Tiếp tục để xem đường đi.", `matchContinue` "Tiếp tục".
- **Chấp nhận**: chỉ hiện một lần, trên S14.02 (S14.03 không bao giờ hiện lớp phủ); không tên khách thì bỏ qua lớp phủ.

## S14.03 · Việc chụp ngay (đang đến, đã đến, đang chụp, chờ khách)

- **Thông tin**: `/work/instant/:id` · thợ ảnh đã nhận · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)). Mã gắn nhãn `arrived`, `shooting`, `done` theo trạng thái (mock `#S14.03-arrived`, `-shooting`, `-done`).
- **Mục đích**: tới điểm hẹn, đánh dấu từng mốc, chụp xong và chờ khách xác nhận.
- **Điểm vào → ra**: S13.04/S14.02, thẻ việc ở S06.01, thông báo `instant_cancelled` của thợ. Yêu cầu không còn là của mình (thợ huỷ, quay về `choosing`…) → về S14.01. "Về Công việc" và Back khi không có trang dưới → `/bookings`. Biểu tượng chat ở thanh → `/chat/{chatId}` (chat booking của cặp, tạo khi nhận việc). "Huỷ việc" → S13.08.
- **Bố cục chung**: thanh: tiêu đề trạng thái + dòng phụ "{tên khách} · {kiểu chụp} {thời lượng}", nút chat (vô hiệu khi chưa có `chatId`); chân màn một nút.
- **Đang đến** (`assigned`, `en_route`; mock `#S14.03`):
  - `MapPreview` cao 150: ghim tên khách tại điểm hẹn và ghim **"Bạn"** (`self`, xanh) ở vị trí mới nhất, đường chấm giữa hai ghim khi đã có vị trí. Không có nút "Về vị trí của tôi" (bản đồ luôn vừa cả hai ghim).
  - Thẻ điểm hẹn: tên điểm hẹn (đậm), "{khu} · {km} km" (chỉ "{khu}" khi chưa có vị trí), nút viền nhỏ "Chỉ đường" (mở `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}`, ứng dụng bản đồ bất kỳ; mở không được → toast `contactOpenError`). Nút "Liên hệ" của mock **không hiện** khi chưa trả (mọi việc của #140; `CustomerContactDial` chỉ hiện khi có bản sao liên hệ).
  - `StatusTimeline`: "Đã nhận · {giờ}" (xong), "Đã đến (bật khi còn cách 200 m)" (đang), "Bắt đầu chụp · Hoàn thành" (sắp).
  - Ghi chú `jobLocationNote`, hoặc khi thiếu quyền vị trí: `jobLocationNeeded` + nút chữ "Cho phép" (còn hỏi được) hoặc "Mở cài đặt" (bị từ chối hẳn, tắt vị trí).
  - Nút chữ đỏ "Huỷ việc".
  - Chân: nút chính "Đã đến". Xa hơn 200 m với vị trí tốt (sai số ≤ 100 m): nút vô hiệu, trên nút là "Còn cách {khoảng cách}. Tới gần hơn để bấm Đã đến." ("350 m" dưới 1 km, "1,4 km" từ 1 km).
- **Đã đến** (`arrived`; mock `#S14.03-arrived`): không có bản đồ (đã dừng chia sẻ); thẻ điểm hẹn "{khu} · điểm hẹn"; dòng thời gian "Đã nhận · {giờ}", "Đã đến · {giờ}", "Bắt đầu chụp · Hoàn thành" (đang); nút chữ đỏ "Khách không có mặt (sau mm:ss)" vô hiệu, đếm từng giây tới 15 phút sau lúc đến, rồi "Khách không có mặt"; **không có "Huỷ việc"** (mock); chân: "Bắt đầu chụp".
- **Đang chụp** (`in_progress`; mock `#S14.03-shooting`): `CountdownRing` 132dp tới `shootEndsAt` (tổng = thời lượng gói) và chữ "còn lại" dưới vòng (vòng hiện "38" + "phút"; dạng "38:12" của mock hoãn); thẻ khách: avatar, "{tên} · {kiểu chụp} {thời lượng}", "Bắt đầu {giờ} · {điểm hẹn}", nhãn "Đang chụp"; ghi chú `jobShootNote`; chân: "Hoàn thành". Vòng về 0 → `tickInstantRequest` (server chuyển `finished`).
- **Chờ khách / đã xong / kết thúc** (`finished`, `completed`, `cancelled_by_customer`, `no_show_customer`; mock `#S14.03-done`): `finished`: thẻ khách "Hoàn thành {giờ} · {điểm hẹn}" + nhãn vàng "Chờ khách", ghi chú `jobFinishedNote`; `completed`: cùng thẻ, không nhãn; khách huỷ: tiêu đề "Khách đã huỷ yêu cầu" và "Bạn nhận {số tiền} phí đi lại." khi có phí, nếu không "Không cần tới điểm hẹn nữa." (ở #140 luôn câu sau); không có mặt: tiêu đề "Khách không có mặt". Chân: nút viền "Về Công việc" (không có nút chính).
- **Dữ liệu**: `instantRequestProvider(id)` (realtime), `instantCustomerContactProvider(id)`, `instantJobControllerProvider(id)` (vị trí mới nhất trong bộ nhớ, quyền vị trí, lệnh đang chạy). `RouteTracker` chia sẻ vị trí.
- **Vị trí và chia sẻ** (Decision 11, chỉ khi màn mở và app ở tiền cảnh):
  - `assigned`: lấy một vị trí rồi `updateJob(start_route, location)` (server ghi điểm đầu vào `instant_tracks`); không có vị trí hoặc bị từ chối thì **thử lại mỗi 16 giây** chừng nào còn `assigned`.
  - `en_route`: `RouteTracker` lấy vị trí tiết kiệm pin mỗi **16 giây**, ghi `instant_tracks/{id}` khi đi ≥ 25 m hoặc sau 60 giây (không bao giờ dưới 16 giây; rules từ chối dưới 15 giây). Mỗi lần ghi bị từ chối không tính, lần sau thử lại. Không giữ gì ngoài điểm ghi cuối.
  - Quyền vị trí được **kiểm lại** ở mỗi lần đổi trạng thái và khi một lần lấy mẫu không có vị trí: mất quyền giữa đường thì dừng chia sẻ, xoá vị trí cũ khỏi bản đồ và nút, hiện `jobLocationNeeded`.
  - App xuống nền: dừng lấy mẫu và chia sẻ; lên lại: tiếp tục. Đang mở chat trên S14.03 vẫn chia sẻ (app vẫn ở tiền cảnh).
- **Tương tác**:
  - "Đã đến": một vị trí độ chính xác cao (`currentFix(highAccuracy: true)`, chỗ duy nhất dùng GPS cao). ≤ 200 m → `arrive` (nếu yêu cầu còn `assigned` thì gửi `start_route` cùng vị trí trước; `conflict` ở đó nghĩa là đã bắt đầu, đi tiếp). Xa hơn 200 m và sai số > 100 m → sheet "GPS chưa chính xác" ("Vị trí đang lệch khoảng {m} m. Xác nhận bạn đã tới điểm hẹn?", nút "Xác nhận đã đến" gửi `arrive(force: true)` kèm sai số thật, "Chờ GPS" đóng). Xa với sai số tốt → toast "Còn cách …". Không có vị trí → toast `jobLocationNeeded`. Tới nơi thì dừng chia sẻ ngay (server xoá `instant_tracks`).
  - "Bắt đầu chụp" → `start`; "Hoàn thành" → `finish` (từ lúc này thợ nhận lời mời mới được, không chờ khách xác nhận; hết giờ gói cũng vậy).
  - "Khách không có mặt" (sau 15 phút) → `ConfirmSheet` đỏ "Báo khách không có mặt?" / "Khách được hoàn 50%, bạn nhận {amount}." (số tính ở app = một nửa giá; #202 thay bằng số của server) → `no_show`; trước 15 phút server trả `deadline_passed`.
  - Lỗi các lệnh: toast lỗi chung, trạng thái giữ nguyên.
- **Chuỗi**: `jobTitleEnRoute` "Đang đến", `jobTitleArrived` "Đã đến", `jobTitleShooting` "Đang chụp", `jobTitleFinished` "Chờ khách xác nhận", `jobTitleCompleted` "Đã hoàn thành", `jobSubtitle` "{name} · {genre} {duration}", `jobDirections` "Chỉ đường", `jobDistanceLine` "{area} · {km} km", `jobMeetPointLine` "{area} · điểm hẹn", `jobStepAccepted` "Đã nhận · {time}", `jobStepArriveHint` "Đã đến (bật khi còn cách 200 m)", `jobStepArrived` "Đã đến · {time}", `jobStepShoot` "Bắt đầu chụp · Hoàn thành", `jobLocationNote` "Vị trí của bạn chỉ chia sẻ với khách trong lúc đang đến. Tới nơi là dừng.", `jobLocationNeeded` "Cho phép dùng vị trí để chia sẻ đường đi với khách.", `jobLocationAllow` "Cho phép", `jobArrive` "Đã đến", `jobArriveFar` "Còn cách {distance}. Tới gần hơn để bấm Đã đến.", `jobArriveForceTitle` "GPS chưa chính xác", `jobArriveForceBody` "Vị trí đang lệch khoảng {meters} m. Xác nhận bạn đã tới điểm hẹn?", `jobArriveForceConfirm` "Xác nhận đã đến", `jobArriveForceKeep` "Chờ GPS", `jobStart` "Bắt đầu chụp", `jobFinish` "Hoàn thành", `jobShootLeft` "còn lại", `jobShootNote` "Hết giờ gói hoặc bấm Hoàn thành, khách sẽ xác nhận.", `jobStartedLine` "Bắt đầu {time} · {place}", `jobFinishedLine` "Hoàn thành {time} · {place}", `jobWaitingBadge` "Chờ khách", `jobFinishedNote` "Khách xác nhận hoặc tự hoàn thành sau 2 giờ. Tiền chuyển cho bạn 24 giờ sau khi hoàn thành.", `jobBackToWork` "Về Công việc", `jobNoShow` "Khách không có mặt", `jobNoShowIn` "Khách không có mặt (sau {time})", `jobNoShowTitle` "Báo khách không có mặt?", `jobNoShowBody` "Khách được hoàn 50%, bạn nhận {amount}.", `jobNoShowConfirm` "Báo khách không có mặt", `jobNoShowKeep` "Chờ thêm", `jobCancel` "Huỷ việc", `jobCancelledTitle` "Khách đã huỷ yêu cầu", `jobCancelledFee` "Bạn nhận {amount} phí đi lại.", `jobCancelledNoFee` "Không cần tới điểm hẹn nữa.", `mapPinYou` "Bạn", `mapSemantics` "Bản đồ: {pins}", `workMessage` "Nhắn tin" (nút chat).
- **Chấp nhận**: vị trí chỉ được ghi khi `en_route`, ≤ 4 lần mỗi phút, dừng ngay khi tới nơi hoặc app xuống nền; "Đã đến" không bao giờ dùng một độ chính xác giả (máy chủ tin `accuracyM` của máy cho `force`); không có "Huỷ việc" từ lúc đã đến; một nút chính mỗi trạng thái.

## S13.08 · Huỷ việc (phía thợ, `#S13.08-provider`)

- **Thông tin**: sheet trên S14.03 · thợ ảnh đã nhận · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), mã S13.08 nhãn `provider`. Phía khách ở mục S13.08 của "S13 khách".
- **Mục đích**: huỷ một việc đã nhận khi biết rõ hậu quả trước.
- **Điểm vào → ra**: nút chữ đỏ "Huỷ việc" ở S14.03 khi `assigned` hoặc `en_route` (không có khi đã đến) → huỷ xong: đóng sheet, về S14.01; "Giữ việc", Back hoặc chạm ngoài: đóng, việc giữ nguyên.
- **Bố cục**: `showAppSheet`: "Huỷ việc chụp ngay?", câu hậu quả, nút đỏ "Huỷ việc" (`AppButton.danger`), nút chữ "Giữ việc".
- **Dữ liệu**: `providerCancelQuoteProvider(id)` = `cancelInstantRequest(dryRun: true)` chạy trước, sheet hiện nội dung khi có kết quả (loader nhỏ trong lúc chờ, lỗi có "Thử lại"). Câu hậu quả là chữ cố định (khách luôn được hoàn 100% khi thợ huỷ), chưa nối với số của bản tính thử (hoãn, #202).
- **Tương tác**: "Huỷ việc" → `cancelInstantRequest(dryRun: false)`; trong lúc chạy sheet không đóng được; lỗi hiện đỏ ngay trong sheet, sheet ở lại (việc vẫn là của thợ). Server: yêu cầu về `choosing` (khách chọn người khác, cửa sổ tìm 10 phút tính lại), thợ bị loại khỏi yêu cầu, `reliability.cancelled + 1`, bản sao liên hệ và vị trí bị xoá; khách nhận `instant_cancelled`.
- **Chuỗi**: `providerCancelTitle` "Huỷ việc chụp ngay?", `providerCancelBody` "Khách được hoàn 100%. Huỷ sau khi nhận làm giảm điểm tin cậy của bạn.", `providerCancelConfirm` "Huỷ việc", `providerCancelKeep` "Giữ việc".
- **Chấp nhận**: xác nhận là nút đỏ trong sheet, không bao giờ là nút gradient; không huỷ được khi đang chụp (server `conflict`).

## Nền: heartbeat, bộ nghe lời mời, mở từ push

- **Heartbeat** (`LiveShutterHeartbeat`, trong `TabShell`, chỉ thợ và khi cờ bật): khi Live Shutter bật và app ở tiền cảnh, lấy vị trí tiết kiệm pin mỗi 60 giây; ghi heartbeat ngay khi mở lại app, rồi khi đi > 300 m hoặc sau 5 phút; không bao giờ hai lần ghi cách nhau dưới 60 giây (rules). Không chạy nền: server ngừng gợi ý 30 phút sau lần ghi cuối, mở lại app là nhận tiếp.
- **Bộ nghe lời mời** (`InstantOfferListener`, cùng chỗ): chỉ nghe khi Live Shutter bật; lời mời mới khi app ở tiền cảnh mở S14.02 trừ khi đã có một S14.02 trong stack; mỗi lời mời tự mở một lần.
- **Push**: lời mời là push riêng kênh `default` ưu tiên cao (kể cả giờ yên lặng), không có dòng hộp thư; chạm mở `/work/instant/offer/{offerId}` (đường cho phép của S17). Hộp thư của thợ chỉ có `instant_missed` ("Bạn đã bỏ lỡ một lời mời" → S14.01) và `instant_cancelled` (→ S14.03).

---

## S13 khách

Mô tả **đúng như đã làm ở #140 PR 2** (plan khách Tasks 1–7). Dữ liệu và callable dùng chung với phía thợ (`InstantRepository` của PR 1: `config`, `createRequest`, `nextCandidates`, `invite`, `cancel`, `confirmComplete`, `tick`, `watchRequest`, `watchTrack`, `myActiveRequestId`).

### Quy ước riêng (phía khách)

- **Cờ tính năng**: lối vào ở S02.01/S02.06 chỉ hiện khi `instantEnabledProvider` bật **và** người dùng là khách; route `/instant` và `/instant/:id` có cùng chốt (`instantCustomerRedirect`: cờ tắt hoặc vai đã biết là thợ thì về `/home`; hồ sơ còn đang tải thì không chuyển, để link sâu và push mở lạnh vẫn tới đích). #140 không bật cờ; #202 bật.
- **Không có tiền ở #140**: "Gửi lời mời" gửi lời mời ngay ở mọi lượt, không bước thanh toán, không chọn phương thức. Các màn có hai nhánh theo `request.paid`: chưa trả (mọi yêu cầu của #140) thì không có câu tiền ("Bạn chưa thanh toán nên không có khoản tiền nào.", "Không có khoản tiền nào.", S13.03 và S13.07 không nói "tiền vẫn được giữ"); đã trả (từ #202; test chạy bằng dữ liệu giả) thì hiện số tiền giữ, hoàn và phí. "Giá vừa đổi … trước khi thanh toán" và "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận." giữ nguyên chữ của mock (đúng từ #202).
- **Một route, đổi theo trạng thái** (plan khách Decision 4): `/instant/:id` (`InstantFlowScreen`) nghe `instantRequestProvider(id)` và hiện `choosing`/`pending_payment` → S13.02, `searching` → S13.03, `assigned`/`en_route`/`arrived` → S13.05 (S13.04 trước đó khi vừa có người nhận), `in_progress`/`finished` → S13.06, `completed` → S13.06 `done`, `no_match` → S13.07, `cancelled_by_customer`/`abandoned`/`no_show_customer` → S13.08 `done`. Đang tải: `SignatureLoader` (sóng lan) trong khung "Chụp ngay" có Back; lỗi: `ErrorState` "Thử lại"; không đọc được (không còn, không phải của mình): "Không tìm thấy yêu cầu" + "Về trang chủ". Yêu cầu kết thúc hoặc biến mất thì thẻ ở Trang chủ đọc lại (`instantActiveRequestIdProvider`).
- **Hẹn giờ** (Decision 6, `InstantTickScheduler` + `instantTickDeadlines`): màn gọi `tickInstantRequest` đúng một lần mỗi mốc: 1 giây sau `expiresAt` muộn nhất của lời mời đang chờ và ở `searchDeadlineAt` (`searching`); ở `searchDeadlineAt` (`choosing` đã gửi lời mời); ở `shootEndsAt` (`in_progress`); và một lần khi app quay lại tiền cảnh. Tick lỗi thì im lặng (ghi log), luồng nghe cho thấy sự thật. Đồng hồ là `clockProvider`.
- **Huỷ**: mọi nút Huỷ là chữ đỏ mở S13.08 (sheet, không route riêng; `/instant/:id/cancel` của spec không thêm); xác nhận là nút đỏ trong sheet; số tiền chỉ lấy từ bản tính thử của server.
- **Riêng tư** (spec §9): vị trí của khách chỉ gửi một lần khi tạo yêu cầu (điểm hẹn), không bao giờ chia sẻ trực tiếp. Ghim của thợ chỉ hiện khi `en_route`.
- **Lỗi thao tác**: toast một dòng (`instantErrorText`), như phía thợ.

## S02.01 · Thẻ Chụp ngay ở Trang chủ (biến thể `#S02.01-instant`)

- **Thông tin**: `/home` · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), ẩn khi cờ tắt hoặc là thợ.
- **Mục đích**: vào Chụp ngay, hoặc quay lại yêu cầu đang mở.
- **Điểm vào → ra**: giữa dòng chào và hàng chip; chạm → `/instant` (S13.01), hoặc `/instant/{id}` khi có yêu cầu đang mở.
- **Bố cục**: `InstantEntryCard`: thẻ nổi (mock `.card.hi`) với ô biểu tượng `AppIcons.instant` (bolt), "Chụp ngay" + "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút", mũi tên; có yêu cầu đang mở thì "Yêu cầu chụp ngay đang mở" + "Chạm để xem tiếp".
- **Dữ liệu**: `instantActiveRequestIdProvider` (một lần `get` khi thẻ hiện, không nghe trực tiếp; đọc lại khi tạo yêu cầu, khi yêu cầu kết thúc và khi kéo làm mới Trang chủ). Ẩn thì không đọc gì.
- **Trạng thái**: đọc lỗi → thẻ vào thường (S13.01).
- **Chuỗi**: `instantTitle`, `instantCardBody`, `instantCardResumeTitle`, `instantCardResumeBody`.
- **Chấp nhận**: cờ tắt hoặc là thợ thì không có thẻ và không gọi repository.

## S02.06 · Nút Chụp ngay ở Tìm thợ ảnh (biến thể `#S02.06-instant`)

- **Thông tin**: `/action` · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), ẩn khi cờ tắt.
- **Bố cục**: `InstantFindButton`: nút viền nhỏ có bolt "Chụp ngay · tới trong 30–90 phút", giữa hàng chip/sắp xếp và dòng đếm kết quả.
- **Tương tác**: chạm thì đọc `myActiveRequestId()` một lần (không đọc khi mở Tìm thợ) → có yêu cầu đang mở thì `/instant/{id}`, không thì `/instant` (chú thích mock).
- **Chuỗi**: `instantFindButton`.

## S13.01 · Chụp ngay: gói, kiểu chụp, điểm hẹn

- **Thông tin**: `/instant` · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)). Mã gắn nhãn `noloc` khi chưa có vị trí (mock `#S13.01-noloc`).
- **Mục đích**: chọn gói, kiểu chụp, đặt tên điểm hẹn tại vị trí hiện tại, rồi xem người phù hợp.
- **Điểm vào → ra**: S02.01, S02.06, "Tạo yêu cầu mới" của S13.08 `done` → tạo xong: `/instant/{id}` (S13.02; `go`, form không nằm dưới); chưa có số điện thoại → `/profile/phone?returnTo=/instant` (S04.05) rồi quay lại với nháp còn nguyên; đã có yêu cầu đang mở (`conflict`) → toast "Bạn đang có một yêu cầu chụp ngay." và mở yêu cầu đó; "Đặt lịch thường" → `/action`.
- **Bố cục** (theo mock): thanh "Chụp ngay" + "Nhiếp ảnh gia tới trong 30–90 phút" có Back; `MapPreview` cao 170, một ghim (`self`) "Vị trí của bạn" khi chưa gõ tên, "Điểm hẹn · {tên}" khi đã gõ, nút "Về vị trí của tôi" lấy vị trí mới; ba ô gói (thời lượng đậm, "{n} ảnh", giá ngắn "390K"/"1,19M"; ô chọn viền primary, nền `primarySubtle`; mặc định gói 1 giờ); năm chip kiểu chụp theo thứ tự mock (Chân dung, Cặp đôi, Gia đình, Sản phẩm, Sự kiện nhỏ; mặc định Chân dung); ô "Tên điểm hẹn" (≤ 80, bắt buộc), ô ghi chú (≤ 140, có bộ đếm); dòng lỗi vùng/tạm dừng (khi có); `EscrowNotice` ba vế (không cắt dòng); chân: nút chính "Xem nhiếp ảnh gia phù hợp".
- **Không có vị trí** (`#S13.01-noloc`): đĩa biểu tượng, "Bật vị trí để Chụp ngay", "Nhiếp ảnh gia cần biết bạn đang ở đâu để tới đúng chỗ.", nút chính "Cho phép vị trí" (hỏi quyền; bị từ chối hẳn → cài đặt của app; vị trí của máy tắt → cài đặt vị trí, `openLocationSettings`), nút chữ "Đặt lịch thường". Chụp ngay cần vị trí (plan khách Decision 3); quay lại app thì kiểm lại.
- **Dữ liệu**: `instantRequestControllerProvider` (`AsyncNotifier`: cấu hình `instantConfigProvider`, quyền và một vị trí tiết kiệm pin `currentFix()`, không GPS cao); `instantDraftProvider` (giữ sống: gói, kiểu chụp, tên điểm hẹn, ghi chú; giữ qua S04.05, xoá sau khi tạo xong và khi đổi tài khoản hoặc đăng xuất). Mở lần đầu chỉ hỏi quyền khi chưa từng hỏi.
- **Trạng thái**: đang tải → skeleton; lỗi cấu hình hoặc bảng giá rỗng → `ErrorState` "Thử lại"; đang tạo → nút chính chờ, không gọi chồng (rời màn giữa chừng vẫn xoá nháp).
- **Tương tác**: "Xem nhiếp ảnh gia phù hợp": thiếu tên → "Nhập tên điểm hẹn để nhiếp ảnh gia dễ tìm."; chưa có số (đọc số lỗi cũng coi là chưa có) → S04.05; rồi `createInstantRequest(packageCode, genre, lat, lng, tên điểm hẹn đã cắt khoảng trắng, ghi chú hoặc null)`. Server từ chối: `phone_required` → S04.05; `outside_service_area` → dòng "Chụp ngay chưa có ở khu vực này. Bạn có thể đặt lịch thường." + "Đặt lịch thường"; `not_eligible` → "Chụp ngay đang tạm dừng."; khi bị từ chối, bàn phím đóng và dòng lỗi được cuộn vào màn; lỗi khác → toast, form giữ nguyên.
- **Chuỗi**: `instantTitle`, `instantSubtitle`, `instantMeetPointPin` "Điểm hẹn · {name}", `instantMeetPointSelf` "Vị trí của bạn", `instantMeetPointLabel` "Tên điểm hẹn", `instantMeetPointHint` "Ví dụ: Cổng Trương Định, Công viên Tao Đàn", `instantMeetPointRequired`, `instantPhotosCount` "{n} ảnh", `instantNoteLabel` "Ghi chú cho nhiếp ảnh gia", `instantNoteHint`, `instantEscrowNote` "Xem 5 người phù hợp miễn phí. Chỉ trả khi gửi lời mời; tiền được giữ an toàn và hoàn 100% nếu bạn huỷ khi chưa có người nhận.", `instantSeeMatches`, `instantLocationTitle`, `instantLocationBody`, `instantLocationAllow`, `instantBookNormally`, `instantOutsideArea`, `instantDisabled`, `instantHasActive`, `mapRecenter`.
- **Chấp nhận**: không tạo yêu cầu khi thiếu tên, vị trí hoặc số điện thoại; nháp sống qua S04.05; vừa 320dp với chữ 1,3×.

## S13.02 · Vuốt chọn nhiếp ảnh gia

- **Thông tin**: `/instant/:id` khi `choosing` (và `pending_payment`, chỉ từ #202) · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)). Mã gắn nhãn `summary` (người đã chọn), `round` (hết lượt), `empty` (chưa có ai) (mock `#S13.02-summary`, `-round`, `-empty`).
- **Mục đích**: xem tối đa 5 người phù hợp của lượt, chọn một hay nhiều người, gửi lời mời.
- **Điểm vào → ra**: tạo yêu cầu ở S13.01; "Chọn thêm người" ở S13.07; thợ huỷ sau khi nhận (về `choosing`). Gửi lời mời thành công → S13.03 (cùng route). Back → trang dưới hoặc `/home` (yêu cầu vẫn mở); "Đặt lịch thường" → `/action`.
- **Bố cục chung**: thanh Back + "Chọn người bạn thích" + "{kiểu chụp} · {thời lượng} · {giá}" + bộ đếm "n / 5" (chỉ khi xem thẻ); khi yêu cầu đã gửi lời mời ít nhất một lần (`committed`), đã trả hoặc `pending_payment`: thêm chữ đỏ "Huỷ" ở thanh → S13.08 (mock `#S13.02-round`).
- **Bộ thẻ** (`SwipeDeck`): thẻ ảnh (chạm nửa trái/phải đổi ảnh, tối đa 3, gạch trên đầu thẻ; vuốt ngang là chọn/bỏ qua), tên + `VerifiedMark`, `MetaLine` [cà chua từ 5 đánh giá | "Mới · n đánh giá"] · "{n} buổi" · "đến khoảng {n} phút", tối đa 2 lý do; hàng người đã chọn (avatar chồng nhau, "Đã chọn n người", nút viền "Xong"); hàng nút Hoàn tác / ✕ / ♥ (nhãn đọc màn hình "Hoàn tác", "Bỏ qua", "Chọn người này"). Hết thẻ: có người được chọn → tóm tắt; không ai → nút chính "Xem 5 người khác" (bộ thẻ còn đó, Hoàn tác vẫn dùng được).
- **Tóm tắt** (`summary`): "Những người bạn đã chọn", mỗi người một hàng kính (avatar, tên, cà chua · ETA, chữ "Bỏ chọn" đọc là "Bỏ chọn {tên}"), lượt đầu (chưa `committed`, #202): "Phương thức thanh toán" + `PayMethodPicker` (Chuyển khoản QR chọn sẵn, MoMo, ZaloPay), `EscrowNotice` "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.", chân: nút chính "Thanh toán {giá} và gửi lời mời" (lượt sau: "Gửi lời mời", không có ô chọn; vô hiệu khi không còn ai) + chữ "Xem 5 người khác". Back (cả nút hệ thống) về bộ thẻ, giữ lịch sử Hoàn tác. `pending_payment` (#202): thẳng vào tóm tắt (nhãn `summary`) với người đang chờ (`pendingInviteIds`), ô chọn phương thức và "Thanh toán tiếp" (`choosePayContinue`); không "Bỏ chọn", không "Xem 5 người khác".
- **Hết lượt** (`round`: không còn ứng viên và lượt đã hết hoặc đã gửi lời mời): banner (vùng đọc trực tiếp) "Chưa ai nhận. Chọn thêm người nhé." trên bộ thẻ trống; mọi người được chọn đều bận lúc gửi thì banner là "{tên, tên} vừa nhận việc khác"; nút chính "Xem 5 người khác".
- **Chưa có ai** (`empty`: chưa gửi lời mời, không có ứng viên): đĩa `person_search`, "Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn", "Bạn chưa phải trả gì. Thử lại sau ít phút hoặc đặt lịch thường.", nút chính nhỏ "Thử lại", nút viền nhỏ "Đặt lịch thường".
- **Dữ liệu**: `chooseControllerProvider(id)` (ai được chọn/bỏ qua, chỉ ở máy tới khi gửi; lượt mới từ server thì làm lại từ đầu); `request.candidates` (tối đa 5).
- **Tương tác**: nút chính → `inviteInstant(liked, skipped, expectedAmountVnd, payMethod)` (`payMethod` chỉ ở lượt đầu; "Thanh toán tiếp" gửi lại `pendingInviteIds`, server dùng lại khoản đang mở), một lệnh mỗi lần (bấm hai lần chỉ gửi một); `price_changed` → giữ tóm tắt với giá mới; người bận lúc gửi → toast "{tên} vừa nhận việc khác".
- **Trả tiền (#202)**: lượt đầu nhận `InstantPaymentNeeded` → S04.04 chung của V1 ở `/instant/{id}/pay` (`InstantPay`; mã `S04.04` nhãn `instant`); lời mời chỉ đi khi tiền vào. Yêu cầu rời `pending_payment` → S04.04 về `/instant/{id}?paid=1` nếu đã trả (màn luồng hỏi `CustomerInstantPrimer` một lần rồi bỏ `?paid=1`), về `/instant/{id}` nếu hết hạn trả. Quay lại app khi `pending_payment` → `checkInstantPayment` một lần. "Xem 5 người khác" / "Thử lại" → `nextInstantCandidates(skipped)`. Lỗi → toast.
- **Chuỗi**: `chooseTitle`, `chooseSubtitle`, `chooseCounter`, `chooseStamp` "CHỌN", `chooseEta`, `chooseLike` "Chọn người này", `chooseSkip`, `chooseUndo`, `choosePicked`, `chooseDone`, `chooseSummaryTitle`, `chooseUnpick`, `chooseUnpickA11y`, `chooseInvite`, `chooseMore`, `chooseEscrow`, `chooseRoundEnded`, `chooseUnavailable`, `chooseEmptyTitle`, `chooseEmptyBody`, `chooseEmptyRetry`, `choosePriceChanged`, `trackingCancel` "Huỷ".
- **Chấp nhận**: nút ♥/✕/Hoàn tác luôn có (≥ 48dp); giảm chuyển động thì thẻ đổi tức thì; một lần bấm gửi một bộ lời mời; lượt sau không trả thêm.

## S13.03 · Đang chờ trả lời

- **Thông tin**: `/instant/:id` khi `searching` · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)).
- **Mục đích**: thấy từng người được mời đang xem lời mời và còn bao lâu.
- **Điểm vào → ra**: "Gửi lời mời" ở S13.02; có người nhận → S13.04 rồi S13.05; hết lượt → S13.02 `round`; hết 10 phút → S13.07; "Huỷ yêu cầu" → S13.08.
- **Bố cục** (theo mock): thanh giữa "Đang chờ trả lời", không Back; `SignatureLoader` sóng rung (chạy khi còn người đang xem); "Đã gửi lời mời cho {n} người" (chỉ đếm người nhận được lời mời của lượt này, không đếm hàng "Không tính"); "Ai nhận trước sẽ tới chỗ bạn. Mỗi lời mời còn **m:ss**." đếm tới `expiresAt` muộn nhất (0:00 khi không còn ai chờ); thẻ kính các hàng: avatar, tên, `MetaLine` (cà chua từ 5 đánh giá) · "khoảng {n} phút", hoặc "vừa nhận việc khác" cho người bận lúc gửi; nhãn trạng thái bằng chữ: "Đang xem" (đang chờ), "Đã từ chối", "Hết hạn" (hết hạn, bị rút), "Không tính" (bận); ghi chú; chân: chữ đỏ "Huỷ yêu cầu".
- **Đọc màn hình**: hàng đang chờ đọc "{tên} đang xem lời mời"; hàng khác "{tên}, {meta}, {trạng thái}"; một hàng chỉ được đọc lại khi trạng thái của nó đổi.
- **Chuỗi**: `waitingTitle`, `waitingSent`, `waitingBody`, `waitingRowEta`, `waitingRowUnavailable`, `waitingViewing`, `waitingDeclined`, `waitingExpired`, `waitingNotCounted`, `waitingRowSemantics`, `waitingNote` (đã trả: "… không trả thêm. Tiền vẫn được giữ …") / `waitingNoteUnpaid` "Chưa ai nhận thì bạn chọn tiếp trong 5 người khác." (chưa trả), `waitingCancel`.
- **Chấp nhận**: "Hết hạn" đọc từ dữ liệu server; tick một lần mỗi mốc, không còn hẹn giờ sau khi rời màn.

## S13.04 · Đã match (phía khách, `#S13.04`)

- **Thông tin**: không có route; là một trạng thái của `/instant/:id`, hiện thay S13.05 tới khi đi tiếp · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), mã S13.04 không nhãn. Phía thợ ở mục S13.04 bên trên.
- **Khi nào**: màn thấy `searching → assigned` khi đang mở, hoặc mở (từ push) một yêu cầu `assigned` có `assignedAt` cách đây dưới 60 giây (plan khách Decision 5); ngoài ra vào thẳng S13.05. Một snapshot gộp `searching → en_route` không hiện lớp phủ.
- **Bố cục**: `MatchOverlay` trên nền aurora: avatar của khách và của thợ, "Đã match với {tên}", "{tên} đã nhận lời mời của bạn và đang chuẩn bị tới {điểm hẹn}, khoảng {n} phút." (không biết ETA thì bỏ phần phút), "Tiếp tục".
- **Tương tác**: "Tiếp tục", tự đi sau khoảng 3 giây, hoặc Back hệ thống → S13.05 (không rời yêu cầu). Yêu cầu rời các trạng thái đang đến (huỷ, đóng) thì lớp phủ biến mất.
- **Chuỗi**: `matchTitle`, `matchBodyCustomer`, `matchBodyCustomerNoEta`, `matchContinue`.

## S13.05 · Đang đến (bản đồ, ETA)

- **Thông tin**: `/instant/:id` khi `assigned`, `en_route`, `arrived` · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)). Mã gắn nhãn `arrived`, `stale` (mock `#S13.05-arrived`, `-stale`).
- **Mục đích**: biết ai đang tới, còn bao lâu, liên lạc, huỷ khi cần.
- **Bố cục**: `MapPreview` tràn viền cao 250: ghim "Bạn" (`self`) **tại điểm hẹn** (không bao giờ là vị trí trực tiếp của khách) và, **chỉ khi `en_route`**, ghim "{tên} · {n} phút" ở điểm vị trí mới nhất của thợ, đường chấm giữa hai ghim khi có điểm; "Về vị trí của tôi" đưa điểm hẹn về giữa bản đồ (không lấy vị trí). Thẻ thợ: avatar, tên, `MetaLine` [cà chua | "Mới · n đánh giá"] · "{n} buổi" · "đến trong khoảng **n phút**", nhãn trạng thái; ghi chú "Đối chiếu ảnh đại diện khi gặp. Vị trí của {tên} chỉ hiện trong lúc đang đến."; "Nhắn tin" → `/chat/{chatId}`; "Liên hệ" (`PhotographerContactAction`, mở khoá) **chỉ khi đã trả** (#140: không có); chữ đỏ Huỷ.
- **ETA** (Decision 7): `assigned` dùng `request.etaMinutes`; `en_route` tính lại từ mỗi điểm (đường thẳng `haversineKm` tới điểm hẹn → `estimateEtaMinutes`).
- **Trạng thái**: không có điểm mới trong 3 phút khi `en_route` → "Đang chờ cập nhật vị trí" (`stale`, ghim giữ ở điểm cuối); quá `lateDeadlineAt` mà chưa đến → dòng trễ ("{tên} đến trễ. Bạn có thể huỷ và được hoàn 100%." khi đã trả, "{tên} đến trễ. Bạn có thể huỷ yêu cầu." khi chưa) và "Huỷ (hoàn 100%)"; `arrived` → không ghim thợ, không ETA, "Đã đến điểm hẹn" + "{tên} đang chờ bạn ở {điểm hẹn}.". Lỗi nghe vị trí: ghi log, thử lại sau 10 giây, tối đa 3 lần liên tiếp; màn giữ trạng thái "chưa có điểm".
- **Nút Huỷ**: đã trả và còn trong 2 phút miễn phí → "Huỷ (miễn phí thêm m:ss)" rồi "Huỷ"; trễ → "Huỷ (hoàn 100%)"; còn lại "Huỷ". Đều mở S13.08.
- **Dữ liệu**: `instantRequestProvider(id)`, `instantTrackProvider(id)` (chỉ nghe khi `en_route`, đăng ký lại khi trạng thái đổi). Một hẹn giờ đánh thức màn ở mốc "chờ cập nhật"/trễ kế tiếp.
- **Chuỗi**: `trackingSelf` "Bạn", `trackingPin`, `trackingEta`, `trackingEtaBold`, `trackingNote`, `trackingMessage`, `trackingCancelFree`, `trackingCancel`, `trackingCancelLate`, `trackingStale`, `trackingLate`, `trackingLateUnpaid`, `trackingArrived`, `trackingArrivedBody`, `mapRecenter`.
- **Chấp nhận**: ghim thợ chỉ khi `en_route`; liên hệ chỉ khi có thợ (nút gọi chỉ khi đã trả); vị trí của khách không rời máy.

## S13.06 · Đang chụp, chờ xác nhận, đã xong

- **Thông tin**: `/instant/:id` khi `in_progress`, `finished` (nhãn `confirm`), `completed` (nhãn `done`) · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)) (mock `#S13.06`, `-confirm`, `-done`).
- **Đang chụp**: thanh giữa có nút chat, không Back; `CountdownRing` 132dp tới `shootEndsAt` + "còn lại"; thẻ "{tên} · {kiểu chụp} {thời lượng}", "Bắt đầu {giờ} · {điểm hẹn}", nhãn "Đang chụp"; `StatusTimeline` (Đã nhận · giờ, Đã đến · giờ, "Hoàn thành và giao {n} ảnh trong 48 giờ"); ghi chú; nút chính "Xác nhận hoàn thành". Giờ theo giờ Việt Nam.
- **Chờ xác nhận** (`finished`): "Chờ bạn xác nhận", "{tên} đã hoàn thành buổi chụp. Tự hoàn thành sau **h:mm:ss** nếu bạn không xác nhận." (đếm từng giây tới `finishedAt + 2 giờ`; về 0 thì chờ bước 15 phút của server), cùng nút chính.
- **Đã xong** (`completed`): đĩa `task_alt`, "Buổi chụp đã hoàn thành", "{tên} sẽ giao {n} ảnh trong 48 giờ.", nút viền "Về trang chủ". Không có đánh giá và khiếu nại (Decision 12; câu "có vấn đề thì báo trong 24 giờ" chỉ là thông tin).
- **Tương tác**: "Xác nhận hoàn thành" → `confirmInstantComplete`; `conflict` → đọc lại yêu cầu, không báo; lỗi khác → toast, nút dùng lại được. Hết giờ gói → tick (server chuyển `finished`).
- **Chuỗi**: `shootingTitle`, `shootingCard`, `shootingMeta`, `shootingStepDeliver`, `shootingNote`, `shootingConfirm`, `shootingFinishedTitle`, `shootingFinishedBody`, `doneTitle`, `doneBody`, `doneHome`, `jobStepAccepted`, `jobStepArrived`, `jobShootLeft`.

## S13.07 · Chưa tìm được nhiếp ảnh gia

- **Thông tin**: `/instant/:id` khi `no_match` · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)).
- **Mục đích**: không ai nhận trong 10 phút; chọn tiếp, đặt lịch thường hoặc huỷ. Không phải trạng thái kết thúc: tiền đã trả vẫn giữ, không tự hoàn (spec §2.1.9).
- **Bố cục**: thanh Back + "Chụp ngay"; đĩa `person_search`, "Chưa tìm được nhiếp ảnh gia", "Bạn đã mời {n} người trong {m} lượt; gần bạn lúc này ít người đang sẵn sàng."; đã trả: `EscrowNotice` "{số tiền} vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ về {MoMo | ZaloPay | tài khoản đã chuyển}." và chữ đỏ "Huỷ yêu cầu và hoàn {số tiền}"; chưa trả: không có dòng tiền, chữ đỏ "Huỷ yêu cầu"; nút viền "Đặt lịch thường với người bạn chọn" → `/action` (yêu cầu vẫn mở); chân: nút chính "Chọn thêm người".
- **Tương tác**: "Chọn thêm người" = `nextInstantCandidates` như "Xem 5 người khác" (server mở lại yêu cầu, cửa sổ 10 phút tính lại) → S13.02 lượt mới.
- **Chuỗi**: `noMatchTitle`, `noMatchBody`, `noMatchHeld`, `refundToBankQr`/`refundToMomo`/`refundToZaloPay`, `noMatchCancel`, `waitingCancel`, `noMatchBookNormally`, `noMatchMore`.

## S13.08 · Huỷ chụp ngay (phía khách) và đã đóng

- **Thông tin**: sheet trên S13.02 (đã gửi lời mời), S13.03, S13.05, S13.07; không route riêng · khách · I5 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)). Màn kết thúc là `#S13.08-done` (mã S13.08 nhãn `done`) trên `/instant/:id`.
- **Bố cục sheet**: "Huỷ chụp ngay?"; `PolicyTable` ba hàng (điều kiện dài xuống dòng tới 3 dòng): "Đang chọn, đang chờ trả lời, chưa tìm được, hoặc 2 phút đầu sau khi có người nhận" · "Hoàn 100%", "Nhiếp ảnh gia đang đến" · "Hoàn 80%", "Đã đến, bạn không có mặt sau 15 phút" · "Hoàn {100 − arrivedCancelPhotographerPercent}%" (số của yêu cầu); hàng của luật trong bản tính thử (`full_refund`/`free_window`/`photographer_late` → hàng 1, `en_route` → 2, `arrived` → 3) được tô, thêm "(bây giờ)" và hiện phần trăm của bản tính thử; `unpaid` không tô hàng nào. Dòng tóm tắt: chưa trả "Bạn chưa thanh toán nên không có khoản tiền nào."; có phí "Bạn sẽ được hoàn **{hoàn}**; {phí} là phí đi lại trả cho {tên}."; thợ trễ "{tên} đến trễ hơn 15 phút nên bạn được hoàn đủ." + "Bạn sẽ được hoàn {hoàn}."; còn lại "Bạn sẽ được hoàn {hoàn}.". Nút đỏ "Huỷ và hoàn {hoàn}" (chưa trả: "Huỷ yêu cầu"), chữ "Giữ yêu cầu".
- **Dữ liệu**: `customerCancelQuoteProvider(id)` = `cancelInstantRequest(dryRun: true)`; sheet không bao giờ tự tính tiền (Decision 8). Bản tính thử được hỏi lại khi trạng thái yêu cầu đổi lúc sheet mở và 1 giây sau mốc `freeCancelUntil`/`lateDeadlineAt` kế tiếp; nút xác nhận vô hiệu khi bản tính đang tải lại hoặc lỗi.
- **Tương tác**: xác nhận → `cancelInstantRequest(dryRun: false)` một lần (sheet không đóng được khi đang chạy) → đóng sheet, luồng nghe hiện màn đã đóng. `conflict` (ở bản tính thử hoặc lệnh thật: yêu cầu đã đi tiếp, ví dụ đã bắt đầu chụp) → đóng sheet với "Chưa thực hiện được. Thử lại nhé."; lỗi khác khi xác nhận → lỗi đỏ trong sheet, sheet ở lại.
- **Đã đóng** (`#S13.08-done`): thanh giữa "Chụp ngay" không Back; đĩa `event_busy`; khách huỷ: "Đã huỷ yêu cầu" + "Hoàn {số tiền} về {phương thức}. Tiền thường về trong vài phút." (đã trả, số = `amountVnd − feeVnd` của server) hoặc "Không có khoản tiền nào." (chưa trả, hoặc không hoàn gì); hết hạn (`abandoned`): "Yêu cầu đã hết hạn" + "Bạn chưa gửi lời mời trong 30 phút nên yêu cầu đã đóng."; thợ báo vắng mặt: "Nhiếp ảnh gia báo bạn không có mặt" + "Bạn được hoàn {số tiền} ({phần trăm}%)." (đã trả; phần trăm từ server) hoặc "Không có khoản tiền nào."; chân: nút chính "Tạo yêu cầu mới" → `/instant`, nút viền "Về trang chủ".
- **Chuỗi**: `cancelInstantTitle`, `cancelRowFree`, `cancelRowEnRoute`, `cancelRowArrived`, `cancelRowNow`, `cancelOutcome`, `cancelInstantRefundFee`, `cancelInstantRefundAll`, `cancelInstantLate`, `cancelInstantUnpaid`, `cancelInstantConfirm`, `cancelInstantConfirmUnpaid`, `cancelInstantKeep`, `cancelledTitle`, `cancelledRefund`, `cancelledNoMoney`, `abandonedTitle`, `abandonedBody`, `noShowTitle`, `noShowBody`, `closedNewRequest`, `doneHome`.
- **Chấp nhận**: số tiền luôn hiện bằng chữ trước khi xác nhận và đúng bằng bản tính thử; xác nhận là nút đỏ trong sheet; không bao giờ "0₫ (0%)".

## Test hai bên

`test/features/instant/instant_two_party_test.dart` chạy app khách và app thợ (hai `ProviderScope`, hai router, một hiện một ẩn) trên cùng một backend trong bộ nhớ (`test/support/instant_simulator.dart`, theo luật của `packages/domain`: lượt 5 người, lời mời 60 giây, ai nhận trước thì được, mũi tên trạng thái, hẹn giờ lười, bảng huỷ) và một đồng hồ: chọn ba người và người thứ hai nhận; cả lượt hết hạn rồi lượt hai; thợ huỷ sau khi nhận; khách huỷ ở từng mốc (chưa trả, đang chờ 100%, đang đến sau 2 phút 80/20, đã đến theo cấu hình 50/50 và 70/30); 10 phút không ai nhận rồi chọn tiếp; hoàn thành và xác nhận.
