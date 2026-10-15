# UX audit và redesign — Cộng đồng nhiếp ảnh gia

Phân tích app hiện tại như một prototype sản phẩm, sau đó thiết kế lại kiến trúc thông tin và các màn hình chính. Mục tiêu: tăng chuyển đổi từ **khám phá → đặt lịch**, giảm ma sát, đưa ảnh thành nhân vật chính. Giữ toàn bộ nghiệp vụ hiện có (đăng nhập, tìm và đặt nhiếp ảnh gia, accept/deny, dự án mở, chat, album, lịch) trừ khi có lý do UX rõ ràng.

Wireframe tương tác: xem artifact "Nhiếp Ảnh Gia Redesign" (link trong báo cáo). Token màu/chữ/spacing dùng `design-system/README.md`.

---

## 1. Điểm mạnh nên giữ

| Điểm mạnh | Vì sao giữ |
|-----------|-----------|
| **Nghiệp vụ hai chiều rõ ràng**: khách đặt trực tiếp *hoặc* đăng dự án mở để nhiếp ảnh gia tự ứng tuyển | Hai mô hình cung cầu bổ sung nhau; ít app booking VN có cả hai. |
| **Album collage** trên Home (`AutoTopImageLayout`, 1 ảnh lớn + 3 nhỏ) | Cách duy nhất app hiện tại "bán" nhiếp ảnh gia bằng ảnh thật. Nên mở rộng, không bỏ. |
| **Vòng đời booking có trạng thái** (WAITING → ACCEPTED/DENIED, OPENED → CLOSED) với màu riêng | Đủ để xây timeline trạng thái cho người dùng. |
| **Badge số trên hamburger và Calendar** (chat chưa đọc + booking chờ) | Ý tưởng "có việc cần làm" đúng; chỉ cần đặt ở chỗ dễ thấy hơn. |
| **Chat gắn với booking** (nút "Send Message" ngay trên màn đặt lịch) | Chat trong ngữ cảnh đặt lịch tăng tỉ lệ chốt. |
| **Place Picker + khoảng giá + ngày** là đúng ba tiêu chí khách quan tâm | Chỉ sai ở chỗ chưa dùng để lọc. |
| **Bottom sheet chọn giá**, **pull-to-refresh**, offline snackbar | Pattern mobile chuẩn, giữ. |

## 2. Vấn đề UX

### 2.1 Không có luồng chính
- Màn hình mặc định là feed album không có hành động; nút tìm kiếm là icon nhỏ trên toolbar. Người mới không biết bước tiếp theo là gì.
- Điều hướng qua drawer 9–10 mục, 3 mục là stub (Help, About, Settings rỗng). Mỗi thao tác chính cần 2 chạm (mở drawer + chọn).
- Nhãn lẫn tiếng Anh/Việt: drawer "Profile", màn hình "About", tab "My Bookings"; hint tiếng Anh cạnh label tiếng Việt trên cùng màn hình.

### 2.2 Tìm kiếm không tìm
- Form "Tìm nháy" bắt nhập địa điểm, ngày, giá, checkbox "Lân cận" nhưng **query bỏ qua tất cả** (chỉ lấy mọi user `is_photographer == true`). Người dùng nhập xong nhận cùng một danh sách.
- Card kết quả hiển thị **placeholder** "120 photos / 3 albums" và **3 ảnh demo hard‑code** cho mọi nhiếp ảnh gia; avatar và tên không bấm được (không xem được hồ sơ trước khi Book).
- Rating hard‑code 1 trong query, 4.6 trên profile.

### 2.3 Đặt lịch mù
- Bấm "Book" nhảy thẳng vào form với header **placeholder** ("Thành Ngọc Hoàng… Canon 6D"), cover không tải, không thấy portfolio, không thấy giá ngày của nhiếp ảnh gia (`User.price` có trong data nhưng không dùng; app đề xuất giá = trung bình khoảng giá lọc).
- Không validation: thiếu địa điểm → NPE bị nuốt, nút "Book" có vẻ chết. Không kiểm tra giờ kết thúc > bắt đầu, giá > 0, ngày quá khứ.
- Sau khi gửi chỉ có toast 2 giây rồi back. Không có màn xác nhận, không thấy trạng thái ở đâu, không hủy được, không có thông báo đẩy khi được chấp nhận.

