# Test app Flutter trên điện thoại Samsung

Tài liệu này hướng dẫn biến một điện thoại Samsung Galaxy (One UI) thành thiết bị chạy và debug app `app_flutter/` qua cáp USB hoặc Wi‑Fi. Bước 0 làm một lần cho mỗi máy tính (và cũng là cách dùng emulator). Bước 1–4 làm một lần cho mỗi điện thoại. Bước 5 làm mỗi lần test. Máy tính phải đã setup theo `docs/SETUP.md` và nối Firebase theo `docs/FIREBASE-SETUP.md`.

Tên menu bên dưới lấy theo One UI 6–7 tiếng Việt, tên tiếng Anh để trong ngoặc. Máy đời cũ có thể đặt tên hơi khác; dùng ô tìm kiếm trong Cài đặt nếu không thấy.

## Yêu cầu

| Mục | Giá trị |
|-----|---------|
| Android tối thiểu | 7.0 (API 24, `minSdk` mặc định của Flutter) |
| Cáp | Cáp USB truyền được dữ liệu. Nhiều cáp đi kèm sạc dự phòng chỉ sạc, máy tính sẽ không thấy điện thoại |
| Driver | macOS không cần driver |
| Package của app | `com.thanhbk.photobooking` |

## 0. Chuẩn bị máy tính (một lần mỗi máy)

VS Code cần biết Android SDK cục bộ của repo để liệt kê điện thoại và emulator. Dart-Code không thay `${workspaceFolder}` trong `dart.env`, nên các biến này đặt trong shell. Thêm vào `~/.zshrc`, sửa `BOOKING` thành đường dẫn repo trên máy bạn:

