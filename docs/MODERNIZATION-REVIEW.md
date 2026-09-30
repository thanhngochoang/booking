# Đánh giá codebase so với chuẩn Android 2026

Codebase được viết cuối 2017 theo mẫu MVP của Paditech. Bản đánh giá này so sánh với kiến trúc Android hiện đại (Kotlin, Jetpack, MVVM/UDF, Compose) và đề xuất lộ trình. Phần nâng cấp thư viện (AndroidX, AGP 8, Firebase BoM) đã làm ở branch `develop`; tài liệu này nói về **kiến trúc và chất lượng code**, là việc còn lại.

## 1. Tóm tắt

| Khía cạnh | 2017 (hiện tại) | Chuẩn 2026 | Mức chênh |
|-----------|-----------------|------------|-----------|
| Ngôn ngữ | Java 7 style (anonymous class, không lambda) | Kotlin | Lớn |
| Kiến trúc UI | MVP tự viết, presenter tạo bằng reflection | MVVM + UDF (ViewModel, StateFlow), hoặc MVI | Lớn |
| UI toolkit | XML + ButterKnife (đã ngừng phát triển) | Jetpack Compose, hoặc ViewBinding nếu giữ XML | Lớn |
| Điều hướng | `replaceFragment()` thủ công trong MainActivity, không có graph | Navigation Component / Compose Navigation | Vừa |
| Bất đồng bộ | Callback lồng nhau, RxAndroid 2 chỉ import chưa dùng, AsyncTask | Coroutines + Flow | Lớn |
| Dữ liệu | Presenter gọi thẳng Firestore; Realm cache; EventBus phát sự kiện toàn cục | Repository + DataSource; Room hoặc Firestore offline cache; Flow thay EventBus | Lớn |
| DI | Không có, singleton tĩnh (`PrefUtil`, `PresenterFactory`) | Hilt | Vừa |
| Ảnh | Glide | Coil (Compose) hoặc giữ Glide | Nhỏ |
| Test | 2 file mẫu | Unit test cho ViewModel/Repository, UI test | Lớn |
| Bảo mật | API key và Facebook app id commit trong repo; token FCM lưu trong Firestore public | Secrets ngoài repo, Firestore rules, App Check | Vừa |

Kết luận: **nâng cấp thư viện giữ được app chạy, nhưng kiến trúc MVP + ButterKnife + Realm + EventBus là ngõ cụt**. ButterKnife đã ngừng hỗ trợ từ 2020, Realm Java ở chế độ bảo trì (MongoDB chuyển sang Realm Kotlin rồi cũng ngừng vào 2025), EventBus toàn cục làm luồng dữ liệu khó theo dõi. Nên rewrite theo module thay vì tiếp tục vá.

## 2. Điểm mạnh nên giữ

- **Tách rõ View / Presenter / Contact**: mỗi màn hình có interface hai chiều, dễ chuyển thành ViewModel + UiState.
- **Model gọn**: `User`, `Booking`, `Album`, `ChatRoom`, `Message` đủ dùng, `BookStatus` enum rõ ràng. Có thể giữ nguyên schema Firestore.
- **Không có backend riêng**: Firebase cho phép rewrite client mà không đụng server.
- **Nghiệp vụ rõ**: tìm → đặt lịch → accept/deny, dự án mở, chat, album. Đủ để định nghĩa use case.

## 3. Vấn đề cụ thể

### 3.1 Kiến trúc

- `PresenterFactory` tạo presenter bằng `Class.newInstance()` và cache theo tên class: không inject được dependency, presenter không sống qua rotation (bị tạo lại trong `onCreateView`), nuốt lỗi khởi tạo trong `catch`.
- `BaseApplication` chứa logic nghiệp vụ: lắng nghe Firestore, ghi Realm, bắn EventBus. Đây là "God object" ẩn, không test được.
- Presenter gọi `FirebaseFirestore.getInstance()` trực tiếp ở 20+ chỗ. Không có repository, không mock được.
- `getView()` có thể null sau khi fragment destroy; nhiều callback Firestore không kiểm tra → crash tiềm ẩn.
- Realm chỉ là cache cho 2 model nhưng kéo theo annotation processor, native lib 10MB+, và `RealmObject` trộn với `@Exclude` của Firestore trong cùng class.

### 3.2 Bất đồng bộ

- `AsyncTask` (deprecated API 30) trong `UpdateProfileActivity` cho Google Calendar.
- `new Handler().postDelayed` để đoán khi upload xong.
- `UploadFileService` là `IntentService` (deprecated API 30); nên là WorkManager.