### 2.4 Nhiếp ảnh gia không có hộp thư yêu cầu
- Yêu cầu mới chỉ hiện dưới dạng **màu sự kiện trên Calendar** hoặc card trong tab "My Projects" với **tên chính mình** thay vì tên khách. Tap card mở "Close Project" chứ không phải Accept/Deny.
- Accept/Deny chỉ có trong màn chi tiết từ Calendar (3 chạm, header placeholder).

### 2.5 Dự án mở đứt đoạn
- Khách tạo dự án, nhiếp ảnh gia "Attend", chủ dự án thấy avatar người tham gia nhưng **không chọn được ai, không chat được, không có thông báo**. Kết cục duy nhất là "Close Project".
- Chủ sở hữu không hiển thị cho người ứng tuyển (header placeholder).

### 2.6 Trạng thái hệ thống
- Không màn hình nào có empty state thật (trừ Album do tình cờ). Hầu hết Firestore read bỏ qua lỗi. Pull‑to‑refresh ở Find và Messages quay mãi.
- 5 cơ chế phản hồi khác nhau: ToastPopup, Toast hệ thống, MessageDialog, AlertDialog thô, notification.

### 2.7 Hồ sơ nhiếp ảnh gia không bán được
- Profile chỉ có avatar, tên, rating giả, địa chỉ, và danh sách comment (**tải nhầm comment của chính người xem**). Không portfolio, không giá, không thiết bị, không phong cách, không nút Đặt lịch. Tab "Book" ở dưới là stub.

## 3. Màn hình và tương tác không cần thiết

| Bỏ / gộp | Lý do |
|----------|-------|
| Drawer + Help, About, Settings stub | Thay bằng bottom navigation 4 tab; Settings vào tab Hồ sơ. |
| `TernRegisterActivity` (màn điều khoản chỉ có 1 dòng + checkbox "Tôi là Photographer") | Gộp vào onboarding: sau đăng nhập hỏi "Bạn muốn làm gì?" (Thuê / Nhận chụp). Điều khoản là link, không phải bước riêng. |
| Form tìm kiếm riêng (`FindPhotographerFragment`) | Tìm kiếm thành thanh tìm + chip lọc ngay trên Khám phá; kết quả là cùng danh sách. |
| `ViewImageActivity` với placeholder tên/số/ngày, nút Vote/Edit/Share/Info chết | Thay bằng viewer vuốt ngang trong album, chỉ có nút đóng và "Đặt lịch với …". |
| Tab "My Bookings / My Projects" phân theo trường dữ liệu | Phân theo vai trò người dùng: **Đang chờ / Sắp tới / Đã xong**. |
| `CreateProjectFragment` (bản sao 95% của `BookFragment`) | Một form đặt lịch, hai chế độ: "Đặt với nhiếp ảnh gia X" và "Đăng dự án mở". |
| Nút Flickr, Google Calendar "Connect" trên Update Profile | Flickr chết; Calendar chỉ log 10 sự kiện. Bỏ cho tới khi có sync thật. |
| Cell "Thời gian" ẩn, checkbox "Lân cận" không binding, FAB ẩn, `ImageAdapter` demo | Dead code. |
| Nút chụp ảnh trong chat (handler rỗng) | Giữ nếu nối lại code gửi ảnh đã có; nếu không thì bỏ. |
| Hai date picker khác nhau (dialog hệ thống ở Find, dải ngày 1000 ô ở Book) | Một component chọn ngày. |

## 4. Component không nhất quán

| Nhóm | Hiện trạng | Chuẩn hoá |
|------|-----------|-----------|
| Card | `item_gallery` (avatar 50dp, collage 200dp), `item_photographer` (avatar 60dp, rating, collage), `item_my_project` (text‑only CardView), `item_project` (không dùng) | 2 card: **PhotographerCard** (ảnh hero + avatar + tên + giá/ngày + rating) và **BookingCard** (ảnh đối tác + trạng thái + ngày giờ + địa điểm + giá). |
| Avatar | 40 / 50 / 60 / 90dp rải rác, hard‑code trong layout | `avatar_xs…xl` token. |
| Nút | Trắng (login), xanh pill (Send Message), xanh (Book), đỏ ẩn (Từ chối), FAB 2 màu | `Button.Primary / Outline / Danger / Text` theo token. |
| Ngày giờ | Dialog hệ thống, dải ngày tự vẽ, `TimePickerDialog` khởi tạo phút = 12 | Một date picker, một time picker, format từ `Constant`. |
| Phản hồi | 5 cơ chế | Snackbar cho thông tin/lỗi có thể thử lại, dialog chỉ cho hành động huỷ/từ chối. |
| Trạng thái booking | Chip màu, nhãn CLOSED dùng nhầm string "Bị từ chối" | `Badge` + `bg_badge_*`, nhãn riêng cho CLOSED ("Đã đóng"). |
| Nền | Toàn app nền ảnh tối (`bg_home`) kể cả form nhập liệu; bottom sheet trắng | Bề mặt sáng cho nội dung và form; ảnh chỉ làm nền ở hero và card. Lý do: độ tương phản chữ trên ảnh không kiểm soát được, form trên ảnh khó đọc. |
| Ngôn ngữ | Anh/Việt lẫn, hard‑code trong Java | Tiếng Việt, mọi chuỗi trong `strings.xml`. |

