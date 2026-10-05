# Portfolio album, giải thưởng và loại nhà cung cấp

Màn của phần A–C trong [`../2026-10-05-provider-types-portfolio-jobs-design.md`](../2026-10-05-provider-types-portfolio-jobs-design.md) (gọi là "spec 10-05"). Mẫu mục và quy ước chung ở [`README.md`](README.md). Mock: `docs/design/ui-mock.html`, mục "Loại nhà cung cấp", S03, S08, S10, S24, S25.

---

## Thay đổi ở màn đã có

### S02.06 · Tìm thợ ảnh: dấu và nhãn loại
- `PhotographerCard` dùng `ProviderMark` cạnh tên và `ProviderTag` dưới tên (NAG: "Nhiếp ảnh gia · {n} giải"; Studio: "Studio · {quận}"). Photographer không có nhãn.
- **Chấp nhận**: ba loại phân biệt được khi tắt màu (hình dấu khác nhau, có chữ); trình đọc màn hình đọc "Lê Hoàng Vũ, Nhiếp ảnh gia đã duyệt, 7 giải".

### S03.01 · Hồ sơ: biến thể NAG và tab Portfolio
- **NAG**: dấu vàng + `ProviderTag`; hàng thống kê `StatTile` thứ hai là "giải thưởng" (thay "phản hồi"); hàng `AwardChip` (tối đa 2 thấy được, cuộn ngang, chạm → danh sách giải đầy đủ dạng sheet chỉ đọc) nằm chỗ hàng huy hiệu; huy hiệu dời xuống dưới bio.
- **Tab Portfolio**: `PortfolioViewToggle` Album / Dòng thời gian + số album bên phải. Album: lưới `AlbumTile` 2 cột, album đầu rộng hết hàng (16:7). Dòng thời gian: masonry như cũ, mọi bài `work` + `real_shoot` của thợ ảnh. Mặc định và ẩn/hiện nút gạt theo spec 10-05 mục 3.1.
- Chủ hồ sơ thấy thêm "Sắp xếp" cạnh nút gạt → S24.02.
- **Dữ liệu**: `albumsProvider(uid)` (album không trống, theo `position`), `timelineProvider(uid)` phân trang 24 bài.
- **Chuỗi**: `s03_tabAlbums` "Album", `s03_tabTimeline` "Dòng thời gian", `s03_albumCount` "{n} album", `s03_awards` "giải thưởng", `s03_arrange` "Sắp xếp".
- **Chấp nhận**: hồ sơ không có album không trống thì không có nút gạt; đổi nút gạt giữ vị trí cuộn của từng chế độ.

### S08.01 · Thiết lập hồ sơ bước 1: "Hình thức"
- Thêm câu hỏi "Bạn nhận việc với tư cách" với hai `AppOptionTile`: **Cá nhân** ("Bạn tự chụp và nhận booking. Có giải thưởng? Thêm sau để lên hạng Nhiếp ảnh gia (NAG).") và **Studio** ("Cơ sở kinh doanh chụp ảnh, có địa chỉ. Thêm thành viên: sắp có."). Mặc định Cá nhân.
- Studio: nhãn ô tên thành "Tên studio"; S08.05 thêm ô "Địa chỉ cơ sở" (bắt buộc).
- Dòng ghi chú: "Đổi Cá nhân ↔ Studio được trong Cài đặt khi không còn booking đang chạy."
- **Chuỗi**: `s0801_typeTitle` "Bạn nhận việc với tư cách", `s0801_typeIndividual` "Cá nhân", `s0801_typeStudio` "Studio", `s0801_studioName` "Tên studio".

### S10.01 · Đăng bài: ô Album
- Công tắc "Thêm vào portfolio" bỏ; thay bằng ô **Album · tuỳ chọn** (giá trị: album dùng gần nhất, hoặc "Không xếp album") mở S24.05. Ảnh trong lưới mock đổi về tỉ lệ 16:10 để vừa một màn; Flutter vẫn dùng ô vuông khi đủ chỗ.
- **Chấp nhận**: đăng bài với album → bài ở cuối album đó và ở đầu Dòng thời gian; không chọn album → chỉ ở Dòng thời gian.

### S09.01 · Hồ sơ cá nhân: dòng Thông báo
- Dòng "Thông báo" ngay dưới tên: biểu tượng chuông trong vòng tròn tô nhạt, tiêu đề, tóm tắt thông báo mới nhất, chấm số chưa đọc, mũi tên → S17.01. Số chưa đọc cũng hiện trên tab Hồ sơ (`TabBadge`). Không còn chuông ở đầu trang các màn khác (spec 10-05 mục 8).
- Thợ ảnh hồ sơ Cá nhân chưa là NAG có thêm dòng nhắc "Có giải thưởng? Lên hạng Nhiếp ảnh gia" → S25.01 (ẩn khi đã bấm "Để sau").

