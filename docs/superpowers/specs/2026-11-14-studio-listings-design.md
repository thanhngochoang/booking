# Danh bạ studio thu thập từ web (điểm chưa xác thực trên bản đồ)

Ngày: 2026-11-14 · Trạng thái: **bản nháp chờ chủ dự án duyệt** (brainstorm 2026-11-14; các mục ghi "người viết chọn" chưa được chủ dự án xác nhận) · Dựa trên: `data-model/README.md` (quy ước id, thời gian, địa lý, mã chuỗi), `2026-10-05-provider-types-portfolio-jobs-design.md` (ba loại nhà cung cấp), `2026-10-06-identity-verification-design.md` (xác minh để nhận đơn), `2026-10-01-instant-booking-design.md` (bản đồ Goong + `maplibre_gl`), `2026-10-01-remaining-screens.md` §3c.2 (vị trí gần đúng).

## 1. Mục tiêu

Lúc ra mắt, app có rất ít studio đã đăng ký, nên bản đồ quanh người dùng trống. Ta thu thập thông tin công khai của các studio ảnh trên địa bàn từ web, chuẩn hoá về một dạng chung và nạp vào cơ sở dữ liệu. Các studio này hiện trên bản đồ của app như **điểm chưa xác thực**: người dùng thấy studio chuyên chụp thể loại gì, ở đâu, website và cách liên hệ. Điểm chưa xác thực không có ảnh đại diện và không đặt lịch được qua app. Khi studio thật đăng ký tài khoản và được xác minh, điểm đó được thay bằng hồ sơ studio.

Thành công nghĩa là:

- Ở khu vực thí điểm, người dùng mở bản đồ và thấy studio quanh mình, lọc được theo thể loại chụp.
- Dữ liệu sạch: trong mẫu 100 điểm đã công bố, ít nhất 90 điểm đúng là studio ảnh còn hoạt động và không quá 3 cặp trùng nhau.
- Một studio đăng ký và được xác minh thì điểm cũ của họ biến mất, hồ sơ thật thế chỗ, không tồn tại song song.

## 2. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| L1 | Điểm chưa xác thực hiện: thể loại chụp, vị trí, website, liên hệ. Có nhãn "Chưa xác thực", **không có ảnh đại diện**. | chủ dự án 2026-11-14 |
| L2 | Công cụ thu thập dữ liệu từ web, **nhiều nguồn**; làm **chuẩn hoá dữ liệu trước**, từng nguồn cắm vào sau. | chủ dự án 2026-11-14 |
| L3 | Studio đăng ký **và được xác minh** thì điểm được thay bằng tài khoản studio. | chủ dự án 2026-11-14 |
| L4 | Điểm thu thập là thực thể riêng `studio_listings`, **không** phải dòng `photographers` (bảng này bắt buộc có `user_id`, và điểm thu thập không nhận đơn). | người viết chọn |
| L5 | Dữ liệu nằm ở **PostgreSQL của `booking-be`**; app đọc qua API tự host (thêm `SelfhostedRepo.studioListings`). Bản build chạy Firebase thuần không có tính năng này. Xem câu hỏi mở Q3. | người viết chọn |
| L6 | Quy trình năm bước tách rời: **thu thập → chuẩn hoá → gộp trùng → duyệt → công bố**. Bản ghi thô giữ nguyên văn để chuẩn hoá lại được khi luật thay đổi. | người viết chọn |
| L7 | Luật chuẩn hoá và gộp trùng là hàm thuần trong `packages/domain`; công cụ dòng lệnh, kho dữ liệu và API là lớp mỏng trong `booking-be`. | quy ước repo (AGENTS.md) |
| L8 | **Ngoại lệ luật liên hệ:** điểm chưa xác thực hiện số điện thoại, Zalo, Facebook, website lấy từ nguồn công khai. Luật "liên hệ chỉ mở sau khi thanh toán" vẫn áp dụng nguyên vẹn cho mọi nhà cung cấp có tài khoản. Điểm đã được nhận thì API không trả liên hệ thu thập nữa. | chủ dự án 2026-11-14 ("website và phần liên hệ"); cần xác nhận lại ở Q1 vì chạm luật "không được nới" |
| L9 | Chỉ lưu **dữ kiện**: tên, địa chỉ, toạ độ, liên hệ, website, thể loại. **Không sao chép ảnh, bài mô tả, đánh giá, điểm sao** từ nguồn. | người viết chọn (bản quyền; khớp L1 "không avatar") |
| L10 | Điểm chưa xác thực hiện **địa chỉ và toạ độ chính xác** (địa chỉ kinh doanh công khai, như điểm chụp S29). Luật "chỉ lộ tới quận" của studio có tài khoản không đổi. | người viết chọn; xem Q5 |
| L11 | Mỗi điểm có lối **"Báo thông tin sai / Yêu cầu gỡ"**; staff ẩn được ngay bằng dòng lệnh. Điểm bị gỡ theo yêu cầu không được nạp lại ở lần thu thập sau. | người viết chọn |
| L12 | Nhận điểm (claim) do **staff duyệt** bằng dòng lệnh ở giai đoạn đầu, giống duyệt xác minh và giải thưởng. | người viết chọn |
| L13 | Thí điểm một khu vực trước (mặc định TP.HCM), rồi mở rộng theo từng thành phố. | người viết chọn; xem Q4 |
| L14 | Luật tiền, luật nhận đơn (chỉ nhà cung cấp đã xác minh và được duyệt), vị trí gần đúng của người dùng: **giữ nguyên**. | AGENTS.md |
| L15 | Điểm khớp với một **tài khoản đã có** (cùng điện thoại hoặc tên miền website) thì không hiện liên hệ thu thập nữa, kể cả khi studio chưa gửi yêu cầu nhận điểm. Cách kiểm tra phụ thuộc Q3. | người viết chọn (hệ quả của luật liên hệ) |
| L16 | Một tài khoản studio **nhận được nhiều điểm** (chuỗi nhiều chi nhánh). Mọi điểm đã nhận đều rời bản đồ; hồ sơ studio hiện một ghim ở địa chỉ đã đăng ký. Hiện từng chi nhánh của studio có tài khoản là việc sau. | người viết chọn |
| L17 | Người không dùng app yêu cầu gỡ qua **email hỗ trợ** ghi trên sheet của điểm; staff ghi nhận bằng dòng lệnh. Không mở endpoint không đăng nhập. | người viết chọn |