## 5. Ma sát trên hành trình đặt lịch

Hành trình hiện tại (khách, đã đăng nhập): Home → icon tìm (1) → chọn địa điểm qua Place Picker (2–3) → ngày (2) → giá (2) → Tìm (1) → cuộn danh sách giống nhau → Book (1) → form: chỉnh giá/giờ (2–4) → Book (1) → toast. **Khoảng 12–15 chạm**, 3 lần rời app (Place Picker), và **không có điểm nào người dùng nhìn thấy ảnh thật của người mình sắp thuê**.

| # | Ma sát | Sửa |
|---|--------|-----|
| 1 | Phải nhập địa điểm trước khi thấy bất kỳ nhiếp ảnh gia nào | Khám phá hiện ngay danh sách theo vị trí hiện tại (đã có `GetLocationManager`); địa điểm là chip lọc tuỳ chọn. |
| 2 | Bộ lọc không có tác dụng | Lọc thật theo bán kính (geohash hoặc so sánh lat/long client cho tập nhỏ), khoảng giá theo `User.price`, ngày theo booking đã ACCEPTED (loại người bận). |
| 3 | Không xem được hồ sơ trước khi Book | Card → Hồ sơ (portfolio hero, giá, thiết bị, phong cách, đánh giá thật) → nút "Đặt lịch" cố định đáy. |
| 4 | Giá đề xuất là trung bình khoảng lọc, không phải giá của người đó | Giá mặc định = `User.price` (giá/ngày), cho phép đề nghị khác. |
| 5 | Form dài trên nền ảnh, không validation | Bottom sheet 2 bước: (a) ngày + khung giờ + địa điểm (mặc định vị trí đã lọc), (b) xem lại: ảnh nhiếp ảnh gia, tổng giá, nút "Gửi yêu cầu". Validation inline. |
| 6 | Sau gửi: toast rồi biến mất | Màn "Đã gửi yêu cầu" với timeline trạng thái, nút Nhắn tin và Huỷ yêu cầu; booking xuất hiện đầu tab Dự án với badge. |
| 7 | Được chấp nhận cũng không biết | FCM notification (đã có `user_devices` token) + badge tab Dự án. |
| 8 | Nhiếp ảnh gia không có nơi trả lời | Tab Dự án của nhiếp ảnh gia mở mặc định ở "Yêu cầu mới" với Accept/Deny ngay trên card. |

Hành trình mới: Khám phá (thấy ảnh + giá ngay) → Hồ sơ (1) → Đặt lịch (1) → chọn ngày/giờ (2–3) → Xem lại → Gửi (1) → Màn xác nhận. **Khoảng 6–7 chạm, 0 lần rời app** nếu địa điểm lấy từ vị trí hiện tại.

## 6. Ảnh làm nhân vật chính

