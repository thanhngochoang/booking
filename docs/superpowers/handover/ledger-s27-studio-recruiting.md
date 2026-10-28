# Sổ bàn giao — S27 Studio tuyển thợ và cộng tác viên (#151)

- **Issue:** [#151](https://github.com/thanhngochoang/booking/issues/151) · **Plan:** [`../plans/2026-10-07-s27-studio-recruiting.md`](../plans/2026-10-07-s27-studio-recruiting.md) · **Spec:** [`../specs/2026-10-07-studio-recruiting-design.md`](../specs/2026-10-07-studio-recruiting-design.md) · **Màn:** [`../specs/screens/recruit.md`](../specs/screens/recruit.md).
- **Nhánh:** `plan/151-s27-studio-recruiting`, từ `origin/develop` 020b8801 (đã có #136 S26, #135 xác minh, #198 cổng đơn, #130 cà chua/gạch, #138 thông báo, #140 Chụp ngay, thanh toán V1 #200). PR vào `develop`.
- Task 1 của plan (khung mock S27, `ScreenCodes` S27.01–S27.07, dòng §2 của spec chính) đã có trên develop qua PR #187 (`9d1b7f43`); unit này là Tasks 2–10.

## Đã làm

| Task | Commit | Kết quả |
|---|---|---|
| 2 Miền: tin, ứng tuyển, khu vực, fan-out | 9b7ea180 | `recruit_areas.ts`, `recruit.ts`, `recruit_ports.ts`, `memory_recruit_store.ts`, `recruit_use_cases.ts`, `recruit_notify.ts`; mã lỗi `collab_full`, `recruit_blocked` (+ `TRANSPORT_CODE`). |
| 3 Miền: cộng tác, nhận làm thành viên, chat cộng tác | cfe7d4ea, be8b809a | `studio_collaboration.ts`, `collab_use_cases.ts`, `open_collab_chat.ts`; `checkMemberActivation` tách khỏi `respondJoinRequest` (S26, hành vi không đổi); `CHAT_KINDS` thêm `collab`. |
| 4 Miền: offer trên booking studio, bản ghi trả tiền, job, tín hiệu chào khách | 83e50e36, 127317b6, c3cefe8e | `collab_jobs.ts`, `collab_offers.ts`, `recruit_sweeps.ts`, `recruit_shared.ts`, `studio_booking_window.ts`; `assignBooking` nhận `assigneeKind: 'collaborator'` + `agreedFee`; `confirmedAssigneeId`. Một vòng sửa (2 Important). |
| 5 Functions, rules, chỉ mục, seed | 9a9ea34c, dc96db37, c75298f5 | 16 callable, `onRecruitPostCreated`, `onPhotographerWrite`/`onUserWrite` giữ `recruitMatchKeys`, `onBookingWrite` (đồng bộ job, cờ chào khách), bước `recruit` trong `bookingClock`; rules + test rules (viết, chưa chạy); chỉ mục; seed. S26 từ chối CTV đang `active` của cùng studio. |
| 6 Dữ liệu app | 1fd3e943, 34adead4 | `lib/data/recruit/*`, `lib/data/collab/*`, `ChatKind.collab`, `AppIcons.handshake`/`campaign`, hình thông báo; S06.01 lọc `assignStatus == 'assigned'`; rules: CTV chờ nhận không đọc booking. |
| 7 S27.01–S27.03, S03.01, đoạn S06.01 | b9d30c05, 8c39e234 | `features/recruit/` danh sách, chi tiết, sheet ứng tuyển, `CollabTermsCard`; `SegmentedTabs` "Hôm nay" / "Tuyển thợ" ở S06.01; dòng "Đang tuyển" ở S03.01. |
| 8 S27.04–S27.05 | c9211bb3, 182e47f4, 989f0374 | Form đăng/sửa tin, tin của studio và ứng viên, `StudioRecruitGate`, route `/studio/recruit…`. Một vòng sửa (1 Important). |
| 9 S27.06–S27.07 và các màn S26/S05/S06/S09/chat | 2ebf2fad, 8922f693 | `features/collab/`, sheet mời CTV (S26.02-collab), giao CTV (S26.04-collab), `StudioOfferLine`, nhãn CTV ở S05.02/S06.01, dòng S09.02, chat cộng tác, liên kết sâu giữ query khi mở app nguội. Một vòng sửa (1 Important). |
| 10 Tài liệu | (commit này) | Spec S27 (§3.2, §5, §5.1, §6, §7, §9), `data-model/domain-model.md` §2.14 + enum + máy trạng thái + bất biến 42–48, `relational-schema.md` §2.13 + ánh xạ, `shared-components.md`, spec chính §2 (link #151) và §3h.2 (biểu tượng, tông, khoá chống trùng), `screens/recruit.md`, sổ này, sửa chữ plan. |

## Tên thật của S26 và các plan khác mà S27 dùng (Task 2 Step 1, đổi tên)

| Tên trong plan | Tên thật trên 020b8801 |
|---|---|
| `DomainError(code, field?)` | có, `errors.ts` (`field`, thêm `details`) |
| `ERROR_CODES` | `errors.ts`; đã có `rate_limited`, `membership_conflict`, `cooldown`, `member_busy`, `studio_full`, `blocked`, `contact_leak`; **thêm** `collab_full`, `recruit_blocked` |
| `findContactLeak` | `contact_filter.ts` (#139 đã đưa lên develop) — dùng, không tạo lại |
| `vnDayKey` | `verification.ts` (#135) — dùng, không có `vn_day.ts` |
| `ProviderOrderGate` | `booking_ports.ts` (`acceptsOrders`, `orderProfile`) |
| `ProviderType`, `providerTypeOf` | `provider_type.ts` |
| `isId`, `newUlid` / `Clock`, `IdGenerator` | `ids.ts` / `ports.ts` |
| `BlockGate.isBlockedEitherWay` | `block_ports.ts`; `FakeBlockGate` |
| `NotifyDeps`, `notify` | `notification_ports.ts`, `notification_use_cases.ts`; lỗi sau commit qua `onPushError` |
| 10 hook S27 của #138 | đủ trong `notification_hooks.ts`; `recruit_application_new` có nội dung `{names, title, count}` (không phải `name`) |
| danh sách khu vực / thể loại | không có trong domain → tạo `RECRUIT_AREAS` (`recruit_areas.ts`, 12 mã như `builtInAreas`) và `RECRUIT_SPECIALTIES` (`recruit.ts`, 14 mã của `kSpecialties`); test Dart giữ hai danh sách bằng nhau |
| `checkMemberActivation(state, now)` | **không có** (kiểm trong `respondJoinRequest`) → tách ra `studio_membership.ts` ở Task 3, hành vi giữ nguyên |
| bản ghi thành viên S26 | `StudioRelation` (`studio_members/{studioId}_{memberId}_{ms}`, `initiatedBy: studio \| member`), khoá thành viên `photographers/{uid}.studioId`, quota `studio_quota/{uid}` |
| "AssignTx" | `StudioBookingTx` (giao dịch của `BookingStore`, `booking_ports.ts`); thêm `getCollaboration`, `getCollabJob`, `getRecruitCounters`, `putCollabJob` |
| `assignBooking` | `studio_assignment.ts` `assignBooking(deps: StudioBookingDeps, …)`; không tự gửi thông báo: `booking_assigned` và thành viên chat đến từ ghi booking (`onBookingWrite` → `notifyStudioBookingChange`, `syncBookingChat`) |
| `AssigneeKind` | `studio_ports.ts`, nay `'member' \| 'collaborator'` |
| job 15 phút của S26 | `bookingClock` (Functions) → `runStudioBookingSweeps`, `runMembershipSweeps`; S27 thêm bước `recruit` (`runRecruitSweeps`) **trước** các bước studio |
| liên hệ cho thợ được giao | không có nhánh trong `getContactLink` (S26 §5.7); thợ được giao đọc liên hệ khách qua rules |
| milestone `shotReleased` | `shootMilestone(bookingId): 'released' \| 'waiting' \| 'refunded'` (thuần: `shootMilestoneState(payments)`) |
| `takeDaily`, `isValidFee`, `Daily`, `NoticeDaily` | `takeRecruitDaily`, `isValidRecruitFee`, `RecruitDaily`, `RecruitNoticeDaily` |
| `AppIcons.eventRepeat` | không thêm; dùng `AppIcons.calendarRepeat` (cùng glyph) |
| `PayMethod` (app) | `CollabPayMethod` (`PayMethod` đã có ở thanh toán) |
| `vnd_input.dart` (widget) | là formatter `VndInputFormatter`, `parseVnd`, `groupVnd` |

## Quyết định của plan (Decisions 1–26, như đã làm)

1. Mã màn và route: S27.01 `/recruit` (+ đoạn S06.01), S27.02 `/recruit/:postId`, S27.03 sheet, S27.04 `/studio/recruit/new` và `/studio/recruit/:postId/edit`, S27.05 `/studio/recruit?post=`, S27.06 `/collab?offer=`, S27.07 sheet. Đúng như plan.
2. Tài khoản nhà cung cấp (R3) = `role == photographer` và có `photographers/{uid}`; rules `isProviderAccount()`, app `ProviderFacts.isProviderAccount`. Đúng.
3. Thù lao, offer và bản ghi trả tiền ở `collab_jobs/{bookingId}_{uid}`, không trên booking. Đúng; spec §5/§5.1 đã sửa theo.
4. `studio_collaborations/{studioId}_{uid}` + `history/{ulid}`. Đúng.
5. Bộ đếm `photographers/{uid}/private/recruit`, ngày VN, thao tác tính như plan. Đúng; `notices` mang thêm `postIds` (chạy lại fan-out không đếm hai lần).
6. Khu vực theo tâm + bán kính, không có tâm thì theo tên thành phố (bí danh `recruitCityOf`). Đúng.
7. `recruitMatchKeys`, `matchKeys`, `filterKeys`; trang 20, xếp theo điểm khớp phía máy. Đúng.
8. Fan-out ≤ 200 người, 3 thông báo mỗi thợ mỗi ngày VN, sửa/gia hạn không gửi lại. Đúng.
9. Đóng tin từ chối ứng viên đang chờ, hết hạn thì `expired`; trang 200. Đúng; lỗi giữa chừng không dừng loạt (báo `onPushError`).
10. Mã lỗi: thêm `collab_full`, `recruit_blocked`; dùng lại mã S26. Đúng.
11. Bộ lọc liên hệ của #139 (`findContactLeak`), trường `title.contact`, `requirements.contact`, `message.contact`. Đúng.
12. Ai cộng tác; thành viên của studio không làm CTV của chính studio đó và ngược lại. Đúng, cả hai chiều (S27 và S26, Task 5).
13. Offer 6 giờ, không quá `assignDeadline`/giờ bắt đầu, < 15 phút → `deadline_passed`; khoá lịch khi nhận. Đúng; thêm luật thay thợ đã nhận (phán quyết Task 4).
14. Trả việc → `returned`, không có bản ghi trả tiền. Đúng.
15. Bản ghi trả tiền, cờ, khoá 30 ngày. Đúng với port `shootMilestone` và con trỏ `pay.checkAfter`.
16. Chat `collab_{studioId}_{uid}`, chỉ đọc sau khi kết thúc, mở lại thì xoá `readOnlyAt`. Đúng (xoá lười trong `openCollabChat` và sau commit ở callable).
17. Đánh giá: thợ cuối (cả CTV) nhận đánh giá thợ kèm tag "Qua {Studio}". Đúng, có test hồi quy.
18. Tín hiệu chào khách `staff_flags/poach_{p}_{c}`, chỉ ghi. Đúng; đếm cả booking nháp.
19. CSV trên máy, chép vào bộ nhớ tạm. Đúng; thêm chặn công thức (`'` trước `=`, `+`, `-`, `@`).
20. Đoạn "Tuyển thợ" cuối `SegmentedTabs` S06.01; S06.01 chưa có đoạn nên tạo "Hôm nay" + "Tuyển thợ". Đúng.
21. Nhận làm thành viên trong giao dịch tuyển (`getMemberState`, `checkMemberActivation`, `putMember`), gửi `studio_join_approved` + `recruit_application_result`. Đúng.
22. Sửa chỉ khi `open`, loại cố định, gia hạn một lần, ảnh chụp studio khi tạo/sửa/gia hạn. Đúng.
23. Rút chỉ khi `applied`, không hoàn lượt, mỗi tin một ứng tuyển mãi mãi. Đúng.
24. Thông báo qua hook của #138; S27 không thêm chữ. Đúng, trừ một kết quả mới `ended` của `collab_assignment_result` (phán quyết Task 4).
25. Nhắc thuế ≥ 5.000.000₫, ẩn được, nhớ `collabTaxNoticeSeen:<uid>`. Đúng.
26. CTV không thêm sức chứa studio; booking chuyển `unassignedIds` → `assignedIds` khi CTV nhận. Đúng.

## Phán quyết khi làm (từ sổ task)

- **Task 2:** `collab_full`/`recruit_blocked` và ánh xạ `TRANSPORT_CODE` thêm ngay ở Task 2 (`Record<ErrorCode>` không biên dịch nếu thiếu). Bộ đếm `notices` mang `postIds` (fan-out chạy lại an toàn). `isRecruitBlocked` và `STUDIO_COLLAB_DAILY_ACTIONS` ở `recruit.ts` (Task 3–4 import, không định nghĩa lại). `expireRecruitApplication`/`expireRecruitPost` xuất cho job của Task 4.
- **Task 3:** `checkMemberActivation` tách khỏi `respondJoinRequest`, hành vi giữ nguyên. Nhận làm thành viên bị từ chối `conflict` khi cặp còn lời mời/yêu cầu S26 đang mở. Nhận làm thành viên tốn cả một thao tác cộng tác S27 và quota studio của S26. Mời bị từ chối `collab_full` khi studio đã đủ CTV `active`. `openCollabChat` không có quan hệ → `not_eligible`. Studio đang bị khoá không nhận ứng viên tin cộng tác của tin đang chạy (Decision 15 chỉ nói tin đang chạy vẫn chạy).
- **Task 4:** không có nhánh CTV trong `getContactLink`: khách luôn liên hệ studio (S26 §5.7); R8 là quyền của CTV đọc liên hệ khách (`collaboratorContactOpen`, rules của Task 5). "Đang khiếu nại" = `payStatus 'disputed'` (job `disputed` chặn kết thúc cộng tác). Offer thay thợ của booking `upcoming` đưa booking về `accepted`. Offer chồng lên thợ đã nhận được phép và có báo (thợ cũ ngay, khách `reassigned` khi CTV nhận, kèm `late_reassign` nếu trễ). Khoá chống trùng của #138 thêm `offerAt` / `reportedAt` / `disputedAt` để lần lặp vẫn được gửi.
- **Task 4 (vòng sửa 1):** thêm chữ #138 cho kết quả `ended` của `collab_assignment_result` ("Cộng tác với {name} đã kết thúc") — mở rộng danh mục của #138, chấp nhận. Port mốc là `shootMilestone('released'|'waiting'|'refunded')`; con trỏ `payPending` là `pay.checkAfter`.
- **Task 5:** bước tuyển thợ chạy trước các bước studio trong `bookingClock`. `readOnlyAt` mở lại bằng đọc lại sau commit (chỉ khi `active`). Chỉ mục `payPending` trên `pay.checkAfter` + 2 chỉ mục cho truy vấn adapter. `onUserWrite` đồng bộ lại `recruitMatchKeys` khi đổi vai trò. Tách `recruit_mapping.ts`. Tín hiệu chào khách đếm cả booking nháp (booking mới là nháp lúc tạo) — chỉ ghi nhận, chỉnh nếu ồn.
- **Task 6:** truy vấn việc được giao ở S06.01 thêm `assignStatus == 'assigned'` (thành viên luôn `assigned`; chỉ offer CTV mới ở `unassigned` có `assigneeId`; không cần chỉ mục mới). Rules từ chối truy vấn `bookings` chỉ theo `assigneeId`, và CTV chờ nhận không đọc booking hay sự kiện của nó. Không thêm `AppIcons.eventRepeat` (dùng `calendarRepeat`). Thêm `RecruitErrorCode.blocked`. `watchMyApplication` là truy vấn (nghe tài liệu chưa có bị rules từ chối). Thông báo `collab_pay_*` giữ biểu tượng `payment`. Tài khoản seed mới Hòa (`seed-photographer-hoa`).
- **Task 7:** tạo `SegmentedTabs` "Hôm nay" + "Tuyển thợ" ở S06.01 (Decision 20; #139 chèn hai đoạn giữa → xung đột dự kiến ở `work_screen.dart` khi gộp). `ProviderFacts.acceptingOrders` là "đã xác minh" (cổng máy chủ `acceptsOrders = verified && onboardingComplete`; thợ đã xác minh mà chưa xong hồ sơ được đưa tới `/verify/start`). Thêm `ProviderFacts.studioId`. 8 khoá arb ngoài bảng plan. Lỗi ứng tuyển hiện trong sheet. `AppChip.trailing` và `PostPickerGrid.crossAxisCount` là thêm tham số. Lọc theo một studio thì ẩn chip. Ứng tuyển đã rút/hết hạn đọc "Bạn đã ứng tuyển tin này." (một ứng tuyển mỗi tin).
- **Task 8:** từ chối ứng viên = sheet xác nhận nút đỏ "Từ chối", không có ô lý do (callable không mang lý do). Thêm `AppChip.enabled`. 14 khoá arb ngoài bảng plan (trạng thái riêng). Router chỉ kiểm vai trò; `StudioRecruitGate` đưa người không phải studio đi trước mọi lần đọc (chỉ còn tiêu đề trên loader). Ô số tiền S27.04 xếp dưới hàng chọn (320dp × 1,3). Danh sách tuyển ở S06.01 giữ 2 phút cho mỗi bộ lọc.
- **Task 8 (vòng sửa 1):** `ProviderMark` giữ cỡ mặc định 14 (`AppIconSize.sm` 20 quá to cạnh chữ 12–13,5).
- **Task 9:** "Từ chối" ở S27.07 qua sheet xác nhận nút đỏ (quy tắc CLAUDE.md; chú thích mock không nói từ chối ngay). "Từ chối" lời mời ở S27.06-me và "Huỷ" lời mời phía studio vẫn ngay (chú thích mock + tiền lệ S26). Hàng CTV ở S26.04 không có rảnh/bận (`assignmentOptions` chỉ trả thành viên; máy chủ từ chối `day_taken`) — hiện % cà chua + thù lao. "Việc đang giao" đếm ở máy; kết thúc dựa vào `member_busy` của máy chủ. `assign(…, {collaborator, agreedFee})` + `assignBookingPayload`. `CollabRepository.pairsOf` cho hàng "Mời lại được từ". Badge chữ in hoa. Chip ngày ở sheet "Đã trả". Sửa lỗi có sẵn: liên kết sâu lúc mở app nguội mất query trong `router.dart` (`from = state.uri`); `from` vẫn chỉ là location go_router trong app.
- **Task 10:** ô trạng thái S27 ở spec chính §2 chỉ là link [#151](https://github.com/thanhngochoang/booking/issues/151) (quy tắc chủ dự án "Issue status = links" thắng chữ plan "✅ đã làm (#151) · khớp mock"). Biểu tượng của `collab_invite*` và `collab_assignment_*` ở §3h.2 sửa theo bản làm (`handshake`, tông theo kết quả). Không có analytics riêng cho S27 (mục "Phân tích" của màn ghi "—"). `screens/README.md` thêm dòng mục lục cho `recruit.md`.

## Ghi chú chuyển giữa các task (đã xử lý)

- **Task 3 → Task 5:** `inviteMember`/`requestToJoin`/`respondInvite`/`respondJoinRequest` của S26 phải từ chối CTV đang `active` của cùng studio (Decision 12, chiều S26) — cần `StudioTx.activeCollaborationOf`. **Đã làm** ở Task 5 (9a9ea34c).
- **Task 4 → Task 5:** `bookingFromFirestore` và writer giữ `assigneeKind: 'collaborator'`, `assigneeAccepted`, các trường của phần tử giao (`offerExpiresAt`, `acceptedAt`, `declinedAt`); rules `isAssignee` cho liên hệ yêu cầu `assigneeAccepted == true` và theo `collaboratorContactOpen`; `runRecruitSweeps` trước `runStudioBookingSweeps`; `staff_flags/poach_{p}_{c}` tạo nếu chưa có; `notify` trên `liveStudioBookingDeps`; chỉ mục `payPending`. **Đã làm** ở Task 5.
- **Task 5 → Task 6/9:** S06.01 liệt kê theo `assigneeId == uid` phải bỏ offer CTV đang chờ; offer chỉ hiện ở S27.06/S27.07. **Đã làm** ở Task 6 (`assignStatus == 'assigned'`). Test rules viết, chưa chạy (CI).
- **Task 6 → Task 9:** `ChatContextCard` (`lib/features/chat/widgets/context_card.dart`) phải xử lý `ChatKind.collab` (trước đó rơi vào thẻ hỏi trước và hiện gói của CTV cho studio). **Đã làm** ở Task 9.
- **Task 7 → Task 8:** `/studio/recruit` chưa đăng ký (`RecruitStudioPostsAction` đẩy tới) — Task 8 đăng ký. **Đã làm**.
- **Minor chuyển task sau (đã sửa ở commit đầu của task sau):** Task 2 → 3 (lỗi loạt sau commit, test đồng thời, đổi tên export, ảnh chụp studio khi sửa/gia hạn) cfe7d4ea; Task 3 → 4 (đọc ngoài giao dịch đưa ra trước, kiểm lại hai bên khi nhận làm thành viên, module dùng chung, test đua) 83e50e36; Task 5 → 6 (JSDoc seed, ứng viên seed không là thành viên, rules CTV chờ nhận, bỏ đọc vai trò khi khoá khớp không đổi, `collaborationId()`, test chỉ mục so thứ tự) 1fd3e943; Task 6 → 7 (chặn công thức CSV, `==` đủ trường, hàm parse dùng chung, RegExp một lần, chú thích rules cũ) b9d30c05; Task 7 → 8 (độ dài theo rune, `recruitAgo` đúng tham số, token, giữ bộ lọc, ẩn tin quá hạn) c9211bb3.

## Câu hỏi cho chủ dự án (đang theo mặc định)

1. Tạm khoá sau 3 cờ không trả trong 90 ngày kéo dài bao lâu? **Mặc định 30 ngày**; staff gỡ sớm trên console (plan, Needs the owner 1).
2. Thợ chưa có tâm bản đồ khớp khu vực theo tên thành phố (TP.HCM → mọi quận HCM)? **Mặc định có**, tới khi phần vị trí lưu tâm (Needs the owner 2).
3. CTV muốn vào làm thành viên cùng studio phải kết thúc cộng tác trước? **Mặc định có** (từ chối với lời rõ ràng); phương án khác: tự kết thúc khi không còn việc mở (Needs the owner 3).
4. Giới hạn 200 người nhận mỗi tin lấy một tập bất kỳ khi khớp nhiều hơn? **Mặc định chấp nhận ở phase 1**; xếp theo độ đầy đủ hồ sơ sau (Needs the owner 4).
5. (Task 4) Booking **bị huỷ** vẫn để CTV đọc liên hệ khách 7 ngày (đọc đúng chữ R8 "xong/huỷ được 7 ngày"), trong khi studio/thành viên mất ngay. Có khoá ngay lúc huỷ không? **Đang làm theo chữ R8** (mở 7 ngày).
6. (Task 4) Khách có được gọi thẳng CTV không? Hiện liên hệ trên booking studio luôn mở kênh của studio (S26 §5.7, không có nút trong mock); muốn khác cần quyết định mới, khoá yêu cầu (ví dụ `assigneeId`) và nút trong mock.
7. (Task 7) "Đã xác minh" đang đọc là `acceptingOrders` (đã xác minh và xong hồ sơ). Muốn chữ riêng cho "chưa xác minh" thì cần thêm `verified` vào `ProviderFacts`.
8. Pháp lý (spec §11, không chặn làm): mẫu điều khoản cộng tác và cam kết 6 tháng; tin tuyển miễn phí có là "dịch vụ việc làm" không; cập nhật mục khấu trừ thuế (kế toán).

## Ứng viên cho đợt sửa cuối (final wave)

- (Task 4) Thành viên được giao lại sau khi một offer đã thay họ nhận `assigned` với khoá không có ngày (bị chống trùng) → không được báo booking lại là của mình. **Đã sửa** ở đợt sửa cuối (S1, 682253ea).
- (Task 4) `shootMilestone` `refunded` tính trên mọi khoản thanh toán (một khoản hoàn + một khoản sau chưa chia thì kết thúc kiểm tra trả tiền). **Đã sửa** (S3, 682253ea).
- (Task 4) Bộ đọc mốc ném lỗi liên tục thì không đẩy `checkAfter` (hơn 200 job như vậy chặn trang). Giữ hoãn.
- (Task 4) Job chờ mốc mãi được kiểm lại mỗi 6 giờ không giới hạn. Giữ hoãn.
- (Task 9) Đưa CTV kèm trạng thái ngày vào `assignmentOptions` của máy chủ (mock S26.04-collab "Rảnh · 95%"). Giữ hoãn.
- (Task 9) `router.dart` `Uri.parse(from)` ném lỗi với `from` hỏng (ví dụ `/splash?from=::`) ngay trong redirect cấp cao → `Uri.tryParse`. **Đã sửa** (A2, df401f41: `from` hỏng về trang chủ).
- (Task 9) Thứ tự import của `assign_sheet_test.dart`. **Đã sửa** (A6, df401f41).
- (Task 9) Các token `*Subtle` của `AppColorsDark` là bí danh của giá trị sáng (nền badge không đổi ở chế độ tối). Giữ hoãn (sửa ở mức token, ngoài phạm vi S27).

## Minor hoãn (chưa sửa)

- (Task 2) Fan-out chạy lại vào một ngày VN sau tốn một suất của giới hạn ngày (hook đã chống gửi trùng).
- (Task 2) Ứng tuyển còn sót sau khi đóng tin dở dang kết thúc `expired` tới 7 ngày sau thay vì `declined` (không có lượt sửa bù).
- (Task 4) Nhắc giao thợ 48 giờ / 26 giờ của S26 vẫn chạy khi offer CTV đang chờ (`assignStatus` vẫn `unassigned`) — vô hại nhưng có thể ồn.
- (Task 6) Khoá khớp không được kiểm lại sau lối tắt "đầu vào không đổi" (đổi `RECRUIT_AREAS`, mất sự kiện đổi vai trò); tông `*_result` cần `variant` mà hộp thư chưa truyền (nay hiện tím; có từ trước).
- (Task 8) `_selected ??= …` ghi trong `build` giữ lựa chọn mặc định (tin vừa tạo không tự được chọn).
- (Task 8) Danh sách tuyển ở S06.01 giữ 2 phút: tin studio vừa đóng còn hiện tới lúc đó (chi tiết đọc lại và báo "Tin đã đóng hoặc hết hạn.").
- (Task 9) "Việc đang giao" ở app là gần đúng (`CollabJob` của app không có `closedAt`); `/collab` lúc mở app nguội khi hồ sơ đang tải đi về trang chủ như S06.04/S08.01; các màn cài đặt, studio, cộng tác nay nghe `studio_collaborations`/`collab_jobs` với nhà cung cấp.
- (Task 5) Seed: An ứng tuyển tin của Cúc khi đang là thành viên của Cúc (ca từ chối `membership_conflict` có chủ đích); Hòa là ứng viên nhận được.

## Chữ chưa có trong mock

Mọi khoá trong `screens/recruit.md` đã so với `app_vi.arb` (254 cặp khoá–chữ, khớp hết; mọi khoá S27 của arb đều có trong tài liệu). So với mock, 44 khoá là trạng thái mock không vẽ (lỗi, toast, sheet phụ, trạng thái trống), lấy từ bảng l10n của plan hoặc là khoá thêm đã ghi ở Task 6–9: `recruitErrorGeneric`, `recruitWithdrawKeep`, `recruitErrorDuplicate`, `recruitSamplesEmpty`, `recruitMessageInvalid`, `recruitSamplesInvalid`, `recruitErrorApplyLimit`, `recruitErrorRateLimited`, `recruitFeeAmountHint`, `recruitSavedToast`, `recruitRequirementsError`, `recruitVerifyToPostNote`, `recruitErrorPostLimit`, `recruitRenewedToast`, `recruitCloseKeep`, `recruitDeclineConfirmBody`, `recruitNoApplicants`, `recruitNoPosts`, `recruitAcceptCollabFull`, `recruitAcceptNotAccepting`, `collabRowOptions`, `collabTaxDismiss`, `collabExportDone`, `collabExportEmpty`, `collabCsvHeader`, `collabStudioEmpty`, `collabPaidDate`, `collabPaidOtherDay`, `collabPaidMethod`, `collabFeeSheetTitle`, `collabFeeHint`, `collabFeeInvalid`, `collabFeeSaved`, `collabErrorFull`, `collabErrorCooldown`, `collabErrorBusy`, `collabErrorConflict`, `collabAcceptedToast`, `collabInviteDeclinedToast`, `collabOfferGone`, `collabDeclineConfirmTitle`, `collabDeclineConfirmBody`, `collabOfferAcceptedState`, `collabErrorDayTaken`. Lệch bố cục so với mock: bộ đếm "0/400" dưới ô (S27.03), lưới bài 5 cột (S27.03), ô số tiền dưới hàng chọn (S27.04), chip ẩn khi lọc theo studio (S27.01), "Từ chối" ở S27.07 qua sheet xác nhận, hàng CTV ở S26.04 không có "Rảnh".

## Bỏ qua theo quy tắc chung

- Test rules Firestore (`app_flutter/firebase/rules-test/rules.test.mjs`, `describe('S27 studio recruiting')`): viết, **không chạy** (sandbox không chạy emulator; CI chạy khi push). Một dòng phụ thuộc emulator: truy vấn `bookings` chỉ theo `assigneeId` phải bị từ chối; nếu emulator khác ý thì bỏ dòng đó.
- Test tích hợp Functions (`npm run test:integration`): không thêm (plan: chỉ unit test với fake trong bộ nhớ).
- Mở mock trong trình duyệt: không làm ở unit này (khung mock thuộc PR #187; `open` bị sandbox chặn).
- Không build trên thiết bị hay simulator; test Flutter, analyzer, unit test domain và Functions chạy ở từng task.
- `services/api` (máy chủ riêng) đã chuyển sang repo `booking-be` (#286): không có gì đồng bộ ở đây; `relational-schema.md` §2.13 là đích.

## Thứ tự deploy và công tắc Blaze

1. **Rules và chỉ mục trước** (chỉ mục `recruitPosts`, `recruitApplications`, `studio_collaborations`, `collab_jobs`; truy vấn `photographers.recruitMatchKeys array-contains-any` dùng chỉ mục một trường tự động; chỉ mục xây có thể mất vài phút), **rồi Functions** (trigger `onRecruitPostCreated` truy vấn `recruitMatchKeys`; bước `recruit` của `bookingClock`), **rồi app**.
2. `BLAZE_ENABLED` đang tắt: Functions không deploy lên dev; chỉ rules và chỉ mục deploy, app chạy trên emulator. Không thêm lịch Cloud Scheduler nào (job tuyển thợ là một bước của `bookingClock`), nên không có gì mới cần đứng sau công tắc.
3. Không cần backfill một lần: `onPhotographerWrite` ghi `recruitMatchKeys` ở lần sửa hồ sơ kế tiếp (và `onUserWrite` khi đổi vai trò); seed tính sẵn khoá. **Khoảng trống đã biết:** thợ không bao giờ sửa hồ sơ thì không nhận `recruit_post_new` cho tới khi sửa (job backfill nằm ở Hoãn).
4. Booking studio tạo trước thay đổi này không có `assigneeAccepted` và đọc như thành viên S26.

## Ghi chú cho unit khác

- **#139 (Đăng việc) sẽ xung đột ở `app_flutter/lib/features/work/work_screen.dart`:** S27 tạo `SegmentedTabs` "Hôm nay" · "Tuyển thợ" (`WorkSegment.today`, `WorkSegment.recruit`); #139 chèn hai đoạn của nó vào giữa (Decision 20). Ai gộp sau giữ "Tuyển thợ" ở cuối và giữ việc giữ bộ lọc tuyển (`_recruitFilter`).
- Mọi client khác truy vấn `bookings` theo `assigneeId` (dashboard web #167…) phải thêm `assignStatus == 'assigned'` (rules từ chối truy vấn chỉ theo `assigneeId`).
- S23 (#83): cờ không trả (`unpaidFlags`), cờ chào khách (`staff_flags`), gỡ `recruitBlockedUntil` và hộp thư staff cho `collab_pay_disputed`.

## Hoãn (plan)

- Chia tiền hoặc chi hộ cho CTV trong app, nền tảng khấu trừ thuế (spec §10 phương án A): cần luật sư, kế toán và đối tác chi hộ.
- Studio và CTV đánh giá nhau; thù lao theo %; thu phí đẩy tin; vai trò "quản lý"; nhiều thợ một booking; loại tin nhân viên (spec §10).
- Lời "Xin cộng tác" do thợ gửi (`requested`, `initiatedBy: collaborator`): enum giữ, chưa có callable hay màn.
- Màn staff: cờ không trả, cờ chào khách, gỡ `recruitBlockedUntil` ở dashboard S23 (Phase 1.5, #83); tới đó dùng console.
- Lọc liên hệ trong tin nhắn chat booking; lưu hoặc chia sẻ CSV thành tệp (không thêm package).
- Xếp hạng 200 người nhận fan-out; job backfill `recruitMatchKeys`.
- Máy chủ riêng: migration và route S27 (Phase 2, #90); `relational-schema.md` là đích.
- Duyệt pháp lý điều khoản cộng tác và "dịch vụ việc làm" (spec §11) — việc của chủ dự án, không phải code.

## Kết quả review cuối (controller điền)

- **Review từng task:** Task 2, 3, 5, 6, 7 Approved ngay (0 Critical/Important; Minor chuyển sang commit đầu của task sau, xem "Minor chuyển task sau"). Task 4 Needs fixes (2 Important) → 1 vòng sửa (c3cefe8e) → sạch. Task 8 Needs fixes (1 Important: S27.05 còn ứng viên trả lời được dưới tin đã đóng/hết hạn) → 1 vòng sửa (989f0374) → sạch.
- **Review lại Task 9** (chỉ đọc, song song với Task 10): lần đầu Needs fixes (1 Important: "Từ chối" ở S27.07 từ chối ngay) → 1 vòng sửa (1 Important + 10 Minor, 2ebf2fad..8922f693) → sạch, 0 Critical/Important. Ba Minor để đợt sửa cuối (router `Uri.tryParse`, thứ tự import test, bí danh `*Subtle` tối).
- **Review Task 10** (81aa75ba, chỉ tài liệu): gộp vào phần tài liệu của review cuối (D1–D6 bên dưới).
- **Review cuối toàn nhánh:** 3 reviewer song song (máy chủ, app, tài liệu; diff ~1,5 MB chia theo vùng), cả ba "With fixes", 0 Critical. Important: S1 thành viên được giao lại sau offer không được báo (`assigned` bị chống trùng); S2 fan-out `recruit_post_new` bỏ qua chặn; A1 lỗi offer CTV ở S26.04 chỉ hiện "Chưa thực hiện được. Thử lại."; D1 ledger thiếu ba mục FINAL WAVE của Task 9. Minor: S3–S5, A2–A6, D2–D6.
- **Đợt sửa cuối (final wave), một implementer:**
  - 682253ea `fix(domain)`: S1 (`booking_assigned` cho người được giao lại, khoá có `assignedAt`, chỉ người được giao), S2 (bỏ thợ chặn hoặc bị chặn trước khi tốn lượt trong ngày), S3 (`refunded` chỉ khi mọi khoản đã chia mốc), S4 (kiểm chặn trước giao dịch khi ứng tuyển), S5 (README seed: Hòa chỉ nhận làm CTV). Test domain và Functions.
  - df401f41 `fix(collab)`: A1 (`assignOfferErrorText`: `deadline_passed`, `recruit_blocked` kèm ngày, `blocked`, `not_found`; studio bị khoá tuyển thấy nhóm "Cộng tác viên" mờ kèm dòng khoá), A2 (`from` hỏng về trang chủ), A3 (S27.05 đọc lại ứng viên khi `applicationCount` đổi), A4 ("Đã mời làm thành viên" thay cho "Mời" khi có lời mời S26 đang chờ), A5 (`AppIconSize.sm`), A6 (thứ tự import). 4 khoá ARB mới.
  - 04b49e3d `docs(s27)`: D2 (mốc huỷ là `shootEndsAt`), D3 (plan S27 Decision 26), D4 (gộp dòng `CountdownText`), D5 (`seq` tăng dần, lớn nhất là mới nhất), D6 (cột `job_ids`), và ghi các thay đổi hành vi của đợt này vào spec thiết kế và `screens/recruit.md`.
  - Commit này `docs(s27)`: D1 (ba mục Task 9 ở "Ứng viên cho đợt sửa cuối", ghi chú `from` ở quyết định Task 9, phần kết quả này).
- **Giữ hoãn sau review cuối (có lý do):**
  - `endCollaboration` đếm `openJobCount` ngoài giao dịch: cửa sổ vài mili giây; job và trả tiền của việc lọt vẫn chạy.
  - Offer đang chờ bị thay bằng offer khác: CTV cũ không được báo (offer biến mất khỏi S27.06/S27.07).
  - S27.01 vẫn hiện tin của studio mà người xem đã chặn: chỉ hiển thị; ứng tuyển bị máy chủ từ chối `blocked`.
  - Bộ đọc mốc ném lỗi liên tục, job chờ mốc kiểm lại mỗi 6 giờ không giới hạn: chưa gặp ở khối lượng phase 1.
  - CTV chưa có trong `assignmentOptions` (không có "Rảnh/Bận"): thay đổi domain + Functions riêng; máy chủ từ chối `day_taken`.
  - Fan-out chạy lại vào ngày VN khác tốn một suất; khoá khớp cũ sau lối tắt "đầu vào không đổi"; ứng tuyển sót sau đóng tin dở dang kết thúc `expired`: như "Minor hoãn".
  - CTV trả việc vẫn giữ booking và liên hệ tới khi được giao người khác: theo tiền lệ thành viên S26.
  - Booking huỷ vẫn mở liên hệ cho CTV 7 ngày: câu hỏi cho chủ dự án (mục 5).
  - "Thù lao cần trả" lấy 50 job theo `updatedAt` có thể sót job `due`/`disputed` cũ: đủ cho phase 1; sau này truy vấn theo `payStatus`.
  - `_selected` ghi trong `build`; tông `*_result` cần `variant`; bí danh `*Subtle` của `AppColorsDark` (mức token).
- PR: (điền khi mở)
- Re-review đợt sửa cuối: mọi Important đã sửa; D5 (dòng ánh xạ `seq`) sửa trong commit này. Để sau: `recruit_blocked` khi luồng bộ đếm chưa kịp cập nhật `recruitBlockedUntil` rơi về dòng chung "Thử lại" (tạm thời, vài giây); `_send` của S26.04 chép thân `runStudioAction` thay vì thêm tham số `errorText`.
- CI (firestore-rules, lần chạy thật đầu tiên): truy vấn `bookings` chỉ lọc `assigneeId` cho phép cộng tác viên đang chờ liệt kê booking (query được xét theo bộ lọc, `get(field, default)` của trường không lọc đọc ra giá trị mặc định). Sửa: tách `allow get` (xét theo tài liệu) và `allow list` (người được giao bắt buộc lọc `assignStatus == 'assigned'`), kèm rules test (commit af66c8bb).