---

## S24.01 · Chi tiết album

- **Thông tin**: `/u/:uid/albums/:albumId` · cả hai · C2 · Chưa có.
- **Mục đích**: xem một bộ ảnh như một album, vẫn có đường tới đặt lịch.
- **Điểm vào → ra**: `AlbumTile` ở S03.01, album đính kèm ở S15.04 → S02.02 (chạm bài, vuốt trong phạm vi album), S04.01 (Đặt lịch), S07.01 (Nhắn tin hỏi trước).
- **Bố cục**: thanh trên Back · Chia sẻ · "…"; tên album (Fraunces 24); hàng tác giả (avatar nhỏ, tên, `ProviderMark`, "· {n} bài · {m} ảnh"); mô tả; masonry 2 cột theo `albumPosition`, bài nhiều ảnh có số đếm góc trên phải; `AppFooterBar` nút chat + "Đặt lịch · từ {giá}".
- **Dữ liệu**: `albumProvider(albumId)`, `albumPostsProvider(albumId)` phân trang 24.
- **Trạng thái**: album trống hoặc bị xoá → `EmptyState` "Album này không còn" + "Xem hồ sơ"; chủ hồ sơ xem album trống thấy "Album chưa có bài" + "Thêm bài" (S24.04).
- **Tương tác**: "…" của người khác: Báo cáo (S20.01). Của chủ: Sửa (S24.03), Thêm bài (S24.04), Sắp xếp bài (chế độ sắp xếp tại chỗ: tay nắm trên từng ô + menu "Chuyển lên đầu / Chuyển xuống cuối / Bỏ khỏi album"), Xoá album (`ConfirmSheet` nút đỏ).
- **Chuỗi**: `s2401_counts` "{posts} bài · {photos} ảnh", `s2401_empty` "Album chưa có bài", `s2401_gone` "Album này không còn".
- **Phân tích**: `album_view{albumId, owner}`, `album_share`.
- **Chấp nhận**: thứ tự bài đúng `albumPosition`; vuốt ở S02.02 dừng ở bài cuối của album; link chia sẻ mở đúng album.

## S24.02 · Album của tôi

- **Thông tin**: `/me/albums` · thợ ảnh · C3 · Chưa có.
- **Mục đích**: tạo và sắp xếp album như xếp thư mục.
- **Điểm vào → ra**: "Sắp xếp" ở S03.01 (của mình), S09.01 → S24.03, S24.04, S24.01.
- **Bố cục**: thanh trên Back · "Album của tôi" · "+"; dòng hướng dẫn; danh sách `ReorderableRow` (tay nắm ≡, ảnh bìa 44 có viền chồng, tên, "{n} bài · {m} ảnh", "…"); album trống mờ kèm "Trống · chưa hiện công khai"; dòng cuối cố định "Chưa xếp album · {n} bài · chỉ ở Dòng thời gian" (viền đứt, không kéo được) → S24.04 ở chế độ xếp; nút chính "Album mới".
- **Dữ liệu**: `myAlbumsProvider`; `reorderAlbums(ids)` ghi một lần khi thả.
- **Trạng thái**: chưa có album → `EmptyState` "Gom bài thành album để khách xem theo bộ" + "Album mới"; đang lưu thứ tự → hàng mờ nhẹ, lỗi → trả về thứ tự cũ + SnackBar "Chưa lưu được thứ tự".
- **Tương tác**: nhấn giữ tay nắm rồi kéo (rung nhẹ khi nhấc); "…" → Chuyển lên / Chuyển xuống / Sửa / Xoá. Sau khi thả: SnackBar "Đã đổi thứ tự" + "Hoàn tác" (5 giây).
- **Chuỗi**: `s2402_title` "Album của tôi", `s2402_hint` "Thứ tự dưới đây là thứ tự trên hồ sơ. Giữ ≡ rồi kéo, hoặc chạm … → Chuyển lên / xuống.", `s2402_unsorted` "Chưa xếp album", `s2402_unsortedSub` "{n} bài · chỉ ở Dòng thời gian", `s2402_emptyAlbum` "Trống · chưa hiện công khai", `s2402_new` "Album mới".
- **Phân tích**: `album_reorder{count}`, `album_create`.
- **Chấp nhận**: mọi thao tác kéo có đường làm bằng menu; trình đọc màn hình đọc vị trí "2 trên 5" và thông báo vị trí mới sau khi chuyển.

