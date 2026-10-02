# Kiểm tra pin và hiệu năng

Áp dụng cho mọi kế hoạch có màn hoặc widget mới. Phần tự động nằm trong test của từng kế hoạch (`test/support/idle.dart`); tài liệu này là phần đo tay trước khi merge.

## Quy tắc khi viết code

- Không có gì chạy khi người dùng không làm gì: không `Timer.periodic`, không polling mạng, animation chỉ chạy khi có tương tác và dừng hẳn sau đó. Vòng quay chờ (`CircularProgressIndicator`) chỉ hiện trong lúc thật sự chờ.
- Tôn trọng giảm chuyển động (`MediaQuery.disableAnimations`): hiện/ẩn tức thì.
- Mờ nền (`BackdropFilter`) tốn GPU: tối đa 4 vùng mờ trên một màn; phần tử nằm trong vùng đã mờ (thẻ trong `GlassCard`, ô trong sheet) không mờ lại; ô danh sách và thẻ lưới không bao giờ dùng `BackdropFilter`, dùng nền trong mờ (màu có alpha).
- Danh sách dài dùng `ListView.builder`/`SliverList`, không `Column` chứa hết phần tử.
- Ảnh giải mã đúng kích thước hiển thị (`cacheWidth`/`memCacheWidth`), không tải ảnh gốc cho thumbnail.
- Lắng nghe Firestore/stream gắn với màn (`autoDispose`): rời màn là huỷ. Chỉ phiên đăng nhập và hồ sơ của mình được giữ suốt vòng đời app.
- Vị trí: hỏi một lần (`getCurrentPosition`, độ chính xác thấp/trung bình, có hạn chờ), dùng lại vị trí đã lưu trong 30 phút (spec chính 3c.2); không theo dõi liên tục, không xin quyền chạy nền.
- Không dịch vụ nền, không wakelock.

## Đo tay (thiết bị Android thật, bản profile)

Chuẩn bị (từ `app_flutter/`):

```bash
flutter run --profile -d <device-id>
```

Gói ứng dụng: `com.thanhbk.photobooking`.

1. **Khung hình khi đứng yên.** Mở màn cần đo, chờ 5 giây, rồi:
   ```bash
   adb shell dumpsys gfxinfo com.thanhbk.photobooking reset
   ```
   Để yên 30 giây, rồi:
   ```bash
   adb shell dumpsys gfxinfo com.thanhbk.photobooking | grep -E "Total frames rendered|Janky frames"
   ```
   Ngưỡng: **≤ 5 khung hình** trong 30 giây.
2. **Cuộn và chuyển màn.** `reset` như trên, cuộn hết danh sách và quay lại 3 lần, rồi đọc `gfxinfo`. Ngưỡng: **Janky frames < 5%**, **90th percentile ≤ 16 ms**. Khi vượt, mở DevTools (Performance) xem khung nào chậm ở luồng UI hay raster.
3. **CPU khi đứng yên.**
   ```bash
   adb shell top -b -n 5 -d 2 | grep photobooking
   ```
   Ngưỡng: **< 3% CPU** trung bình khi màn đứng yên.
4. **Pin (10 phút dùng thử theo kịch bản của kế hoạch).**
   ```bash
   adb shell dumpsys battery unplug
   adb shell dumpsys batterystats --reset
   ```
   Dùng app 10 phút theo kịch bản, rồi:
   ```bash
   adb shell dumpsys batterystats --charged com.thanhbk.photobooking > battery.txt
   adb shell dumpsys battery reset
   ```
   Trong `battery.txt` kiểm: **không có Wake lock** của app; **GPS ≤ 15 giây** cho mỗi lần hỏi vị trí; mạng di động không bật liên tục khi đứng yên. Muốn xem đồ thị: `adb bugreport bugreport.zip` rồi mở bằng Battery Historian.
5. **Bộ nhớ** sau khi lướt hết các màn của kế hoạch:
   ```bash
   adb shell dumpsys meminfo com.thanhbk.photobooking | grep "TOTAL PSS"
   ```
   Ngưỡng: **< 250 MB**.

## Mẫu ghi kết quả (dán vào mô tả PR)

| Màn / kịch bản | Khung hình đứng yên (30 s) | Janky % | p90 (ms) | CPU đứng yên | Wake lock | GPS (s) | PSS (MB) | Thiết bị |
|---|---|---|---|---|---|---|---|---|
| S… | | | | | | | | |

## Nền tảng vị trí (kế hoạch 3a1)

Kiểm tự động: `test/battery/location_foundations_battery_test.dart` (đứng yên không lên khung hình, danh sách dựng lười, tối đa 4 `BackdropFilter` và không lồng nhau, adapter vị trí chỉ lấy một lần với độ chính xác thấp, manifest Android chỉ xin `ACCESS_COARSE_LOCATION`, Info.plist chỉ xin when-in-use).

Đo tay sau khi 3a2 đưa các thành phần lên màn hình (chưa đo: device profiling pending):