| Nơi | Hiện tại | Đề xuất |
|-----|---------|---------|
| Khám phá | Feed album 200dp, chủ yếu text bên trên | Card ảnh full‑width 4:5, tên + giá + rating phủ lên đáy ảnh (gradient), avatar nhỏ. Lưới 2 cột cho "gần bạn". |
| Hồ sơ nhiếp ảnh gia | Avatar 60dp + comment | Hero = ảnh album đầu tiên toàn màn hình ngang, cuộn ngang các album, lưới ảnh 3 cột; thông tin thiết bị/phong cách là chip dưới ảnh. |
| Kết quả tìm | 3 ảnh demo hard‑code | Ảnh thật từ `albums` của người đó (query 1 album/người, cache). |
| Đặt lịch (xem lại) | Không có ảnh | Card nhỏ: ảnh đại diện album + avatar + tên + giá. |
| Tab Dự án | Card text | Ảnh đối tác (avatar lớn hoặc ảnh album) bên trái card. |
| Dự án mở (nhiếp ảnh gia xem) | Text | Ảnh địa điểm (Static Map) hoặc avatar chủ dự án; người ứng tuyển hiển thị bằng dải avatar. |
| Chat | Bong bóng text | Card booking ở đầu hội thoại (ảnh + ngày + trạng thái) để cuộc chat có ngữ cảnh. |
| Viewer ảnh | 1 ảnh, placeholder | Vuốt ngang trong album, đếm "3/12", nút "Đặt lịch với …" ở đáy. |
| Empty state | Không có | Minh hoạ + câu hành động ("Chưa có album. Đăng 5 ảnh đẹp nhất để khách tìm thấy bạn"). |

## 7. Kiến trúc thông tin mới

### 7.1 Điều hướng

Bottom navigation 4 tab, giống nhau cho cả hai vai trò; nội dung tab thay đổi theo vai trò.

```
Khách hàng                         Nhiếp ảnh gia
┌──────────┬──────────┬──────────┬──────────┐
│ Khám phá │ Dự án    │ Tin nhắn │ Hồ sơ    │
└──────────┴──────────┴──────────┴──────────┘
 Feed ảnh   Đang chờ   Hội thoại   Thông tin
 Tìm/lọc    Sắp tới    (badge)     Cài đặt
 Hồ sơ NAG  Đã xong                Trở thành NAG
 → Đặt lịch [+ Đăng dự án]

Nhiếp ảnh gia:
 Khám phá = Dự án mở gần bạn (thay cho "Find Projects")
 Dự án    = Yêu cầu mới (badge) · Sắp tới · Đã xong · Dự án đã ứng tuyển
 Hồ sơ    = Portfolio (Album, FAB thêm) · Giá & thiết bị · Lịch · Cài đặt
```

Calendar trở thành một chế độ xem trong tab Dự án (toggle Danh sách / Lịch), không phải màn hình riêng.

### 7.2 Sơ đồ màn hình

```
Onboarding
 ├─ Đăng nhập (email · Google · Facebook)
 ├─ Đăng ký (email, mật khẩu, tên)            ← thêm tên, bỏ màn điều khoản
 └─ Chọn vai trò: Thuê nhiếp ảnh gia / Nhận chụp  ← NAG đi tiếp Hoàn thiện hồ sơ

Khám phá (khách)
 ├─ Thanh tìm kiếm + chip: Địa điểm · Ngày · Giá
 ├─ Feed card ảnh (PhotographerCard)
 ├─ Hồ sơ nhiếp ảnh gia
 │    ├─ Album → Viewer ảnh
 │    ├─ Đánh giá
 │    └─ [Đặt lịch] → Sheet đặt lịch (2 bước) → Xác nhận đã gửi
 └─ [Đăng dự án mở] (FAB) → Sheet dự án (cùng form, chế độ mở)

Dự án (khách)
 ├─ Đang chờ · Sắp tới · Đã xong · Dự án của tôi   (segmented)
 ├─ Chi tiết booking: timeline, ảnh NAG, Nhắn tin, Huỷ / Đánh giá (khi xong)
 └─ Chi tiết dự án mở: người ứng tuyển (avatar) → chọn → tạo booking → Đóng

Dự án (nhiếp ảnh gia)
 ├─ Yêu cầu mới (badge): card có Chấp nhận / Từ chối
 ├─ Sắp tới · Đã xong · Đã ứng tuyển
 └─ Toggle Lịch (WeekView hiện có)

Tin nhắn → Hội thoại (card booking ở đầu, gửi text/ảnh)

Hồ sơ
 ├─ Khách: thông tin, Trở thành nhiếp ảnh gia, Cài đặt, Đăng xuất
 └─ NAG: portfolio (Album + tạo album), Giá & thiết bị (form hiện có), Cài đặt
```

### 7.3 Ánh xạ nghiệp vụ cũ → mới

