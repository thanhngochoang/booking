# Function `onPhotographerWrite`: độ khớp hồ sơ và minh chứng tính ở server

Ngày: 2026-10-02 · Branch: `flutter-rewrite` · Trạng thái: đã duyệt hướng (người dùng: "làm hết")
Mở rộng: `2026-10-01-remaining-screens.md` §3e.2, §3e.3; plan thực hiện: các task mới cuối `plans/2026-10-01-backend-phase1-firebase-local.md`.

## 1. Mục tiêu và quyết định của người dùng

- **Điểm "Độ khớp hồ sơ" chỉ tính ở server.** App không tính điểm, không tính gợi ý bước tiếp theo. S08.02 hiện con số server đã lưu; khi đang sửa thì ghi "Lưu để cập nhật độ khớp". (Chọn phương án 1, 2026-10-02.)
- **Minh chứng phải là bài của chính nhiếp ảnh gia.** Function tự sửa: gỡ id không hợp lệ (bài không tồn tại hoặc `authorId` khác), thể loại "Chuyên sâu" không còn minh chứng thì hạ xuống "Thành thạo". Lần mở S08.02 kế tiếp báo "Một số minh chứng không hợp lệ đã được gỡ". (Phương án được khuyên; người dùng không phản đối.)
- **Function nằm trong project Functions của backend-phase1** (`app_flutter/firebase/functions`, logic thuần trong `packages/domain`), plan đó chạy ngay sau 2c.
- **Deploy qua CI**, không deploy từ máy. Test emulator chỉ chạy trên CI (quy tắc 2026-10-02).

Ngoài phạm vi: báo dịch vụ gợi ý cập nhật chỉ mục (3e.4) — để plan recommender; xác minh số điện thoại; App Check.

## 2. Function

- **Kích hoạt**: Firestore v2 `onDocumentWritten('photographers/{uid}')`, region `asia-southeast1`, `memory 256MiB`, `timeoutSeconds 30`, `maxInstances 10`, `minInstances 0`, `retry: true`.
- **Bỏ qua** khi: tài liệu bị xoá; không có `skills`; `skills` trước và sau giống nhau sau khi bỏ các trường server (`completeness`, `completenessNext`, `updatedAt`, `evidenceRemovedAt`). Đây là chặn vòng lặp: lần ghi của chính Function không kích hoạt tính lại. Chỉ bỏ qua khi điểm đang lưu (`completeness`, `completenessNext`, `completenessNextAfter`) đúng bằng điểm tính (thuần, không đọc) từ `skills` đang lưu; mọi lần ghi của Function giữ điều này đúng. Hồ sơ chưa có điểm hoặc điểm lệch (lần chạy trước bị `stale`, hay sự kiện bị bỏ vì quá cũ) được tính ở lần ghi kế tiếp của tài liệu, dù lần ghi đó đổi trường nào (ví dụ `completeContactSetup`).
- **Đọc lược đồ** bằng hàm thuần `parseSkills` trong `packages/domain` (cùng quy tắc với `skillsFromMap` Dart). Sai lược đồ → log `warn`, không ghi gì (rules đã chặn từ trước).
- **Kiểm minh chứng**: gom mọi `evidencePostIds` (tối đa 18), đọc một lần `db.getAll(posts/…)`; giữ id khi bài tồn tại và `authorId == uid`. Hàm thuần `cleanEvidence(skills, ownedIds)` trả về kỹ năng đã sửa và cờ `removed`. Mức 3 không còn id → mức 2.
- **Tính điểm**: hàm thuần `skillsCompleteness(skills)` trong `packages/domain`, đúng trọng số 3e.2 (25 thể loại, 20 mức độ, 20 minh chứng cho mọi mức 3, 10 phong cách, 10 ngôn ngữ, 10 khách phù hợp, 5 kỹ năng thêm) và trả `{ percent, next }`, `next` là mã bước còn thiếu đầu tiên: `specialties | levels | evidence | styles | languages | audiences | extras` hoặc `null` khi đủ 100.
- **Ghi**: một lần `update` qua Admin SDK: `skills.completeness`, `skills.completenessNext` (mã hoặc `null`), `skills.updatedAt` (server timestamp); nếu `removed` thì thêm `skills.specialties` đã sửa và `skills.evidenceRemovedAt` (server timestamp). Dùng `precondition: { lastUpdateTime }` của snapshot vừa đọc; nếu tài liệu đã đổi (người dùng lưu tiếp) thì đọc lại tài liệu một lần và tính lại trên bản đang lưu (precondition theo lần đọc đó); nếu vẫn `stale` thì dừng: bản mới hơn chưa có điểm nên lần kích hoạt của nó sẽ tính.
- **Lỗi**: lỗi đọc/ghi Firestore → ném lại để Functions thử lại (idempotent nhờ precondition và bỏ qua khi không đổi). Không thử lại mãi: sự kiện cũ hơn 1 giờ (`event.time`) bị bỏ với log `error` (chỉ `uid`); lỗi Firestore mã 3 (INVALID_ARGUMENT) và 7 (PERMISSION_DENIED) là lỗi vĩnh viễn: log `error` (`uid`, mã) và kết thúc không ném. Hồ sơ của sự kiện bị bỏ vẫn được tính ở lần ghi kế tiếp (xem **Bỏ qua**).
- **Rules**: không đổi; client vẫn không ghi được các trường server. Thêm `completenessNext` và `evidenceRemovedAt` vào danh sách trường server bị ghim trong `firestore.rules` (cùng chỗ `completeness`/`updatedAt`) để client không tự ghi.

