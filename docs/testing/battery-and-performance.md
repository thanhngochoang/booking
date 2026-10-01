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