| Nghiệp vụ hiện có | Ở đâu trong IA mới | Thay đổi |
|------------------|--------------------|----------|
| Login/Register/Terms | Onboarding | Gộp Terms vào chọn vai trò; thêm trường tên |
| Home (feed album) | Khám phá | Card ảnh, có lọc |
| Find Photographer | Khám phá (chip lọc) | Lọc thật |
| Profile / About / Album | Hồ sơ NAG (khách xem) và tab Hồ sơ (tự xem) | Có portfolio, giá, CTA |
| Book (create) | Sheet đặt lịch | Validation, xem lại, xác nhận |
| Book (detail Accept/Deny) | Tab Dự án › Yêu cầu mới | Inline trên card |
| My Project (2 tab theo field) | Tab Dự án (theo trạng thái) | Tên đối tác đúng |
| Create Project | Sheet dự án (cùng form) | Chủ dự án chọn người ứng tuyển |
| Find Projects | Khám phá (NAG) | |
| Calendar | Toggle Lịch trong Dự án | Sửa bug +1 ngày |
| Messages / Messenger | Tin nhắn | Card ngữ cảnh, nối lại gửi ảnh |
| Update Profile | Hồ sơ › Giá & thiết bị | Bỏ Flickr/Calendar |
| Help / About / Settings | Hồ sơ › Cài đặt | Help = link, About = phiên bản |
| Rating (`rating_star`) | Chi tiết booking Đã xong | Hiện chưa ghi; nối vào |

### 7.4 Thay đổi nghiệp vụ có lý do UX

| Thay đổi | Lý do |
|----------|-------|
| Bỏ bước Terms riêng | Bước không có nội dung (1 dòng), chặn luồng đăng nhập xã hội. Điều khoản thành link ở màn chọn vai trò. |
| Chủ dự án mở **chọn** một người ứng tuyển → tạo booking | Hiện tại dự án mở không có kết thúc; "Attend" là ngõ cụt. Chọn = cùng dữ liệu `photographers_attended` + tạo `booking` như luồng thường. |
| Khách **huỷ** yêu cầu khi WAITING | Không có cách rút yêu cầu; thêm trạng thái CANCELLED (5) hoặc dùng DENIED với cờ `cancelled_by_user`. |
| Giá mặc định = giá/ngày của nhiếp ảnh gia | Data đã có, hiện bị bỏ qua. |
| Thông báo đẩy khi trạng thái đổi | Token thiết bị đã lưu; không có thông báo thì booking "im lặng". |

## 8. Thiết kế màn hình chính

Mọi kích thước dùng token trong `design-system/`. Nền `color_background`, ảnh làm hero.

### 8.1 Khám phá (khách)
- Top: lời chào + vị trí hiện tại ("Gần Quận 1 · đổi"). Thanh tìm kiếm 48dp. Hàng chip cuộn ngang: Địa điểm, Ngày, Giá (`Chip`, selected = primary).
- Section "Nổi bật gần bạn": card ảnh 4:5 full‑width, gradient đáy, overlay: avatar 32dp + tên (Subtitle, inverse), giá/ngày (Body inverse, tabular), sao + số đánh giá. Tap → Hồ sơ.
- Section "Album mới": lưới 2 cột ảnh vuông, tên NAG dưới ảnh.
- FAB "Đăng dự án" (Outline, chỉ khách).
- Empty (không có NAG trong bán kính): minh hoạ + "Mở rộng bán kính" (Text button).

### 8.2 Hồ sơ nhiếp ảnh gia (khách xem)
- Hero: ảnh album đầu, cao 60% màn hình, toolbar trong suốt (`toolbar_fg_on_image`), nút chia sẻ.
- Dưới hero: avatar 64dp đè lên mép ảnh, tên (Headline), địa chỉ (Caption), sao + số đánh giá, **giá/ngày** (Title, primary).
- Chip thiết bị/phong cách: Thân máy, Ống kính, Phong cách (từ `User`).
- "Album" cuộn ngang (ảnh 120dp), tap → viewer. "Đánh giá" (comment thật của `photographerId`).
- **Thanh đáy cố định**: "Nhắn tin" (Outline) + "Đặt lịch" (Primary, chiếm 2/3). An toàn vùng gesture.

