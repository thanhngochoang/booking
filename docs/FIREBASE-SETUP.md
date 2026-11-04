# Setup Firebase cho app Flutter (Android)

Tài liệu này hướng dẫn nối app `app_flutter/` với một Firebase project để chạy được đăng nhập bằng email, Google và Facebook, cùng Firestore. Bạn làm các bước 1–7 một lần cho mỗi project. Bước 8 làm lại trên mỗi máy dev. Bước 9 (Storage) và bước 10 (deploy tự động bằng GitHub Actions) làm khi cần.

Từ #299, backend Firebase (Cloud Functions, Firestore/Storage rules, indexes, `rules-test`, seed, `firebase.json`, `.firebaserc`) và `packages/domain` nằm trong repo riêng (private) https://github.com/thanhngochoang/booking-be, ở `firebase/` và `packages/domain/`. Tài liệu này vẫn ở repo app. Các lệnh bên dưới chạy từ thư mục gốc của repo app và cần bản clone booking-be cạnh nó (`../booking-be`): `git clone https://github.com/thanhngochoang/booking-be.git ../booking-be`.

## Thông số của repo

| Mục | Giá trị |
|-----|---------|
| Android package (applicationId) | `com.thanhbk.photobooking` |
| Firebase project dev | `booking-c1922` (alias `dev` trong `firebase/.firebaserc` của booking-be) |
| Firebase project production | Chưa tạo. Khi có, thêm alias `prod` (bước 6) và biến cho environment `production` (bước 10) |
| Facebook App ID | `546233675712070` |
| SHA‑1 debug (máy này, `.home/.android/debug.keystore`) | `D2:BC:10:FD:7C:AF:07:A5:29:9B:03:FF:F8:F2:B6:7E:AF:DB:0D:14` |
| SHA‑256 debug | `59:A1:19:16:D9:3B:DC:50:66:8C:BC:93:DA:CF:80:D2:54:3F:1F:46:CE:05:AC:0E:F3:38:8B:53:8B:CA:87:D7` |
| Facebook key hash debug | `0rwQ/XyvB6UpmwP/+PK2fq/bDRQ=` |

Bản debug của app Flutter ký bằng khoá dùng chung `app_flutter/android/app/debug.keystore` (có trong git), nên cả team chỉ cần thêm một SHA‑1/SHA‑256 debug (xem bằng `scripts/check-device.sh`); bản release dùng khoá riêng, thêm sau. App Java cũ vẫn theo từng máy: mỗi máy và mỗi keystore có SHA‑1 riêng. App Flutter dùng package `com.thanhbk.photobooking`, khác app Java cũ, nên phải thêm nó như một app Android mới trong Firebase (bước 2) và tải `google-services.json` mới (bước 7). File cũ `app/google-services.json` không dùng được cho app Flutter: Gradle sẽ báo `No matching client found for package name 'com.thanhbk.photobooking'`.

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
- **Tạo project mới**: bấm nút tạo project, nhập tên, chấp nhận điều khoản, **Continue**, tắt Google Analytics nếu chưa cần, rồi **Create project**. Ở các bước sau, thay `booking-c1922` bằng id mới. Project production cũng tạo theo cách này: làm lại các bước 1–7 và 9 cho nó.

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
| Facebook | Enable, điền **App ID** `546233675712070` và **App secret** (lấy ở bước 5). Copy **OAuth redirect URI** mà Firebase hiển thị (dạng `https://<project-id>.firebaseapp.com/__/auth/handler`) để dùng ở bước 5. |

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
2. Deploy rules và indexes từ repo. Firebase CLI đã có sẵn trong `rules-test/node_modules`, không cần cài global. Project được chọn qua alias trong `firebase/.firebaserc` của booking-be:

   | Alias | Project |
   |-------|---------|
   | `dev` | `booking-c1922` |
   | `prod` | chưa có |

   `.firebaserc` cố ý không có `default`, nên lệnh deploy nào cũng phải chỉ rõ project. Không dùng `firebase use` để đổi project: lệnh đó lưu project đang chọn trên máy, và rất dễ deploy nhầm sang production.

```bash
source scripts/env.sh
cd ../booking-be/firebase/rules-test
npm install                 # lần đầu
npx firebase login          # mở trình duyệt, chỉ cần một lần
npm test                    # chạy test rules trên emulator trước khi deploy
npm run deploy:rules:dev    # Firestore rules + indexes lên dev
npm run deploy:rules:prod   # lên production, chỉ chạy được sau khi đã thêm alias prod
```

