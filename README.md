# Cộng đồng nhiếp ảnh gia — Android

Ứng dụng Android (Java) kết nối khách hàng với nhiếp ảnh gia: tìm theo vị trí và khoảng giá, đặt lịch (booking), đăng dự án mở, chat 1‑1, quản lý album và lịch làm việc. Backend hoàn toàn trên Firebase (Auth, Firestore, Realtime Database, Storage).

| | |
|--|--|
| applicationId | `com.thanhbk.timnhay` (app Java cũ) · `com.thanhbk.photobooking` (app Flutter) |
| Java package | `com.paditech.mvpbase` |
| minSdk / targetSdk / compileSdk | 23 / 34 / 34 |
| Ngôn ngữ | Java 17 |
| Build | Gradle 8.9, Android Gradle Plugin 8.5.2 |
| Kiến trúc | MVP tự viết (xem `CLAUDE.md`), Realm cache, EventBus |

## Setup trên máy mới (không cần quyền admin)

Mọi công cụ nằm **trong thư mục repo**, không cài vào hệ thống. Chỉ cần sẵn `git`, `curl`, `unzip`, `python3` (macOS có sẵn) và một JDK 17 do user sở hữu.

```bash
git clone <repo-url> booking && cd booking
git checkout flutter-rewrite          # branch đang phát triển app Flutter
scripts/setup.sh                      # tải Android SDK, Flutter SDK, font; kiểm tra flutter doctor
source scripts/env.sh                 # chạy lại trong MỖI shell mới
cd app_flutter && flutter pub get && flutter run
```

`scripts/setup.sh` làm tuần tự:

| Bước | Script | Kết quả |
|------|--------|---------|
| Android SDK | `scripts/install-sdk.sh` | `.android-sdk/` với platform 34 + 36, build-tools 34.0.0 + 36.0.0, platform-tools. Tải zip thẳng từ dl.google.com nên không cần sdkmanager. |
| Flutter SDK | `scripts/install-flutter.sh` | `.flutter/` bản stable mới nhất cho CPU của máy. |
| Font | `scripts/fetch-fonts.sh` | Be Vietnam Pro + Fraunces vào `app_flutter/assets/fonts/`. |
| Môi trường | `scripts/env.sh` | `JAVA_HOME`, `ANDROID_HOME`, `PATH` (ưu tiên `scripts/bin`), `local.properties`, truststore TLS. |

**JDK 17**: `env.sh` tìm theo thứ tự `.jdk/` trong repo → Homebrew `openjdk@17` (`/opt/homebrew` hoặc `/usr/local`). Không cần sudo: `brew install openjdk@17`, hoặc giải nén tar.gz Temurin/Zulu 17 vào `.jdk/` sao cho có `.jdk/Contents/Home/bin/java`. Vì sao 17 mà không mới hơn: Android Gradle Plugin 8.x (cả app Java cũ lẫn Flutter) chỉ chạy trên JDK 17–21.

**`scripts/bin/flutter` và `scripts/bin/dart`** là wrapper đặt `HOME=.home/` trong repo trước khi gọi Flutter thật. Nhờ vậy Dart, Gradle, Android debug keystore và pub cache đều ghi vào `.home/`, `.pub-cache/`, không đụng home thật. Debug keystore nằm ở `.home/.android/debug.keystore`; SHA‑1 của nó cần đăng ký trong Firebase cho Google Sign‑In (`cd app_flutter/android && ./gradlew signingReport`).

**Mạng công ty (Cloudflare Zero Trust)**: nếu máy nằm sau gateway ký lại HTTPS, Gradle báo `PKIX path building failed`. `env.sh` tự ghép cacerts của JDK với chứng chỉ trong macOS keychain thành `.certs/truststore.jks` và đăng ký cho Gradle qua `.home/.gradle/gradle.properties`. Máy không có gateway thì bước này vô hại.

**Chạy trong Claude Code sandbox**: `flutter test` cần bind cổng local; bật trong settings `"sandbox": { "network": { "allowLocalBinding": true } }`. Sandbox cũng cấm ghi thư mục `.idea/`, nên `flutter create` phải chạy ở thư mục tạm rồi `mv` vào repo (đã làm cho `app_flutter/`).

Thư mục sinh ra và đã gitignore: `.android-sdk/ .flutter/ .jdk/ .home/ .pub-cache/ .certs/ local.properties`.

### Build app Java cũ (`app/`)

```bash
source scripts/env.sh
./gradlew assembleEnvTestDebug              # APK debug
./gradlew testEnvTestDebugUnitTest          # unit test JVM
./gradlew testEnvTestDebugUnitTest --tests com.paditech.mvpbase.ExampleUnitTest
```

Hai flavor `envReal` và `envTest` hiện giống hệt nhau (cùng applicationId, `Config.java` rỗng).

### Build app Flutter (`app_flutter/`)

```bash
source scripts/env.sh && cd app_flutter
flutter pub get
dart run tool/gen_tokens.dart               # theme từ design-system/tokens.json (khi có)
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze && flutter test
flutter build apk --debug
```

