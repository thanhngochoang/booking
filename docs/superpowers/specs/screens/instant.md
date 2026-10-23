# Chụp ngay (S13–S14)

Màn của use case S13 (khách) và S14 (thợ ảnh) trong [`../2026-10-01-instant-booking-design.md`](../2026-10-01-instant-booking-design.md) (gọi là "spec Chụp ngay"; luồng §2, trạng thái và lời mời §3, tiền §4, giai đoạn 1 ở hộp đầu §5, vị trí §9). Mẫu mục và quy ước chung ở [`README.md`](README.md). Mock: `docs/design/ui-mock.html`, khung `#S06.01-instant`, `#S13.04-provider`, `#S13.08-provider`, `#S14.01`, `#S14.01-terms`, `#S14.01-locked`, `#S14.02`, `#S14.03`, `#S14.03-arrived`, `#S14.03-shooting`, `#S14.03-done`. Plan: [`../../plans/2026-10-07-s13-s14-dispatch-provider.md`](../../plans/2026-10-07-s13-s14-dispatch-provider.md) (gọi là "plan", Decisions 1–31); sổ bàn giao [`../../handover/ledger-instant-dispatch-provider.md`](../../handover/ledger-instant-dispatch-provider.md).

Phần thợ ảnh dưới đây mô tả **đúng như đã làm ở #140** (PR 1). Phần khách (S13.01–S13.08 phía khách) là chỗ dành cho plan [`../../plans/2026-10-07-s13-instant-customer.md`](../../plans/2026-10-07-s13-instant-customer.md) (#140 PR 2).

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

- **Thông tin**: không có route; hiện trên S14.02 sau khi nhận thắng · thợ ảnh · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), mã S13.04 nhãn `provider`. Phía khách (trên S13.05) thuộc plan khách.
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

- **Thông tin**: sheet trên S14.03 · thợ ảnh đã nhận · I4 · Đã có ([#140](https://github.com/thanhngochoang/booking/issues/140)), mã S13.08 nhãn `provider`. Phía khách thuộc plan khách.
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

Chỗ dành cho plan khách [`../../plans/2026-10-07-s13-instant-customer.md`](../../plans/2026-10-07-s13-instant-customer.md) (#140 PR 2): S13.01 Chụp ngay (gói, kiểu chụp, điểm hẹn), S13.02 vuốt chọn, S13.03 chờ trả lời, S13.04 đã match (phía khách), S13.05 đang đến, S13.06 đang chụp, S13.07 không tìm được người, S13.08 huỷ (phía khách). Dữ liệu và callable phía khách đã có ở #140 PR 1 (`InstantRepository`: `createRequest`, `nextCandidates`, `invite`, `cancel`, `confirmComplete`, `tick`, `watchRequest`, `watchTrack`, `myActiveRequestId`).