## 3. Không làm, và những điều phải tránh

**Không làm trong đợt này:** thu thập thợ cá nhân (chỉ studio); đặt lịch, chat hay đánh giá với điểm chưa xác thực; tự động gửi tin mời studio vào app; giao diện web cho staff (dùng dòng lệnh); xếp hạng điểm chưa xác thực trong gợi ý của recommender.

**Phải tránh (làm đúng kỹ thuật mà vẫn hỏng):**

- Điểm chưa xác thực trông như studio trên nền tảng: có nút đặt lịch, huy hiệu, ảnh, hoặc lẫn vào danh sách "Tìm thợ ảnh". Người dùng phải luôn phân biệt được.
- Điểm thu thập làm lộ liên hệ của studio **đã có tài khoản** (đi vòng qua luật liên hệ sau thanh toán).
- Hai ghim cho cùng một studio (điểm cũ và hồ sơ mới cùng hiện).
- Lần thu thập sau ghi đè chỉnh sửa tay của staff, hoặc làm sống lại điểm đã gỡ.
- Số điện thoại thu thập xuất hiện trong log, thông báo lỗi hay kết quả test (theo cùng kỷ luật với số tài khoản ở S06.06).

## 4. Mô hình dữ liệu (PostgreSQL, `booking-be`)

Theo `data-model/README.md`: id ULID, thời điểm UTC, mã chuỗi `snake_case`, toạ độ `lat`/`lng` kèm `geohash` dài 9, mảng thành bảng liên kết.

### 4.1 `listing_source_records` (bản ghi thô, mỗi nguồn một dòng cho mỗi studio)