## Cấu hình cần điền trước khi chạy

Không có key hay bí mật nào trong source code. Tất cả nằm trong file `.env` ở thư mục gốc (gitignored), tạo từ mẫu:

```bash
cp .env.example .env    # rồi điền giá trị
```

| Biến | Dùng cho | Ghi chú |
|------|----------|---------|
| `GOOGLE_PLACES_API_KEY` | App Java cũ: Places Autocomplete, Maps | Giới hạn key cho Places API và cho app Android (package + SHA‑1) trong Google Cloud. |
| `FACEBOOK_CLIENT_TOKEN` | Cả hai app | Meta developer console → Settings → Advanced → Client token. |
| `APP_GOOGLE_SERVICES_JSON_B64` | App Java cũ (tuỳ chọn) | `base64` của `app/google-services.json`; `scripts/env.sh` ghi ra file khi file chưa có. |
| `FLUTTER_GOOGLE_SERVICES_JSON_B64` | App Flutter (tuỳ chọn) | Tương tự cho `app_flutter/android/app/google-services.json`. |

Gradle đọc biến từ môi trường trước, sau đó mới đến `.env`, rồi đưa vào `resValue`. Vì vậy Android Studio cũng build được mà không cần `source scripts/env.sh`. Biến đã đặt sẵn trong môi trường (ví dụ secret trên CI) luôn thắng giá trị trong `.env`.

Các file `google-services.json` và `app_flutter/lib/firebase_options.dart` cũng gitignored. Lấy chúng từ Firebase console, xem `docs/FIREBASE-SETUP.md`.

Lịch sử git của các commit cũ vẫn còn các key đã lộ. Hãy thu hồi hoặc giới hạn chúng trong Google Cloud Console; gỡ khỏi code hiện tại không làm key cũ hết hiệu lực.

## Nâng cấp 2017 → 2026 (branch `develop`)

Project gốc dùng Gradle 4.1, AGP 3.0.1, Support Library 26, Firebase 11.8. Đã nâng cấp:

- Gradle 8.9, AGP 8.5.2, `namespace` thay cho `package` trong manifest, Java 17.
- Support Library → AndroidX + Material Components (95 file Java/XML, mapping tự động).
- Firebase BoM 33, Play Services Auth 21, Location 21, Facebook SDK 17, Glide 4.16, ButterKnife 10, Realm 10.19, OkHttp 4, Gson 2.11.
- Các API Google đã bị gỡ được thay thế:
  - **Place Picker** (ngừng hoạt động 2019) → Places SDK Autocomplete qua `PlacePickerHelper`, khởi tạo trong `BaseApplication`.
  - `FirebaseInstanceId.getToken()` → `FirebaseMessaging.getToken()` (bất đồng bộ; `Device.device_token` có thể null ở lần lưu đầu).
  - `GoogleApiClient` sign‑in → `GoogleSignInClient`.
  - `LocationServices.SettingsApi` / `FusedLocationApi` → `SettingsClient` + `FusedLocationProviderClient`.
  - Jackson1 `JacksonFactory` + `AndroidHttp` (Calendar API) → `GsonFactory` + `NetHttpTransport`.
- Xoá `FlickrManager` và thư viện flickrj (code mẫu không dùng).

**Trạng thái kiểm chứng:** mã nguồn đã được migrate và kiểm tra tĩnh (không còn tham chiếu `android.support.*`, tài nguyên XML hợp lệ), nhưng **chưa chạy được `assembleEnvTestDebug` thành công** trong môi trường tạo ra thay đổi này vì Maven Central bị chặn. Bước đầu tiên khi checkout: chạy build theo hướng dẫn trên và sửa lỗi biên dịch nếu có (dự kiến nhỏ: deprecation, thiếu import).

## Viết lại bằng Flutter (branch `flutter-rewrite`)

Phiên bản kế tiếp là app Flutter mới trong `app_flutter/`, thiết kế theo `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` (marketplace nhiếp ảnh vận hành bởi cộng đồng: khám phá → tin cậy → đặt cọc → chụp → review → chia sẻ). App Java cũ giữ nguyên để tham chiếu và migrate dữ liệu.

Bắt đầu: xem `app_flutter/README.md`. CI (`.github/workflows/flutter.yml`) chạy analyze, test và Firestore rules test mỗi lần push.

## Tài liệu

- `CLAUDE.md` — kiến trúc, luồng dữ liệu, quy ước.
- `docs/FIREBASE-SETUP.md` — từng bước nối app Flutter với Firebase (project, SHA‑1, Google/Facebook login, Firestore rules, firebase_options.dart).
- `design-system/README.md` — design tokens (màu, chữ, spacing, component) và bảng migration từ resource cũ.
- `docs/MODERNIZATION-REVIEW.md` — đánh giá codebase so với chuẩn Android hiện tại và lộ trình.
- `docs/UX-REDESIGN.md` — phân tích UX và đề xuất kiến trúc thông tin mới.
- `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` — spec sản phẩm v1 Flutter (kiến trúc, hành trình, dữ liệu, booking, thanh toán, kiến trúc app, phân rã).