### 3.3 UI

- ButterKnife `@BindView`/`@OnClick` ở 38 file. Thay bằng ViewBinding là đổi cơ học; Compose là rewrite.
- `MainActivity` 300 dòng chứa switch điều hướng cho cả 2 role.
- Không có state cho loading / empty / error thống nhất; mỗi fragment tự xử lý.
- Hard‑code màu và kích thước rải rác (đã có design tokens ở `design-system/` để thay).

### 3.4 Bảo mật và vận hành

- `google_place_api_key`, Facebook app id, `google-services.json` trong git.
- `FirebaseDatabase.setPersistenceEnabled(true)` + Firestore listener toàn cục chạy suốt vòng đời app → tốn pin và quota.
- Không có ProGuard/R8 rule cho Realm, Gson model, Facebook; `minifyEnabled false` ở release.
- Không crash reporting (Crashlytics), không analytics event.

## 4. Kiến trúc đề xuất

```
app/
 ├─ core/            design tokens (Compose theme), common UI, utils
 ├─ data/
 │   ├─ auth/        AuthRepository (Firebase Auth, Google, Facebook)
 │   ├─ user/        UserRepository (users collection)
 │   ├─ booking/     BookingRepository (booking, photographers_attended)
 │   ├─ album/       AlbumRepository (albums + Storage upload via WorkManager)
 │   └─ chat/        ChatRepository (chat_room + RTDB messages)
 ├─ domain/          use cases: SearchPhotographers, CreateBooking, RespondBooking, AttendProject…
 └─ feature/
     ├─ onboarding/  login, register, terms
     ├─ discover/    home, find photographer, photographer profile
     ├─ booking/     book, my projects, calendar
     ├─ project/     create project, find project
     ├─ chat/
     └─ profile/     profile, update profile, album
```

- **Kotlin + Coroutines/Flow**. Firestore có `snapshots()` Flow qua KTX; bỏ EventBus và Realm, dùng Firestore offline persistence làm cache.
- **MVVM + UDF**: mỗi feature có `ViewModel` phát `StateFlow<UiState>`, nhận `UiEvent`. Presenter Contact hiện tại map gần 1:1 sang UiState/UiEvent.
- **Compose** cho UI mới; Navigation Compose với graph theo role. Nếu cần giữ XML để giảm rủi ro: ViewBinding + Navigation Component, nhưng chi phí lâu dài cao hơn.
- **Hilt** cho DI; `PrefUtil` thành `DataStore`.
- **WorkManager** cho upload album, **FCM** cho thông báo booking (hiện chưa có notification thực).
- **Room không cần** nếu Firestore cache đủ; chỉ thêm khi cần query offline phức tạp.

## 5. Lộ trình

| Giai đoạn | Việc | Kết quả |
|-----------|------|---------|
| 0 (đã làm) | AndroidX, AGP 8, Firebase BoM, thay API bị gỡ | App build được trên toolchain 2026 |
| 1 | Bật Kotlin, thêm Hilt, tạo `data/` repository bọc Firestore, viết unit test cho repository | Presenter gọi repository thay vì Firestore; `BaseApplication` gầy đi |
| 2 | Thay ButterKnife bằng ViewBinding; thay EventBus + Realm bằng Flow từ repository | Bỏ 3 dependency chết |
| 3 | Chuyển từng feature sang ViewModel + Compose theo thứ tự: Login → Discover → Booking → Chat → Profile/Album | Rewrite tăng dần, app chạy ở mọi bước |
| 4 | Navigation Compose, xoá `MainActivity` switch, xoá MVP base | Kiến trúc mới hoàn toàn |
| Song song | Secrets ra khỏi repo, Firestore security rules, Crashlytics, R8 rules, CI build | Vận hành được |

Ước lượng: giai đoạn 1–2 khoảng 2–3 tuần cho một người; giai đoạn 3 phụ thuộc redesign UX (xem `docs/UX-REDESIGN.md`), nên làm cùng lúc để không viết Compose cho màn hình sắp bỏ.

## 6. Việc không nên làm

- Không viết thêm màn hình mới theo MVP/ButterKnife.
- Không nâng Realm lên Realm Kotlin (đã ngừng phát triển); bỏ hẳn.
- Không đổi Java lên 21+ trước khi đổi AGP; D8 chưa hỗ trợ.
- Không redesign UI trong XML rồi lại rewrite sang Compose; chọn một.
