# Setup máy mới (app Flutter)

Làm theo thứ tự từ trên xuống, mỗi bước một lần cho mỗi máy. Mọi công cụ (Android SDK, Flutter, emulator, cache) cài **trong thư mục repo**, không cần quyền admin, không đụng cấu hình hệ thống ngoài vài dòng trong `~/.zshrc`.

Chi tiết sâu hơn: `README.md` (toolchain, `.env`), `docs/FIREBASE-SETUP.md` (Firebase console), `docs/DEVICE-TESTING.md` (điện thoại thật), `app_flutter/README.md` (backend local, cổng, seed).

## Tóm tắt

```bash
brew install openjdk@17 node@22                 # 1. công cụ nền (hoặc cách khác, xem bước 1)
git clone https://github.com/thanhngochoang/booking.git && cd booking
git checkout flutter-rewrite
scripts/setup.sh                                # 2. Android SDK, Flutter, font; in ra đoạn ~/.zshrc
# 3. dán đoạn ~/.zshrc mà setup.sh in ra, rồi mở terminal mới
scripts/install-emulator.sh                     # 4. emulator + AVD photobooking_api35 (~2,2 GB, không bắt buộc)
cp .env.example .env                            # 5. điền key; đặt google-services.json + firebase_options.dart
cd app_flutter && ../scripts/bin/flutter pub get && ../scripts/bin/flutter analyze && ../scripts/bin/flutter test   # 6. kiểm tra
# 7. VS Code: Cmd+Q rồi mở lại thư mục gốc repo, chọn "Flutter: Android emulator", F5
```

## 1. Công cụ nền

| Công cụ | Dùng cho | Cài |
|---|---|---|
| `git`, `curl`, `unzip`, `python3` | script cài đặt | macOS có sẵn (`xcode-select --install` nếu thiếu `git`) |
| JDK 17 | Gradle/Android, Firestore emulator | `brew install openjdk@17`, hoặc giải nén Temurin/Zulu 17 (tar.gz) vào `.jdk/` sao cho có `.jdk/Contents/Home/bin/java`. AGP chỉ chạy trên JDK 17–21. |
| Node.js 22+ | Firebase CLI, Cloud Functions, backend local | `brew install node@22` hoặc nvm |
| VS Code + extension **Flutter** (Dart-Code) | debug app | — |

## 2. Cài SDK vào repo

```bash
scripts/setup.sh
```

Script tải Android SDK vào `.android-sdk/`, Flutter stable vào `.flutter/`, font vào `app_flutter/assets/fonts/`, tạo truststore cho mạng công ty (`.certs/`), chấp nhận license Android và chạy `flutter doctor`. Chạy lại an toàn: phần đã có thì bỏ qua.

Không gọi `flutter`/`dart` của hệ thống. Dùng `scripts/bin/flutter` và `scripts/bin/dart` (đặt `HOME=.home/`, SDK, JDK và truststore của repo), hoặc `source scripts/env.sh` trong mỗi shell mới để `PATH` trỏ tới chúng.

## 3. Biến môi trường cho VS Code (`~/.zshrc`)

Dart-Code (extension Flutter của VS Code) tìm `adb` và emulator qua `ANDROID_HOME` của shell. Cuối bước 2, `scripts/setup.sh` in ra đúng đoạn cần dán, với đường dẫn repo **trên máy này**:

```bash
# booking repo (Android SDK + AVD inside the repo)
BOOKING="/đường/dẫn/tới/booking"
export ANDROID_HOME="$BOOKING/.android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_AVD_HOME="$BOOKING/.home/.android/avd"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
```

- Đừng chép đường dẫn từ máy khác. Nếu `ANDROID_HOME` trỏ vào thư mục không tồn tại, VS Code không thấy thiết bị nào.
- Không đặt các biến này trong `.vscode/settings.json` (`dart.env`): đường dẫn tuyệt đối ở đó sẽ sai trên máy khác, và Dart-Code không hiểu `${workspaceFolder}`.
- Sau khi sửa `~/.zshrc`: **thoát hẳn VS Code (Cmd+Q) rồi mở lại**. Reload Window không đủ, vì VS Code chỉ đọc môi trường shell lúc khởi động.

Kiểm tra trong terminal mới: `echo $ANDROID_HOME && ls "$ANDROID_HOME/platform-tools/adb"`.

## 4. Android emulator (không bắt buộc)

```bash
scripts/install-emulator.sh       # tải emulator + system image Android 35 (Google Play), tạo AVD photobooking_api35
scripts/start-emulator.sh         # bật AVD và chờ boot xong (VS Code tự gọi khi F5)
```

AVD nằm ở `.home/.android/avd/`. Test trên điện thoại thật thì làm theo `docs/DEVICE-TESTING.md` bước 1–4.

