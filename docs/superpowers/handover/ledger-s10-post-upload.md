# Handover ledger — plan S10 post upload: photo upload pipeline (issue #147)

Plan: `docs/superpowers/plans/2026-10-07-s10-post-upload.md`, Tasks 1–6. Branch `plan/147-s10-dang-bai-anh-tai-len`. Merge base b848dfa; commits e8b4617 and 0ce9b11 (purposes, JPEG tools, fit loop), 7c1bcc8 (compress before upload), a06c965 (call sites pass purposes, chat `.jpg`), 2cfda91 (Storage rules), 98db0a6 and a469fa2 (S10.01 mock parity), then the docs commit of Task 6.

## Built
- Task 1: `lib/data/media/image_purpose.dart` (`ImagePurpose`, six purposes with long side, JPEG quality, `maxBytes`, cache header), `jpeg_tools.dart` (`stripJpegMetadata`, `jpegHasMetadata`, `jpegSize`, `encoderBound`), `image_compressor.dart` (`ImageCompressor` port, `CompressedImage`, `ImageCompressError`, `encodeForPurpose` fit loop, `FakeImageCompressor`). Metadata is stripped across every scan and data after EOI is dropped (Ruling 2).
- Task 2: `native_image_compressor.dart` (the only `flutter_image_compress` import), `firebase_media_uploader.dart` (`FirebaseMediaUploader` compresses, then `putFile` of the compressor's temp file with `contentType: image/jpeg`, `cacheControl`, `customMetadata.purpose`; temp file deleted after success, failure and cancel), picker pre-pass 2048 px q95. `MediaUploader.upload(image, storagePath:, purpose:)` has no default purpose; `UploadedMedia` gains `width`, `height`, `sizeBytes`.
- Task 3: the eight call sites pass their purpose (Decision 8); chat image path `.webp` → `.jpg`; S10.01 writes `imageMeta.w/h` from the upload result and the event timeline uses it instead of re-measuring.
- Task 4: `app_flutter/firebase/storage.rules` gets `jpegUpTo(maxBytes)` on avatars (512 KiB), posts (3 MiB), awardProofs (3 MiB, create only), chats (1.5 MiB, members), eventCovers (2 MiB); `validImage()` and the `users/{uid}/**` block are gone (closed by the catch-all deny). `test/data/media/storage_rules_limits_sync_test.dart` pins each block against `ImagePurpose.maxBytes`; rules tests added to `rules.test.mjs`.
- Task 5: S10.01 mock parity (tab-root title, "n / 10 ảnh" line), `photographer.md` S10.01 now lists the "Album" field instead of the portfolio toggle.
- Task 6 (docs): `data-model/README.md` subsection "Ảnh tải lên" under the `FileStorage` + `MediaUrlResolver` port (purpose table, JPEG only, EXIF rule, `customMetadata.purpose`, what a self-hosted `FileStorage` must enforce); `shared-components.md` section and lookup row for `ImagePurpose` / `MediaUploader.upload(purpose:)`; cost spec §11 row "Ảnh trước #147"; main spec §2 S10.01 status "khớp mock, ảnh nén theo mục đích (#147)".

## Decisions of the plan
1. One purpose per upload, chosen by the call site, required by the type system (`purpose:` has no default, so a new call site cannot forget it).
2. Purposes and limits (`maxBytes` = the Storage rule limit, with headroom over the expected size):

   | `ImagePurpose` | code | long side | JPEG q | expected | `maxBytes` | Cache-Control |
   |---|---|---|---|---|---|---|
   | `avatar` | `avatar` | 512 | 80 | ~60 KB | 512 KiB | `public, max-age=31536000` |
   | `chat` | `chat` | 1280 | 75 | ~150 KB | 1.5 MiB | `private, max-age=31536000` |
   | `share` | `share` | 1600 | 80 | ~300 KB | 2 MiB | `public, max-age=31536000` |
   | `deliverySample` | `delivery_sample` | 1600 | 75 | ~250 KB | 2 MiB | `private, max-age=31536000` |
   | `portfolio` | `portfolio` | 2048 | 82 | ~500 KB | 3 MiB | `public, max-age=31536000` |
   | `document` | `document` | 2048 | 85 | ~600 KB | 3 MiB | `private, max-age=31536000` |

   File names never change content (a new name per upload), so a one-year cache is safe; `private` keeps chat, samples and documents out of shared caches.
3. Always JPEG: universal decode (Android, iOS, web, the watermark Function's `sharp`), one content type for rules. WebP would save ~25% more but needs per-platform encoder support and the server pipeline; revisit with thumbnails.
4. EXIF removal is guaranteed in Dart, not trusted to the plugin: the encoder is called with `keepExif: false` and `autoCorrectionAngle: true` (orientation baked into pixels), then `stripJpegMetadata` drops APP1 (Exif, XMP), APP3–APP15, COM and APP2 unless it is an ICC profile; APP0 (JFIF) and the ICC profile stay.
5. Scaling uses one symmetric bound: the plugin scales by `max(1, min(w / minWidth, h / minHeight))`, so `minWidth = minHeight = round(short × longSide / long)` makes the long side exactly `longSide` whatever the EXIF rotation, and never upscales. **Verified in Task 2 in the pinned plugin version's sources** (Android `calcScale`, iOS `scaleWithMinWidth`); the fit loop re-checks the real output anyway.
6. Fit loop (`encodeForPurpose`, pure, injected encoder): encode → strip → read size; long side > 2% over `longSide` → shrink the bound proportionally and retry; bytes > `maxBytes` → quality −8 (floor 60) and retry; at most 4 encodes, then `ImageCompressException(ImageCompressError.tooLarge)`. A decoder failure is `ImageCompressError.unreadable`.
7. Picker pre-pass 2048 px q95 (was q85): bounded decode memory, near-lossless second encode for the 2048 purposes; the compressor reads the pre-pass size with `ui.ImageDescriptor` (header only).
8. Upload path vs rules audit (2026-10-07): avatar `avatars/{uid}/{ulid}.jpg` → `avatar`; S10.01 `posts/{uid}/{draftId}/{key}.jpg` → `portfolio`; S05.05 `real_shoot` and S11.05 `event_share` under `posts/…` → `share`; S12.01 cover `eventCovers/{uid}/{eventId}/{ulid}.jpg` → `share`; awards `awardProofs/{uid}/{awardId}/{ulid}.jpg` → `document`; S07.01 chat `chats/{chatId}/{uid}/{clientId}` → `chat` (the extension lied: `.webp` with JPEG bytes, now `.jpg`); S11.06 `chats/event_{eventId}/{uid}/{clientId}.jpg` → `chat`; `users/{uid}/**` had no writer and is closed. `posts/` holds both portfolio and share, so its limit is the larger (3 MiB).
9. Image size travels with the upload (`UploadedMedia.width/height/sizeBytes`).
10. S10.01 mock parity: mock fixed (tab-root bar without back arrow, "n / 10 ảnh" line); app uses the tab-root title style; square tiles accepted by `portfolio-awards.md`; the remaining fields already matched.
11. Delivery samples (#130) are compressed on the phone too (`deliverySample`), then watermarked by the Function at the same 1600 px; identity documents (#135) use `document`.

## Owner answers
1. JPEG everywhere (no WebP for public images for now; reconsider with upload-time thumbnails).
2. Keep the ICC colour profile (Display P3 photos from iPhones look right) while stripping EXIF/XMP.

## Rulings
1. Task 2 may run `flutter pub add flutter_image_compress` / `flutter pub get` outside the sandbox (pub.dev + storage.googleapis.com), committing `pubspec.yaml` and `pubspec.lock` — cost if wrong: none (normal dependency add the plan prescribes).
2. Strip across every scan and drop data after EOI (stronger than the plan's parse boundary) — Decision 4 claims a Dart-side guarantee — cost if wrong: a little more parsing code.
3. The deploy note is corrected here and in the PR — old builds already send `image/jpeg`; the real regression is size: avatars > 512 KiB (most 2048px q85 photos), chats > 1.5 MiB, covers > 2 MiB from older builds are refused; deploy `storage.rules` (manual) only after testers run a #147 build — cost if wrong: avatar changes fail for testers on old builds.

## Task 2 notes
- `FirebaseMediaUploader` is no longer the URL resolver: `FirebaseMediaUrlResolver` (same file) implements `MediaUrlResolver`, and `mediaUrlResolverProvider` returns it. The uploader needs a compressor, the resolver does not.
- Decision 5 scaling formula checked in the plugin sources (Android `calcScale`, iOS `scaleWithMinWidth`): the symmetric bound is correct.

## Deploy order and what was run
- **Rules tests were run locally this time** (`app_flutter/firebase/rules-test`, emulator): 172/172 passed. CI also runs them on push.
- **Deploy order:** ship the app first, then deploy `storage.rules` by hand with `npm run deploy:storage:dev|prod` (from `app_flutter/firebase/rules-test/`; Storage deploys only manually, never from CI on push). Do it only after testers run a #147 build. Older builds already send `image/jpeg`, so a type change is not the risk; the risk is size: avatars > 512 KiB (most 2048 px q85 photos), chats > 1.5 MiB and covers > 2 MiB from older builds are refused after the deploy.
- **No device build** (Android Gradle needs Maven, blocked in the sandbox). Run `flutter build apk --debug` once on the owner's machine and upload one photo with GPS per purpose on the emulator (`../scripts/backend-local.sh`, then `flutter run --dart-define=USE_EMULATORS=true …`), then check in the Storage emulator UI (:4000) that the object has no Exif and the expected size and `purpose` metadata. The native encoder never runs in `flutter test`, so the real pixels (orientation 6 portraits, long side exactly the purpose's) and the ~650 KB "before" estimate are device-only checks.
- No Cloud Function and no Storage trigger were added (dev project on Spark; server-side limits are Storage rules only).

## Hand-off for other units
- **#131 (chat):** `MediaUploader.upload(image, storagePath: 'chats/$chatId/$uid/$clientId.jpg', purpose: ImagePurpose.chat)`; the `.webp` → `.jpg` rename is already done here (its plan's Decision 7 finds it done and skips that edit). Chat image display from download URLs and retry (`chat_screen.dart`, `chat_controller.dart`) remain #131's.
- **#130 (delivery samples):** `ImagePurpose.deliverySample`; the path and its rule line are #130's and must use `jpegUpTo(2 * 1024 * 1024)`; add the path to the sync test's table. The watermark Function does not need to resize (1600 px already).
- **#135 (identity documents):** `ImagePurpose.document`, rule `jpegUpTo(3 * 1024 * 1024)`, path owned by #135 (private); add it to the sync test's table.
- **S15/S16 job references:** `jobRefs/{uid}/{draftId}/{ulid}.jpg`, `ImagePurpose.share`, `jpegUpTo(2 * 1024 * 1024)`. **S18 dispute evidence:** `ImagePurpose.document`, `jpegUpTo(3 * 1024 * 1024)` instead of its planned `image/(jpeg|png|webp|heic|heif)`. Whichever unit lands later rebases onto `jpegUpTo` in `storage.rules` (see the comment above the function) and ledgers the merge.

## Cost (Google)
Before: 2048 px q85 ≈ 650 KB for every purpose (estimate, confirm on a device). After: avatar 60 KB, chat 150 KB, share/cover 300 KB, portfolio 500 KB, document 600 KB. Assumed view mix of 600 views/MAU/month: 390 MB → 172 MB per MAU, i.e. **−$26/month at (b) 1,000 MAU, −$262/month at (c) 10,000 MAU** (egress $0.12/GB is an unconfirmed assumption; if the Firebase 100 GB/month free download applies, (b) shrinks to about −$14). Storage at rest −$0.04/month at (b). No Firestore read/write and no Functions work added. Thumbnails would add another −$12 (b) / −$116 (c) per month (Deferred).

## Needs the owner
None open (both questions answered above).

## Review notes
From the SDD progress ledger (`.superpowers/sdd/2026-10-07-s10-post-upload/progress-plan-147-s10-dang-bai-anh-tai-len.md`):
- Pre-flight scan: T1 → T2, T2 → T3, T1 → T4 ok; T5 independent; T2 needs `flutter pub add flutter_image_compress` (Ruling 1).
- Task 1: review 1 (e8b4617) approved with Important plan-mandated (metadata after the first SOS or after EOI not stripped); fix round 1 (Ruling 2); complete (b848dfa..0ce9b11, review clean).
- Task 1: minor (deferred): denylist vs allowlist of segments; standalone markers before SOS; tooLarge code after overshoot retries; DHT-before-SOF fixture; duplicated marker walk
- Task 1: minor (deferred): isIcc may misclassify an APP2 shorter than 14 bytes
- Task 2: complete (0ce9b11..7c1bcc8, review approved).
- Task 2: minor (deferred): temp-file write error untyped; put uses purpose.cacheControl not meta.cacheControl; task.cancel() future discarded; no test for cancel during compression; chat repo builds its own NativeImageCompressor; stale fake comments
- Task 3: complete (7c1bcc8..a06c965, review approved).
- Task 3: minor (deferred): imageMeta w/h at the Firestore publisher level not pinned by this task's tests
- Task 4: complete (a06c965..2cfda91, review approved; Important was documentation only).
- Task 4: minor (deferred, FINAL TRIAGE): sync test should assert every create block uses jpegUpTo; chats create lacks resource == null
- Task 4: minor (deferred): awardProofs read/delete inline auth vs isOwner; client-declared contentType; no per-owner file-count cap (pre-existing)
- Task 5: review 1 (98db0a6): Important — photographer.md S10.01 still listed the old portfolio toggle; fix round 1 (98db0a6..a469fa2); complete (2cfda91..a469fa2, review clean).

## Not run
- No device build, no emulator walkthrough with a real photo, no iOS step (see "Deploy order and what was run"). Rules tests were run (172/172); the native encoder is covered only through the injected-encoder tests.

## Deferred
- Upload-time thumbnails (~400 px, ~35 KB) for grids and feeds, with `thumbUrls` on posts: the largest remaining egress lever (−$12 (b) / −$116 (c) per month); needs a post schema change and every grid to read thumbnails. Own unit.
- WebP output (owner question 1; answered JPEG for now).
- Server-side verification of pixel dimensions or a Storage trigger that re-encodes uploads: needs Blaze and Functions on Storage events; rules size and type limits are the server guard for now.
- Chat image display from download URLs and image retry (`chat_screen.dart`, `chat_controller.dart`): #131.
- Delivery samples path, rule and watermark Function: #130. Identity document upload and its private path: #135.
- Video in posts (`PostMedia`): out of scope.
- Minors, verbatim from the review notes above: Task 1 (denylist vs allowlist of segments; standalone markers before SOS; tooLarge code after overshoot retries; DHT-before-SOF fixture; duplicated marker walk; isIcc may misclassify an APP2 shorter than 14 bytes); Task 2 (temp-file write error untyped; put uses purpose.cacheControl not meta.cacheControl; task.cancel() future discarded; no test for cancel during compression; chat repo builds its own NativeImageCompressor; stale fake comments); Task 3 (imageMeta w/h at the Firestore publisher level not pinned by this task's tests); Task 4 FINAL TRIAGE (sync test should assert every create block uses jpegUpTo; chats create lacks resource == null; awardProofs read/delete inline auth vs isOwner; client-declared contentType; no per-owner file-count cap, pre-existing).
