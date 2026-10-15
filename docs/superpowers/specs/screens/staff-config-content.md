# S23 · Cấu hình & nội dung (#168)

- **Issue:** #168, epic #83. **Ngày:** 2026-10-09. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` ("spec dashboard": quyền, `audit_log`, `staff_approvals` §5.4, công tắc Blaze D3), spec chính §3 (sự kiện, `events/{id}`, §3.6 quyền tạo), `./events.md` (S12.01–S12.03 của app), plan `../../plans/2026-10-07-s13-s14-dispatch-provider.md` (#140; `instant_config/current`), plan `../../plans/2026-10-07-s17-notifications.md` (#138, đã merge; loại `promo`), plan `../../plans/2026-10-07-s26-studio-members.md` (#136; bộ đếm studio), `./staff-money.md` (ngưỡng hai người M2).
- **Mock:** `docs/design/dashboard-mock.html#S23.18` … `#S23.23`.

## 0. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| C1 | **Sự kiện làm đủ trên web:** danh sách, tạo / sửa (hai phần như S12.01–S12.02), quản lý (đăng ký, FAQ, thông báo, kiểm duyệt timeline và nhóm chat, huỷ). Dùng nguyên callable sự kiện đang có (`saveEventDraft`, `publishEvent`, `updateEvent`, `cancelEvent`, `postEventAnnouncement`, `moderateEventTimeline`, `moderateEventChat`). Huỷ sự kiện có tổng tiền hoàn từ 10.000.000₫ cần người thứ hai (`kind: event_cancel`). | chủ dự án 2026-10-09 |
| C2 | **Đổi cấu hình liên quan tiền cần admin thứ hai** (`kind: config_change`): phí nền tảng, giá và hệ số giá Chụp ngay, tỉ lệ chia khi huỷ, ngưỡng duyệt hai người. Bật / tắt Chụp ngay, thêm hoặc sửa tên thành phố, khu vực: một admin là đủ. Mỗi lần lưu giữ bản cũ để quay lại. | chủ dự án 2026-10-09 |
| C3 | **Promo:** tối đa **1 promo mỗi người mỗi 7 ngày**; chỉ gửi người đã tự bật promo (mặc định tắt, S17.02); tôn trọng giờ yên lặng như mọi thông báo; xem trước và gửi thử cho chính mình trước khi gửi; không cần người thứ hai. | chủ dự án 2026-10-09 |
| C4 | Ngưỡng hai người của #163 (M2) chuyển từ hằng số sang `platform_config/money.twoPersonThreshold`; thiếu doc thì dùng hằng số `DEFAULT_MONEY_CONTROLS` làm mặc định. | #163 M2 hẹn chuyển khi có màn cấu hình |
| C5 | Tỉ lệ thuế khấu trừ và hoa hồng của booking (`DEFAULT_PAYOUT_POLICY`, #134) **vẫn là hằng số trong code**: đổi thuế là việc pháp lý, cần PR có người duyệt. | #134 Decision 1 |
| C6 | Mọi thứ ở đây chạy trên emulator cho tới khi bật Blaze (spec dashboard D3); gửi promo thật cần Functions và FCM nên cũng chờ công tắc. | chủ dự án 2026-10-09 |

## 1. Màn và mã

| Mã | Màn | Route | Vai trò |
|---|---|---|---|
| S23.18 | Sự kiện: danh sách | `/staff/events` | admin (mọi sự kiện) · sales (sự kiện mình tạo) |
| S23.19 | Tạo / sửa sự kiện | `/staff/events/new`, `/staff/events/:id/edit` | admin · sales |
| S23.20 | Quản lý sự kiện: đăng ký, FAQ, thông báo, kiểm duyệt, huỷ | `/staff/events/:id` | admin · sales (của mình) |
| S23.21 | Khuyến mãi (promo): danh sách và soạn | `/staff/promos` | admin · sales |
| S23.22 | Cấu hình: Chụp ngay, kiểm soát tiền, lịch sử phiên bản | `/staff/config` | admin |
| S23.23 | Chỉ số studio (bộ đếm vi phạm) | `/staff/studios` | admin · support |

Thanh bên nhóm "Nội dung": Sự kiện · Khuyến mãi · Cấu hình; nhóm "Hàng đợi" (hoặc "Hệ thống") thêm Chỉ số studio. Thẻ S23.09 của sales: sự kiện của mình sắp diễn ra, sự kiện chờ thợ đồng ý tổ chức (tạo hộ).

## 2. Sự kiện (S23.18–S23.20)

Luật giữ nguyên spec chính §3.6: `admin` quản lý mọi sự kiện, `sales` chỉ sự kiện mình tạo; tạo hộ một thợ cần thợ đồng ý trong 24 giờ (`respondToHostConsent`); sự kiện của nền tảng không có chat hỏi trước, có FAQ (`Event.faq`).

### S23.18 · Danh sách

- Tab **Sắp diễn ra** · **Bản nháp** · **Đã qua** · **Đã huỷ**; lọc: người tổ chức (Nền tảng / thợ), người tạo (admin thấy mọi người; sales chỉ mình).
- Bảng: tên, loại, ngày giờ, địa điểm, đã đăng ký / sức chứa, giá vé ("Không thu phí" khi 0), người tổ chức, trạng thái (chip "Chờ thợ đồng ý" cho sự kiện tạo hộ). Nút chính **"Tạo sự kiện"**.

### S23.19 · Tạo / sửa

- Một trang hai phần, nút lưu cuối trang, giống nội dung S12.01–S12.02:
  - **Thông tin:** ảnh bìa (tải qua URL ký như S28.04: nén trong trình duyệt theo quy định ảnh bìa sự kiện của #147, callable cấp URL), tên, loại, mô tả, người tổ chức ("Nền tảng" hoặc "Tạo hộ thợ", tìm thợ theo tên), hashtag (tự sinh, khoá khi đã có đăng ký).
  - **Lịch & vé:** bắt đầu, kết thúc, địa điểm (tên, điểm hẹn, toạ độ chọn trên bản đồ vẽ như app), sức chứa, giá vé (0 = Không thu phí), hạn đăng ký (mặc định trước giờ bắt đầu 12 giờ), FAQ (chỉ sự kiện nền tảng; tối đa 10 câu).
- Nút: chính **"Đăng sự kiện"** (`publishEvent`, sau khi `saveEventDraft`); phụ "Lưu nháp". Khi sửa sự kiện đã có đăng ký: các trường bị khoá theo `updateEvent` hiện mờ kèm lý do.
- Lỗi: mã lỗi của callable sự kiện → câu tiếng Việt như app.

### S23.20 · Quản lý

- Đầu trang: ảnh bìa, tên, ngày giờ, trạng thái, "{n}/{sức chứa} đã đăng ký", tổng tiền vé đã thu (`MoneyText`), link xem như khách (`/e/{id}` trên app).
- Tab **Đăng ký:** bảng người đăng ký (tên, trạng thái thanh toán, đã check-in, lúc đăng ký); không có số điện thoại. Check-in làm trên app (quét QR), web chỉ xem.
- Tab **FAQ:** sửa câu hỏi thường gặp (sự kiện nền tảng) → `updateEvent`.
- Tab **Thông báo:** gửi thông báo cho người đã đăng ký (`postEventAnnouncement`, ≤ 500 ký tự).
- Tab **Kiểm duyệt:** bài timeline và tin nhóm chat mới nhất, ẩn / gỡ bằng `moderateEventTimeline` / `moderateEventChat` (admin như hiện tại; sales cho sự kiện của mình). Báo cáo về sự kiện từ S23.05 trỏ vào đây (#166).
- Nút đỏ **"Huỷ sự kiện…"** (trong hộp): nêu số vé sẽ hoàn và tổng tiền hoàn, bắt lý do (gửi kèm thông báo huỷ cho người đăng ký) → `cancelEvent`. Tổng hoàn từ 10 triệu → "Gửi duyệt lần hai" (người duyệt: admin khác người đề xuất).
- **Chấp nhận:** sales mở URL sự kiện của người khác nhận 403; sự kiện tạo bằng web hiện trên app giống hệt sự kiện tạo bằng app; huỷ hoàn đúng mọi vé đã trả (luật `cancelEventWithRefunds`).

## 3. S23.21 · Khuyến mãi (promo)

```
promo_campaigns/{ulid}               (server-only)
  title (≤ 60 ký tự), body (≤ 160), target (route trong danh sách cho phép của #138, ví dụ /e/{id}, /discover)
  audience     all | customers | providers
  status       draft | sending | sent | cancelled
  createdBy, createdAt, sentBy?, sentAt?
  stats        {eligible, sent, skippedRecent, skippedOptOut}
users/{uid}/private/promo_quota      {lastPromoAt}   (server-only)
```

- **Bố cục:** danh sách chiến dịch (tên, đối tượng, trạng thái, đã gửi / đủ điều kiện, lúc gửi); nút chính "Soạn khuyến mãi". Trang soạn: tiêu đề, nội dung, nơi mở khi chạm (chọn từ danh sách: sự kiện, trang Khám phá, hồ sơ thợ, Chụp ngay khi đã bật), đối tượng; **xem trước** đúng hình thông báo trên điện thoại; ước tính "Khoảng {n} người sẽ nhận (đã bật khuyến mãi, chưa nhận trong 7 ngày)". Nút phụ "Gửi thử cho tôi", nút chính "Gửi".
- **Gửi:** `sendPromoCampaign({campaignId})` đặt `status = sending`; trigger `onPromoCampaignWrite` duyệt người dùng theo lô 500, chỉ người có `prefs.promo` bật, đúng đối tượng, `promo_quota.lastPromoAt` cũ hơn 7 ngày; mỗi người một thông báo loại `promo` qua hook của #138 (giờ yên lặng do #138 xử lý); cập nhật `lastPromoAt` và `stats`; xong thì `sent`. Gửi thử: `sendPromoTest({campaignId})` chỉ tới người gọi, không tính quota.
- Không sửa được chiến dịch đã gửi; "Huỷ" chỉ khi đang `draft`.
- **Chấp nhận:** người tắt promo không nhận; người vừa nhận promo 3 ngày trước bị bỏ qua và được đếm vào `skippedRecent`; gửi hai lần cùng một chiến dịch không gửi lại.

## 4. S23.22 · Cấu hình

### 4.1 Lưu và duyệt

- Mỗi nhóm cấu hình là một doc: `instant_config/current` (đã có, #140) và `platform_config/money` (mới, C4). Client app đọc như hiện tại; chỉ server ghi.
- `proposeConfigChange({key: 'instant' | 'money', patch, reason})`: kiểm bằng parser của domain (`parseInstantConfig`, `parseMoneyControls`); patch chỉ đụng trường không liên quan tiền thì ghi ngay; có trường tiền (C2) thì tạo `staff_approvals` `config_change`, admin khác duyệt ở S23.15.
- Mỗi lần ghi: `config_history/{ulid}` `{key, before, after, proposedBy, approvedBy?, at}` và `audit_log` `config.change` (diff là các trường đổi).
- **Quay lại phiên bản cũ:** chọn một dòng lịch sử → "Dùng lại bản này…" tạo một đề xuất mới với giá trị cũ, theo đúng luật duyệt ở trên.

### 4.2 Bố cục

- Tab **Chụp ngay:**
  - Công tắc "Bật Chụp ngay" (`enabled`).
  - Phí nền tảng (% nhập, lưu `platformFeeBp`); tỉ lệ thợ nhận khi khách huỷ lúc thợ đã tới (`instantArrivedCancelPhotographerPercent`).
  - Bảng gói: mã, thời lượng, số ảnh, giá. Đổi giá tăng `priceListVersion`; hộp xác nhận nói rõ "Thợ đang bật Chụp ngay phải đồng ý bảng giá mới trước khi nhận việc tiếp" (luật `price_changed` của #140) và "Yêu cầu đang chạy giữ giá cũ".
  - Thành phố: tên, khung toạ độ (Nam, Tây, Bắc, Đông), hệ số giá (`surgeBp`); khu vực gợi ý: tên, toạ độ.
- Tab **Kiểm soát tiền:** ngưỡng duyệt hai người (₫), mặc định 10.000.000.
- Tab **Lịch sử:** bảng thay đổi (lúc, nhóm, trường đổi, người đề xuất, người duyệt, lý do); bấm mở diff.
- Thay đổi chờ duyệt hiện banner "Đang chờ duyệt lần hai" trên tab, các ô liên quan khoá tới khi có quyết định.
- **Chấp nhận:** sửa phí nền tảng chỉ có hiệu lực sau khi admin thứ hai duyệt; tắt Chụp ngay có hiệu lực ngay; quay lại phiên bản cũ tạo đúng một dòng lịch sử mới.

## 5. S23.23 · Chỉ số studio

- Bảng studio: tên, số thành viên, đã xác minh doanh nghiệp, booking 90 ngày, `lateAssignCount`, `changeDeclinedCount`, `lateReassignCount`, `lateDeliveryCount` (spec studio §3.1; chỉ server ghi, chưa công khai), cờ chưa trả công (S23.17). Sắp theo cột; bấm dòng mở `DetailPane` với các booking gây ra từng bộ đếm (nếu có ghi lại) và link sang S23.04, S23.16, S23.17.
- Chỉ đọc; xử lý bằng các màn đã có (khoá, gỡ khoá đăng tin).
- Index: `photographers (providerType, lateDeliveryCount)` và tương tự cho cột sắp mặc định.

## 6. Bảng quyền và backend

**`StaffAction` thêm:** `event.view_all`, `event.manage_any`, `config.view`, `config.change`, `config.decide` (admin); `event.create`, `event.manage_own`, `promo.view`, `promo.send` (admin, sales); `studio_stats.view` (admin, support). `APPROVAL_KINDS` thêm `event_cancel` (duyệt: `event.manage_any`), `config_change` (duyệt: `config.decide`).

| Callable | Mới / có | Ghi chú |
|---|---|---|
| `saveEventDraft`, `publishEvent`, `updateEvent`, `cancelEvent`, `postEventAnnouncement`, `moderateEventTimeline`, `moderateEventChat` | có | `cancelEvent` đi qua `staff_approvals` khi tổng hoàn ≥ ngưỡng và người gọi là staff; thêm `audit_log` khi người gọi là staff |
| `createEventCoverUploadUrl` | mới | URL ký `PUT` cho ảnh bìa (giới hạn của #147), như `createDeliveryUploadUrls` (#167) |
| `sendPromoCampaign`, `sendPromoTest`, `savePromoDraft`, `cancelPromoDraft` | mới | C3 |
| `proposeConfigChange` | mới | §4.1 |

- Domain: `parseMoneyControls`, port `MoneyControlsReader` (mặc định hằng số); `promoEligible(user, prefs, quota, audience, now)` thuần; `requiresTwoPeople` đọc ngưỡng từ port thay cho hằng số (#163).
- Rules: client đọc `instant_config/current` như hiện tại, `platform_config/money` không cần cho client; không đọc `promo_campaigns`, `promo_quota`, `config_history`.

## 7. Chi phí

- Promo: mỗi chiến dịch đọc danh sách người dùng theo lô (≈ số người dùng / 500 truy vấn, mỗi doc 1 lượt đọc) và ghi một thông báo + một quota cho mỗi người nhận. 10.000 người dùng, 10% bật promo, 1 chiến dịch/tuần: ≈ 10.000 lượt đọc + 2.000 lượt ghi mỗi tuần, trong hạn mức. FCM miễn phí.
- Sự kiện, cấu hình, chỉ số studio: vài chục lượt đọc mỗi lần mở.
- Cộng thêm **~$0** ở cả hai mức người dùng (và $0 khi Blaze còn tắt, vì chỉ chạy trên emulator).

## 8. Kiểm thử

- **Domain:** `promoEligible` (tắt promo, sai đối tượng, nhận 6 ngày trước, nhận 8 ngày trước); `proposeConfigChange` tách trường tiền / không tiền; `parseMoneyControls` từ chối ngưỡng ≤ 0; `requiresTwoPeople` đọc ngưỡng mới; huỷ sự kiện tổng hoàn 9.999.999 / 10.000.000.
- **Functions:** sales sửa sự kiện của người khác → `permission_denied`; `sendPromoCampaign` hai lần chỉ gửi một lần; `proposeConfigChange` đổi `platformFeeBp` tạo yêu cầu, đổi `enabled` ghi ngay; đổi giá tăng `priceListVersion`.
- **Dashboard:** form sự kiện khoá trường theo trạng thái; ước tính số người nhận promo; banner chờ duyệt khoá ô.
- **Playwright:** sales tạo sự kiện nền tảng không thu phí → hiện ở S11.01 dữ liệu seed; admin A đổi phí nền tảng 5%, admin B duyệt → `instant_config/current.platformFeeBp = 500` và một dòng lịch sử.

## 9. Phụ thuộc

- Cứng: #162 (nền tảng). Sự kiện và promo làm ngay được (#126 sự kiện và #138 thông báo đã merge). Tab Chụp ngay cần #140. Chỉ số studio cần #136. Ngưỡng tiền (C4) sửa code của #163.
- Plan có thể chia: sự kiện + promo trước; cấu hình và chỉ số studio sau khi #140, #136 merge.

## 10. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Lọc promo theo thành phố? | Chưa; hồ sơ người dùng chưa có thành phố chung |
| Q2 | Hẹn giờ gửi promo? | Chưa; cần job lập lịch (Blaze) |
| Q3 | Check-in vé trên web? | Không; dùng app quét QR |
| Q4 | Sales có thấy doanh thu vé của sự kiện mình tạo? | Có, chỉ tổng số tiền |
