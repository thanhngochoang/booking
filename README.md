# Cộng đồng nhiếp ảnh gia — Android

Ứng dụng Android (Java) kết nối khách hàng với nhiếp ảnh gia: tìm theo vị trí và khoảng giá, đặt lịch (booking), đăng dự án mở, chat 1‑1, quản lý album và lịch làm việc. Backend hoàn toàn trên Firebase (Auth, Firestore, Realtime Database, Storage).

| | |
|--|--|
| applicationId | `com.thanhbk.timnhay` |
| Java package | `com.paditech.mvpbase` |
| minSdk / targetSdk / compileSdk | 23 / 34 / 34 |
| Ngôn ngữ | Java 17 |
| Build | Gradle 8.9, Android Gradle Plugin 8.5.2 |
| Kiến trúc | MVP tự viết (xem `CLAUDE.md`), Realm cache, EventBus |

## Yêu cầu môi trường

Toolchain nằm **trong thư mục project**, không cần cài hệ thống hay quyền admin:

| Thành phần | Vị trí | Cách có |
|-----------|--------|---------|
| Android SDK (platform 34, build‑tools 34.0.0, platform‑tools) | `.android-sdk/` (gitignored) | `scripts/install-sdk.sh` |
| JDK 17 | `.jdk/` (gitignored) hoặc Homebrew `openjdk@17` | Giải nén tar.gz Temurin/Zulu 17 (macOS aarch64) vào `.jdk/`, hoặc `brew install openjdk@17` |
| Truststore TLS | `.certs/truststore.jks` (gitignored) | `scripts/env.sh` tự tạo |

**Vì sao JDK 17 mà không phải mới hơn:** Android Gradle Plugin 8.5 chỉ chạy trên JDK 17–21 và D8/R8 chưa biên dịch được class file của Java 22+. JDK 26/27 có trên máy nhưng AGP không dùng được. Khi AGP hỗ trợ, đổi `JAVA_HOME` trong `scripts/env.sh` và `compileOptions` trong `app/build.gradle`.

**Vì sao cần truststore:** máy nằm sau Cloudflare Zero Trust gateway (chứng chỉ HTTPS bị ký lại). JDK không tin CA đó nên Gradle tải dependency sẽ lỗi `PKIX path building failed`. `scripts/env.sh` ghép cacerts của JDK với chứng chỉ trong macOS keychain thành một truststore và đăng ký cho Gradle (`~/.gradle/gradle.properties`).

## Build

```bash
scripts/install-sdk.sh          # lần đầu: tải SDK vào .android-sdk/
source scripts/env.sh           # JAVA_HOME, ANDROID_HOME, truststore, local.properties

./gradlew assembleEnvTestDebug              # APK debug
./gradlew assembleEnvRealRelease            # APK release (chưa ký)
./gradlew installEnvTestDebug               # cài lên thiết bị
./gradlew testEnvTestDebugUnitTest          # unit test JVM
./gradlew testEnvTestDebugUnitTest --tests com.paditech.mvpbase.ExampleUnitTest
./gradlew connectedEnvTestDebugAndroidTest  # instrumented test (cần thiết bị)
```

Hai flavor `envReal` và `envTest` hiện giống hệt nhau (cùng applicationId, `Config.java` rỗng).

## Cấu hình cần điền trước khi chạy

| Khoá | File | Ghi chú |
|------|------|---------|
| `facebook_client_token` | `app/src/main/res/values/strings.xml` | Bắt buộc từ Facebook SDK 13+. Lấy tại Meta developer console → Settings → Advanced. Đang để trống. |
| `google_place_api_key` | `app/src/main/res/values/strings.xml` | Places SDK (Autocomplete) và Maps. Bật "Places API" cho key này trong Google Cloud. |
| `google-services.json` | `app/` | Cấu hình Firebase. Nên tách theo flavor (`app/src/envReal/`, `app/src/envTest/`). |

Các key này đang được commit trong repo. Nên chuyển sang `local.properties` hoặc `secrets-gradle-plugin` và xoá khỏi lịch sử git.

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

## Tài liệu

- `CLAUDE.md` — kiến trúc, luồng dữ liệu, quy ước.
- `design-system/README.md` — design tokens (màu, chữ, spacing, component) và bảng migration từ resource cũ.
- `docs/MODERNIZATION-REVIEW.md` — đánh giá codebase so với chuẩn Android hiện tại và lộ trình.
- `docs/UX-REDESIGN.md` — phân tích UX và đề xuất kiến trúc thông tin mới.