### 8.3 Sheet đặt lịch (2 bước)
- Bước 1 "Thời gian & địa điểm": chọn ngày (calendar tháng, ngày NAG bận bị mờ), khung giờ (2 chip nhanh: Buổi sáng 8–12, Cả ngày 8–17, hoặc tuỳ chỉnh), địa điểm (mặc định từ chip lọc / vị trí; sửa → Autocomplete). Progress "1/2".
- Bước 2 "Xem lại": card NAG (ảnh + tên), dòng ngày giờ, địa điểm, giá (mặc định giá/ngày; "Đề nghị giá khác" → nhập), ghi chú tuỳ chọn. Nút "Gửi yêu cầu" (Primary, loading state).
- Validation inline: ngày quá khứ, giờ kết thúc ≤ bắt đầu, giá ≤ 0, thiếu địa điểm. Lỗi hiện dưới trường, nút disabled tới khi hợp lệ.

### 8.4 Xác nhận & chi tiết booking
- Sau gửi: màn "Đã gửi yêu cầu" với timeline dọc: Đã gửi ✓ · Chờ xác nhận (active) · Chụp · Hoàn thành. Card NAG, ngày giờ, địa điểm, giá. Nút "Nhắn tin" và "Huỷ yêu cầu" (Danger text).
- Cùng màn dùng cho mọi trạng thái: ACCEPTED (timeline bước 2 ✓, thêm "Thêm vào lịch"), DENIED (badge đỏ + "Tìm nhiếp ảnh gia khác"), CLOSED/hoàn thành (nút "Đánh giá" → ghi `rating_star` + comment).

### 8.5 Tab Dự án
- Khách: segmented Đang chờ / Sắp tới / Đã xong / Dự án của tôi. BookingCard: ảnh NAG 72dp trái, tên, ngày giờ (tabular), địa điểm, badge trạng thái, giá phải.
- Nhiếp ảnh gia: mặc định "Yêu cầu mới" (badge số). Card có avatar khách, ngày giờ, địa điểm, giá, và 2 nút inline "Từ chối" (Outline) / "Chấp nhận" (Primary). Toggle icon Lịch ở toolbar → WeekView.
- Empty state mỗi segment ("Chưa có yêu cầu nào. Hoàn thiện portfolio để được tìm thấy").

### 8.6 Dự án mở
- Khách tạo qua cùng sheet, chế độ "Dự án mở" (không có NAG, thêm ngân sách + mô tả). Chi tiết: dải avatar người ứng tuyển → tap → Hồ sơ → "Chọn người này" → tạo booking ACCEPTED + đóng dự án.
- Nhiếp ảnh gia thấy ở Khám phá: card có ảnh bản đồ tĩnh, ngày, ngân sách, mô tả 2 dòng, nút "Ứng tuyển" (đã ứng tuyển → Outline "Đã ứng tuyển", disabled).

### 8.7 Tin nhắn
- Danh sách: avatar 40dp, tên, tin cuối, thời gian, chấm chưa đọc; sắp xếp theo tin cuối.
- Hội thoại: card booking mỏng ở đầu (ảnh, ngày, badge) nếu có; bong bóng `bg_chat_bubble_me/you`; nút gửi ảnh nối lại `GetImageManager` + `image/` Storage đã có.

### 8.8 Trạng thái chung
- Loading: skeleton card (không dialog chặn) cho danh sách; nút Primary có spinner khi submit.
- Empty: minh hoạ 120dp + tiêu đề + 1 hành động.
- Lỗi mạng: Snackbar "Không có kết nối" + "Thử lại"; giữ dữ liệu cache (Firestore offline).

## 9. Ưu tiên triển khai

| Ưu tiên | Việc | Tác động chuyển đổi |
|--------|------|---------------------|
| 1 | Bottom nav + Khám phá card ảnh + Hồ sơ NAG có CTA | Người dùng thấy ảnh và giá trước khi đặt |
| 2 | Sheet đặt lịch 2 bước + validation + màn xác nhận + huỷ | Giảm bỏ dở, có điểm quay lại |
| 3 | Yêu cầu mới cho NAG (accept/deny inline) + FCM | Rút ngắn thời gian phản hồi |
| 4 | Lọc thật (bán kính, giá, ngày bận) | Kết quả liên quan |
| 5 | Gộp form dự án mở, chọn người ứng tuyển | Đóng vòng dự án mở |
| 6 | Chat có ngữ cảnh, gửi ảnh | |
| 7 | Đánh giá sau chụp | Nuôi rating thật, thay số giả |

Nên làm cùng lộ trình Compose trong `docs/MODERNIZATION-REVIEW.md`: mỗi feature viết lại một lần theo thiết kế này.