```bash
BOOKING="$HOME/Documents/_project/Tool/booking"
export ANDROID_HOME="$BOOKING/.android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_AVD_HOME="$BOOKING/.home/.android/avd"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

Sau đó thoát hẳn VS Code (Cmd+Q) rồi mở lại: VS Code chỉ đọc môi trường của zsh lúc khởi động, Reload Window không đủ.

Muốn test trên emulator thay vì điện thoại, chạy `scripts/install-emulator.sh` một lần (tải khoảng 2,2 GB). Script tạo AVD `photobooking_api35` (Android 35, có Google Play). Mở nó trong VS Code bằng lệnh **Flutter: Launch Emulator**, hoặc `emulator -avd photobooking_api35` trong terminal. Trên Dock, emulator hiện tên `qemu-system-aarch64`. Từ đây, chọn emulator thay cho điện thoại ở bước 5; bước 1–4 chỉ dành cho điện thoại.

## 1. Bật Tùy chọn nhà phát triển

1. Mở **Cài đặt → Thông tin điện thoại → Thông tin phần mềm** (Settings → About phone → Software information).
2. Chạm 7 lần vào **Số hiệu bản tạo** (Build number), nhập mã PIN nếu được hỏi.
3. Máy báo "Chế độ nhà phát triển đã được bật". Mục **Tùy chọn nhà phát triển** (Developer options) giờ nằm ở cuối danh sách Cài đặt.

## 2. Bật gỡ lỗi USB

Trong **Cài đặt → Tùy chọn nhà phát triển**:

- Bật **Gỡ lỗi USB** (USB debugging). Bắt buộc.
- Bật **Không khóa màn hình** (Stay awake) để màn hình không tắt khi đang cắm cáp. Không bắt buộc nhưng tiện khi debug lâu.
- Bật **Gỡ lỗi không dây** (Wireless debugging) nếu muốn debug qua Wi‑Fi (bước 6).

## 3. Tắt Chặn tự động (Auto Blocker)

Từ One UI 6, Samsung có tính năng **Chặn tự động** (Auto Blocker), mặc định bật trên nhiều máy. Khi bật, nó chặn lệnh qua cáp USB: máy tính không thấy điện thoại, hoặc cài app bị từ chối, dù đã bật gỡ lỗi USB.

Mở **Cài đặt → Bảo mật và quyền riêng tư → Chặn tự động** (Security and privacy → Auto Blocker) và tắt nó. Nếu muốn giữ phần còn lại, chỉ cần tắt mục **Chặn lệnh qua cáp USB** (Block commands by USB cable).

## 4. Cho phép máy tính này

1. Mở khóa điện thoại và cắm cáp vào máy tính.
2. Nếu thanh thông báo hỏi chế độ USB, chọn **Truyền tệp** (Transferring files). Chế độ "Chỉ sạc" đôi khi làm adb không thấy máy.
3. Điện thoại hiện hộp thoại **Cho phép gỡ lỗi USB?**. Đánh dấu **Luôn cho phép từ máy tính này** rồi chọn **Cho phép**.
4. Kiểm tra từ gốc repo:

   ```bash
   .android-sdk/platform-tools/adb devices -l
   ```

   Điện thoại phải hiện với trạng thái `device`, ví dụ `R5CT1234ABC  device  model:SM_S918B`. Nếu hiện `unauthorized`, xem mục Xử lý lỗi.

## 5. Chạy và debug app

### VS Code

1. Mở thư mục gốc repo (`booking/`), không mở `app_flutter/`. Các file `.vscode/launch.json` và `.vscode/settings.json` nằm ở gốc.
2. Chọn điện thoại ở thanh trạng thái (góc phải dưới), ví dụ `SM S918B (mobile)`.
3. Mở tab Run and Debug, chọn **Flutter: (debug)** rồi nhấn F5. Lần đầu build mất vài phút.
4. Lưu file là hot reload. Breakpoint, DevTools và log hoạt động như trên emulator.

Cấu hình **Flutter: (profile)** dùng để đo hiệu năng thật (không có hot reload, gần giống bản release). Xem thêm `docs/testing/battery-and-performance.md`.

### Terminal

```bash
cd app_flutter
../scripts/bin/flutter devices                 # lấy id của điện thoại
../scripts/bin/flutter run -d <id>             # debug
../scripts/bin/flutter run -d <id> --profile   # profile
```

## 6. Debug qua Wi‑Fi (không bắt buộc)

Android 11 trở lên. Máy tính và điện thoại phải cùng một mạng Wi‑Fi. Mạng công ty hoặc Wi‑Fi khách thường chặn kết nối giữa các thiết bị; khi đó dùng cáp.

1. Trên điện thoại: **Tùy chọn nhà phát triển → Gỡ lỗi không dây** → chạm vào chữ (không phải công tắc) → **Ghép nối thiết bị bằng mã ghép nối** (Pair device with pairing code). Màn hình hiện địa chỉ `IP:cổng` và mã 6 số.
2. Trên máy tính:

   ```bash
   .android-sdk/platform-tools/adb pair <IP>:<cổng ghép nối>      # nhập mã 6 số
   .android-sdk/platform-tools/adb connect <IP>:<cổng kết nối>    # cổng ở màn hình Gỡ lỗi không dây, khác cổng ghép nối
   ```

3. Điện thoại hiện trong danh sách thiết bị của VS Code như khi cắm cáp. Ghép nối chỉ làm một lần. Sau khi điện thoại khởi động lại hoặc đổi mạng, chỉ cần chạy lại `adb connect`.

## 7. Lưu ý riêng cho app này

- **Đăng nhập Google** dùng SHA‑1 của debug keystore trên **máy tính** build app (`.home/.android/debug.keystore`), không phụ thuộc điện thoại. Nếu đăng nhập Google lỗi ngay (`ApiException: 10`), thêm SHA‑1 của máy tính này vào Firebase theo `docs/FIREBASE-SETUP.md` bước 3.
- **Mỗi máy tính có keystore riêng.** Điện thoại đang có app do máy A cài thì máy B không cài đè được (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Gỡ app cũ trước:

  ```bash
  .android-sdk/platform-tools/adb uninstall com.thanhbk.photobooking
  ```

- **Tiết kiệm pin của Samsung** có thể đóng app chạy nền, làm thông báo đến trễ hoặc không đến. Khi test thông báo, vào **Cài đặt → Pin → Giới hạn sử dụng nền** (Background usage limits) và thêm app vào **Ứng dụng không bao giờ ngủ** (Never sleeping apps). Người dùng thật không làm bước này, nên cũng test một lần ở chế độ mặc định.

## Xử lý lỗi

| Hiện tượng | Nguyên nhân và cách sửa |
|------------|-------------------------|
| `adb devices` không hiện gì | Cáp chỉ sạc, Chặn tự động đang bật (bước 3), hoặc chế độ USB là "Chỉ sạc". Đổi cáp/cổng, chọn **Truyền tệp**, tắt Chặn tự động. |
| `unauthorized` | Chưa bấm Cho phép trên điện thoại. Mở khóa màn hình và cắm lại. Nếu không hiện hộp thoại: **Tùy chọn nhà phát triển → Thu hồi ủy quyền gỡ lỗi USB** (Revoke USB debugging authorizations), rồi chạy `adb kill-server` và cắm lại. |
| `offline` | Rút cáp, tắt rồi bật lại **Gỡ lỗi USB**, chạy `adb kill-server`. |
| `adb` thấy máy nhưng VS Code không hiện | Thiếu biến ở bước 0, hoặc VS Code mở trước khi thêm chúng. Kiểm tra bước 0, thoát hẳn VS Code (Cmd+Q) rồi mở lại ở gốc repo. |
| `adb devices` trống và **Thông tin hệ thống → USB** (System Information → USB) cũng không có thiết bị Samsung nào | Máy Mac không thấy điện thoại ở mức phần cứng: cáp chỉ sạc, hoặc cắm qua hub/adapter. Đổi cáp, cắm thẳng vào máy. |
| App mở ra rồi lỗi `[core/duplicate-app] A Firebase App named "[DEFAULT]" already exists` | `lib/firebase_options.dart` và `google-services.json` trỏ hai Firebase project khác nhau. Sinh lại `firebase_options.dart` theo `docs/FIREBASE-SETUP.md` bước 7, cách B. |
| Cài app bị từ chối, `INSTALL_FAILED_USER_RESTRICTED` hoặc `INSTALL_FAILED_VERIFICATION_FAILURE` | Chặn tự động hoặc **Xác minh ứng dụng qua USB** (Verify apps over USB) đang chặn. Tắt Chặn tự động; nếu vẫn lỗi, tắt Xác minh ứng dụng qua USB trong Tùy chọn nhà phát triển. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | App do máy tính khác cài. `adb uninstall com.thanhbk.photobooking` rồi chạy lại. |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | Điện thoại hết dung lượng. Bản debug cần khoảng 200 MB. |
| Build dừng ở `Running Gradle task 'assembleDebug'...` rất lâu lần đầu | Bình thường: Gradle tải dependency. Nếu báo `PKIX path building failed`, chạy `source scripts/env.sh` một lần để tạo truststore (xem `README.md`). |

## Khi xong

Tắt **Gỡ lỗi USB** nếu điện thoại là máy cá nhân dùng hằng ngày, và bật lại **Chặn tự động** nếu bạn đã tắt nó. Bật lại khi cần test tiếp.