## 5. Cấu hình bí mật (không có trong git)

| File | Lấy ở đâu |
|---|---|
| `.env` (gốc repo) | `cp .env.example .env`, điền `FACEBOOK_CLIENT_TOKEN` (và `GOOGLE_PLACES_API_KEY` nếu build app Java cũ). Bảng biến: `README.md`. |
| `app_flutter/android/app/google-services.json` | Firebase console → Project settings → app Android `com.thanhbk.photobooking`. Hoặc đặt `FLUTTER_GOOGLE_SERVICES_JSON_B64` trong `.env`, `scripts/env.sh` sẽ ghi ra file. |
| `app_flutter/lib/firebase_options.dart` | Sinh từ `google-services.json`: `docs/FIREBASE-SETUP.md` bước 7, cách B (không cần login). |

**Google Sign-In** cần SHA‑1 của debug keystore trên máy này (`.home/.android/debug.keystore`, tạo ở lần build đầu). Lấy SHA‑1 bằng `cd app_flutter/android && ./gradlew signingReport` (sau `source scripts/env.sh`), thêm vào Firebase theo `docs/FIREBASE-SETUP.md` bước 3. Chưa thêm thì đăng nhập Google báo `ApiException: 10`.

## 6. Kiểm tra

```bash
cd app_flutter
../scripts/bin/flutter pub get
../scripts/bin/flutter analyze && ../scripts/bin/flutter test
../scripts/bin/flutter devices          # phải thấy emulator-5554 (nếu emulator đang chạy) hoặc điện thoại
```

Backend local (không bắt buộc, cần Node 22): `scripts/backend-local.sh`, Emulator UI ở http://127.0.0.1:4000, tài khoản seed trong `app_flutter/firebase/functions/seed/README.md`.

## 7. Chạy app từ VS Code

Mở **thư mục gốc repo** (`booking/`, không phải `app_flutter/`), tab Run and Debug, chọn cấu hình rồi nhấn F5:

| Cấu hình | Thiết bị | Backend |
|---|---|---|
| Flutter: (debug) | thiết bị đang chọn ở thanh trạng thái (góc phải dưới) | Firebase dev |
| Flutter: Android emulator | tự bật `photobooking_api35` (`scripts/start-emulator.sh`) | Firebase dev |
| Flutter: Android emulator + backend local | như trên | emulators local (chạy `scripts/backend-local.sh` trước) |
| Flutter: (profile) | thiết bị đang chọn | Firebase dev, đo hiệu năng |

Terminal thay cho VS Code: `cd app_flutter && ../scripts/bin/flutter run -d emulator-5554` (thêm `--dart-define=USE_EMULATORS=true` để dùng backend local).

## Xử lý lỗi thường gặp

| Hiện tượng | Nguyên nhân và cách sửa |
|---|---|
| F5 báo **device not found** / VS Code không thấy emulator, trong khi `scripts/bin/flutter devices` vẫn thấy | Daemon Flutter của VS Code đang chạy với `ANDROID_HOME` sai hoặc cũ (chép từ máy khác, hoặc VS Code mở trước khi sửa `~/.zshrc`). Sửa `~/.zshrc` theo bước 3, **Cmd+Q** VS Code rồi mở lại. Kiểm tra: `ps -Eo command= -p $(pgrep -f "flutter_tools.snapshot daemon") \| tr ' ' '\n' \| grep ANDROID_HOME` phải ra đường dẫn của máy này. |
| Emulator bật lên rồi tắt ngay khi F5 (log `.home/emulator.log`: "emulator ran for just 6xx ms") | Bản cũ của `scripts/start-emulator.sh` để emulator dính vào terminal của task, terminal đóng thì emulator tắt theo. Pull bản mới (emulator chạy trong session riêng). |
| `adb devices` thấy emulator là `unauthorized` hoặc `offline` | `adb kill-server`, rồi chạy lại `scripts/start-emulator.sh`. |
| Gradle báo `PKIX path building failed` | Mạng công ty ký lại HTTPS. Chạy `source scripts/env.sh` một lần để tạo `.certs/truststore.jks`; nếu vẫn lỗi, xoá `.certs/` rồi chạy lại. |
| `JDK 17 not found` khi chạy `setup.sh` | Cài theo bước 1. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | App trên thiết bị do máy khác cài (keystore khác): `adb uninstall com.thanhbk.photobooking`. |
| `[core/duplicate-app]` khi mở app | `firebase_options.dart` và `google-services.json` khác project. Sinh lại `firebase_options.dart` (bước 5). |

Thiết bị thật (Samsung, Wi‑Fi debug, Chặn tự động): bảng lỗi đầy đủ trong `docs/DEVICE-TESTING.md`.
