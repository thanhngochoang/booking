# S10 · Đăng bài & ảnh tải lên (shared image compressor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every photo the app uploads is resized and re-encoded once for what it is used for (avatar 512 px q80 · chat 1280 q75 · ảnh chia sẻ 1600 q80 · ảnh mẫu 1600 q75 · portfolio 2048 q82 · giấy tờ 2048 q85), leaves the phone without EXIF (GPS, device, owner), and Storage rules accept only JPEG up to the size its purpose can produce, path by path. S10.01 Đăng bài is checked against the mock and its upload path against the rules. Later plans (#131 chat, #152 delivery samples, #135 identity documents) use the same API. **Architecture:** A pure-Dart core in `lib/data/media/` (`ImagePurpose` with the six specs, JPEG segment tools: strip metadata, read size; the encode-and-fit loop over an injected encoder) plus one plugin adapter `NativeImageCompressor` (`flutter_image_compress`, the only file that imports it). `MediaUploader.upload` gains a required `purpose`; the Storage adapter compresses to a temp file, uploads it with `putFile` (still streamed from disk), sets `contentType: image/jpeg`, a per-purpose `Cache-Control` and `customMetadata.purpose`, and deletes the temp file. The picker keeps a light pre-pass (2048 px, q95) so the compressor never decodes a 50 MP original. All eight existing upload call sites pass their purpose. `storage.rules` gets one helper `jpegUpTo(maxBytes)` per path, mirrored by a Dart sync test. **Tech Stack:** Flutter, Riverpod 3, `flutter_image_compress` (new), `firebase_storage` (adapter only), Storage rules, `flutter_test`, rules tests in `app_flutter/firebase/rules-test/rules.test.mjs` (written, not run). **Spec:** issue #147 (purpose table); cost spec `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §5, §11–§14; mock `docs/design/ui-mock.html#S10.01`; `docs/superpowers/specs/screens/photographer.md` S10.01; `docs/superpowers/specs/screens/portfolio-awards.md` (S10.01 ô Album, grid aspect ruling); `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` (watermark at 1600 px); `2026-10-06-identity-verification-design.md` (documents); `docs/superpowers/specs/data-model/README.md` (ports: `FileStorage` + `MediaUrlResolver`). **Issue:** #147

**Branch:** `plan/147-s10-post-upload` from `origin/develop` (claimed with `scripts/project.py claim 147`), PR into `develop` titled `feat(media): shared image compressor by purpose, EXIF stripped, Storage limits [#147]`.