## S24.03 · Tạo / sửa album (sheet)

- **Thông tin**: sheet trên S24.02 / S24.01 / S24.05 · thợ ảnh · C3 · Chưa có.
- **Bố cục**: tiêu đề "Album mới" / "Sửa album" + nút đóng; ô Tên (bắt buộc, đếm "n / 40"); ô Mô tả (tuỳ chọn, ≤ 300); hàng "Ảnh bìa" (giá trị "Tự động: ảnh đầu tiên của album" + nút "Chọn ảnh", vô hiệu khi album trống); ghi chú; nút chính "Tạo và thêm bài" (mới) hoặc "Lưu" (sửa); ở chế độ sửa thêm chữ đỏ "Xoá album".
- **Kiểm tra**: tên trống hoặc trùng → lỗi dưới ô ("Bạn đã có album tên này"); 30 album → nút "+" ở S24.02 vô hiệu kèm lý do.
- **Tương tác**: tạo xong mở thẳng S24.04 cho album mới; mở từ S24.05 thì quay lại S24.05 với album mới đã chọn. Đóng khi đã nhập → hỏi "Bỏ thay đổi?".
- **Chuỗi**: `s2403_new` "Album mới", `s2403_edit` "Sửa album", `s2403_name` "Tên album · bắt buộc", `s2403_desc` "Mô tả · tuỳ chọn", `s2403_cover` "Ảnh bìa", `s2403_coverAuto` "Tự động: ảnh đầu tiên của album", `s2403_create` "Tạo và thêm bài", `s2403_delete` "Xoá album", `s2403_deleteBody` "Bài trong album không bị xoá, chuyển về Chưa xếp album.", `s2403_dup` "Bạn đã có album tên này".
- **Chấp nhận**: xoá album → mọi bài có `albumId = null`, hồ sơ cập nhật ngay.

## S24.04 · Thêm bài vào album (sheet)

- **Thông tin**: sheet cao tối đa 92% · thợ ảnh · C3 · Chưa có.
- **Bố cục**: tiêu đề "Thêm bài vào album" + "{n} đã chọn"; `SegmentedTabs` "Chưa xếp · {n}" / "Tất cả bài · {n}"; `PostPickerGrid` 3 cột (ô chọn có số thứ tự, bài nhiều ảnh ghi "{n} ảnh", bài đã ở album khác ghi tên album); dòng cảnh báo khi có bài sẽ chuyển album; nút chính "Thêm {n} bài".
- **Dữ liệu**: `myPostsProvider(filter)` phân trang 30; `movePostsToAlbum(albumId, postIds)` (thêm vào cuối theo thứ tự chọn).
- **Trạng thái**: không có bài → "Đăng bài trước" + nút mở S10.01; chạm tới 200 bài → ô còn lại vô hiệu, dòng "Album đã đủ 200 bài".
- **Chuỗi**: `s2404_title` "Thêm bài vào album", `s2404_selected` "{n} đã chọn", `s2404_unsorted` "Chưa xếp · {n}", `s2404_all` "Tất cả bài · {n}", `s2404_moveWarn` "{n} bài đang ở \"{album}\" sẽ chuyển sang album này.", `s2404_add` "Thêm {n} bài".
- **Chấp nhận**: bài chuyển album thì rời album cũ và album cũ dồn thứ tự; số trên ô khớp thứ tự sau khi thêm.

## S24.05 · Chọn album khi đăng (sheet)

- **Thông tin**: sheet trên S10.01 · thợ ảnh · C1 · Chưa có.
- **Bố cục**: tiêu đề "Xếp vào album"; `AppOptionTile` radio: "Không xếp album · Chỉ hiện ở Dòng thời gian", rồi các album (ảnh bìa 40, tên, số bài, "dùng gần nhất" cho album gần nhất); nút viền "Album mới" (→ S24.03).
- **Tương tác**: chọn là đóng sheet và điền ô ở S10.01; album gần nhất lưu cục bộ (`SharedPreferences`, theo uid).
- **Chuỗi**: `s2405_title` "Xếp vào album", `s2405_none` "Không xếp album", `s2405_noneSub` "Chỉ hiện ở Dòng thời gian", `s2405_recent` "dùng gần nhất", `s2405_new` "Album mới".
- **Chấp nhận**: tạo album mới từ đây quay lại với album đó được chọn.

---

## S25.01 · Giải thưởng của tôi