Lệnh deploy đẩy đúng nội dung file trên đĩa, kể cả phần chưa commit. Nên commit và chạy `npm test` trước.

Khi đã có project production, thêm alias `prod` vào `firebase/.firebaserc` của booking-be rồi commit (trong repo booking-be):

```json
{
  "projects": {
    "dev": "booking-c1922",
    "prod": "<id-project-production>"
  }
}
```

Production nên deploy qua GitHub Actions (bước 10) để có bước duyệt. `deploy:rules:prod` từ máy chỉ dùng khi cần gấp.

Trong Claude Code, chạy lệnh `firebase login` bằng tiền tố `!` vì nó cần tương tác. Sau khi deploy, vào **Databases & Storage → Firestore → Rules** để kiểm tra nội dung giống `firebase/firestore.rules` của booking-be.

Vì sao không dùng project cũ `time-96441`: app Java cũ ghi vào `users`, `booking`, `albums`, `chat_room` mà không tuân theo rules mới (ví dụ có `mail_address`, `is_photographer`). Deploy rules mới sẽ chặn app cũ ghi tiếp. Vì vậy app Flutter dùng project riêng (`booking-c1922` cho dev), dữ liệu cũ sẽ migrate sau.

## 7. Tải cấu hình về máy

1. **Project settings → General → Your apps**, chọn app Android → **google-services.json**: tải file, đặt vào `app_flutter/android/app/google-services.json`. File này đã nằm trong gitignore.
2. Tạo `app_flutter/lib/firebase_options.dart` (cũng gitignored). Dùng một trong hai cách:

   **Cách A, FlutterFire CLI** (cần Firebase CLI đã login):
   ```bash
   source scripts/env.sh && cd app_flutter
   dart pub global activate flutterfire_cli
   dart pub global run flutterfire_cli:flutterfire configure --project=<project-id> --platforms=android --android-package-name=com.thanhbk.photobooking --yes
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

## 9. Storage rules (khi app bắt đầu upload ảnh)

Rules nằm ở `firebase/storage.rules` của booking-be. Bản hiện tại:

- Chỉ mở `users/{uid}/**`: người đã đăng nhập được đọc; chỉ chủ (`uid`) được ghi, và chỉ ghi ảnh (`image/*`) dưới 15 MB.
- Mọi đường dẫn khác bị chặn.

Dữ liệu chỉ lưu khoá lưu trữ (`storage_key`), không lưu URL tải của Firebase. Khi chốt cấu trúc key, sửa rules cho khớp.

1. **Gói Blaze**: từ 10/2024, bucket Storage mới bắt buộc gói Blaze. Bucket `*.appspot.com` trên gói Spark mất quyền truy cập từ 02/2026 ([thông báo](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)). Kiểm tra gói ở **Usage and billing**: `https://console.firebase.google.com/project/<project-id>/usage/details` (dev: https://console.firebase.google.com/project/booking-c1922/usage/details). Blaze vẫn có hạn mức miễn phí. Nên đặt **budget alert** trong Google Cloud Billing.
2. Menu trái: **Databases & Storage → Storage** → **Get started**. Chọn location gần Firestore (`asia-southeast1`), chọn **Production mode**.
3. Deploy:

```bash
cd ../booking-be/firebase/rules-test
npm run deploy:storage:dev    # hoặc deploy:storage:prod
```

Kiểm tra ở **Storage → Rules**: nội dung phải giống `storage.rules`. Project cũ `time-96441` của app Java không bị ảnh hưởng.

## 10. Deploy tự động bằng GitHub Actions

Từ #299, workflow deploy và các GitHub environment của nó nằm ở **booking-be**: `.github/workflows/firebase-deploy.yml` của https://github.com/thanhngochoang/booking-be. Repo app không còn workflow deploy; environment `dev`/`production` và secret `FIREBASE_SERVICE_ACCOUNT` cũ của repo app không còn được dùng (xoá được). Workflow có 4 job: `test` chạy test rules trên emulator, `deploy` (rules và indexes) chỉ chạy khi `test` pass; `functions-test` chạy test của `packages/domain` và Cloud Functions (cả test emulator), `deploy-functions` chỉ chạy khi `test` và `functions-test` pass (điều kiện riêng ở mục 11). Hai job deploy độc lập: functions lỗi không chặn deploy rules.

| Khi nào (repo booking-be) | Environment | Deploy |
|---------|-------------|--------|
| Push vào `develop` có thay đổi trong `firebase/**` hoặc `packages/domain/**` (hoặc chính workflow) | `dev` | Firestore rules và indexes |
| Push vào `main` có thay đổi tương tự | `production` | Firestore rules và indexes |
| Chạy tay (**Actions → firebase-deploy → Run workflow**) | chọn `dev` hoặc `production` (ô **target**) | Như trên. Tích **Also deploy Storage rules** (ô **storage**) để deploy thêm Storage. |
| Push hoặc chạy tay như trên | như trên | Cloud Functions, job `deploy-functions`; **chỉ khi `BLAZE_ENABLED` = `true`** |

Project id không ghi trong workflow. Mỗi GitHub environment có biến `FIREBASE_PROJECT_ID` và secret `FIREBASE_SERVICE_ACCOUNT` riêng. Environment chưa có `FIREBASE_PROJECT_ID` thì job `deploy` chỉ in cảnh báo và không deploy gì. Nhờ vậy `production` an toàn khi chưa có project.

**Công tắc Blaze (`BLAZE_ENABLED`).** Mọi thứ cần gói Blaze (trả theo dùng) chỉ deploy khi environment có biến `BLAZE_ENABLED` bằng đúng `true`: Cloud Functions (kèm job lập lịch và secret) và Storage rules. Không đặt biến, hoặc giá trị khác, là **tắt**: chỉ Firestore rules và indexes được deploy (chạy trên gói Spark miễn phí), các bước cần Blaze in cảnh báo và bỏ qua. Script chạy tay `npm run deploy:storage:dev|prod` (trong `rules-test/`) cũng từ chối khi chưa có `BLAZE_ENABLED=true`. Chủ dự án để công tắc **tắt** cho tới khi cần Blaze (2026-10-09); app và dashboard chạy trên emulator (`scripts/backend-local.sh`, chạy emulator của bản clone booking-be).

IAM, service account và key đều miễn phí. GitHub Actions miễn phí cho repo public; booking-be là repo private nên dùng quota phút miễn phí mỗi tháng.

Làm 10.1–10.3 cho **dev** sau khi PR #299 của repo app đã merge (để không có hai repo cùng deploy). Làm 10.4 một lần cho repo app. Làm lại 10.1–10.3 cho **production** khi đã có project, với project id và key của production. Mỗi project dùng một service account riêng: key của dev không deploy được lên production, và ngược lại.

### 10.1 Tạo service account (trong từng project)

1. Mở `https://console.cloud.google.com/iam-admin/serviceaccounts?project=<project-id>` (dev: https://console.cloud.google.com/iam-admin/serviceaccounts?project=booking-c1922) → **Create service account**.
   - Name: `github-firebase-deploy` → **Create and continue**.
2. **Grant this service account access to project**, thêm các role:

   | Role | Để làm gì |
   |------|-----------|
   | Firebase Rules Admin | Deploy Firestore rules và Storage rules |
   | Cloud Datastore Index Admin | Deploy Firestore indexes |
   | Service Usage Consumer | Firebase CLI kiểm tra API đã bật chưa |

   Bấm **Continue** → **Done**.
3. Bấm vào service account vừa tạo → tab **Keys** → **Add key → Create new key** → **JSON** → **Create**. Trình duyệt tải về một file `.json`.

Project dev đã có service account `github-firebase-deploy` từ trước #299 (khi repo app còn deploy). Dùng lại nó, không cần tạo mới: chỉ tạo key mới (bước 3) cho booking-be, rồi xoá key cũ khi đã xoá secret `FIREBASE_SERVICE_ACCOUNT` ở repo app.

Nếu deploy báo thiếu quyền (`The caller does not have permission`, `...permission denied`), log sẽ ghi tên permission còn thiếu. Thêm role chứa permission đó ở trang **IAM** của project (`https://console.cloud.google.com/iam-admin/iam?project=<project-id>`). Cách nhanh nhưng rộng quyền hơn: gán role **Firebase Admin**.

Nếu không tạo được key vì policy của organization (`iam.disableServiceAccountKeyCreation`), dùng Workload Identity Federation thay cho key và sửa bước `google-github-actions/auth` trong workflow.

### 10.2 Tạo environment và lưu cấu hình

Mở https://github.com/thanhngochoang/booking-be/settings/environments → **New environment**. Environment có secret trong repo private cần gói GitHub hỗ trợ (GitHub Free không có); chưa có thì kiểm tra gói trước.

| | `dev` | `production` |
|--|-------|--------------|
| Tên environment | `dev` | `production` |
| **Environment variables** → `FIREBASE_PROJECT_ID` | `booking-c1922` | id project production (để trống tới khi có) |
| **Environment variables** → `BLAZE_ENABLED` | không đặt (đang ở Spark) | `true` khi project đã lên Blaze |
| **Environment secrets** → `FIREBASE_SERVICE_ACCOUNT` | toàn bộ nội dung file JSON của dev | toàn bộ nội dung file JSON của production |
| **Required reviewers** | không cần | bật, thêm chính bạn |
| **Deployment branches and tags** | `develop` | chỉ `main` |

Lưu ý:

- Secret phải đặt trong **environment**, không đặt ở **Repository secrets**. Đặt ở repository thì cả hai environment dùng chung một key.
- Sau khi lưu secret, xoá file JSON trên máy. Không commit file này. Key bị lộ thì vào tab **Keys** của service account, xoá key cũ và tạo key mới.
- Khi bật Required reviewers cho `production`, mỗi lần push vào `main` của booking-be có đụng `firebase/**` hoặc `packages/domain/**`, GitHub sẽ chờ bạn bấm **Approve**, kể cả lúc chưa có project id.

### 10.3 Chạy thử

1. Mở https://github.com/thanhngochoang/booking-be/actions/workflows/firebase-deploy.yml → **Run workflow** → branch `develop`, target `dev` → **Run workflow**. Nút này chỉ hiện khi workflow đã có trên branch mặc định của repo.
2. Kiểm tra: cả hai job xanh, và trang **Firestore → Rules** của project dev có thời điểm publish mới.
3. Với production: sau khi điền 10.2, chạy lại với branch `main`, target `production`, rồi duyệt.

| Lỗi trong log | Cách sửa |
|---------------|----------|
| Cảnh báo `FIREBASE_PROJECT_ID is not set for this environment` | Chưa thêm biến cho environment đó (10.2). |
| Cảnh báo `BLAZE_ENABLED is not true for this environment` | Đúng ý khi project còn ở Spark. Muốn deploy Functions hoặc Storage: lên Blaze (mục 11 bước 1) rồi đặt `BLAZE_ENABLED` = `true` (10.2). |
| `the GitHub Action workflow must specify exactly one of "workload_identity_provider" or "credentials_json"` | Secret `FIREBASE_SERVICE_ACCOUNT` chưa có trong environment, hoặc sai tên (10.2). |
| `Permission ... denied` hoặc `does not have permission` | Thiếu role (10.1), hoặc key thuộc project khác với `FIREBASE_PROJECT_ID`. |
| `Failed to get Firebase project ...` | Project id sai, hoặc service account chưa được gán role nào trong project đó. |
| Storage: `Firebase Storage has not been set up` | Chưa làm bước 9 (bucket chưa tạo hoặc chưa lên Blaze). |

### 10.4 Deploy key để CI của repo app đọc booking-be

Test của app đọc một số file của booking-be (rules, `firebase.json`, fixture của `packages/domain`, ...) ở commit ghi trong `backend.lock`; `scripts/sync-backend.sh` lấy chúng về `.backend/` (gitignored). booking-be là repo private, nên job `test` của `.github/workflows/flutter.yml` đọc nó bằng một deploy key chỉ đọc. Làm một lần, ở máy bạn:

```bash
ssh-keygen -t ed25519 -N '' -C booking-ci-read -f booking_be_ci   # tạo booking_be_ci (private) và booking_be_ci.pub
```

1. https://github.com/thanhngochoang/booking-be/settings/keys → **Add deploy key**: dán nội dung `booking_be_ci.pub`, tên `booking-ci-read`, **không** tích **Allow write access**.
2. https://github.com/thanhngochoang/booking/settings/secrets/actions → **New repository secret** `BOOKING_BE_DEPLOY_KEY`: toàn bộ nội dung file `booking_be_ci` (key private).
3. Thêm đúng secret đó (cùng tên, cùng nội dung) ở https://github.com/thanhngochoang/booking/settings/secrets/dependabot. PR pub của Dependabot chạy `flutter.yml` mà không thấy secret của Actions; thiếu bước này thì các PR đó lỗi ở bước sync.
4. Xoá hai file key trên máy. Key bị lộ thì xoá deploy key ở booking-be và làm lại từ đầu.

Thiếu secret (hoặc PR từ fork, không có secret) thì job `test` lỗi ở bước "booking-be files the tests read (backend.lock)".

## 11. Cloud Functions (deploy qua CI)

Job `deploy-functions` (workflow của booking-be, mục 10) deploy codebase `firebase/functions` của booking-be (region `asia-southeast1`: `getContactLink`, `onPhotographerWrite`) bằng `firebase deploy --only functions`. Không deploy từ máy. Làm các bước dưới đây một lần cho mỗi project: **dev** ngay, **production** khi đã có project.

1. **Gói Blaze.** Firebase Console → ⚙ → **Usage and billing** → **Details & settings** → **Modify plan** → **Blaze**. Cloud Functions không chạy trên gói Spark. Nên đặt budget alert (ví dụ 5 USD) trong Google Cloud Billing. Sau đó đặt biến `BLAZE_ENABLED` = `true` cho environment (10.2); chưa đặt thì job `deploy-functions` chỉ in cảnh báo.
2. **Bật API** tại `https://console.cloud.google.com/apis/library?project=<project-id>`: Cloud Functions API, Cloud Build API, Artifact Registry API, Eventarc API, Cloud Run Admin API. Service account của CI không có quyền bật API, nên bật trước bằng tay.
3. **Thêm role cho service account CI** (`github-firebase-deploy`, mục 10.1) ở trang IAM `https://console.cloud.google.com/iam-admin/iam?project=<project-id>`:

   | Role | Để làm gì |
   |------|-----------|
   | Cloud Functions Admin (`roles/cloudfunctions.admin`) | Tạo, cập nhật, xoá function và đặt quyền gọi công khai cho callable `getContactLink` (Developer không đặt được IAM policy) |
   | Service Account User (`roles/iam.serviceAccountUser`) | Cho function chạy bằng service account mặc định |
   | Artifact Registry Administrator (`roles/artifactregistry.admin`) | Lưu image build và đặt chính sách dọn image ở lần deploy đầu với `--force` (Writer không đặt được) |
   | Cloud Run Admin (`roles/run.admin`) | Function thế hệ 2 chạy trên Cloud Run |
   | Eventarc Admin (`roles/eventarc.admin`) | Tạo trigger Firestore của `onPhotographerWrite` |

   **Project mới** (tạo từ 2024): service account mặc định không còn role Editor, nên bước build của Cloud Build có thể lỗi quyền. Thêm role **Cloud Build Service Account** (`roles/cloudbuild.builds.builder`) cho service account Compute mặc định `<project-number>-compute@developer.gserviceaccount.com` (và cho `<project-number>@cloudbuild.gserviceaccount.com` nếu project có). Số project ở Console → ⚙ **Project settings**.

   > **Cảnh báo `--force`:** workflow deploy với `--force`, nên **mọi function đang chạy trong codebase mặc định mà `src/index.ts` không export sẽ bị xoá** (kể cả function tạo tay hay từ repo khác). Trước lần deploy đầu tiên, mở Console → **Functions** của project và kiểm tra danh sách; function nào cần giữ thì chuyển sang codebase khác hoặc export từ `src/index.ts` trước.

4. **Chạy thử**: **Run workflow** như 10.3. Kiểm tra: job `deploy-functions` xanh; Console → **Functions** có `getContactLink` và `onPhotographerWrite` ở `asia-southeast1`. Trong app, sửa kỹ năng ở S38 rồi lưu, mở lại S38: "Độ khớp hồ sơ" hiện số do server ghi (trước lần lưu đầu tiên là "Chưa có điểm").

Workflow chạy với `--force` để Firebase CLI tự đặt chính sách dọn image cũ trong Artifact Registry ở lần deploy đầu và xoá function không còn trong `src/index.ts`. Thiếu điều kiện nào thì chỉ job `deploy-functions` đỏ, kèm thông báo của Firebase CLI; job `deploy` (rules) không bị ảnh hưởng.

| Lỗi trong log | Cách sửa |
|---------------|----------|
| `must be on the Blaze (pay-as-you-go) plan` | Bước 1. |
| `... API has not been used in project ... or it is disabled` | Bật API được nêu (bước 2), chờ vài phút rồi chạy lại. |
| `Permission 'cloudfunctions.functions.create' denied`, `iam.serviceAccounts.actAs`, `artifactregistry...`, `run.services...`, `eventarc.triggers...` | Thiếu role tương ứng (bước 3). |
| `Since this is your first time using 2nd gen functions, we need a little bit longer to finish setting everything up` | Lần đầu dùng Eventarc: chờ vài phút rồi chạy lại. |

## 12. Khóa mã hóa tài khoản nhận tiền (`PAYOUT_ACCOUNT_KEY`)

Callable `savePayoutAccount` mã hóa số tài khoản ngân hàng của nhiếp ảnh gia bằng AES‑256‑GCM trước khi lưu (`payoutAccounts/{uid}/accounts/{id}`, chỉ server đọc được). Khóa là 32 byte ngẫu nhiên, mã hóa base64, lưu trong Secret Manager với tên `PAYOUT_ACCOUNT_KEY`. Khóa này được gắn vào các function xử lý và hoàn tiền tài khoản: `savePayoutAccount`, `requestPayoutOtp`, `createPayouts`, `createPayment`, `checkPayment`, `confirmFakePayment`, `getPaymentInstructions`, `paymentWebhook`, `paymentClock`, `transitionBooking`, `bookingClock`, `registerEvent`, `cancelRegistration`, `checkTicketPayment`, `cancelEvent`, `eventClock`, `openDispute`, `resolveDispute` (khiếu nại S18, #142: kết quả có hoàn tiền gửi lệnh hoàn qua cổng), `lookupRefundAccount`, `chooseRefundAccount` (tài khoản nhận hoàn S22.04, #141: mã hóa tài khoản khách tra được, gửi lệnh hoàn). **Phải tạo secret này trong từng project trước khi deploy functions**: nếu chưa có, `firebase deploy --only functions` (và job `deploy-functions` của CI) lỗi.

Tạo secret (một lần cho mỗi project, chạy ở máy bạn, không commit khóa):

```bash
openssl rand -base64 32 | firebase functions:secrets:set PAYOUT_ACCOUNT_KEY --project <project-id> --data-file -
```

Cấp quyền cho service account của CI (bước 10.1) trên **chính secret này**, để lần deploy sau gắn được secret vào function:

```bash
gcloud secrets add-iam-policy-binding PAYOUT_ACCOUNT_KEY \
  --project <project-id> \
  --member "serviceAccount:<ci-service-account>@<project-id>.iam.gserviceaccount.com" \
  --role roles/secretmanager.admin
```

Lưu ý:

- Không bao giờ đổi hoặc xóa khóa khi đã có tài khoản được lưu: dữ liệu cũ sẽ không giải mã được. Chuỗi mã hóa có tiền tố phiên bản (`v1:`) để sau này xoay khóa.
- Emulator dùng khóa thử trong `firebase/functions/.secret.local` của booking-be (giá trị test, không phải bí mật). Công cụ nhân viên `npm run payouts` đọc khóa từ biến môi trường `PAYOUT_ACCOUNT_KEY`, hoặc từ file này khi chạy với emulator.
- Chuyển tiền thật chưa tồn tại: `npm run payouts -- execute` chỉ chạy với cổng giả: với emulator, hoặc khi đặt `PAYOUTS_MODE=fake` và `GCLOUD_PROJECT` đúng bằng project dev trong `.firebaserc` (alias `dev`, công cụ tự đọc, không ghi cứng). Với mọi project khác (kể cả production) lệnh `execute` bị từ chối.

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
cd ../booking-be/firebase/rules-test && npm install && npm test
```

CI của booking-be (`.github/workflows/ci.yml`) chạy bước này cho mọi PR (job `firestore-rules`), cùng job `domain` (test của `packages/domain`) và `functions` (lint, typecheck, unit của Cloud Functions). Test Cloud Functions trên emulator **không** chạy lúc PR: job `functions-test` của `firebase-deploy.yml` (booking-be) chạy chúng sau khi code được merge vào `develop` hoặc `main`. Test emulator chỉ chạy trên CI. CI của repo app không còn chạy test backend.
