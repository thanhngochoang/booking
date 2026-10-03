# Setup máy mới (app Flutter)

Làm theo thứ tự từ trên xuống, mỗi bước một lần cho mỗi máy. Mọi công cụ (Android SDK, Flutter, emulator, cache) cài **trong thư mục repo**, không cần quyền admin, không đụng cấu hình hệ thống ngoài vài dòng trong `~/.zshrc`.

Chi tiết sâu hơn: `README.md` (toolchain, `.env`), `docs/FIREBASE-SETUP.md` (Firebase console), `docs/DEVICE-TESTING.md` (điện thoại thật), `app_flutter/README.md` (backend local, cổng, seed).

## Tóm tắt

```bash
brew install openjdk@17 node@22                 # 1. công cụ nền (hoặc cách khác, xem bước 1)
git clone https://github.com/thanhngochoang/booking.git && cd booking
git checkout flutter-rewrite
scripts/setup.sh                                # 2. Android SDK, Flutter, font; 3. tự ghi biến môi trường vào ~/.zshrc (scripts/machine-env.sh)
scripts/install-emulator.sh                     # 4. emulator + AVD photobooking_api35 (~2,2 GB, không bắt buộc)
cp .env.example .env                            # 5. điền key; đặt google-services.json + firebase_options.dart
cd app_flutter && ../scripts/bin/flutter pub get && ../scripts/bin/flutter analyze && ../scripts/bin/flutter test   # 6. kiểm tra
# 7. VS Code: Cmd+Q rồi mở lại thư mục gốc repo, chọn "Flutter: Android emulator" (hoặc "Flutter: (debug)" cho thiết bị đang chọn), F5
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

## 3. Biến môi trường cho VS Code (`~/.zshrc`, tự động)

Dart-Code (extension Flutter của VS Code) tìm `adb` và emulator qua `ANDROID_HOME` của shell. `scripts/setup.sh` gọi `scripts/machine-env.sh`, script này **tự ghi** vào `~/.zshrc` (hoặc `~/.bash_profile` nếu dùng bash) một khối có đánh dấu, với đường dẫn repo **trên máy này**:

```bash
# >>> booking repo (scripts/machine-env.sh) >>>
export BOOKING="/đường/dẫn/tới/booking"
export ANDROID_HOME="$BOOKING/.android-sdk"
...
# <<< booking repo <<<
```

- Chạy lại `scripts/machine-env.sh` bất cứ lúc nào (chuyển repo sang thư mục khác, hoặc `scripts/check-device.sh` báo `~/.zshrc does not point at this repo`): khối cũ được thay, không bị lặp. Khối dán tay kiểu cũ cũng được thay luôn.
- Mọi worktree (`scripts/worktree.sh`) dùng chung SDK và AVD của checkout chính, nên chỉ cần một khối cho mỗi máy.
- Không đặt các biến này trong `.vscode/settings.json` (`dart.env`): đường dẫn tuyệt đối ở đó sẽ sai trên máy khác, và Dart-Code không hiểu `${workspaceFolder}`. Thứ gì riêng của máy (đường dẫn, thiết bị đã chọn) nằm ở môi trường máy và trạng thái VS Code của máy đó; project trong git giống hệt nhau trên mọi máy.
- Sau đó: **thoát hẳn VS Code (Cmd+Q) rồi mở lại**. Reload Window không đủ, vì VS Code chỉ đọc môi trường shell lúc khởi động.

## 4. Android emulator (không bắt buộc)

```bash
scripts/install-emulator.sh       # tải emulator + system image Android 35 (Google Play), tạo AVD photobooking_api35
scripts/start-emulator.sh         # bật AVD và chờ boot xong (VS Code tự gọi khi F5)
```

AVD nằm ở `.home/.android/avd/`. ABI theo máy: `arm64-v8a` trên Mac Apple Silicon, `x86_64` trên Mac Intel; còn lại (Android 35, Google Play, 1080×2400) giống nhau trên mọi máy. Test trên điện thoại thật thì làm theo `docs/DEVICE-TESTING.md` bước 1–4.

**Genymotion** (nếu dùng): Settings → ADB → "Use custom Android SDK tools" → chọn thư mục `.android-sdk` của repo. Nếu để adb riêng của Genymotion, hai adb server tranh nhau và thiết bị lúc thấy lúc không (`adb server version doesn't match`).

