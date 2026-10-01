# Setup Firebase cho app Flutter (Android)

Tài liệu này hướng dẫn nối app `app_flutter/` với một Firebase project để chạy được đăng nhập bằng email, Google và Facebook, cùng Firestore. Bạn làm các bước 1–7 một lần cho mỗi project. Bước 8 làm lại trên mỗi máy dev.

## Thông số của repo

| Mục | Giá trị |
|-----|---------|
| Android package (applicationId) | `com.thanhbk.photobooking` |
| Firebase project đang dùng | `booking-c1922` (theo `app_flutter/android/app/google-services.json`) |
| Facebook App ID | `546233675712070` |
| SHA‑1 debug (máy này, `.home/.android/debug.keystore`) | `D2:BC:10:FD:7C:AF:07:A5:29:9B:03:FF:F8:F2:B6:7E:AF:DB:0D:14` |
| SHA‑256 debug | `59:A1:19:16:D9:3B:DC:50:66:8C:BC:93:DA:CF:80:D2:54:3F:1F:46:CE:05:AC:0E:F3:38:8B:53:8B:CA:87:D7` |
| Facebook key hash debug | `0rwQ/XyvB6UpmwP/+PK2fq/bDRQ=` |

Mỗi máy và mỗi keystore có SHA‑1 riêng. App Flutter dùng package `com.thanhbk.photobooking`, khác app Java cũ, nên phải thêm nó như một app Android mới trong Firebase (bước 2) và tải `google-services.json` mới (bước 7). File cũ `app/google-services.json` không dùng được cho app Flutter: Gradle sẽ báo `No matching client found for package name 'com.thanhbk.photobooking'`.

Lấy lại các giá trị này trên máy khác:

```bash
source scripts/env.sh
keytool -list -v -keystore .home/.android/debug.keystore -alias androiddebugkey -storepass android | grep -E 'SHA1|SHA256'
keytool -exportcert -alias androiddebugkey -keystore .home/.android/debug.keystore -storepass android | openssl sha1 -binary | openssl base64   # Facebook key hash
```

File keystore chỉ có sau lần build Android đầu tiên (`flutter build apk --debug`).

## 1. Chọn project

Mở https://console.firebase.google.com.

- **Đã có project `booking-c1922`**: chọn nó. Đây là project mà `google-services.json` của app Flutter đang trỏ tới.
- **Tạo project mới**: bấm nút tạo project, nhập tên, chấp nhận điều khoản, **Continue**, tắt Google Analytics nếu chưa cần, rồi **Create project**. Ở các bước sau, thay `booking-c1922` bằng id mới.

Project cũ `time-96441` của app Java không dùng cho app Flutter (xem lưu ý ở bước 6).

Khi dùng project mới, gói Spark (miễn phí) đủ cho sub‑project 1. Riêng Cloud Functions (đặt cọc ở sub‑project 4) cần gói Blaze.

## 2. Thêm (hoặc kiểm tra) app Android

1. Bấm bánh răng cạnh **Project Overview** → **Project settings** → tab **General** → thẻ **Your apps**.
2. Thêm app Android `com.thanhbk.photobooking` (app Java cũ `com.thanhbk.timnhay` là app khác, giữ nguyên): bấm **Add app** → biểu tượng Android:
   - Package name: `com.thanhbk.photobooking`
   - App nickname: `Nhiếp ảnh gia (Flutter)`
   - Debug signing certificate SHA‑1: dán SHA‑1 ở bảng trên
   - Bấm **Register app**.
3. Bỏ qua các bước "Add Firebase SDK". Flutter và Gradle plugin đã được cấu hình sẵn.

## 3. Thêm SHA‑1 và SHA‑256

Vẫn trong **Project settings → General → Your apps**, chọn app Android, mục **SHA certificate fingerprints**: bấm **Add fingerprint**, thêm cả SHA‑1 lẫn SHA‑256 của từng máy dev. Sau này khi phát hành, thêm cả SHA của keystore release và của Play App Signing.

Mỗi lần thêm fingerprint, phải tải lại `google-services.json` (bước 7) vì OAuth client mới chỉ có trong file mới.

## 4. Bật đăng nhập

Menu trái: **Security → Authentication**. Nếu là lần đầu, bấm **Get started**. Sau đó mở tab **Sign‑in method**.

Bỏ qua bước này thì mọi kiểu đăng nhập đều hỏng. API của Firebase Auth trả về `CONFIGURATION_NOT_FOUND`, và app chỉ báo lỗi chung.