**Execution wave:** 1 (cross-plan review 2026-10-07). **Blocked by:** none. **Owns:** `ImagePurpose`, `MediaUploader.upload(image, storagePath:, purpose:)`, `jpegUpTo(maxBytes)` in `storage.rules`; every later plan that uploads an image (#152 delivery samples, #131 chat, #135 documents, #139 job references, #142 dispute evidence) uses them and adds no compressor, picker parameter or size rule of its own.

## Global Constraints

- Firebase isolation: `firebase_storage` only in `lib/data/media/firebase_media_uploader.dart` and `lib/main.dart` (existing test). New: `flutter_image_compress` only in `lib/data/media/native_image_compressor.dart` (new test). Features never import either.
- Imports `package:photobooking/...`; features import `core/core.dart` and `data/media/*` interfaces.
- The product rules are not touched (money, contact unlock); this unit is media only.
- No new Cloud Function and no Storage trigger (owner ruling 3: dev project on Spark; everything runs on the emulators). Server-side size guards are Storage rules only.
- Region `asia-southeast1` (Storage bucket in Singapore, `docs/FIREBASE-SETUP.md`); no function added.
- Strings: this plan adds one key (S10.01 none); any user-visible text goes to `lib/l10n/app_vi.arb` + `flutter gen-l10n`.
- Ids: uploaded file names stay opaque (ULID / client id) with the `.jpg` extension; Storage keys, not download URLs, are the business reference where a doc already stores a path (chat `imagePath`, award `storagePath`, user `avatarPath`) (`data-model/README.md` rule 7).
- Env for Flutter commands, from `app_flutter/`: `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Adding the package needs pub.dev: run `flutter pub add flutter_image_compress` with `allowed_domains: ["pub.dev", "storage.googleapis.com", "pub.dartlang.org"]`; if the sandbox still refuses, stop and ask the user to run it (do not edit `pubspec.lock` by hand).
- Tests: `flutter test --no-pub --timeout 60s <file or folder>` one folder at a time; bounded pumps. The native encoder never runs in `flutter test` (no platform): everything testable lives in pure Dart with an injected encoder. Rules tests are written in `rules.test.mjs` and not run (CI runs them). No device build (Android Gradle needs Maven, blocked in the sandbox): ledger it.
- Commits: Conventional Commits, subject ends with `[#147]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions

1. **One purpose per upload, chosen by the call site, required by the type system.** `MediaUploader.upload(image, storagePath:, purpose:)`; no default, so a new call site cannot forget it.
2. **Purposes and limits** (issue table; `maxBytes` = the Storage rule limit, with headroom over the expected size so a detailed photo never fails):

   | `ImagePurpose` | code | long side | JPEG q | expected | `maxBytes` | Cache-Control |
   |---|---|---|---|---|---|---|
   | `avatar` | `avatar` | 512 | 80 | ~60 KB | 512 KiB | `public, max-age=31536000` |
   | `chat` | `chat` | 1280 | 75 | ~150 KB | 1.5 MiB | `private, max-age=31536000` |
   | `share` | `share` | 1600 | 80 | ~300 KB | 2 MiB | `public, max-age=31536000` |
   | `deliverySample` | `delivery_sample` | 1600 | 75 | ~250 KB | 2 MiB | `private, max-age=31536000` |
   | `portfolio` | `portfolio` | 2048 | 82 | ~500 KB | 3 MiB | `public, max-age=31536000` |
   | `document` | `document` | 2048 | 85 | ~600 KB | 3 MiB | `private, max-age=31536000` |

   File names never change content (new name per upload), so a one-year cache is safe; `private` keeps chat, samples and documents out of shared caches.
3. **Always JPEG.** Universal decode (Android, iOS, web, the watermark Function's `sharp`), one content type for rules. WebP would save ~25% more but needs per-platform encoder support and the server pipeline; revisit with thumbnails (owner question 1).
4. **EXIF removal is guaranteed in Dart, not trusted to the plugin.** The encoder is called with `keepExif: false` and `autoCorrectionAngle: true` (orientation baked into pixels), then `stripJpegMetadata` drops APP1 (Exif, XMP), APP3–APP15, COM and APP2 unless it is an ICC profile; APP0 (JFIF) and the ICC colour profile stay (colour accuracy, not personal data — owner question 2).
5. **Scaling uses one symmetric bound.** `flutter_image_compress` scales by `max(1, min(w / minWidth, h / minHeight))`; passing `minWidth = minHeight = round(short × longSide / long)` makes the long side exactly `longSide` whatever the EXIF rotation (no upscaling when the photo is smaller). The implementer verifies this formula in the pinned plugin version's sources (Android `calcScale`, iOS scale category in the pub cache) and ledgers it; the fit loop (Decision 6) re-checks the real output size anyway.
6. **Fit loop** (`encodeForPurpose`, pure, injected encoder): encode → strip → read size; if the long side is > 2% over `longSide`, shrink the bound proportionally and retry; if bytes > `maxBytes`, lower quality by 8 (floor 60) and retry; at most 4 encodes, then `ImageCompressException(ImageCompressError.tooLarge)`. A decoder failure is `ImageCompressError.unreadable`.
7. **Picker pre-pass 2048 px q95** (was q85): keeps decode memory bounded and the second encode near-lossless for the 2048 purposes. The compressor reads the pre-pass file's size with `ui.ImageDescriptor` (header only).
8. **Upload path vs rules audit (2026-10-07):**

   | Call site | Path | Rule block | Purpose | Status |
   |---|---|---|---|---|
   | `features/settings/avatar_controller.dart` | `avatars/{uid}/{ulid}.jpg` | `avatars/{uid}/{file}` | `avatar` | ok |
   | `features/create_post/post_composer.dart` | `posts/{uid}/{draftId}/{key}.jpg` (draftId = post doc id) | `posts/{uid}/{postId}/{file}` | `portfolio` | ok |
   | `features/review/review_controller.dart` (S05.05 `real_shoot`) | `posts/{uid}/{postId}/{key}.jpg` | posts | `share` | ok |
   | `data/events/firestore_event_timeline_repository.dart` (S11.05 `event_share`) | `posts/{uid}/{postId}/{ulid}.jpg` | posts | `share` | ok |
   | `data/events/firestore_event_repository.dart` (S12.01 cover) | `eventCovers/{uid}/{eventId}/{ulid}.jpg` | `eventCovers/{uid}/{eventId}/{file}` | `share` | ok |
   | `features/awards/edit_award_controller.dart` via `AwardRepository.proofPath` | `awardProofs/{uid}/{awardId}/{ulid}.jpg` | `awardProofs/…` (create only) | `document` | ok |
   | `data/chat/firestore_chat_repository.dart` (S07.01) | `chats/{chatId}/{uid}/{clientId}.webp` | `chats/{chatId}/{uid}/{file}` | `chat` | **extension lies** (bytes and content type are JPEG): rename to `.jpg` |
   | `data/events/firestore_event_chat_repository.dart` (S11.06) | `chats/event_{eventId}/{uid}/{clientId}.jpg` | chats (members list on `chats/event_{id}`) | `chat` | ok |
   | — | `users/{uid}/**` | `users/{uid}/{allPaths=**}` (15 MB, any image) | — | **no writer** (grep `lib/`, `firebase/functions/src`): close it (the catch-all denies) |

   `posts/` holds both portfolio (2048) and share (1600) images, so its limit is the larger (3 MiB).
9. **Image size travels with the upload.** `UploadedMedia` gains `width`, `height`, `sizeBytes` from the compressor; S10.01 writes them to `imageMeta` (`w`, `h`) and the event timeline uses them instead of re-measuring the file (`_measureSafely` stays as the fallback when null).
10. **S10.01 mock parity (checked 2026-10-07):** (P1) mock bar has a back arrow and the pushed-screen title; S10.01 is the middle tab (no back destination) → **mock fixed** (no arrow, tab-root title), **app** uses the tab-root title style like S09.01/S06.01 (`centerTitle: false`, `tabRootTitleStyle`). (P2) mock tiles 16:10, app square → accepted by `portfolio-awards.md` ("Flutter vẫn dùng ô vuông"). (P3) app shows "{n} / 10 ảnh" under the grid → **mock fixed** (add the line). (P4) "Bài đăng / Sự kiện" `SegmentedTabs`, "Mô tả", "Gói dịch vụ · bắt buộc" (accent, "Chân dung 2 giờ · 1.500.000₫"), "Địa điểm" + "Phong cách" row, "Album · tuỳ chọn" → "Không xếp album", footer "Đăng" → **match**.
11. **Delivery samples (#130) are compressed on the phone too** (`deliverySample`), then watermarked by the Function at the same 1600 px; the Function does not need to resize. The temporary samples path and its rule line are #130's; it must use `jpegUpTo(2 * 1024 * 1024)` and `ImagePurpose.deliverySample`. Identity documents (#135) use `ImagePurpose.document` and `jpegUpTo(3 * 1024 * 1024)`.
12. **Other units adding Storage paths** (S05 delivery `deliveryUploads/…`/`deliveries/…`, S15/S16 job references `jobRefs/{uid}/{draftId}/{ulid}.jpg` (`ImagePurpose.share`, `jpegUpTo(2 * 1024 * 1024)`), S18 `disputeEvidence/…`) edit `storage.rules` too. Whichever lands later rebases onto `jpegUpTo`: client-uploaded images on a new path use `jpegUpTo(<purpose maxBytes>)` (S18 evidence: `document`, 3 MiB, instead of its planned `image/(jpeg|png|webp|heic|heif)`), and the sync test's table gains the path. Ledger the merge.

## Needs the owner

1. JPEG everywhere, or WebP for public images (~25% less egress, more platform work)? Default: JPEG now; reconsider with upload-time thumbnails.
2. Keep the ICC colour profile (Display P3 photos from iPhones look right) while stripping EXIF/XMP? Default: keep.

## Contract

- **`lib/data/media/image_purpose.dart`** (pure Dart):
  ```dart
  enum ImagePurpose {
    avatar('avatar', longSide: 512, quality: 80, maxBytes: 512 * 1024, publicCache: true),
    chat('chat', longSide: 1280, quality: 75, maxBytes: 1536 * 1024, publicCache: false),
    share('share', longSide: 1600, quality: 80, maxBytes: 2 * 1024 * 1024, publicCache: true),
    deliverySample('delivery_sample', longSide: 1600, quality: 75, maxBytes: 2 * 1024 * 1024, publicCache: false),
    portfolio('portfolio', longSide: 2048, quality: 82, maxBytes: 3 * 1024 * 1024, publicCache: true),
    document('document', longSide: 2048, quality: 85, maxBytes: 3 * 1024 * 1024, publicCache: false);

    const ImagePurpose(this.code, {required this.longSide, required this.quality, required this.maxBytes, required this.publicCache});
    final String code; final int longSide; final int quality; final int maxBytes; final bool publicCache;
    String get cacheControl => '${publicCache ? 'public' : 'private'}, max-age=31536000';
  }
  ```
- **`lib/data/media/jpeg_tools.dart`** (pure Dart, `dart:typed_data` only):
  ```dart
  /// Drops APP1 (Exif/XMP), APP3–APP15, COM, and APP2 unless it starts with
  /// "ICC_PROFILE\0". Keeps everything from SOS on untouched. Returns [bytes]
  /// itself when nothing was dropped. Throws FormatException if not a JPEG.
  Uint8List stripJpegMetadata(Uint8List bytes);
  /// True if any segment [stripJpegMetadata] would drop is present.
  bool jpegHasMetadata(Uint8List bytes);
  /// Width/height from the first SOFn marker (C0–CF except C4, C8, CC); null if none.
  ({int width, int height})? jpegSize(Uint8List bytes);
  /// minWidth = minHeight bound for the encoder (Decision 5); never upscales.
  int encoderBound({required int width, required int height, required int longSide});
  ```
- **`lib/data/media/image_compressor.dart`**:
  ```dart
  @immutable class CompressedImage { const CompressedImage({required this.path, required this.width, required this.height, required this.sizeBytes}); final String path; final int width; final int height; final int sizeBytes; }
  enum ImageCompressError { unreadable, tooLarge }
  class ImageCompressException implements Exception { const ImageCompressException(this.code); final ImageCompressError code; }
  abstract class ImageCompressor {
    /// Resizes and re-encodes [source] for [purpose] into a new temporary JPEG
    /// without metadata. The caller deletes [CompressedImage.path] when done.
    Future<CompressedImage> compress(PickedImage source, ImagePurpose purpose);
  }
  /// Encoder seam: [bound] is passed as both minWidth and minHeight.
  typedef JpegEncoder = Future<Uint8List> Function(String path, {required int bound, required int quality});
  /// Decision 6. Returns stripped bytes within the purpose's size and bytes.
  Future<({Uint8List bytes, int width, int height})> encodeForPurpose(String path, {required int width, required int height, required ImagePurpose purpose, required JpegEncoder encode});
  class FakeImageCompressor implements ImageCompressor { // tests: records calls, returns the source path with fixed 1000x750
    final List<(String, ImagePurpose)> calls = [];
    ImageCompressError? failWith;
  }
  final imageCompressorProvider = Provider<ImageCompressor>((ref) => NativeImageCompressor()); // in media_providers.dart
  ```
- **`lib/data/media/native_image_compressor.dart`** (the only `flutter_image_compress` import): reads source size via `ui.ImmutableBuffer.fromFilePath` + `ui.ImageDescriptor.encoded` (dispose both); `encode` = `FlutterImageCompress.compressWithFile(path, minWidth: bound, minHeight: bound, quality: q, format: CompressFormat.jpeg, keepExif: false, autoCorrectionAngle: true)` (null → `unreadable`); writes the result to `${Directory.systemTemp.path}/upload_${newUlid()}.jpg`.
- **`MediaUploader`** (`lib/data/media/media_uploader.dart`):
  ```dart
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath, required ImagePurpose purpose});
  // UploadedMedia gains: final int? width; final int? height; final int? sizeBytes;
  // FakeMediaUploader gains: final Map<String, ImagePurpose> purposes = {}; (storagePath -> purpose)
  ```
  `FirebaseMediaUploader({FirebaseStorage? storage, required ImageCompressor compressor})`: `compress` → `putFile(File(c.path), SettableMetadata(contentType: 'image/jpeg', cacheControl: purpose.cacheControl, customMetadata: {'purpose': purpose.code}))` → progress as today → done with `UploadedMedia(url, storagePath, width: c.width, height: c.height, sizeBytes: c.sizeBytes)`; temp file deleted in `finally`. `mediaUploaderProvider` = `FirebaseMediaUploader(compressor: ref.watch(imageCompressorProvider))`.
- **Picker** (`lib/data/media/plugin_image_picker.dart`): `_quality = 95` (long side stays 2048); `ImagePickerPort` doc comment updated.
- **Call sites** pass purposes exactly as Decision 8; chat path becomes `chats/$chatId/$uid/$clientId.jpg`.
- **Storage rules** (`app_flutter/firebase/storage.rules`): add
  ```
  // Every upload is a JPEG made by the app's compressor (lib/data/media/image_purpose.dart);
  // the limit of each path is the maxBytes of its purpose (test/data/media/storage_rules_limits_sync_test.dart).
  function jpegUpTo(maxBytes) {
    return request.resource.contentType == 'image/jpeg' && request.resource.size <= maxBytes;
  }
  ```
  and use it: `avatars/{uid}/{file}` create/update `isOwner(uid) && jpegUpTo(512 * 1024)`; `posts/{uid}/{postId}/{file}` `jpegUpTo(3 * 1024 * 1024)`; `awardProofs/{uid}/{awardId}/{file}` create `… && resource == null && jpegUpTo(3 * 1024 * 1024)`; `chats/{chatId}/{uid}/{file}` create `isOwner(uid) && jpegUpTo(1536 * 1024) && <membership as today>`; `eventCovers/{uid}/{eventId}/{file}` `jpegUpTo(2 * 1024 * 1024)`; delete `validImage()` and the `users/{uid}/{allPaths=**}` block. Comments name the purpose of each path and reserve: `// #152 delivery samples: jpegUpTo(2 * 1024 * 1024) (deliverySample)`, `// #135 identity documents: jpegUpTo(3 * 1024 * 1024) (document)`.
- **Mock** `#S10.01`: replace `<div class="bar"><div class="ic"><span class="ms">arrow_back</span></div><div class="t" style="font-size:17px">Đăng bài</div><div class="ic" style="opacity:0"></div></div>` with `<div class="bar"><div class="t">Đăng bài</div></div>`; after the `.grid2` add `<div class="meta x">3 / 10 ảnh</div>`; caption `<span>` appends ` Tab giữa nên không có nút quay lại. Ảnh nén trên máy theo mục đích "portfolio" (cạnh dài 2048 px, JPEG 82, xoá EXIF) trước khi tải lên.`
- **For consumer plans** (#131 chat, #152 delivery, #135 documents, S18 dispute evidence): call `MediaUploader.upload(image, storagePath: …, purpose: ImagePurpose.<x>)`; compression, EXIF removal and the JPEG content type happen inside the uploader, so a consumer does not call the compressor itself. `ImageCompressor.compress(PickedImage, ImagePurpose) → CompressedImage` (a temp JPEG the caller deletes) is exposed only for a flow that needs the compressed file before uploading (e.g. a local preview). Purpose per consumer: chat images `chat`; delivery samples `deliverySample` (path and rule line `jpegUpTo(2 * 1024 * 1024)` owned by #130); identity documents and dispute evidence `document` (`jpegUpTo(3 * 1024 * 1024)`, path owned by #135 / S18). New paths must be JPEG-only (`jpegUpTo`), never `image/.*`.
- **Overlap with #131:** #131's plan also renames the chat image path `.webp` → `.jpg` (its Decision 7). Whichever unit lands second finds it done and skips that edit (ledger it).

## Review Focus

1. A photo with GPS in its EXIF uploaded from any of the eight call sites reaches Storage without APP1. Pinned in Task 1 (`strips Exif/XMP but keeps JFIF and ICC`), Task 2 (`the adapter uploads the compressor's file, never the picked file`) and Task 3 (`every call site passes its purpose` via `FakeMediaUploader.purposes`).
2. A large, detailed photo that encodes above `maxBytes` at the purpose quality: the loop lowers quality instead of failing, and a rule-limit rejection never happens for app uploads. Pinned in Task 1 (`lowers quality until the bytes fit`, `gives up with tooLarge after 4 encodes`).
3. A rotated (EXIF orientation 6) portrait photo: the output is upright and its long side is exactly the purpose's long side. Device-only for the pixels; the size logic is pinned in Task 1 (`encoderBound is symmetric, so rotation does not change the long side`, `retries with a smaller bound when the encoder overshoots`).
4. Temp files do not pile up in the app cache when uploads fail or are cancelled. Pinned in Task 2 (`the temp file is deleted after success, failure and cancel`).
5. Old app builds in testers' hands (before this unit) upload PNG/HEIC award proofs or > 3 MiB posts and are refused after the rules deploy. Not testable here: deploy order note in the ledger (ship the app build first, then `npm run deploy:storage:*`).

## Chi phí Google

Unit prices from the cost spec: Storage $0.020/GB-month **[S]**; egress $0.12/GB (**giả định, chưa xác nhận**; the Singapore bucket is assumed to have no free tier); 600 image views/MAU/month (§11).

- **Firestore:** no read or write added (`imageMeta.w/h` ride on the existing post write).
- **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. This plan adds no Functions work (compression runs on the phone; no Storage trigger).
- **Scheduled jobs / paid APIs:** none.
- **Storage paths:** none new; limits tightened on five existing paths, `users/{uid}/**` closed.
- **Image sizes before → after** (before = today's picker output for every purpose, 2048 px JPEG q85 ≈ 650 KB, estimate to confirm on a device in the ledger): avatar 650 → 60 KB; chat 650 → 150 KB; share/cover 650 → 300 KB; portfolio 650 → 500 KB; document 650 → 600 KB.
- **Egress per MAU** (assumed view mix of the 600 views: 40% avatars, 45% portfolio/feed, 10% share and covers, 5% chat): before 600 × 650 KB = **390 MB**; after 240 × 60 + 270 × 500 + 60 × 300 + 30 × 150 KB = **172 MB**. Saving 218 MB/MAU/month → **218 GB at 1,000 MAU = −$26/month; 2.18 TB at 10,000 MAU = −$262/month.** (If the Firebase "100 GB/month free download" applies to the new bucket after all, the (b) saving shrinks to about −$14.)
- **Storage at rest** (cost spec §11: 60 portfolio photos per photographer, 5 chat photos per booking): (b) 100 photographers × 60 × (650 − 500) KB = 0.9 GB, chats 1,500/month × 500 KB = 0.75 GB/month, avatars 1,000 × 590 KB = 0.6 GB → ≈ 2.2 GB less in the first month, **−$0.04/month**, growing by ~0.75 GB/month; (c) ×10 → **−$0.45/month** in the first month.
- **Against §12:** the cost spec's worst case assumed 150 KB per viewed image (90 MB/MAU); the code as built averages ~650 KB, so today's real egress is ~4× that table. After this plan it is 172 MB/MAU, still ~2× the table, because grids and feeds download 2048 px images. Upload-time thumbnails (~35 KB tiles; Deferred) would bring it to ~75 MB/MAU (another −$12 (b) / −$116 (c) per month).
- **Conclusion:** **−$26/month at (b) 1,000 MAU, −$262/month at (c) 10,000 MAU** (savings; nothing added).

## Tasks

### Task 1: Purposes, JPEG tools and the fit loop (pure Dart)

**Files:**
- Create: `app_flutter/lib/data/media/image_purpose.dart`, `app_flutter/lib/data/media/jpeg_tools.dart`, `app_flutter/lib/data/media/image_compressor.dart` (port, `CompressedImage`, errors, `encodeForPurpose`, `FakeImageCompressor`; no plugin import), `app_flutter/test/data/media/jpeg_tools_test.dart`, `app_flutter/test/data/media/encode_for_purpose_test.dart`, `app_flutter/test/support/jpeg_fixtures.dart`

**Interfaces:**
- Produces: everything under "`image_purpose.dart`", "`jpeg_tools.dart`", "`image_compressor.dart`" in Contract (except the provider, Task 2).

- [ ] **Step 1: Test fixtures.** `jpeg_fixtures.dart` builds JPEG byte arrays segment by segment (no image decoding needed): `jpegWith({bool app0 = true, bool exif = false, bool xmp = false, bool icc = false, bool flashPixApp2 = false, bool comment = false, bool app13 = false, int width = 1600, int height = 1200, bool progressive = false})` → `FF D8`, the chosen segments (Exif payload contains the ASCII `GPSLatitude` so a test can search for it), `DQT`, `SOF0` or `SOF2` with the dims, `DHT`, `SOS` + a few entropy bytes containing `FF 00` stuffing and an `FF D0` restart marker, `FF D9`.
- [ ] **Step 2: Failing tests.**
  - `jpeg_tools_test.dart`: `strips Exif/XMP but keeps JFIF and ICC` (no `GPSLatitude`, no `http://ns.adobe.com/xap/`, `ICC_PROFILE` and `JFIF` still present); `drops COM, APP13 and a non-ICC APP2`; `keeps the scan data byte for byte` (bytes from SOS to EOI identical); `returns the same instance when there is nothing to strip`; `throws FormatException for a PNG or truncated data`; `jpegHasMetadata is true before and false after stripping`; `jpegSize reads SOF0 and SOF2, skips DHT`; `jpegSize is null without a frame header`; `encoderBound: 4000x3000 to 2048 → 1536; 3000x4000 → 1536 (symmetric); 1200x900 to 2048 → 900 (no upscale); square 3000 → 2048`.
  - `encode_for_purpose_test.dart` (fake `JpegEncoder` returning fixture bytes chosen by `(bound, quality)`):
    - `one encode when size and bytes fit` (calls: 1, quality = purpose.quality, bound from `encoderBound`).
    - `the result never carries Exif even when the encoder keeps it` (encoder returns `exif: true`).
    - `lowers quality until the bytes fit` (first two results > maxBytes → qualities 82, 74, 66 for portfolio).
    - `quality never goes below 60` and `gives up with tooLarge after 4 encodes`.
    - `retries with a smaller bound when the encoder overshoots` (first result long side 2400 for portfolio → second call bound = floor(bound × 2048 / 2400)).
    - `encoderBound is symmetric, so rotation does not change the long side` (portrait 3000×4000 and landscape 4000×3000 give the same bound).
    - `purposes match the issue table` (six rows: code, longSide, quality, maxBytes, cacheControl).
    - `FakeImageCompressor records calls and can fail with unreadable`.
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/data/media/` — new tests fail.
- [ ] **Step 4: Implement.** Hard part, `stripJpegMetadata`:
  ```dart
  Uint8List stripJpegMetadata(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      throw const FormatException('not a JPEG');
    }
    final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
    var i = 2;
    var dropped = false;
    while (i + 4 <= bytes.length) {
      if (bytes[i] != 0xFF) throw const FormatException('bad marker');
      final marker = bytes[i + 1];
      if (marker == 0xFF) { i++; continue; }            // fill byte
      if (marker == 0xDA) {                              // SOS: the rest is scan data
        if (!dropped) return bytes;
        out.add(Uint8List.sublistView(bytes, i));
        return out.toBytes();
      }
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      final end = i + 2 + len;
      if (len < 2 || end > bytes.length) throw const FormatException('bad length');
      final isIcc = marker == 0xE2 && _ascii(bytes, i + 4, 'ICC_PROFILE\u0000');
      final drop = marker == 0xE1 || (marker >= 0xE3 && marker <= 0xEF) ||
          marker == 0xFE || (marker == 0xE2 && !isIcc);
      if (drop) { dropped = true; } else { out.add(Uint8List.sublistView(bytes, i, end)); }
      i = end;
    }
    throw const FormatException('no scan data');
  }
  ```
  `encodeForPurpose` per Decision 6 (sizes from `jpegSize` of the stripped bytes; a null size or a `FormatException` → `ImageCompressException(unreadable)`).
- [ ] **Step 5: Run** the folder and `flutter analyze`; green.
- [ ] **Step 6: Commit** `feat(media): image purposes, JPEG metadata stripping and the fit loop [#147]`.

### Task 2: Native compressor, uploader integration and picker pre-pass

**Files:**
- Modify: `app_flutter/pubspec.yaml` (+ `pubspec.lock` via `flutter pub add flutter_image_compress`), `app_flutter/lib/data/media/media_uploader.dart`, `app_flutter/lib/data/media/firebase_media_uploader.dart`, `app_flutter/lib/data/media/media_providers.dart`, `app_flutter/lib/data/media/plugin_image_picker.dart`, `app_flutter/lib/data/media/image_picker_port.dart` (doc comment), `app_flutter/test/data/media/media_uploader_test.dart`, `app_flutter/test/data/media/image_picker_port_test.dart` (if it pins q85)
- Modify (one `purpose:` argument each, Decision 8): the eight call-site files listed in Decision 8 and any fake/in-memory repository or test the compiler flags
- Create: `app_flutter/lib/data/media/native_image_compressor.dart`, `app_flutter/test/data/media/firebase_media_uploader_flow_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces: `NativeImageCompressor`, `imageCompressorProvider`, `MediaUploader.upload(…, purpose:)`, `UploadedMedia.width/height/sizeBytes`, `FakeMediaUploader.purposes`, `FirebaseMediaUploader({storage, required compressor})`.

- [ ] **Step 1: Failing tests.**
  - `firebase_media_uploader_flow_test.dart`: extract the adapter's non-Firebase flow into a testable function in the adapter file, e.g. `@visibleForTesting Stream<UploadEvent> uploadCompressed({required ImageCompressor compressor, required PickedImage image, required ImagePurpose purpose, required String storagePath, required Future<String> Function(String localPath, SettableMetadataLike meta, void Function(double) onProgress) put, required Future<void> Function(String path) deleteLocal})` where `SettableMetadataLike` is a small record `({String contentType, String cacheControl, Map<String,String> custom})` (keeps `firebase_storage` types out of the test). Tests: `the adapter uploads the compressor's file, never the picked file`; `metadata is image/jpeg with the purpose's Cache-Control and customMetadata.purpose`; `done carries width, height and size from the compressor`; `the temp file is deleted after success, failure and cancel` (cancel = the listener cancels the subscription mid-upload); `a compressor failure is a stream error with ImageCompressException`.
  - `media_uploader_test.dart`: update calls with `purpose:`; `the fake records each path's purpose`; change the source test `the Storage adapter streams from disk and throttles progress` to also expect `customMetadata`, `cacheControl: purpose.cacheControl` (still `putFile`, no `putData`, no `readAsBytes`); add `flutter_image_compress is imported only by the native compressor` (same pattern as the `firebase_storage` test).
  - `image_picker_port_test.dart`: if it pins quality 85, it now pins 95.
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/data/media/` — fails.
- [ ] **Step 3: Implement.** `flutter pub add flutter_image_compress` (Global Constraints for network). `NativeImageCompressor` per Contract. `FirebaseMediaUploader.upload` delegates to `uploadCompressed` with `put` wrapping `ref.putFile(File(path), SettableMetadata(contentType:…, cacheControl:…, customMetadata:…))` and the existing 5% progress throttle. Provider wiring in `media_providers.dart` (`mediaUrlResolverProvider` keeps a resolver-only instance; give `FirebaseMediaUploader` a `MediaUrlResolver`-only named constructor or split the resolver into `FirebaseMediaUrlResolver` — ledger which). The required `purpose:` breaks the eight call sites and the fakes: fix them **mechanically in this task** with the purposes of Decision 8 (one argument each, no other change; the chat path rename, size propagation and per-site tests are Task 3), and add `purpose:` to every test that calls `upload(` directly (`grep -rn "\.upload(" test`), so the tree compiles and stays green after this commit.
- [ ] **Step 4: Run** `flutter analyze` (clean) and `flutter test --no-pub --timeout 60s test/data/media/`, then the folders whose tests call `upload(` directly; green.
- [ ] **Step 5: Commit** `feat(media): compress before upload, JPEG with per-purpose cache headers [#147]`.

### Task 3: Per-site purposes pinned, chat `.jpg`, sizes from the upload

**Files:**
- Modify: `app_flutter/lib/features/settings/avatar_controller.dart`, `app_flutter/lib/features/create_post/post_composer.dart`, `app_flutter/lib/features/review/review_controller.dart`, `app_flutter/lib/features/awards/edit_award_controller.dart`, `app_flutter/lib/data/chat/firestore_chat_repository.dart`, `app_flutter/lib/data/events/firestore_event_timeline_repository.dart`, `app_flutter/lib/data/events/firestore_event_repository.dart`, `app_flutter/lib/data/events/firestore_event_chat_repository.dart`, plus any fake/in-memory repository the compiler flags (e.g. `lib/data/events/event_repository.dart`, `event_chat_repository.dart` fakes) and every test that calls `upload(` directly (`grep -rn "\.upload(" test`)
- Test: `app_flutter/test/features/settings/avatar_controller_test.dart`, `app_flutter/test/features/create_post/post_composer_test.dart`, `app_flutter/test/features/review/` (controller test), `app_flutter/test/features/awards/edit_award_sheet_test.dart`, `app_flutter/test/data/chat/` (repository or controller test using `FakeMediaUploader`), `app_flutter/test/data/events/` or `test/features/events/` (timeline share, cover), `app_flutter/test/features/event_chat/`

**Interfaces:**
- Consumes: `MediaUploader.upload(…, purpose:)`, `UploadedMedia.width/height`, `FakeMediaUploader.purposes` (Task 2; the call sites already pass a purpose).
- Produces: tests pinning each site's purpose; chat path `chats/{chatId}/{uid}/{clientId}.jpg`; post `imageMeta` with `w`/`h` from the upload; timeline sizes from the upload.

**Backend wiring:** unchanged adapters and callables (`sendMessage` with `imagePath`, `createAward`/`updateAward` proofs, `createEvent` cover path check, event timeline `shareToEvent`, post create through rules `validPostCreate`). The server's chat path check (`packages/domain/src/chat.ts`: `chats/` prefix and `{chatId}` segment) does not look at the extension.

- [ ] **Step 1: Failing tests** (one per site, through each feature's existing test world with `FakeMediaUploader`):
  - `avatar upload uses the avatar purpose` (`purposes['avatars/u1/…'] == ImagePurpose.avatar`).
  - `post photos use the portfolio purpose and imageMeta carries the uploaded size` (`FakeMediaUploader` done event with width 2048, height 1365 → the published `PostImage.width/height`).
  - `review share photos use the share purpose`.
  - `award proofs use the document purpose`.
  - `chat images are uploaded as .jpg with the chat purpose`.
  - `event share photos use the share purpose and the uploaded size` (and fall back to measuring when the media has no size).
  - `event cover uses the share purpose`.
  - `event chat images use the chat purpose`.
  - Make `FakeMediaUploader` done events carry `width: 1000, height: 750, sizeBytes: 100000` by default so the size assertions have values.
- [ ] **Step 2: Run** each touched folder — the chat path and size tests fail; the purpose tests pass if Task 2 chose right (they pin it).
- [ ] **Step 3: Implement** the chat rename (`.webp` → `.jpg`) and the size propagation; correct any purpose Task 2 got wrong; `PostComposerController` copies `media.width/height` into the image it hands to the publisher (check `ComposerImage` → `PostImage` mapping); the timeline repository uses `media.width/height` and calls `_measureSafely` only when null.
- [ ] **Step 4: Run** `flutter analyze`, then one folder at a time: `test/data/`, `test/features/settings/`, `test/features/create_post/`, `test/features/review/`, `test/features/awards/`, `test/features/chat/`, `test/features/events/`, `test/features/event_chat/`, `test/features/event_create/`. Green.
- [ ] **Step 5: Commit** `fix(media): chat images saved as .jpg, upload sizes reach posts; purposes pinned per site [#147]`.

### Task 4: Storage rules per purpose, sync test and rules tests

**Files:**
- Modify: `app_flutter/firebase/storage.rules`, `app_flutter/firebase/rules-test/rules.test.mjs`
- Create: `app_flutter/test/data/media/storage_rules_limits_sync_test.dart`

**Interfaces:**
- Consumes: `ImagePurpose.maxBytes` (Task 1).
- Produces: `jpegUpTo(maxBytes)` and the per-path limits (Contract).

- [ ] **Step 1: Failing test** `storage_rules_limits_sync_test.dart` (reads `firebase/storage.rules` as text, like `test/data/skills/rules_catalogue_sync_test.dart`):
  - `each upload path uses jpegUpTo with its purpose's maxBytes`: table `{'avatars/{uid}/{file}': ImagePurpose.avatar, 'posts/{uid}/{postId}/{file}': ImagePurpose.portfolio, 'awardProofs/{uid}/{awardId}/{file}': ImagePurpose.document, 'chats/{chatId}/{uid}/{file}': ImagePurpose.chat, 'eventCovers/{uid}/{eventId}/{file}': ImagePurpose.share}`; for each `match /<path> {` block, find `jpegUpTo(<expr>)`, evaluate `<expr>` as a product of integers, compare to `maxBytes`.
  - `share fits under the posts limit` (`ImagePurpose.share.maxBytes <= ImagePurpose.portfolio.maxBytes`, since both live under `posts/`).
  - `no upload path accepts any image/* type` (`image/.*` and `validImage()` absent).
  - `users/{uid}/** is closed` (no `match /users/` block).
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/data/media/storage_rules_limits_sync_test.dart` — fails.
- [ ] **Step 3: Implement** the rules per Contract (keep `resource == null` on `awardProofs`, keep chat membership and `update, delete: if false`). Rules: hard part sample:
  ```
  match /chats/{chatId}/{uid}/{file} {
    allow read: if signedIn()
      && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.members;
    allow create: if isOwner(uid)
      && jpegUpTo(1536 * 1024)
      && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.members;
    allow update, delete: if false;
  }
  ```
- [ ] **Step 4: Rules tests (written, not run)** in `rules.test.mjs`: update the existing storage tests to the new limits and add: `avatars: 512 KiB jpeg ok, 512 KiB + 1 refused, png refused`; `posts: 3 MiB ok, 3 MiB + 1 refused, image/webp refused`; `chats: 1.5 MiB ok for a member, + 1 refused`; `eventCovers: 2 MiB ok, + 1 refused`; `awardProofs: 3 MiB jpeg ok, 10 MiB refused, png refused (was allowed)`; `users/{uid}/x.jpg refused (path closed)`. Replace the old expectations (`photo(8 * 1024 * 1024 + 1)` on posts stays refused; the award `b.png` success becomes a failure; `photo(10 * 1024 * 1024)` on awards becomes a failure).
- [ ] **Step 5: Run** the sync test green; `flutter analyze`. Ledger: rules tests written, not run (CI); deploy order (Review Focus 5).
- [ ] **Step 6: Commit** `feat(storage): JPEG-only uploads with per-purpose size limits; close users/** [#147]`.

### Task 5: S10.01 mock parity

**Files:**
- Modify: `app_flutter/lib/features/create_post/create_post_screen.dart` (AppBar), `docs/design/ui-mock.html` (`#S10.01` bar, count line, caption), `docs/superpowers/specs/screens/photographer.md` (S10.01 "Bố cục": no back, "{n} / 10 ảnh"; "Dữ liệu": "nén trên máy theo mục đích portfolio: cạnh dài 2048 px, JPEG q82, xoá EXIF; `posts/{uid}/{postId}/{file}`, ≤ 3 MiB")
- Test: `app_flutter/test/features/create_post/create_post_screen_test.dart`

**Interfaces:**
- Consumes: `tabRootTitleStyle(context)` (`lib/core/theme/app_theme.dart`, exported by `core.dart`).

**Mock parity:** `#S10.01` (after this task): tab-root bar "Đăng bài" without back; `SegmentedTabs` "Bài đăng / Sự kiện"; 2-column photo grid with the "+" tile (app: square tiles, accepted); "3 / 10 ảnh"; "Mô tả"; "Gói dịch vụ · bắt buộc" (accent border) "Chân dung 2 giờ · 1.500.000₫"; row "Địa điểm" + "Phong cách"; "Album · tuỳ chọn" → "Không xếp album"; footer primary "Đăng".

**Backend wiring:** unchanged: photos → `FirebaseMediaUploader` (purpose `portfolio`, Storage `posts/{uid}/{draftId}/{key}.jpg`, rule `jpegUpTo(3 * 1024 * 1024)`); publish → `FirestorePostPublisher` (Firestore `posts/{draftId}`, rule `validPostCreate`, trigger `onPostCreated`); packages → `myServicesProvider` (`FirestoreServiceRepository`); albums → `myAlbumsProvider` (album callables).

- [ ] **Step 1: Failing tests:** `S10.01 uses the tab-root title and has no back button` (`AppBar.centerTitle == false`, `titleTextStyle == tabRootTitleStyle(context)`, no `BackButton`/leading); `the order of fields matches the mock` (vertical order: `create-post-tabs`, `create-add`, `create-caption`, `create-service`, `create-location` and `create-style` on one row, `create-album`); `the photo count reads "1 / 10 ảnh" after one photo` (pins P3).
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/create_post/` — the title test fails.
- [ ] **Step 3: Implement** `AppBar(centerTitle: false, titleTextStyle: tabRootTitleStyle(context), title: Text(l.tabCreate))`; mock and spec edits per Contract.
- [ ] **Step 4: Run** the folder and `flutter analyze`; green.
- [ ] **Step 5: Commit** `fix(create-post): S10.01 tab-root header; mock and spec match the app [#147]`.

### Task 6: Docs for consumers, cost spec note, status and ledger

**Files:**
- Modify: `docs/superpowers/specs/data-model/README.md` (under the `FileStorage` + `MediaUrlResolver` port row, a subsection "Ảnh tải lên" in Vietnamese: the purpose table of Decision 2, EXIF rule, JPEG only, `customMetadata.purpose`, how a self-hosted `FileStorage` must keep the same limits), `docs/superpowers/specs/components/shared-components.md` (one row: "`ImagePurpose` / `MediaUploader.upload(purpose:)` — mọi màn tải ảnh"), `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §11 (add: "Ảnh hiện tại trước #147: 2048 px q85 ≈ 650 KB cho mọi mục đích; sau #147 theo bảng mục đích; thumbnail chưa có"), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S10.01 "✅ đã làm (3c) · khớp mock, ảnh nén theo mục đích (#147)")
- Create: `docs/superpowers/handover/ledger-s10-post-upload.md`

- [ ] **Step 1:** Edit the docs. In the ledger: Decisions 1–11, the two owner questions with defaults, the verified scaling formula of the plugin version (Decision 5), "rules tests written, not run (CI)", "no device build (Maven blocked): run `flutter build apk --debug` once on the owner's machine and upload one photo with GPS per purpose on the emulator, then check in the Storage emulator UI that the object has no Exif and the expected size", deploy order (app first, then `npm run deploy:storage:dev|prod`), and the hand-off lines for #131 (chat: `ImagePurpose.chat`, `.jpg`), #130 (`ImagePurpose.deliverySample`, `jpegUpTo(2 * 1024 * 1024)`), #135 (`ImagePurpose.document`, `jpegUpTo(3 * 1024 * 1024)`).
- [ ] **Step 2: Commit** `docs(media): upload purposes for consumers, cost note, S10 status and ledger [#147]`.

## Deferred

- Upload-time thumbnails (~400 px, ~35 KB) for grids and feeds, with `thumbUrls` on posts: the largest remaining egress lever (−$12 (b) / −$116 (c) per month, see Chi phí); needs a post schema change and every grid to read thumbnails. Own unit.
- WebP output (owner question 1).
- Server-side verification of pixel dimensions or a Storage trigger that re-encodes uploads: needs Blaze and Functions on Storage events; rules size/type limits are the server guard for now.
- Chat image display from download URLs and image retry (`chat_screen.dart`, `chat_controller.dart`): #131.
- Delivery samples path, rule and watermark Function: #130. Identity document upload and its private path: #135.
- Video in posts (`PostMedia`): out of scope.