## 3. App (Flutter)

- **Xoá tính điểm trên máy**: bỏ `lib/data/skills/skills_completeness.dart` và test của nó; các ca test chuyển sang bảng JSON chung `packages/domain/test/fixtures/skills_completeness.json` (TS chạy bảng này).
- **Đọc trường server**: `SkillsRepository.load` trả thêm `SkillsServerInfo { int? completeness; CompletenessStepCode? next; DateTime? evidenceRemovedAt }` (domain, không kiểu Firebase; adapter chuyển `Timestamp` → UTC `DateTime`).
- **S08.02**: `CompletenessMeter(percent: int?)`. `null` → "Chưa có điểm" + gợi ý "Lưu để tính độ khớp". Có số và bản nháp khác bản đã lưu → giữ số đã lưu, gợi ý "Lưu để cập nhật độ khớp". Có số và không đổi → gợi ý theo mã `next` (chuỗi trong `app_vi.arb`, giữ nội dung gợi ý hiện có).
- **Báo gỡ minh chứng**: nếu `evidenceRemovedAt` mới hơn mốc đã thấy (lưu `SharedPreferences`, khoá `skillsEvidenceSeen.<uid>`) → SnackBar "Một số minh chứng không hợp lệ đã được gỡ" một lần, rồi ghi mốc.
- Không thêm listener: số mới hiện ở lần mở S08.02 kế tiếp (sau khi lưu, S08.02 rời màn ở cả hai chế độ).

## 4. CI và triển khai

- **`flutter.yml`**: thêm job `functions` (Node 22): `npm ci` cho `packages/domain` và `app_flutter/firebase/functions`; `lint`, `typecheck`, unit test, `test:integration` trên emulator (auth, firestore, functions).
- **`firebase-deploy.yml`**: thêm `packages/**` và `app_flutter/firebase/functions/**` vào `paths`; job `deploy-functions` (cần `test` và test functions xanh) chạy `firebase deploy --only functions --project "$PROJECT_ID"` cho môi trường `dev` (push `flutter-rewrite`/`develop`) và `production` (push `main`); bỏ qua khi `FIREBASE_PROJECT_ID` chưa đặt.
- **Điều kiện ngoài repo** (ghi vào `docs/FIREBASE-SETUP.md`): project ở gói Blaze; bật Cloud Functions, Cloud Build, Artifact Registry, Eventarc, Cloud Run API; service account của CI có thêm `roles/cloudfunctions.developer`, `roles/iam.serviceAccountUser`, `roles/artifactregistry.writer`, `roles/run.admin`, `roles/eventarc.admin`. Thiếu điều kiện → job deploy lỗi rõ ràng, không ảnh hưởng job rules.

## 5. Test

- Unit (TS, `node --test`): `parseSkills`, `cleanEvidence` (bài của người khác, bài đã xoá, mức 3 hạ 2, không gỡ gì), `skillsCompleteness` theo bảng JSON, chặn vòng lặp (chỉ đổi trường server → bỏ qua).
- Tích hợp (emulator, chỉ CI): ghi hồ sơ có minh chứng của người khác → đọc lại thấy id bị gỡ, mức hạ, `completeness` đúng, `evidenceRemovedAt` có; ghi lại y nguyên → Function không ghi thêm.
- Flutter: adapter đọc `SkillsServerInfo`; S08.02 hiện số server, ba trạng thái gợi ý, SnackBar gỡ minh chứng một lần; không còn import `skills_completeness.dart`.

## 6. Tài liệu cần sửa khi làm

`2026-10-01-remaining-screens.md` §3e.2 ("Do Function tính" giữ, thêm `completenessNext`, `evidenceRemovedAt`), §3e.3 (dòng 488–489: Function đã có); `screens/photographer.md` S08.02 (bỏ "tính ngay trên máy"); `components/shared-components.md` (`CompletenessMeter.percent` nullable); `data-model/` (hai trường server mới).