1. Mở Khám phá, chạm "Cho phép", đồng ý: biểu tượng vị trí phải tắt trong vài giây; lần vào lại trong 30 phút không được bật lại.
2. Để Khám phá mở 5 phút không chạm: ghi mức pin hoặc năng lượng thay đổi, timeline không có khung hình.
3. Mở và đóng sheet khu vực 10 lần: raster time dưới 16 ms.

Android: máy tầm trung, `flutter run --profile`, DevTools Performance và `adb shell dumpsys batterystats`.
iOS: Xcode Instruments (Energy Log, Time Profiler) trên iPhone thật; Energy Impact phải là "Low" khi đứng yên và mũi tên vị trí không được còn sau khi lấy vị trí. Hiện chưa build iOS được: ghi "iOS: not measured, blocked by iOS enablement". Dòng iOS trong bảng ghi model iPhone ở cột Thiết bị và Energy Impact thay cho các cột chỉ có ở Android.

## Màn Khám phá (kế hoạch 3a2)

Kiểm tự động: `test/battery/explore_battery_test.dart` (11 test):

- Màn đã tải xong không còn khung hình nào ở cả bốn trạng thái (hỏi vị trí, sự kiện gần bạn, chọn khu vực, sheet khu vực đang mở). Skeleton có nhịp đập nên phải kiểm sau khi dữ liệu đã về. Ngân sách blur: thẻ xin vị trí 1, hàng sự kiện 0, sheet 1.
- Vị trí chỉ hỏi một lần: kéo để làm mới, quay lại từ nền và đổi bán kính dùng lại vị trí còn mới (30 phút); chạm "Cho phép" gọi OS đúng một lần và lấy đúng một vị trí.
- Rời màn thì không còn việc nào chạy: bỏ lifecycle observer, các provider `autoDispose` dừng, không còn truy vấn sự kiện.
- Danh sách 100 sự kiện dựng lười (dưới 25 hàng được dựng).
- Rà mã nguồn: thư mục Explore không có `Timer.periodic`, `Stream.periodic`, `AnimationController`, `Ticker`, `getPositionStream`; cổng sự kiện dựa trên Future; không có ảnh mạng.

Đo tay (chưa đo: device profiling pending, cần điện thoại thật qua adb):

1. Lần đầu vào Khám phá trên máy mới cài: chạm "Cho phép" một lần, cuộn 100 sự kiện, xem raster time.
2. Để Khám phá ở chế độ gần bạn 5 phút không chạm.
3. Đổi chip bán kính 10 lần.
4. Mở sheet khu vực 10 lần.
5. Đưa app xuống nền 1 phút rồi quay lại: một lần đọc quyền, không lấy vị trí mới.

Android: máy tầm trung, `flutter run --profile`, DevTools Performance và `adb shell dumpsys batterystats`. iOS: Xcode Instruments (Energy Log, Time Profiler) trên iPhone thật, Energy Impact phải là "Low" khi đứng yên; hiện ghi "iOS: not measured, blocked by iOS enablement". Dán kết quả vào mô tả PR theo bảng mẫu ở trên.

## Lớp dữ liệu nguồn cấp (kế hoạch 3b1)

Kiểm tự động: `test/battery/feed_data_battery_test.dart` (5 test): thư mục `lib/data/content` không có `.snapshots(`, `Timer.periodic`, `StreamController` và cổng không có `Stream<` (không listener nào có thể sống lâu hơn màn hình); yêu cầu trang 100000 bài chỉ trả 50; `candidates` tối đa 200 và `freeThisWeek` tối đa 50; danh sách dịch vụ tối đa 50; thích là đúng một lần ghi một tài liệu, bỏ thích là một lần xoá. Lớp này không có widget nên không có `expectIdle` hay `expectBlurBudget` ở đây; hai hàm hỗ trợ đã có ở `test/support/idle.dart` và `test/support/blur.dart` cho các kế hoạch màn hình.

Bảng đếm lượt đọc theo hành vi thật của adapter (kiểm bằng đọc mã, `fake_cloud_firestore` không đếm lượt đọc):

| Thao tác | Truy vấn / lượt đọc |
|---|---|
| Trang nguồn cấp đầu (`feed`, `byPhotographer`), trang 20 | 1 truy vấn `limit(n+1)` = n+1 tài liệu (1 bài nhìn trước). Nếu có bài bị bỏ (xoá mềm, hỏng) thì bù thêm tối đa 3 truy vấn nữa: tối đa 1+3 truy vấn, mỗi lần chỉ xin phần còn thiếu. |
| Trang sau | Thêm 1 lượt đọc tài liệu con trỏ (`posts/{cursor}`) rồi như trang đầu. |
| `byId` | 1 tài liệu. |
| Tóm tắt thợ ảnh (`summaries`, `_join`) | Mỗi tác giả khác nhau: tối đa 2 tài liệu (`photographers` và `users`), gom `whereIn` theo nhóm 30 id, các nhóm chạy song song. Một lần tải Trang chủ: 1 truy vấn trang bài + tối đa 2 tài liệu cho mỗi tác giả khác nhau. |
| `freeThisWeek` | 1 truy vấn `limit` (tối đa 50) + 1 tài liệu `users` cho mỗi dòng (nhóm 30). |
| `candidates` | 1 truy vấn tối đa 200 tài liệu + `users` tương ứng (7 nhóm 30); thiết kế để bên gọi lưu đệm. |
| `activeFor` | 1 truy vấn tối đa 50 tài liệu. |
| Thích / lưu / theo dõi | 1 lần ghi (hoặc 1 lần xoá) một tài liệu `{uid}_{id}`; `engagementFor` 2 lượt đọc, `savedAmong` 1–2 truy vấn (nhóm 30 id). |