| Cột | Ghi chú |
|---|---|
| `id` | ULID |
| `source` | Mã nguồn: `manual`, `osm`, `website`, `directory_<tên>`, `google_places`, `facebook` (hai nguồn cuối chờ Q2) |
| `source_ref` | Khoá của bản ghi ở nguồn (id của nguồn, hoặc URL chuẩn hoá). Duy nhất theo (`source`, `source_ref`) |
| `source_url` | Trang gốc, để staff kiểm tra và để hiện "Nguồn" |
| `run_id`, `fetched_at` | Lần chạy và thời điểm lấy |
| `payload` | `jsonb`, nguyên văn nguồn trả về |
| `payload_hash` | Phát hiện bản ghi không đổi giữa hai lần chạy |
| `normalized` | `jsonb`, kết quả chuẩn hoá (§5.2); `normalize_version` ghi phiên bản luật đã dùng |
| `status` | `new` \| `normalized` \| `rejected`; `reject_reason` (`not_photo_studio`, `no_location`, `outside_area`, `invalid`) |
| `listing_id` | Điểm mà bản ghi này được gộp vào (rỗng khi chưa gộp hoặc bị loại) |

### 4.2 `studio_listings` (điểm đã gộp, thứ app nhìn thấy)

| Cột | Ghi chú |
|---|---|
| `id` | ULID |
| `name`, `name_key` | Tên hiển thị (≤ 80 ký tự) và khoá so khớp (§5.2) |
| `address_line` | Địa chỉ như nguồn công bố |
| `city`, `area_code` | Mã thành phố và mã khu vực trong taxonomy `area`, suy từ toạ độ (không phân tích chữ "quận/phường", để không phụ thuộc thay đổi đơn vị hành chính) |
| `lat`, `lng`, `geohash` | Bắt buộc; `geohash` dài 9 |
| `website`, `website_host` | URL chuẩn hoá và tên miền để so khớp |
| `phone`, `zalo`, `facebook_url`, `instagram_url`, `email` | Liên hệ công khai; `phone` dạng E.164 |
| `status` | `draft` \| `published` \| `hidden` \| `claimed` \| `closed` |
| `hidden_reason` | `staff`, `removal_request`, `duplicate`, `stale` |
| `quality_score` | 0–1 (§5.4) |
| `claimed_by` | `photographers.user_id` của studio đã nhận (không duy nhất: một studio nhận được nhiều điểm, L16); `claimed_at` |
| `overrides` | `jsonb`: các trường staff sửa tay, luôn thắng dữ liệu nguồn |
| `field_sources` | `jsonb`: trường nào lấy từ bản ghi thô nào |
| `first_seen_at`, `last_seen_at`, `published_at`, `created_at`, `updated_at` | UTC |

Bảng liên kết `studio_listing_specialties (listing_id, specialty_id, confidence)`; `specialty_id` là mã trong taxonomy `specialty` (`wedding`, `portrait`, `graduation`, …).

Chỉ mục: `ix_studio_listings_geohash` trên `geohash text_pattern_ops` với điều kiện `status = 'published'`; chỉ mục thường trên `phone`, `website_host`, `name_key` cho bước gộp trùng.

### 4.3 `studio_listing_claims`

`id`, `listing_id`, `photographer_id`, `status` (`pending` \| `approved` \| `rejected` \| `withdrawn`), `match_reasons` (`phone`, `website_host`, `name_near`), `note`, `decided_by`, `decided_at`, `created_at`. Mỗi cặp (điểm, studio) chỉ có một yêu cầu `pending`.

### 4.4 `studio_listing_reports`

`id`, `listing_id`, `reporter_user_id` (rỗng khi staff ghi hộ yêu cầu gửi qua email, L17), `reason` (`wrong_info` \| `closed` \| `not_studio` \| `duplicate` \| `removal_request`), `note` (≤ 300 ký tự), `status` (`open` \| `resolved`), `created_at`.

## 5. Quy trình

```
nguồn web ──thu thập──▶ listing_source_records ──chuẩn hoá──▶ normalized
                                                                │ gộp trùng
                                                                ▼
                         staff duyệt ◀── studio_listings (draft) ──công bố──▶ published ──▶ API ──▶ bản đồ
```

### 5.1 Thu thập (bộ chuyển đổi theo nguồn)

Mỗi nguồn là một bộ chuyển đổi cùng giao diện: nhận khu vực (mã thành phố hoặc khung toạ độ), trả về dòng bản ghi thô. Lõi không biết gì về nguồn; thêm nguồn mới không đụng tới chuẩn hoá hay gộp trùng.