## 5. Cấu hình bí mật (không có trong git)

| File | Lấy ở đâu |
|---|---|
| `.env` (gốc repo) | `cp .env.example .env`, điền `FACEBOOK_CLIENT_TOKEN` (và `GOOGLE_PLACES_API_KEY` nếu build app Java cũ). Bảng biến: `README.md`. |
| `app_flutter/android/app/google-services.json` | Firebase console → Project settings → app Android `com.thanhbk.photobooking`. Hoặc đặt `FLUTTER_GOOGLE_SERVICES_JSON_B64` trong `.env`, `scripts/env.sh` sẽ ghi ra file. |
| `app_flutter/lib/firebase_options.dart` | Sinh từ `google-services.json`: `docs/FIREBASE-SETUP.md` bước 7, cách B (không cần login). |

**Khoá ký debug dùng chung**: mọi bản debug ký bằng `app_flutter/android/app/debug.keystore` (có trong git, mật khẩu chuẩn `android`, không phải bí mật), dù build từ VS Code hay terminal, trên máy nào. Nhờ vậy bản build của người này cài đè được lên bản của người khác trên cùng thiết bị. **Google Sign-In** cần SHA‑1 của khoá này trong Firebase (chỉ thêm một lần cho cả team, `docs/FIREBASE-SETUP.md` bước 3); xem SHA‑1 bằng `scripts/check-device.sh`. Chưa thêm thì đăng nhập Google báo `ApiException: 10`.

## 6. Kiểm tra

```bash
cd app_flutter
../scripts/bin/flutter pub get
../scripts/bin/flutter analyze && ../scripts/bin/flutter test
../scripts/bin/flutter devices          # phải thấy thiết bị đang kết nối (AVD, Genymotion hoặc điện thoại)
../scripts/check-device.sh              # adb, thiết bị, khoá ký: so sánh giữa các máy khi có lỗi
```

Backend local (không bắt buộc, cần Node 22): `scripts/backend-local.sh`, Emulator UI ở http://127.0.0.1:4000, tài khoản seed trong `app_flutter/firebase/functions/seed/README.md`.

## 7. Chạy app từ VS Code

Mở **thư mục gốc repo** (`booking/`, không phải `app_flutter/`), tab Run and Debug, chọn cấu hình rồi nhấn F5. **Thiết bị đang chọn** là thiết bị hiện ở thanh trạng thái (góc phải dưới): bấm vào đó hoặc Cmd+Shift+P → **Flutter: Select Device** để xem danh sách thiết bị đang kết nối (điện thoại USB/Wi‑Fi, AVD, Genymotion). Thiết bị vừa cắm vào được chọn ngay; nếu chưa có thiết bị hợp lệ, F5 tự hiện danh sách.

Thiết bị đã chọn được VS Code **nhớ riêng trên từng máy** (không ghi vào `launch.json`): lần đầu chọn trong danh sách, những lần sau F5 chạy luôn trên thiết bị đó nếu nó đang kết nối.

| Cấu hình | Thiết bị | Backend |
|---|---|---|
| Flutter: (debug) | thiết bị đang chọn | Firebase dev |
| Flutter: Android emulator | tự bật `photobooking_api35` nếu chưa có emulator (`scripts/start-emulator.sh`), chạy trên thiết bị đang chọn | Firebase dev |
| Flutter: Android emulator + backend local | như trên | emulators local (chạy `scripts/backend-local.sh` trước) |
| Flutter: (debug) + backend local | thiết bị đang chọn (điện thoại, AVD, Genymotion) | emulators local, qua `adb reverse` (dưới) |
| Flutter: (profile) | thiết bị đang chọn | Firebase dev, đo hiệu năng |

**Backend local trên mọi thiết bị như nhau:** "Flutter: (debug) + backend local" chạy `scripts/adb-reverse.sh` trước khi build. Script `adb reverse` các cổng 9099, 8080, 5001, 9199 của mọi thiết bị đang kết nối về máy Mac, nên app dùng `EMULATOR_HOST=127.0.0.1` cho mọi loại thiết bị: không cần nhớ `10.0.3.2` cho Genymotion hay IP LAN cho điện thoại, và `backend-local.sh` không cần `--lan`. Cắm thêm thiết bị trong lúc chạy thì chạy lại `scripts/adb-reverse.sh`.