| Provider | Cách bật |
|----------|----------|
| Email/Password | Enable. Không bật "Email link". |
| Google | Enable, chọn support email, Save. Firebase tự tạo "Web client". App lấy client này qua `default_web_client_id` trong `google-services.json` để nhận `idToken`. |
| Facebook | Enable, điền **App ID** `546233675712070` và **App secret** (lấy ở bước 5). Copy **OAuth redirect URI** mà Firebase hiển thị (dạng `https://booking-c1922.firebaseapp.com/__/auth/handler`) để dùng ở bước 5. |

Nên bật thêm ở **Security → Authentication → Settings → User actions**: "Email enumeration protection" (mặc định bật ở project mới). Khi bật, sai email và sai mật khẩu đều báo "Email hoặc mật khẩu không đúng.". App đã xử lý trường hợp này.

## 5. Cấu hình Facebook (Meta for Developers)

Mở https://developers.facebook.com/apps, chọn app `546233675712070`. Nếu không có quyền vào app này, tạo app mới loại **Consumer**, rồi thay App ID trong `app_flutter/android/app/src/main/res/values/strings.xml` (`facebook_app_id` và `fb_login_protocol_scheme` = `fb<APP_ID>`).

1. **Settings → Basic**: copy **App secret** sang Firebase (bước 4). Ở **Add platform → Android**:
   - Package name: `com.thanhbk.photobooking`
   - Default activity class name: `com.thanhbk.photobooking.MainActivity`
   - Key hashes: dán key hash ở bảng trên (thêm một dòng cho mỗi máy, và cho keystore release)
2. **Settings → Advanced → Security → Client token**: điền vào `FACEBOOK_CLIENT_TOKEN` trong file `.env` ở thư mục gốc (tạo từ `.env.example`). Facebook SDK 13+ bắt buộc có giá trị này. Gradle tự đưa nó vào app.
3. **Use cases → Authentication and account creation → Facebook Login → Settings**: dán redirect URI của Firebase vào **Valid OAuth Redirect URIs**.
4. Khi app còn ở chế độ Development, chỉ tài khoản có vai trò trong app (Admin, Developer, Tester) mới đăng nhập được. Thêm tài khoản test ở **App roles**.

Không ghi token vào `strings.xml` hay bất kỳ file nào được commit. `.env` đã nằm trong gitignore.

## 6. Tạo Firestore và deploy rules

1. Menu trái: **Databases & Storage → Firestore** → **Create database** (hoặc **Add database**).
   - Edition: **Standard edition** → **Next**.
   - Database ID: giữ `(default)`. App gọi `FirebaseFirestore.instance`, tức chỉ dùng database mặc định. Đặt id khác thì app không thấy database.
   - Location: `asia-southeast1 (Singapore)`, gần Việt Nam nhất → **Next**. Location không đổi được sau khi tạo.
   - Security rules: **Production mode** (rules của repo sẽ ghi đè ngay ở bước kế) → **Create**.
2. Deploy rules và indexes từ repo. Firebase CLI đã có sẵn trong `app_flutter/firebase/rules-test/node_modules`, không cần cài global:

```bash
source scripts/env.sh
cd app_flutter/firebase
npx --prefix rules-test firebase login          # mở trình duyệt, chỉ cần một lần
npx --prefix rules-test firebase deploy --only firestore:rules,firestore:indexes --project booking-c1922
```

Trong Claude Code, chạy lệnh `firebase login` bằng tiền tố `!` vì nó cần tương tác. Sau khi deploy, vào **Databases & Storage → Firestore → Rules** để kiểm tra nội dung giống `app_flutter/firebase/firestore.rules`.

Vì sao không dùng project cũ `time-96441`: app Java cũ ghi vào `users`, `booking`, `albums`, `chat_room` mà không tuân theo rules mới (ví dụ có `mail_address`, `is_photographer`). Deploy rules mới sẽ chặn app cũ ghi tiếp. Vì vậy app Flutter dùng project riêng `booking-c1922`, dữ liệu cũ sẽ migrate sau.

## 7. Tải cấu hình về máy