| Nguồn | Lấy gì | Ghi chú pháp lý (người viết ghi theo hiểu biết, **phải kiểm tra điều khoản hiện hành trước khi làm bộ chuyển đổi**) | Đợt |
|---|---|---|---|
| `manual` | Tệp CSV/NDJSON do staff soạn hoặc xuất từ công cụ khác | Không vướng | 1 |
| `osm` | OpenStreetMap qua Overpass: `shop=photo`, `craft=photographer`, `amenity=studio` + `studio=photography` | Giấy phép ODbL: được lưu, phải ghi nguồn "© OpenStreetMap contributors" | 1 |
| `website` | Website riêng của studio: dữ liệu có cấu trúc (JSON-LD `LocalBusiness`), thẻ meta, trang liên hệ | Thông tin doanh nghiệp tự công bố; tôn trọng `robots.txt`, giới hạn tốc độ | 2 |
| `directory_*` | Trang danh bạ doanh nghiệp, mỗi trang một bộ chuyển đổi | Xét điều khoản từng trang | 2 |
| `google_places` | Google Maps | Điều khoản Google Maps Platform cấm cào trang và hạn chế lưu nội dung Places ngoài `place_id`. **Chờ Q2** | chờ |
| `facebook` | Trang Facebook của studio | Điều khoản Meta cấm thu thập tự động khi chưa được phép. **Chờ Q2** | chờ |

Nguồn không có toạ độ (website, danh bạ) đi qua cổng `Geocoder` (địa chỉ → toạ độ). Bộ chuyển đổi đầu tiên dùng Goong (cùng nhà cung cấp bản đồ của app); bản ghi không ra được toạ độ bị loại với `no_location`.

Mọi bộ chuyển đổi: có `User-Agent` nhận diện, giới hạn tốc độ, chạy lại an toàn (cùng `source` + `source_ref` thì cập nhật, không thêm dòng).

### 5.2 Chuẩn hoá (hàm thuần, `packages/domain`)

Đầu vào là `payload` của một nguồn đã được bộ chuyển đổi đưa về dạng trung gian `{name, addressLine, lat, lng, phones[], urls[], tags[], text}`. Đầu ra là `normalized`:

- **Lọc "có phải studio ảnh không":** từ khoá nhận (studio, ảnh viện, photo, chụp ảnh, wedding studio…) và từ khoá loại (photocopy, in ảnh lấy liền, phòng thu, yoga, nail, xăm, gym, cửa hàng máy ảnh…). Không qua thì `rejected: not_photo_studio`.
- **Tên:** bỏ khoảng trắng thừa, emoji, đuôi quảng cáo; giữ cách viết hoa của nguồn. `name_key` = chữ thường, bỏ dấu, bỏ từ chung (studio, photo, photography, ảnh viện, áo cưới), bỏ ký tự không phải chữ số.
- **Điện thoại:** về E.164 (`+84…`); đổi đầu số di động 11 số cũ sang 10 số; nhận số bàn có mã vùng; số sai định dạng bị bỏ. Số di động đầu tiên là `phone`.
- **Website và mạng xã hội:** URL về `https`, tên miền chữ thường, bỏ `www.` và tham số theo dõi. Tên miền Facebook, Instagram, Zalo, trang gom link đi vào trường mạng xã hội, không phải `website`.
- **Toạ độ:** phải nằm trong khung Việt Nam và trong khu vực đang chạy (không thì `outside_area`); tính `geohash` 9; `city` và `area_code` suy từ bảng tâm khu vực `(mã khu vực, mã thành phố, lat, lng)` đặt trong `packages/domain`, lấy từ danh sách khu vực app đang dùng (`builtInAreas`), U1 nạp cho khu vực thí điểm. Taxonomy `area` hiện chưa có toạ độ, nên bảng này là dữ liệu mới. Điểm nằm ngoài bán kính của mọi khu vực thì chỉ có `city`, `area_code` để trống.
- **Thể loại:** từ điển từ khoá tiếng Việt và tiếng Anh ánh xạ sang mã `specialty` (cưới/pre-wedding → `wedding`; kỷ yếu → `graduation`; em bé/newborn → `newborn`; gia đình → `family`; chân dung/beauty → `portrait`; sản phẩm → `product`; thời trang/lookbook → `fashion`; sự kiện → `event`; món ăn → `food`; nội thất/bất động sản → `real_estate`…), mỗi mã kèm độ tin cậy; tối đa 5 mã. Không đoán được thì để trống, app hiện "Chưa rõ thể loại".