Task (Terminal → Run Task) **check-device**: in cấu hình debug của máy này (`scripts/check-device.sh`) để so giữa các máy.

Terminal thay cho VS Code: `cd app_flutter && ../scripts/bin/flutter run` (hỏi thiết bị nếu có nhiều; `-d <id>` để chọn sẵn). Backend local: `../scripts/adb-reverse.sh && ../scripts/bin/flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=127.0.0.1`. Luôn dùng `../scripts/bin/flutter`, không dùng `flutter` của hệ thống.

## Xử lý lỗi thường gặp

| Hiện tượng | Nguyên nhân và cách sửa |
|---|---|
| F5 báo **device not found** / VS Code không thấy emulator, trong khi `scripts/bin/flutter devices` vẫn thấy | Daemon Flutter của VS Code đang chạy với `ANDROID_HOME` sai hoặc cũ (chép từ máy khác, hoặc VS Code mở trước khi sửa `~/.zshrc`). Chạy `scripts/machine-env.sh`, **Cmd+Q** VS Code rồi mở lại. Kiểm tra: `ps -Eo command= -p $(pgrep -f "flutter_tools.snapshot daemon") \| tr ' ' '\n' \| grep ANDROID_HOME` phải ra đường dẫn của máy này. |
| Emulator bật lên rồi tắt ngay khi F5 (log `.home/emulator.log`: "emulator ran for just 6xx ms") | Bản cũ của `scripts/start-emulator.sh` để emulator dính vào terminal của task, terminal đóng thì emulator tắt theo. Pull bản mới (emulator chạy trong session riêng). |
| `adb devices` thấy emulator là `unauthorized` hoặc `offline` | `adb kill-server`, rồi chạy lại `scripts/start-emulator.sh`. |
| Gradle báo `PKIX path building failed` | Mạng công ty ký lại HTTPS. Chạy `source scripts/env.sh` một lần để tạo `.certs/truststore.jks`; nếu vẫn lỗi, xoá `.certs/` rồi chạy lại. |
| `JDK 17 not found` khi chạy `setup.sh` | Cài theo bước 1. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | App trên thiết bị được ký bằng khoá khác (bản cài trước khi có khoá debug dùng chung, hoặc build bằng `flutter` của hệ thống). Gỡ một lần: `adb uninstall com.thanhbk.photobooking` (mất dữ liệu app trên thiết bị đó). |
| App chạy nhưng không kết nối backend local | Chưa chạy `scripts/backend-local.sh`, hoặc thiết bị cắm sau khi F5: chạy `scripts/adb-reverse.sh`. `scripts/check-device.sh` cho biết `adb-reverse:on/off` của từng thiết bị. |
| Thiết bị lúc thấy lúc không, `adb server version doesn't match` | Hai adb server chạy cùng lúc (thường là của Genymotion). Trỏ Genymotion vào `.android-sdk` của repo (bước 4), rồi `adb kill-server`. |
| `[core/duplicate-app]` khi mở app | `firebase_options.dart` và `google-services.json` khác project. Sinh lại `firebase_options.dart` (bước 5). |

Thiết bị thật (Samsung, Wi‑Fi debug, Chặn tự động): bảng lỗi đầy đủ trong `docs/DEVICE-TESTING.md`.

## Worktree (làm nhiều nhánh cùng lúc)

```bash
scripts/worktree.sh <branch> [tên]     # tạo .worktrees/<tên> (nhánh có sẵn, hoặc nhánh mới từ origin/develop)
code .worktrees/<tên>                  # mở riêng trong VS Code, F5 như checkout chính
```

Toolchain (`.flutter`, `.android-sdk`, `.home`, `.pub-cache`, `.certs`) và cấu hình bí mật (`.env`, `google-services.json`, `firebase_options.dart`) không có trong git, nên script tạo symlink từ checkout chính thay vì tải lại. AVD, cache Gradle và khoá ký debug dùng chung. Xoá: `git worktree remove .worktrees/<tên>`.