- **Thông tin**: `/me/awards` · thợ ảnh · B1 · Chưa có.
- **Mục đích**: khai giải, theo dõi duyệt và biết còn bao nhiêu nữa thì lên NAG.
- **Điểm vào → ra**: S09.02 "Giải thưởng", dòng nhắc ở S09.01, lối lên NAG ở S16.02 → S25.02.
- **Bố cục**: thanh trên Back · "Giải thưởng" · nút (i) (giải thích hạng NAG, sheet chỉ đọc); thẻ `GlassCard` viền spectrum: biểu tượng giải vàng, "Hạng Nhiếp ảnh gia (NAG)", "Còn {n} giải đã duyệt nữa để nhận tích vàng", số "{a} / 3", `CapacityBar`; `SectionHeader` "Đã khai · {n} giải"; danh sách `AwardRow` (biểu tượng, "{kết quả} · {cuộc thi} {năm}", `StatusBadge` + hạng mục hoặc lý do); nút chính "Thêm giải thưởng".
- **Trạng thái**: chưa có giải → `EmptyState` "Giải thưởng giúp khách tin tác phẩm của bạn" + nút chính; đã là NAG → thẻ thành "Bạn là Nhiếp ảnh gia · từ {ngày}"; hồ sơ Studio → không có thẻ hạng, chỉ danh sách.
- **Tương tác**: chạm giải `needs_info` / `rejected` / `pending` / `approved` mở S25.02 để sửa (sửa giải đã duyệt hỏi xác nhận "Giải sẽ được duyệt lại"); nhấn giữ → Xoá (`ConfirmSheet`).
- **Chuỗi**: `s2501_title` "Giải thưởng", `s2501_tier` "Hạng Nhiếp ảnh gia (NAG)", `s2501_remaining` "Còn {n} giải đã duyệt nữa để nhận tích vàng", `s2501_isArtist` "Bạn là Nhiếp ảnh gia · từ {date}", `s2501_listed` "Đã khai", `s2501_add` "Thêm giải thưởng", trạng thái `awardPending` "Chờ duyệt", `awardApproved` "Đã duyệt", `awardNeedsInfo` "Bổ sung", `awardRejected` "Từ chối", `awardRevoked` "Đã thu hồi".
- **Phân tích**: `award_view_list{approved, pending}`.
- **Chấp nhận**: trạng thái luôn có chữ; lý do của staff hiện nguyên văn; khi giải thứ 3 được duyệt, thẻ đổi sang "Bạn là Nhiếp ảnh gia" không cần tải lại (nghe `photographers/{uid}`).

## S25.02 · Thêm / sửa giải thưởng (sheet)

- **Thông tin**: sheet cao tối đa 94% · thợ ảnh · B1 · Chưa có.
- **Bố cục**: tiêu đề + nút đóng; ô "Cuộc thi / triển lãm · bắt buộc"; hàng ô "Năm" (4 chữ số, 1950–năm nay) + "Hạng mục"; chip chọn đơn "Kết quả · bắt buộc" (Vàng / Nhất, Bạc / Nhì, Đồng / Ba, Khuyến khích, Top / Chung kết, Chọn triển lãm); ô "Tác phẩm · tuỳ chọn" (chọn một bài của mình, hiện thumb); ô "Minh chứng · bắt buộc" mở sheet con (tối đa 3 ảnh + 2 link https); ghi chú khoá "Minh chứng chỉ đội duyệt xem và được xoá 30 ngày sau khi duyệt xong. Duyệt trong 3 ngày làm việc."; nút chính "Gửi duyệt".
- **Kiểm tra**: thiếu trường bắt buộc → lỗi dưới ô; link không phải https → "Link phải bắt đầu bằng https://"; ảnh > 10 MB → nén trước khi tải.
- **Dữ liệu**: `createAward` / `updateAward`; ảnh minh chứng tải lên đường riêng tư `awardProofs/{awardId}/…`.
- **Chuỗi**: `s2502_add` "Thêm giải thưởng", `s2502_edit` "Sửa giải thưởng", `s2502_competition` "Cuộc thi / triển lãm · bắt buộc", `s2502_year` "Năm", `s2502_category` "Hạng mục", `s2502_result` "Kết quả · bắt buộc", `s2502_work` "Tác phẩm · tuỳ chọn", `s2502_proof` "Minh chứng · bắt buộc", `s2502_privacy` (ghi chú trên), `s2502_submit` "Gửi duyệt".
- **Phân tích**: `award_submit{result, hasWork, proofs}`.
- **Chấp nhận**: không gửi được khi thiếu minh chứng; huỷ giữa chừng không để ảnh mồ côi (xoá tệp đã tải khi đóng không lưu).