Từ điển và danh sách từ khoá là dữ liệu trong `packages/domain`, có test bảng ví dụ. Đổi luật thì tăng `normalize_version` và chạy lại bước này trên bản ghi thô đã lưu, không cần thu thập lại.

### 5.3 Gộp trùng (hàm thuần)

Hai bản ghi đã chuẩn hoá là **cùng một studio** khi có một trong các điều kiện:

1. Cùng `phone` và cách nhau ≤ 300 m.
2. Cùng `website_host` và cách nhau ≤ 300 m.
3. `name_key` giống nhau ≥ 0,85 (độ giống chuỗi) và cách nhau ≤ 100 m.

Chuỗi studio nhiều chi nhánh dùng chung đường dây nóng hoặc website nhưng ở xa nhau là **các điểm khác nhau**. Cặp gần đạt ngưỡng (ví dụ cùng điện thoại nhưng cách 300–2.000 m) được ghi là "nghi trùng" cho staff xem, không tự gộp.

Khi gộp, mỗi trường lấy theo thứ tự ưu tiên: chỉnh sửa của staff (`overrides`) → `manual` → `website` → `osm` → `directory_*` → nguồn khác. Riêng toạ độ ưu tiên nguồn bản đồ hơn toạ độ suy từ địa chỉ. Thể loại là hợp của các nguồn, giữ độ tin cậy cao nhất. `field_sources` ghi lại lựa chọn.

Điểm ở trạng thái `claimed` hoặc `hidden` vì `removal_request` vẫn tham gia so khớp, để bản ghi mới của cùng studio rơi vào điểm đó thay vì tạo điểm mới.

### 5.4 Duyệt và công bố

`quality_score` cộng điểm cho: có ≥ 2 nguồn trùng khớp; có website hoặc điện thoại; có thể loại; toạ độ từ nguồn bản đồ; trừ điểm khi có cặp "nghi trùng" chưa xử lý. Điểm mới ở `draft`. Staff xuất danh sách ra CSV để xem, rồi công bố theo lô (ví dụ mọi điểm của một thành phố có `quality_score` ≥ 0,7), hoặc ẩn, sửa, gộp tay từng điểm.

Điểm không còn thấy ở bất kỳ nguồn nào sau 180 ngày chuyển sang `hidden` với lý do `stale` (chờ staff xem). Nguồn báo đã đóng cửa thì `closed`.

### 5.5 Công cụ dòng lệnh (`booking-be`, `npm run listings -- <lệnh>`)

Theo mẫu `tools/firestore-import`: mỗi lệnh chạy lại được nhiều lần, có `--dry-run`, in báo cáo số liệu; từ chối chạy với cơ sở dữ liệu production nếu không có cờ xác nhận.

| Lệnh | Việc |
|---|---|
| `collect --source <mã> --area <mã>` | Chạy một bộ chuyển đổi, ghi bản ghi thô |
| `import --source manual --file <tệp>` | Nạp CSV/NDJSON |
| `normalize [--all]` | Chuẩn hoá bản ghi `new` (hoặc tất cả khi đổi phiên bản luật) |
| `merge` | Gộp trùng, tạo hoặc cập nhật `studio_listings` |
| `review --city <mã> --out <csv>` | Xuất danh sách để staff xem, gồm cả cặp nghi trùng |
| `publish --city <mã> --min-score <n>` · `hide <id>` · `edit <id> --set trường=giá trị` · `merge-into <id> <id>` | Công bố và sửa tay |
| `claims list` · `claims approve <id>` · `claims reject <id>` | Duyệt yêu cầu nhận điểm (§7) |
| `reports list` · `reports add --listing <id> --reason <mã>` · `reports resolve <id>` | Xử lý báo sai; `add` để staff ghi yêu cầu gửi qua email |
| `stats` | Số điểm theo trạng thái, nguồn, thành phố |

## 6. API và app

### 6.1 API (`api/openapi.yaml`, người dùng đã đăng nhập)