Ghi chú chi phí đọc: trước bản sửa này một lần tải Trang chủ tốn khoảng 82 lượt đọc; `savedAmong` nay chỉ còn khoảng 1–2 truy vấn (1 truy vấn `userId` + `postId whereIn` cho mỗi 30 id) thay vì 1 lượt đọc mỗi bài. Khởi động nguội của bộ gợi ý khoảng 400 lượt đọc. Về sau: Cloud Functions phi chuẩn hoá `displayName`/`avatarUrl` vào `photographers` và `posts` để bỏ lượt đọc `users`.

Đo tay (chưa đo: device profiling pending):

1. Chạy bộ giả lập Firestore và ghi số lượt đọc của một lần tải Trang chủ: mong đợi 1 truy vấn trang bài và tối đa 2 tài liệu cho mỗi tác giả khác nhau; ghi vào mô tả PR.
2. Khi các màn của kế hoạch 3b4 có mặt: cuộn 5 trang nguồn cấp, kiểm tra DevTools Network không có kết nối mở lâu sau khi rời màn, thêm Performance cho thời gian dựng.

Android: máy tầm trung, `flutter run --profile`, DevTools Network và Performance. iOS: hiện ghi "iOS: not measured, blocked by iOS enablement". Dán kết quả vào mô tả PR theo bảng mẫu ở trên.

## Thẻ nguồn cấp (kế hoạch 3b2)

Kiểm tự động: `test/battery/feed_cards_battery_test.dart` (5 test): một nguồn cấp gồm 5 `PhotoCard`, 5 `PhotographerCard` và một `AppAvatar` đứng yên không còn khung hình nào được lên lịch (`expectIdle`) và có 0 `BackdropFilter` (`expectBlurBudget(max: 0)`); mọi ảnh được yêu cầu với độ rộng giải mã (`cacheWidth`) khác null, làm tròn lên bội số của 50 px (ở tỉ lệ điểm ảnh 3), và ảnh đại diện không bao giờ thử lại và không giải mã ảnh gốc (48 dp x 3 = 144 px, tối đa 200); `network_photo.dart` dùng `CachedNetworkImage` với `memCacheWidth: widget.cacheWidth`, không có `Image.network` hay `NetworkImage(` trần, không có `Timer`, `Ticker`, `AnimationController` hay `Stream.periodic` (chỉ có hiệu ứng hiện dần 150 ms tự kết thúc); năm tệp thẻ (`app_avatar`, `reason_chips`, `photo_card`, `photographer_card`, `network_photo`) không có `BackdropFilter`, `AnimationController` hay `.repeat(`.

Giới hạn: bộ dựng ảnh thật (`CachedNetworkImage`) không chạy trong test widget (test dùng `testPhotoScope`), nên được kiểm bằng đọc mã nguồn và bằng đo tay dưới đây. Danh sách thẻ ở các màn của kế hoạch 3b4 phải dùng `ListView.builder` hoặc sliver lười.

Đo tay (chưa đo: device profiling pending), làm khi 3b4 đã đặt thẻ lên Trang chủ và Tìm:

1. Cuộn nhanh nguồn cấp 100 bài trên máy tầm trung: đọc thời gian raster và kích thước image cache trong DevTools Memory (không tăng sau 100 thẻ ngoài giới hạn của cache).
2. Để Trang chủ đứng yên 5 phút: không khung hình mới, không mạng.
3. Tắt mạng: thẻ ảnh trong feed không bao giờ hiện "Thử lại" (chỉ có ô nền phẳng); chỉ thư viện ảnh ở S02 (retry:true) hiện ô "Thử lại" và không tự thử lại; bật mạng rồi chạm ô để tải lại.

Android: máy tầm trung, `flutter run --profile`, DevTools Performance và Memory, `adb shell dumpsys batterystats`. iOS: Xcode Instruments (Time Profiler, Allocations, Energy Log) trên iPhone thật, Energy Impact phải là "Low" khi đứng yên; hiện ghi "iOS: not measured, blocked by iOS enablement". Dán kết quả vào mô tả PR theo bảng mẫu ở trên (hàng iOS ghi kiểu iPhone ở cột Thiết bị và Energy Impact thay cho các cột chỉ có ở Android).