1. **Project settings → General → Your apps**, chọn app Android → **google-services.json**: tải file, đặt vào `app_flutter/android/app/google-services.json`. File này đã nằm trong gitignore.
2. Tạo `app_flutter/lib/firebase_options.dart` (cũng gitignored). Dùng một trong hai cách:

   **Cách A, FlutterFire CLI** (cần Firebase CLI đã login):
   ```bash
   source scripts/env.sh && cd app_flutter
   dart pub global activate flutterfire_cli
   dart pub global run flutterfire_cli:flutterfire configure --project=booking-c1922 --platforms=android --android-package-name=com.thanhbk.photobooking --yes
   ```

   **Cách B, sinh từ `google-services.json`** (không cần login):
   ```bash
   cd app_flutter && python3 - <<'EOF'
   import json
   d = json.load(open('android/app/google-services.json')); p = d['project_info']
   c = next(x for x in d['client'] if x['client_info']['android_client_info']['package_name'] == 'com.thanhbk.photobooking')
   open('lib/firebase_options.dart', 'w').write(f"""import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
   import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

   class DefaultFirebaseOptions {{
     static FirebaseOptions get currentPlatform => switch (defaultTargetPlatform) {{
           TargetPlatform.android => android,
           _ => throw UnsupportedError('Platform not configured'),
         }};

     static const FirebaseOptions android = FirebaseOptions(
       apiKey: '{c['api_key'][0]['current_key']}',
       appId: '{c['client_info']['mobilesdk_app_id']}',
       messagingSenderId: '{p['project_number']}',
       projectId: '{p['project_id']}',
       storageBucket: '{p.get('storage_bucket', '')}',
     );
   }}
   """)
   print('wrote lib/firebase_options.dart')
   EOF
   ```

## 8. Chạy và kiểm tra

```bash
source scripts/env.sh && cd app_flutter
flutter pub get && flutter gen-l10n
flutter run            # cần điện thoại cắm USB (bật USB debugging) hoặc Android emulator
```

Kiểm tra lần lượt:

| Bước | Kỳ vọng |
|------|---------|
| Đăng ký bằng email | Vào màn "Bạn muốn làm gì?". Firestore có `users/{uid}` với `displayName` đúng tên vừa nhập, không có `email`. |
| Chọn "Nhận chụp" | Tab giữa thành "Đăng bài", tab 4 thành "Công việc". Firestore có thêm `photographers/{uid}` với `verified: false`. |
| Đăng xuất → đăng nhập Google | Không có lỗi. Nếu báo lỗi chung, xem phần sự cố bên dưới. |
| Huỷ giữa chừng Google hoặc Facebook | Không hiện thông báo lỗi, nút bấm được lại. |
| Đăng nhập Facebook | Thành công nếu đã điền client token và tài khoản có vai trò trong app Meta. |
| Tắt app rồi mở lại | Hiện màn splash ngắn, rồi vào thẳng tab, không thấy form đăng nhập. |

## Sự cố thường gặp

| Triệu chứng | Nguyên nhân và cách sửa |
|-------------|-------------------------|
| Google Sign‑In báo lỗi ngay, logcat có `ApiException: 10` | SHA‑1 của máy chưa được đăng ký, hoặc `google-services.json` cũ. Làm lại bước 3 và 7. |
| Google trả về nhưng Firebase báo `invalid-credential` | Thiếu Web client (`client_type: 3`) trong `google-services.json`. Bật lại Google provider ở bước 4 rồi tải lại file. |
| Facebook báo lỗi chung | `FACEBOOK_CLIENT_TOKEN` trong `.env` còn trống, key hash chưa thêm, hoặc tài khoản không có vai trò trong app ở chế độ Development (bước 5). |
| Facebook: "Invalid key hash" | Dán đúng key hash mà thông báo lỗi hiển thị vào Meta → Settings → Basic → Android. |
| Đăng ký hoặc đăng nhập nào cũng báo lỗi chung | Chưa bấm **Get started** ở Security → Authentication, hoặc provider chưa bật (bước 4). |
| Kẹt ở màn "Không tải được tài khoản" | Firestore chưa được tạo, database không phải `(default)`, hoặc rules chưa deploy (bước 6). Bấm "Thử lại" sau khi sửa. |
| `PERMISSION_DENIED` khi chọn vai trò | Rules trên server khác bản trong repo. Deploy lại ở bước 6. |
| Build lỗi `File google-services.json is missing` | Chưa làm bước 7. |

## Test rules không cần project thật

Emulator chạy hoàn toàn local, không đụng project thật:

```bash
source scripts/env.sh
cd app_flutter/firebase/rules-test && npm install && npm test
```