- `GET /v1/studio-listings?cell=<geohash 4–6 ký tự>&radiusKm=<1–50>&specialtyId=&cursor=&limit=<≤ 50>`: điểm `published` quanh một ô. App gửi **ô geohash**, không gửi toạ độ chính xác của người dùng (luật vị trí gần đúng); khoảng cách thật do app tính trên máy.
- `GET /v1/studio-listings/{id}`: chi tiết một điểm. Điểm `claimed` trả về chuyển hướng tới hồ sơ studio (`claimedBy`), không kèm liên hệ thu thập.
- `POST /v1/studio-listings/{id}/reports`: báo sai hoặc yêu cầu gỡ.
- `POST /v1/studio-listings/{id}/claims`: studio (đã đăng nhập, `providerType = studio`) xin nhận điểm. `GET /v1/me/studio-listing-claims`: yêu cầu của mình.

Trả về: `id`, `name`, `specialtyIds`, `addressLine`, `city`, `areaCode`, `lat`, `lng`, `website`, `phone`, `zaloUrl`, `facebookUrl`, `instagramUrl`, `sources` (nhãn nguồn để ghi công, ví dụ OpenStreetMap), `verified: false`. Test hợp đồng hiện cấm trường điện thoại ở lược đồ công khai; `StudioListing.phone` được thêm vào danh sách cho phép **có tên rõ ràng**, không nới luật chung.

Truy vấn: tiền tố geohash của ô và 8 ô kề (như app đang làm với Firestore), lọc lại bằng khoảng cách tới tâm ô. Quy mô dự kiến vài chục nghìn điểm toàn quốc nên chưa cần PostGIS.

### 6.2 App (ticket riêng ở repo app)

- Cổng `StudioListingRepository` với bộ chuyển đổi HTTP; thêm `SelfhostedRepo.studioListings`.
- **Bản đồ "Studio quanh đây"** (use case mới, mã `Sxx` kế tiếp còn trống; vẽ khung mock trước khi code): bản đồ thật bằng `maplibre_gl` + Goong như spec Chụp ngay đã chọn. Hai loại ghim: studio đã xác minh (ảnh đại diện, màu thương hiệu) và điểm chưa xác thực (biểu tượng chung màu trung tính, không ảnh). Lọc theo thể loại. Dưới bản đồ là danh sách sắp theo khoảng cách.
- **Chạm điểm chưa xác thực** mở sheet: tên, nhãn "Chưa xác thực", thể loại, địa chỉ, khoảng cách, website, liên hệ, dòng "Thông tin thu thập từ nguồn công khai" kèm nguồn, "Báo thông tin sai", "Đây là studio của bạn?". Không có nút đặt lịch, không chat, không đánh giá.
- Studio có tài khoản lấy từ nguồn dữ liệu hiện có của app; app ghép hai nguồn trên bản đồ và **bỏ điểm đã `claimed`**.
- Điểm chưa xác thực không xuất hiện trong "Tìm thợ ảnh" (S02.06) và trong gợi ý.

## 7. Studio nhận điểm

1. **Gợi ý:** khi một tài khoản studio đặt địa chỉ studio, số liên hệ hoặc website, máy chủ tìm điểm khớp theo cùng luật gộp trùng (§5.3) và ghi gợi ý. Studio thấy "Có phải đây là studio của bạn?" trong phần thiết lập.
2. **Yêu cầu:** studio xác nhận gợi ý, hoặc bấm "Đây là studio của bạn?" trên một điểm. Tạo `studio_listing_claims` ở `pending` kèm `match_reasons`.
3. **Duyệt:** staff duyệt bằng dòng lệnh. Khớp điện thoại hoặc tên miền website với thông tin studio đã khai là bằng chứng mạnh; chỉ khớp tên và vị trí thì staff kiểm tra thêm.
4. **Thay thế:** yêu cầu được duyệt **và** tài khoản studio đã xác minh (`verified`) thì điểm chuyển `claimed`, ghi `claimed_by`. Từ lúc đó điểm không còn trên bản đồ, hồ sơ studio thế chỗ, API không trả liên hệ thu thập. Yêu cầu được duyệt mà studio chưa xác minh thì điểm vẫn hiện như cũ cho tới khi xác minh xong.
5. **Dữ liệu cũ:** thể loại và website của điểm được **đề nghị** cho studio điền sẵn vào hồ sơ; studio bấm nhận, không tự chép. Dòng `studio_listings` giữ lại để lần thu thập sau không tạo lại điểm.

Trong lúc chờ (studio đã có tài khoản nhưng chưa nhận điểm, hoặc đã được duyệt nhận nhưng chưa xác minh), điểm vẫn hiện nhưng **không kèm liên hệ thu thập** (L15).

Studio bị thu hồi xác minh hoặc xoá tài khoản: điểm trở lại `published` (staff quyết định bằng dòng lệnh, không tự động).

## 8. Chi phí và vận hành

- Lưu trữ: vài chục nghìn dòng, không đáng kể. Không có ảnh.
- Geocoding và bản đồ Goong: tính phí theo lượt gọi, **chưa xác nhận bảng giá**; chỉ geocode bản ghi thiếu toạ độ, lưu kết quả, không gọi lại.
- Thu thập chạy tay từ máy staff ở giai đoạn đầu (API Postgres chưa có bộ chạy định kỳ). Lịch chạy lại định kỳ là ticket sau.

## 9. Chia việc (đề xuất)

| # | Phần | Repo | Phụ thuộc |
|---|---|---|---|
| U1 | Lược đồ + luật chuẩn hoá và gộp trùng + dòng lệnh `import/normalize/merge/review/publish` + nguồn `manual` và `osm` | `booking-be` | — |
| U2 | API quanh đây, chi tiết, báo sai; cập nhật bản chụp hợp đồng ở app | `booking-be` | U1 |
| U3 | Nguồn đợt 2: `website`, `directory_*`, cổng `Geocoder` | `booking-be` | U1 |
| U4 | Khung mock + thư viện bản đồ + màn "Studio quanh đây" | app | U2 |
| U5 | Nhận điểm: gợi ý, yêu cầu, duyệt, thay thế | `booking-be` + app | U2, U4 |
| U6 | Chạy lại định kỳ, điểm cũ, số liệu | `booking-be` | U3 |

U1 làm trước vì chủ dự án muốn tập trung chuẩn hoá dữ liệu trước; U1 không cần app, không cần nguồn nào có rủi ro pháp lý, và không phụ thuộc Q3. U2–U5 chờ câu trả lời Q3.

## 10. Câu hỏi mở (chủ dự án quyết)

| # | Câu hỏi | Mặc định nếu chưa trả lời |
|---|---|---|
| Q1 | Điểm chưa xác thực hiện cả **số điện thoại và Zalo**, hay chỉ website và mạng xã hội? (Luật hiện tại: điện thoại, Zalo chỉ mở sau thanh toán.) | Hiện cả điện thoại và Zalo (L8) |
| Q2 | Google Maps và Facebook là hai nguồn đầy đủ nhất nhưng điều khoản của họ hạn chế thu thập và lưu trữ. Bỏ qua, chỉ dùng API chính thức trong giới hạn cho phép, hay vẫn cào? | Chưa làm hai nguồn này; làm `manual`, `osm`, `website`, danh bạ trước |
| Q3 | **Tính năng chạy ở đâu?** App phát hành đang chạy trên Firestore: tài khoản studio, `providerType` và trạng thái xác minh nằm ở đó, và chưa có gì đồng bộ sang PostgreSQL. U1 (chuẩn hoá và nạp dữ liệu) không bị ảnh hưởng. Nhưng U2–U5 cần chọn một trong ba: (a) API `booking-be` được triển khai và app gọi tới, việc nhận điểm và kiểm tra tài khoản (L15, §7) đọc dữ liệu tài khoản qua một bước đồng bộ Firestore → PostgreSQL; (b) công bố điểm sang một collection Firestore, nhận điểm chạy bằng dòng lệnh Admin SDK như các công cụ staff khác; (c) đợi di trú sang PostgreSQL xong mới làm U2–U5. | Chưa có mặc định dùng được; **cần trả lời trước khi lên kế hoạch U2** |
| Q4 | Khu vực thí điểm? | TP.HCM |
| Q5 | Sau khi studio nhận điểm, ghim của studio đặt ở địa chỉ chính xác (đã công khai từ trước) hay chỉ tới mức quận như luật hiện tại? | Giữ luật hiện tại (tới mức quận), studio tự bật "hiện địa chỉ chính xác" nếu muốn |
| Q6 | Dữ liệu cá nhân: số di động của chủ studio nhỏ có thể là dữ liệu cá nhân theo Nghị định 13/2023. Có cần ý kiến pháp lý trước khi công bố không? | Có lối yêu cầu gỡ (L11); hỏi pháp lý trước khi mở rộng ngoài khu vực thí điểm |
